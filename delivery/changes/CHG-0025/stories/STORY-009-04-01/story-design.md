---
story-id: "STORY-009-04-01"
change-id: "CHG-0025"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
feature-path: "FEAT-009/FEAT-009-04/FEAT-009-04-01/STORY-009-04-01"
---

# Story Design（Story 技术设计）— 延迟订单自动取消

## 0. 元信息

- Change ID：CHG-0025；Story ID：STORY-009-04-01（REQ-M7-004，P1）
- 前置依赖：STORY-009-01-01（MQ 基础设施）、STORY-009-02-01（Outbox）、STORY-009-03-01（findStatusById/事件发布）；M4 OrderCancelService CAS 取消全流程
- 两 DU：DU-BE-004（repo-1：mall-order 延迟消息全链路 + admin 后端）、DU-FE-002（repo-2：mall-admin 延迟任务页）

### DU 划分表

| DU ID | 仓库 | 范围 | 覆盖 AC | 前置 DU |
|---|---|---|---|---|
| DU-BE-004 | repo-1 | outbox_event 加 delay_level 列；建单追加 PAYMENT_TIMEOUT_CHECK 事件 + assembler 扩展 + 动态超时策略/级别映射 + EventRouter 延迟路由；回查消费者（PaymentTimeoutCheckHandler）；超时兜底扫描器；DelayTaskAdminController（列表/手动取消）+ mall-identity V14 权限菜单种子 | AC-026~031 | DU-BE-002、DU-BE-003 |
| DU-FE-002 | repo-2 | mall-admin：distributed.ts 延迟任务 API + DelayTaskListView.vue（列表/状态筛选/手动取消）+ component-registry 注册 | AC-032 | DU-BE-004 |

### 现状事实（已核实）

- 契约常量已在 S1 落位：`EventTopics.AIMALL_ORDER_DELAY="aimall-order-delay"`、`EventTags.PAYMENT_TIMEOUT_CHECK`、`ConsumerGroups.ORDER_DELAY_CONSUMER_GROUP`；Payload DTO `OrderDelayPayload(String orderId, String orderNo, Instant expireAt)` 已存在。
- `EventRouter` 预留扩展点（`register`）且注释明确指向本 Story；`SendTarget(topic, delayLevel)` 已支持延迟发送，`OutboxDeliveryTask` 已按 `target.isDelayed()` 分支调 `producer.sendDelay`。
- outbox_event 表无 delay_level 列（V4 建表）；`OutboxRecordWriter.append(aggregateId, eventType, envelope)` 不携带级别。
- mall-order 已在 S3 具备：Order 聚合 `integrationEvents` 收集/`pullIntegrationEvents()`、`MyBatisOrderRepository` insert/transition 的同事务 flush 挂点（flush 在 id 回填之后）、`OrderRepository.findStatusById`、`OrderEnvelopeAssembler`（paymentDeadline 当前读静态 @Value）。
- mall-order 未依赖 mall-common-config；mall-cart/mall-search 已依赖该包读取动态参数，自动配置带默认值（mall.config.enabled matchIfMissing=true）。
- 不存在"扫描超时待支付订单"的既有组件——兜底扫描器在本 Story 新建。
- 测试库 H2 MySQL 模式 + Flyway 执行全部迁移；管理端 SQL 须同时兼容 H2 与 MySQL。

## 1. 模块改动（Module Changes）

### 1.1 数据变更：outbox_event 延迟级别列

新增 mall-order 迁移 `V5__outbox_delay_level.sql`：

```sql
ALTER TABLE outbox_event ADD COLUMN delay_level INT NOT NULL DEFAULT 0 AFTER event_type;
```

- 0=即时投递（既有四事件）；1~18=RocketMQ 延迟级别。
- 级别在**业务事务 flush 时**落定（与 payload 的 expireAt 同时刻、同一超时值计算），投递任务直接读取——避免"flush 后参数被修改导致级别与 expireAt 漂移"。
- H2/MySQL 均支持该语法；既有数据默认 0 语义不变。

同步改动：`OutboxEvent` 领域对象增加 `delayLevel`（构造器/ reconstitute/getter）、`OutboxEventPo` 增加字段、`OutboxEventMapper` result 映射自动承载、`OutboxEventRepository.save` 插入 delay_level；`OutboxAdminDtos.OutboxView` 追加 delayLevel（Outbox 管理页表格新增列，属同仓顺带完善）。

`OutboxRecordWriter` 新增重载：

```java
public void append(String aggregateId, String eventType, Envelope envelope, int delayLevel)
```

原三参方法委托四参（delayLevel=0），既有调用零改动。

### 1.2 动态超时策略与延迟级别映射

pom 新增依赖 `mall-common-config`（${project.version}）。

新增 `application/order/timeout/PaymentTimeoutPolicy.java`（@Component）：

- 构造器注入 `SystemParameterProvider` + `@Value("${order.payment.timeout-minutes:30}") long defaultMinutes`；
- `long timeoutMinutes()`：`systemParameterProvider.getLong("order.payment.timeout-minutes", defaultMinutes)`——缺键/非法值由 provider 回退默认 + WARN 限流；本地 TTL 缓存保证动态生效窗口 ≤ mall.config.local-ttl-seconds（AC-031）。

新增 `application/order/timeout/DelayLevelMapper.java`（无状态 @Component）：

RocketMQ 18 级时长（秒）：

| level | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 秒 | 1 | 5 | 10 | 30 | 60 | 120 | 180 | 240 | 300 | 360 | 420 | 480 | 540 | 600 | 1200 | 1800 | 3600 | 7200 |

- `int toLevel(long timeoutMinutes)`：找 **≥ 目标时长的最小级别**（向上对齐，保证消息不早于 expireAt 到期）；目标 >7200s 封顶 level 18（尽力而为，WARN）；timeoutMinutes ≤0 视为非法回退 level 16（30 分钟，对齐默认值语义）+ WARN。
- 30 分钟 → level 16（恰好 1800s）；1 分钟 → level 5。
- 新增 `@Value("${mall.order.delay.force-level:0}") int forceLevel`：0=按映射；非 0 时强制该级别（**仅供 Integration Gate 短延迟验证 AC-027**，生产配置保持 0）。

### 1.3 领域事件：建单追加延迟检查

- `OrderIntegrationEventType` 枚举追加 `PAYMENT_TIMEOUT_CHECK`（值与 EventTags 同名）。
- `Order.create(...)` 在追加 ORDER_CREATED 后，再追加 `new OrderIntegrationEvent(PAYMENT_TIMEOUT_CHECK)`——两事件同处一个列表、一次 flush 成对落库（AC-026 同事务）。
- 其余迁移点不产生该事件。

### 1.4 Assembler 与 Flusher 扩展

`OrderEnvelopeAssembler` 改动：

- `assemble` 签名改为 `assemble(Order order, OrderIntegrationEvent event, long timeoutMinutes)`——**超时分钟数由 flusher 在循环前读取一次传入**，保证同单两事件使用同一超时值。
- ORDER_CREATED 的 paymentDeadline 改用传入 timeoutMinutes（替换原静态 @Value 读取；构造器移除该 @Value 依赖）。
- PAYMENT_TIMEOUT_CHECK：eventType=`EventTags.PAYMENT_TIMEOUT_CHECK`，payload=`new OrderDelayPayload(String.valueOf(order.getId()), order.orderNo(), order.createdAt().plus(timeoutMinutes, MINUTES))`。
- `toTag` 增加 PAYMENT_TIMEOUT_CHECK 映射。

`OutboxOrderEventFlusher.flush` 改动：

1. 进入异步分支后先 `long timeoutMinutes = paymentTimeoutPolicy.timeoutMinutes()` 读取一次；
2. 逐事件 assemble 传入该值；
3. writer 调用按事件类型区分：PAYMENT_TIMEOUT_CHECK → `append(aggregateId, tag, envelope, delayLevelMapper.toLevel(timeoutMinutes))`（forceLevel 非 0 时覆盖）；其余 → 原三参 append（delayLevel=0）。

### 1.5 EventRouter 延迟路由注册

`EventRouter.initDefaultRoutes` 追加：

```java
register(EventTags.PAYMENT_TIMEOUT_CHECK, new SendTarget(EventTopics.AIMALL_ORDER_DELAY, 0));
```

- 路由目标固定为 delay Topic；delayLevel 不从 SendTarget 取（该列只表达"是否延迟"），实际级别以 outbox_event.delay_level 为准。
- `OutboxDeliveryTask.deliver` 调整发送分支：

```java
int delayLevel = target.isDelayed() ? target.delayLevel() : event.getDelayLevel();
if (delayLevel > 0) producer.sendDelay(target.topic(), envelope, delayLevel);
else producer.sendSync(target.topic(), envelope);
```

既有四事件两路值均为 0，行为不变；延迟消息级别来自落库列。

### 1.6 回查消费者

新增 `application/order/consumer/PaymentTimeoutCheckHandler.java`：

- 类注解：`@Component` + `@ConditionalOnProperty(name="rocketmq.enabled", havingValue="true")` + `@IntegrationEventListener(topic=AIMALL_ORDER_DELAY, eventType=PAYMENT_TIMEOUT_CHECK, consumerGroup=ORDER_DELAY_CONSUMER_GROUP, maxSupportedVersion=1)`；
- `extends AbstractIntegrationHandler<OrderDelayPayload>`，构造器 `(ObjectMapper, IdempotentConsumer, OrderRepository, OrderCancelService)`。
- `handle(envelope, payload)` 逻辑（**以库中当前状态为唯一裁决依据，不使用消息快照**）：
  1. `orderRepository.findStatusById(Long.parseLong(payload.orderId()))`；
  2. empty（订单不存在）→ `markSkipped` + WARN「延迟检查订单不存在，数据异常单查」，ACK（错误语义见 story-spec §4）；
  3. status == PENDING_PAYMENT → `orderCancelService.systemCancel(orderId, "PAYMENT_TIMEOUT", "DELAY_MESSAGE")`；
  4. status ∈ {PAID, SHIPPED, COMPLETED, CANCELLED} → `markSkipped` + INFO/WARN（AC-028）。
- 幂等两层：eventId 占位（处理链自动）+ 订单 CAS（systemCancel 内），Outbox 重投 N 次只取消一次（AC-029）。
- systemCancel 抛异常 → 处理链删占位 + RECONSUME_LATER；超限进 RocketMQ DLQ。**DLQ → ORDER_AUTO_CANCEL 补偿登记由 STORY-009-05-01 DU-BE-005 衔接**（依赖图 BE-005 depends on BE-004）。

`OrderCancelService` 新增系统取消入口并重构共用：

```java
public Order systemCancel(long orderId, String reason, String source)
```

- 按 id 加载（不做归属校验），404 同既有；
- operator 标记 = `"SYS:" + source`（source ∈ DELAY_MESSAGE / TIMEOUT_FALLBACK / ADMIN_MANUAL），写入 history 可审计；
- 状态裁决/CAS/异步返回/同步降级 releaseAfterCancel 与会员 `cancel` 完全共用私有 `doCancel(Order, operator, reason)`；CANCELLED 幂等返回；CAS 落败重读：CANCELLED 幂等返回，其余状态 409（消费者侧对 409 视为状态已变化，捕获后 markSkipped 不重试——在 handler 内把 STATUS_CONFLICT 归一为跳过，避免无意义重试）。
- 原 `cancel(memberId, orderNo, reason)` 薄化为：loadOwned → doCancel(operator=memberId)。

### 1.7 定时兜底扫描器

新增 `application/order/timeout/OrderTimeoutFallbackScanner.java`（@Component）：

- `@Scheduled(fixedDelayString="${mall.order.timeout-fallback.fixed-delay-ms:60000}")`，开关 `mall.order.timeout-fallback.enabled`（默认 true；@ConditionalOnProperty）。
- 仓储新增（端口 + Impl + Mapper）：
  - `List<ExpiredOrder> findExpiredPending(int limit, Instant cutoff)`：
    `SELECT id, order_no FROM orders WHERE status='PENDING_PAYMENT' AND created_at < #{cutoff} LIMIT #{limit}`；
  - cutoff = now − timeoutMinutes（策略动态值）；limit @Value 默认 100。
- 逐单调 `systemCancel(id, "PAYMENT_TIMEOUT", "TIMEOUT_FALLBACK")`：
  - 单条异常 catch 记 WARN 不中断整轮；订单仍 PENDING → 下轮天然重试；CAS 已被延迟路径抢先 → CANCELLED 幂等返回（AC-030 双路径无双重取消）。
- 多实例并发：无分布式锁，CAS 裁决，与既有 CompensationService 同模式。

### 1.8 管理端后端 API

新增 `interfaces/rest/admin/DelayTaskAdminController.java`（`/api/admin/order-delay/tasks`）：

- `GET`（`@PreAuthorize("hasAuthority('order-delay:list')")`）参数：`status`（PENDING/CANCELLED/FAILED，可空）、page/size。
- 任务视图为三源派生（新增 `infrastructure/persistence/order/DelayTaskAdminMapper` + service 编排）：
  - PENDING：orders 中 PENDING_PAYMENT；
  - CANCELLED：orders 中 CANCELLED 且 cancel_reason='PAYMENT_TIMEOUT'；
  - FAILED：outbox_event 中 event_type='PAYMENT_TIMEOUT_CHECK' 且 status='FAILED'（LEFT JOIN orders 取 order_no，订单缺失时 order_no 显示 aggregate_id）。
- 单条 SQL `UNION ALL` 三同构 SELECT（派生列 delay_status），`LIMIT/OFFSET` 分页 + `COUNT(*)` 包装查询；视图字段：`{orderId, orderNo, delayStatus, createdAt, cancelledAt, lastError}`（H2 MySQL 模式与 MySQL 均支持，避免 JSON 函数差异，expireAt 不在列表展示，可经 Outbox 页查 payload）。
- `POST /{orderId}/cancel`（`@PreAuthorize("hasAuthority('order-delay:cancel')")`）：调 `systemCancel(orderId, reason 可传默认 "ADMIN_MANUAL", "ADMIN_MANUAL")`，独立审计 logger `order-delay-audit` 记录 operator/orderId/beforeStatus/afterStatus/at/traceId（AC-032）；返回最新任务视图。

权限/菜单种子：mall-identity 新增 `V14__order_delay_permissions.sql`（仿 V13 结构）：

- 权限码 `order-delay:list`（/api/admin/order-delay/tasks，GET）、`order-delay:cancel`（/api/admin/order-delay/tasks/*/cancel，POST）；
- 菜单页：挂"分布式增强"目录，name「延迟取消任务」，path `/distributed/delay`，component_key `DelayTaskList`，permission_code=`order-delay:list`；
- SUPER_ADMIN 补权限与菜单授权（INSERT IGNORE）。

### 1.9 配置

mall-order application.yml 增：

```yaml
mall:
  order:
    delay:
      force-level: ${ORDER_DELAY_FORCE_LEVEL:0}   # 仅集成测试短延迟用
    timeout-fallback:
      enabled: ${ORDER_TIMEOUT_FALLBACK_ENABLED:true}
      fixed-delay-ms: ${ORDER_TIMEOUT_FALLBACK_DELAY_MS:60000}
```

rocketmq 段 S2 已存在，不重复。

### 1.10 前端 DU-FE-002

- `src/api/distributed.ts` 追加：类型 `DelayTaskStatus='PENDING'|'CANCELLED'|'FAILED'`、`DelayTaskView`（5 字段）、`delayTaskApi.page({status,page,size})` / `delayTaskApi.cancel(orderId, reason?)`。
- 新增 `src/views/distributed/DelayTaskListView.vue`，复用 OutboxListView 模式：状态筛选（待取消/已取消/失败）、表格（orderNo、delay_status Tag、创建时间、取消时间、lastError）、PENDING 行「手动取消」按钮（el-popconfirm 二次确认，v-permission="'order-delay:cancel'"，成功 ElMessage + 刷新）；分页/空态/加载态对齐。
- `src/router/component-registry.ts` 注册 `DelayTaskList`；菜单经 V14 后端动态下发，不改静态 MenuItems。

## 2. 接口契约细化

- 延迟消息：topic=aimall-order-delay，Tag=PAYMENT_TIMEOUT_CHECK，keys=eventId，body=Envelope（payload `{orderId:String, orderNo:String, expireAt:epoch秒}`），delayLevel 由 outbox_event 列承载。
- `GET /api/admin/order-delay/tasks?status=&page=1&size=10`：出统一信封 PageView<DelayTaskView>；status 非法值返回全部（服务端忽略）。
- `POST /api/admin/order-delay/tasks/{orderId}/cancel`：body 可空（或 `{reason?}`）；404=订单不存在；409=当前状态不可取消（前端提示刷新）；成功返回该任务视图。
- 消费者错误语义：解析失败/业务异常 → RECONSUME_LATER；订单不存在/状态非 PENDING/409 冲突 → markSkipped ACK。

## 3. 数据变更

- mall-order：V5 迁移 outbox_event 加 delay_level 列；无新表。
- mall-identity：V14 权限 2 条 + 菜单 1 页 + SUPER_ADMIN 授权 DML。

## 4. 关键流程

### 4.1 创建 → 延迟到期 → 自动取消

```
OrderCreateService.create
  Order.create(): PENDING_PAYMENT + 收集 [ORDER_CREATED, PAYMENT_TIMEOUT_CHECK]
  repository.insert: 主表/行/历史 + id 回填（同事务）
    flush（同事务）:
      timeoutMinutes = policy.timeoutMinutes()   # 只读取一次
      ORDER_CREATED → append(delayLevel=0)
      PAYMENT_TIMEOUT_CHECK → append(delayLevel=mapper.toLevel(timeoutMinutes))
[提交后] OutboxDeliveryTask:
  ORDER_CREATED → aimall-order-events 即时
  PAYMENT_TIMEOUT_CHECK → aimall-order-delay + 存储级别延迟投递
[到期] PaymentTimeoutCheckHandler:
  findStatusById → PENDING_PAYMENT: systemCancel(doCancel: CAS + ORDER_CANCELLED 事件)
                  其余状态: markSkipped ACK
```

### 4.2 双路径竞争（AC-030）

```
延迟消息与 fallback 扫描器同时命中同一 PENDING 订单
  → 两侧均进入 doCancel → casCancel 仅一行命中（rows=1）
  → 负方重读：CANCELLED → 幂等返回；PAID（支付抢先）→ 409 → handler 归并 skip
库存释放：异步模式下由唯一 ORDER_CANCELLED 事件驱动（事件只可能有一条），无重复释放。
```

### 4.3 手动介入（AC-032）

```
admin POST /order-delay/tasks/{orderId}/cancel
  → systemCancel(source=ADMIN_MANUAL) → CAS 走同一聚合入口
  → order-delay-audit: operator/before/after/traceId
```

## 5. 测试策略（Test Strategy，详见 test-design）

- mall-order：
  - DelayLevelMapperTest：各级别边界（30m→16、1m→5、>120m→18、非法值）、向上对齐语义；
  - PaymentTimeoutPolicyTest：动态参数命中/缺键回退；
  - assembler：PAYMENT_TIMEOUT_CHECK payload（expireAt/orderId/orderNo）、ORDER_CREATED paymentDeadline 改传入值、同 flush 一次超时读取；
  - flusher：延迟事件带级别 append、forceLevel 覆盖、普通事件 delayLevel=0；
  - PaymentTimeoutCheckHandler：五状态分支、订单不存在 skip、409 归并 skip、正常触发 systemCancel；
  - OrderCancelService.systemCancel：加载/幂等/CAS 落败/异步返回/同步降级；
  - OrderTimeoutFallbackScanner：cutoff 查询、逐单取消、异常隔离、CAS 幂等；
  - DelayTaskAdminController：分页/筛选/手动取消 + 审计；Mapper union 三源用 H2 集成测试；
  - 仓储：V5 迁移列存在/默认值、save delay_level、findExpiredPending。
- mall-admin（前端）：distributed.ts delayTaskApi 单测（URL/参数/解包）、DelayTaskListView 状态映射与取消交互逻辑（参照既有 .spec.ts 纯逻辑测试模式）。
- 真实跨服务短延迟端到端（AC-027/029/030 运行态）归 M7 Integration Gate，converge 时以 force-level + 真实 RocketMQ 产出证据。

## 6. 非功能

- 延迟消息替代轮询库扫描：每订单仅一次到期触发，无空扫描成本；fallback 扫描周期 60s 且只查索引列（idx status/created_at）。
- 配置动态生效窗口 ≤ 本地 TTL（默认随 mall.config），无需重启；新订单生效，存量订单以其落库级别/expireAt 为准（预期语义）。
- 可观测：延迟级别映射 WARN（封顶/非法）、订单不存在 WARN、跳过 INFO、降级 WARN、手动操作审计，traceId 全链。
- 与 Story 5 接缝：本 Story 只抛异常/DLQ，ORDER_AUTO_CANCEL 补偿类型与 Handler 在 DU-BE-005 新增，接口契约（source/operator/reason）本设计冻结。
