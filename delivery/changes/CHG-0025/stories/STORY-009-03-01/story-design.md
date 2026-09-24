---
story-id: "STORY-009-03-01"
change-id: "CHG-0025"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
feature-path: "FEAT-009/FEAT-009-03/FEAT-009-03-01/STORY-009-03-01"
---

# Story Design（Story 技术设计）— 订单集成事件与库存异步消费者

## 0. 元信息

- Change ID：CHG-0025；Story ID：STORY-009-03-01（REQ-M7-003，P0）
- 单 DU：DU-BE-003（repo-1：mall-order 发布侧 + mall-inventory 消费侧，同一仓库）
- 前置依赖：STORY-009-01-01（MQ 基础设施）、STORY-009-02-01（Outbox）；M2/M4 既有库存 lock/confirm/release 同步契约
- 无前端 DU：无新增用户可见页面（补偿任务在 M4 已有管理页可查）

### DU 划分表

| DU ID | 仓库 | 范围 | 覆盖 AC | 前置 DU |
|---|---|---|---|---|
| DU-BE-003 | repo-1 | mall-order：领域集成事件收集 + 事务内 Outbox flush（4 发布点）+ 订单状态/补偿登记 internal 端点；mall-inventory：2 消费者（确认扣减/释放 + 乱序裁决 + 失败登记补偿）+ mall-order 状态客户端 + 按 orderNo 枚举预留 | AC-018~025 | DU-BE-002 |

### 现状事实（已核实）

- 4 个订单事件 Payload DTO（OrderCreated/PaymentSucceeded/OrderCancelled/OrderCompletedEventPayload）已在 S1 随契约包落位，字段对齐 §41，**本 Story 不新增契约 DTO**。
- mall-order 事务边界在仓储层：`MyBatisOrderRepository.insert` / `transition` 标注 `@Transactional`；应用服务（PaymentService/OrderCancelService）本身无事务，confirm/release 当前在 CAS 成功后的方法调用栈内同步执行。
- mall-order 已有 `OutboxRecordWriter.append(aggregateId, eventType, envelope)`（@Transactional MANDATORY）；`EventRouter` 默认路由订单四事件 → aimall-order-events。
- mall-order / mall-inventory 两侧安全链均已对 `/api/internal/**` 配置 ROLE_SERVICE + `InternalIdentityFilter`（X-Internal-Token，共享密钥 `mall.security.internal.shared-secret`）。
- 库存 confirm/release 以 per-line reservationId（= `orderNo:skuId`）为幂等键，由预留状态 CAS 保证只产生一次数量变化；`inventory_reservation` 表 reservation_id 即该键，尚无"按订单枚举"查询方法。
- mall-inventory pom 未依赖 mall-common-mq / mall-event-contracts，需新增。
- mall-order 无聚合 ID 字段：orderId 为雪花主键，insert 后由 `assignPersistedId` 回填。

## 1. 模块改动（Module Changes）

### 1.1 mall-order：领域事件收集

新增 `domain/order/event/` 包：

- `OrderIntegrationEventType` 枚举：ORDER_CREATED / PAYMENT_SUCCEEDED / ORDER_CANCELLED / ORDER_COMPLETED（值与 EventTags 常量一一对应，领域层不反向依赖 contracts 包的字符串常量）。
- `OrderIntegrationEvent` record：`(OrderIntegrationEventType type)`，仅类型标记——Payload 组装所需全部数据在 flush 时从 Order 聚合当前状态读取，事件对象不做字段快照（避免与聚合状态双份维护）。
- Order 聚合改动：
  - 新增 `private final List<OrderIntegrationEvent> integrationEvents`；
  - `Order.create(...)` 追加 ORDER_CREATED；`pay()` 追加 PAYMENT_SUCCEEDED；`cancel()` 追加 ORDER_CANCELLED；`confirmReceipt()` 追加 ORDER_COMPLETED；
  - 构造/reconstitute 时初始化空列表（**从持久层重建的聚合不带待发事件**，事件只在一次业务迁移的内存周期内存在）；
  - `List<OrderIntegrationEvent> pullIntegrationEvents()`：取出并清空。
- CAS 落败（transition 返回 false）时被修改的聚合对象直接丢弃，其事件不会被 flush，无脏事件。

### 1.2 mall-order：事务内 Outbox flush

新增 application 端口 `application/order/event/OrderEventOutbox.java`：

```java
public interface OrderEventOutbox {
    /** 在当前事务内把聚合收集的事件 flush 到 Outbox；同步模式下取出丢弃。 */
    void flush(Order order);
}
```

实现 `application/order/event/OutboxOrderEventFlusher`：

1. `order.pullIntegrationEvents()`；无事件直接返回。
2. 异步模式（IntegrationMode.async()=true）：逐事件 → `OrderEnvelopeAssembler.assemble(order, event)` → `outboxRecordWriter.append(String.valueOf(order.getId()), type.tag(), envelope)`。MANDATORY 传播保证与业务数据在同一事务；append 抛异常 → 业务事务回滚（AC-018 发布原子性）。
3. 同步模式（rocketmq.enabled=false）：事件取出即丢弃，不产生 outbox 行。

新增 `OrderEnvelopeAssembler`（application/order/event/）：

- `Envelope assemble(Order order, OrderIntegrationEvent event)`：按类型构造 payload DTO → `objectMapper.valueToTree(dto)` → Envelope builder：
  - eventId=UUID、eventType=tag、eventVersion=EventVersions.CURRENT、occurredAt=now、producer="mall-order"、traceId=TraceContext.get()（可为空）、payload=JsonNode。
- 字段映射裁决（聚合上不存在的 §41 字段）：
  - 全部事件的 orderId：`String.valueOf(order.getId())`。
  - `reservationNo`：取 orderNo（订单级预留组标识；per-line reservationId = orderNo:skuId，库存侧据此枚举）。
  - PAYMENT_SUCCEEDED 的 paymentNo：M4 为模拟支付、聚合无支付单号字段 → 用确定性编号 `"PAY" + orderNo`；paymentAmount=money.payFen()、currency="CNY"、paidAt=order.paidAt()。
  - ORDER_CREATED 的 paymentDeadline：`order.createdAt()` + `order.payment.timeout-minutes`（@Value，默认 30，对齐 M5 超时配置口径）；orderAmount=money.payFen()。
  - ORDER_CANCELLED：cancelReason=order.cancelReason()（超时取消为 PAYMENT_TIMEOUT，允许为空）、cancelledAt=order.cancelledAt()。
  - ORDER_COMPLETED：memberId、completedAt。

仓储 flush 挂点（`MyBatisOrderRepository`，构造器新增 OrderEventOutbox 依赖）：

- `insert`：主表/行/历史落库 + id 回填完成后调 `orderEventOutbox.flush(order)`——ORDER_CREATED 的 payload 需要 orderId，故必须在回填之后。
- `transition`：仅 CAS 获胜（rows==1）并插入 history 后调 `flush(order)`；SHIP 迁移聚合不产生事件，flush 为 no-op。
- flush 与 CAS/history 在同一 @Transactional 内，原子提交。

### 1.3 mall-order：同步降级分支

新增组件 `IntegrationMode`（application/order/event/）：`@Value("${rocketmq.enabled:false}")` 唯一权威来源，方法 `boolean async()`。

- PaymentService.pay：CAS 获胜后——
  - async：不再同步 confirm（库存经事件消费确认）；
  - sync：执行既有 `confirmAfterPaid(order)`（逐行 inventoryPort.confirm，失败登记补偿），并记 WARN「RocketMQ 关闭，支付后同步确认扣减降级」。
- OrderCancelService.cancel：同构——sync 执行 `releaseAfterCancel(order)` + 降级 WARN；async 不同步释放。
- OrderCreateService 不变：lock 仍走同步 HTTP（锁库存发生在订单落库前，无法事件化）；ORDER_CREATED 事件在 sync 模式由 flusher 丢弃。
- ReceiptService 无需分支：ORDER_COMPLETED 只发布不订阅，sync 模式丢弃即可。

### 1.4 mall-order：internal 端点新增

- `interfaces/rest/internal/OrderStatusInternalController`：
  - `GET /api/internal/orders/{orderId}/status` → `{orderId, status}`；按 id 查询，不存在抛 BusinessException（404 语义）。供库存消费者乱序裁决。
- `interfaces/rest/internal/CompensationInternalController`：
  - `POST /api/internal/compensations`，body：`{orderId, orderNo, type(INVENTORY_CONFIRM_DEDUCT|INVENTORY_RELEASE), reason, lines:[{skuId, quantity, reservationId}]}`；
  - 按 type 调 `OrderCompensationPort.enqueueInventoryConfirm/Release`（登记幂等，复用 M4 既有实现）。供库存消费者业务失败时登记补偿（AC-023）。
- 两端点经既有安全链自动获得 X-Internal-Token / ROLE_SERVICE 保护，无需改安全配置。

### 1.5 mall-inventory：消费者

pom 新增：mall-event-contracts（纯契约）、mall-common-mq（${project.version}）。

新增 `infrastructure/client/OrderServiceClient.java`：

- RestClient，baseUri=`mall.inventory.order-uri`（默认 http://localhost:8105），默认头 X-Internal-Token + Trace 拦截器；
- `OrderStatusView getStatus(String orderId)`：GET `/api/internal/orders/{orderId}/status`；传输异常转 503 语义业务异常（触发消费重试）；
- `void registerCompensation(RegisterCompensationRequest request)`：POST `/api/internal/compensations`。

新增消费者（均 `@Component` + `@IntegrationEventListener(topic=AIMALL_ORDER_EVENTS, consumerGroup=INVENTORY_CONSUMER_GROUP, maxSupportedVersion=1)` + `@ConditionalOnProperty(name="rocketmq.enabled", havingValue="true")`——MQ 关闭时 handler Bean 不创建，容器零半开态）：

- `consumer/PaymentSucceededInventoryHandler extends AbstractIntegrationHandler<PaymentSucceededEventPayload>`：
  1. `orderStatus = orderServiceClient.getStatus(payload.orderId())`；查询失败抛异常 → RocketMQ 重试（保守不跳过）。
  2. orderStatus == CANCELLED → `markSkipped(...)` + WARN（eventId/orderId/当前状态），库存不变（AC-022）。
  3. 其余状态：经库存仓储新增方法 `findReservationIdsByOrderNo(orderNo)`（reservation_id LIKE `orderNo:%`，枚举订单全部 per-line 预留）；逐个：状态 DEDUCTED 跳过、LOCKED 调 `inventoryApplicationService.confirmDeduction(new ConfirmCommand(reservationId))`（M2 既有幂等语义，重复投递只扣一次，AC-019/021）。
  4. confirm 抛错：先调 `orderServiceClient.registerCompensation(INVENTORY_CONFIRM_DEDUCT, 失败行...)`（失败即登记，语义等价 DLQ 后补偿且更及时，AC-023；登记幂等允许重试时重复调用），再原样抛出交 RocketMQ 重试/DLQ。
- `consumer/OrderCancelledInventoryHandler extends AbstractIntegrationHandler<OrderCancelledEventPayload>`：
  1. 回查订单状态。
  2. orderStatus == COMPLETED → markSkipped + WARN（AC-022）。
  3. orderStatus == CANCELLED → 枚举预留并逐行 release（RELEASED 跳过、LOCKED 调 release；幂等——重复/乱序场景库存数据不变，AC-020/021）。
  4. PAID/SHIPPED 等与事件冲突的权威状态：订单状态是裁决权威，不执行释放 → markSkipped + WARN（保守防止误释放已确认/在途订单库存）。
  5. release 抛错：登记 INVENTORY_RELEASE 补偿后抛出。
- eventId 消费幂等（consumed_event 占位）由 S1 处理链自动承载；consumed_event 建表与组件通用化在 STORY-009-05-01，本 Story 消费者仅依赖 IdempotentConsumer 接口（单测 mock，运行时由 mall-common-mq 自动装配提供 Bean）。

库存仓储新增方法：

- `InventoryRepository.findReservationIdsByOrderNo(String orderNo)`：`SELECT reservation_id FROM inventory_reservation WHERE reservation_id LIKE #{orderNo} || ':%'`；Mapper 新增 @Select，返回 List<String>。

### 1.6 配置

- mall-order application.yml 增：
  ```yaml
  rocketmq:
    enabled: ${ROCKETMQ_ENABLED:false}
    name-server: ${ROCKETMQ_NAMESERVER:localhost:9876}
  ```
- mall-inventory application.yml 增同上 rocketmq 段 + `mall.inventory.order-uri` + internal shared-secret（dev 阶段核对现有配置后补，不覆盖既有键）。

## 2. 接口契约细化

- `GET /api/internal/orders/{orderId}/status`：出 `{orderId:String, status:String}`；404=订单不存在；401/403 由统一错误信封输出。
- `POST /api/internal/compensations`：type 仅接受 INVENTORY_CONFIRM_DEDUCT / INVENTORY_RELEASE；成功返回统一信封；lines 必填非空校验。
- 消费者错误语义沿用 S1：业务异常 → 删占位 + RECONSUME_LATER；乱序跳过 → markSkipped（consumed_event 结果 SKIPPED）+ ACK。
- at-least-once + 双层幂等（eventId 占位 + reservationNo/reservationId 业务 CAS），消息重复 N 次库存只变化一次。

## 3. 数据变更

- 本 Story 无新表、无表结构变更（outbox_event 已由 S2 建好；consumed_event 建表归 S5）。
- 无 DML（无新权限码/菜单）。

## 4. 关键流程

### 4.1 支付成功（异步模式）

```
PaymentService.pay
  order.pay() → 聚合 PAID + 收集 PAYMENT_SUCCEEDED
  repository.transition: CAS PENDING_PAYMENT→PAID + history（同事务）
    CAS 赢 → flush: assembler 组 Envelope → writer.append（同事务原子提交）
    CAS 输 → 对象丢弃，无事件
[提交后] OutboxDeliveryTask 投递 → inventory handler:
  回查订单状态 → CANCELLED: skip+warn | 否则逐行 confirm（幂等）
  confirm 失败 → 登记补偿 → 重试/DLQ
```

### 4.2 同步降级（rocketmq.enabled=false）

```
transition CAS（同 S2 前行为，flusher 丢弃事件）
  → confirmAfterPaid / releaseAfterCancel：同步 HTTP 调库存（M4 原路径）+ 降级 WARN
  → 失败行登记 M4 既有补偿
库存终态与异步路径一致（同一 confirm/release 业务逻辑）。
```

## 5. 测试策略（Test Strategy，详见 test-design）

- mall-order 单测：OrderEnvelopeAssemblerTest（4 事件 Payload/Envelope 字段）、OutboxOrderEventFlusherTest（async flush / sync 丢弃）、PaymentService/OrderCancelService 分支测试（async 不调同步路径、sync 降级调 + 失败补偿）、Order 聚合事件收集/拉取清空、两个 internal 端点测试；仓储单测补 flush 挂点验证。
- mall-inventory 单测：两 handler 各场景（正常逐行 confirm/release、乱序 skip+warn、状态查询失败抛出、业务失败登记补偿后抛出、已 DEDUCTED/RELEASED 跳过）。
- 跨服务端到端（真实投递+消费）归 M7 Integration Gate 七场景（AC-019/020/022 运行态证据在 Change converge 时产出）。

## 6. 非功能

- 异步化后支付/取消接口不再串行等待库存 confirm/release（建单 lock 仍同步），P99 下降；最终一致窗口 = outbox fixedDelay(5s) + 消费耗时。
- 无消费者时订单事件保留 SENT 状态可查；补偿链路与 M4 完全复用，不引入新组件。
- 可观测：降级 WARN、乱序 WARN（含 eventId/orderId/当前状态）、补偿登记、traceId 全链贯穿。
