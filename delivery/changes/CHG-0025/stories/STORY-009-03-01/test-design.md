# Test Design（TC 测试用例设计）— STORY-009-03-01 订单集成事件与库存异步消费者

## 0. 元信息

- Change ID: CHG-0025
- design 来源: requirement-design.md + stories/STORY-009-03-01/story-design.md
- feature-path: FEAT-009 > FEAT-009-03 > FEAT-009-03-01 > STORY-009-03-01
- TC 总数: 8（AC-018~025 全部有 Story 级验证；AC-019/020/022 的真实跨服务运行态证据另在 M7 Integration Gate 产出）

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 单测 OrderEnvelopeAssemblerTest | AC-018 | DU-BE-003 | 四事件各产出 Envelope：eventType/Tag 正确、eventVersion=1、producer=mall-order、eventId 非空；payload 字段对齐 §41 DTO（orderId/orderNo/reservationNo=orderNo/金额分/CNY/paymentNo=PAY+orderNo/paidAt/cancelReason/cancelledAt/completedAt/paymentDeadline=createdAt+timeout） |
| TC-002 | 单测 OutboxOrderEventFlusherTest + 仓储挂点测试 | AC-018 | DU-BE-003 | async：聚合 pull 的每事件 → writer.append(aggregateId=orderId, tag, envelope)，事件被清空；sync：事件丢弃、writer 零调用；MyBatisOrderRepository.insert 在 id 回填后 flush、transition 仅 CAS 赢时 flush（输则不 flush） |
| TC-003 | 单测 PaymentServiceTest / OrderCancelServiceTest | AC-024 | DU-BE-003 | async：CAS 赢后不调 inventoryPort.confirm/release；sync：逐行调既有同步路径，失败行登记补偿并输出降级 WARN；两条路径库存终态一致（同一 confirm/release 语义） |
| TC-004 | 单测 Order 聚合事件收集 | AC-018 | DU-BE-003 | create→ORDER_CREATED、pay→PAYMENT_SUCCEEDED、cancel→ORDER_CANCELLED、confirmReceipt→ORDER_COMPLETED；reconstitute 重建聚合无待发事件；pull 后列表清空 |
| TC-005 | 单测 OrderStatusInternalControllerTest + CompensationInternalControllerTest | AC-023 | DU-BE-003 | GET status 出 {orderId,status}，不存在 404；POST compensations 按 type 调对应 OrderCompensationPort 登记，非法 type/lines 空拒绝 |
| TC-006 | 单测 PaymentSucceededInventoryHandlerTest | AC-019, AC-021, AC-022, AC-023 | DU-BE-003 | 订单 PAID：枚举 orderNo:% 预留逐行 confirm，DEDUCTED 跳过；订单 CANCELLED：markSkipped+WARN 不 confirm；状态查询异常：抛出触发重试；confirm 异常：先登记 INVENTORY_CONFIRM_DEDUCT 补偿再抛出；同 payload 处理 N 次 confirm 只对 LOCKED 行生效一次（业务幂等） |
| TC-007 | 单测 OrderCancelledInventoryHandlerTest | AC-020, AC-021, AC-022 | DU-BE-003 | 订单 CANCELLED：逐行 release（RELEASED 跳过）；订单 COMPLETED：markSkipped+WARN；订单 PAID/SHIPPED：markSkipped+WARN 不释放；release 异常：登记 INVENTORY_RELEASE 补偿后抛出；重复投递 Available 只恢复一次 |
| TC-008 | 回归合集（mall-order + mall-inventory 全量 mvn test） | AC-025 | DU-BE-003 | TC-001~007 全绿；M2/M4/M5 既有库存/订单/补偿用例零回退 |

覆盖核对：AC-018→TC-001/002/004、AC-019→TC-006、AC-020→TC-007、AC-021→TC-006/007、AC-022→TC-006/007、AC-023→TC-005/006、AC-024→TC-003、AC-025→TC-008；无 TC-NOT-TESTABLE 项。

## 2. 测试策略

- **分层**：全部为 JUnit5 + Mockito 单元测试，不起 Spring 上下文、不依赖 RocketMQ/MySQL 运行时：
  - Assembler/Flusher/Service/聚合：直接构造 + mock 协作者（OutboxRecordWriter、OrderRepository、InventoryPort、OrderCompensationPort）。
  - Handler：直接调 protected `handle(envelope, payload)`（同包测试类），真实 ObjectMapper（findAndRegisterModules），mock IdempotentConsumer/OrderServiceClient/InventoryApplicationService/仓储枚举方法；markSkipped 经 mock IdempotentConsumer 验证。
  - Internal 控制器：控制器直调（service/port mock），断言 DTO 与错误分支。
- **数据准备**：Order 聚合 fixture（create 后未持久化/带 id 各状态）、四 payload DTO fixture、reservationId 列表（orderNo:skuId 多行）。
- **不覆盖项**：真实跨服务投递→消费→库存状态变化（Testcontainers RocketMQ）归 M7 Integration Gate 场景 1/2/4；consumed_event 建表与集成归 STORY-009-05-01。
- **环境要求**：`mvn -pl mall-services/mall-order,mall-services/mall-inventory -am test`（Java 21，Windows PowerShell 下 -D 参数加引号）。

## 3. DU 覆盖矩阵

| DU | verifies TC | covers AC |
| --- | --- | --- |
| DU-BE-003（repo-1，[S3]） | TC-001~008 | AC-018~025 |
