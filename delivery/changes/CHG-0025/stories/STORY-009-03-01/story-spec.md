---
story-id: "STORY-009-03-01"
change-spec-ref: "requirement-spec.md#3-功能范围"
scope-refs: [S3]
---

# Story Spec（Story 产品规格）— 订单集成事件与库存异步消费者

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3 [S3]、§4、§5（AC-018~025）
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0025
- Story ID: STORY-009-03-01 订单集成事件与库存异步消费者（REQ-M7-003，P0）
- Change spec 引用: requirement-spec.md#3-功能范围（S3）
- 仓库分工: repo-1 mall-order（4 状态迁移点写 Outbox 事件）+ mall-inventory（消费者）+ mall-contracts（事件 Payload DTO）
- 前置依赖: STORY-009-01-01（基础设施）+ STORY-009-02-01（Outbox）+ M4 REQ-M4-001/REQ-M2-002（既有同步路径）

## 1. Story 目标

把 M4 "支付成功同步调库存 confirm、取消同步调库存 release" 的强耦合升级为事件驱动最终一致：

1. mall-order 在订单创建/支付/取消/完成四个事务提交后发布集成事件（Payload 对齐 §41）；
2. mall-inventory 幂等消费 PAYMENT_SUCCEEDED（确认扣减）与 ORDER_CANCELLED（释放）；
3. 重复/乱序消息正确处理；消费失败 DLQ 由补偿兜底；MQ 不可用降级同步且结果一致。

## 2. Scope（范围）

### 2.1 包含

- [S3] mall-contracts 新增 4 个订单事件 Payload DTO（OrderCreated/PaymentSucceeded/OrderCancelled/OrderCompleted），字段严格对齐 product/10-API与事件契约.md §41（orderId/orderNo/memberId/reservationNo/orderAmount/currency/paymentDeadline/paymentNo/paymentAmount/paidAt/cancelReason/cancelledAt/completedAt 等）。
- [S3] mall-order 4 个发布点：订单创建（ORDER_CREATED）/支付成功（PAYMENT_SUCCEEDED）/取消（ORDER_CANCELLED）/完成（ORDER_COMPLETED）事务内经 S2 OutboxRecordWriter 写入；发布失败回滚业务事务。
- [S3] mall-inventory 消费者（inventory-consumer-group）：PAYMENT_SUCCEEDED → 调库存聚合将预留转确认扣减；ORDER_CANCELLED → 调库存聚合释放锁定；二者基于 reservationNo 业务幂等（复用 M2 confirm/release 幂等语义）+ eventId 消费幂等（复用 S5 consumed_event）。
- [S3] 乱序处理：消费者判断依据=回调 mall-order 订单状态查询内部 API（库存不直查订单库）：订单已取消收 PAYMENT_SUCCEEDED → 跳过+告警；订单已完成/已取消收 ORDER_CANCELLED → 跳过+告警；判断基于订单聚合当前状态。
- [S3] 消费失败进 DLQ → 对应补偿任务（INVENTORY_CONFIRM_DEDUCT/INVENTORY_RELEASE）登记（复用 S5 机制）。
- [S3] 同步降级：`rocketmq.enabled=false` 或 RocketMQ 不可用时，支付/取消流程降级为同步调用 mall-inventory 内部 API（与 M4 完全一致），记降级日志；降级与异步业务结果一致。
- [S3] ORDER_COMPLETED 首期只发布不订阅（供统计/通知扩展，不强制实现下游消费者）。

### 2.2 不包含

- 库存超卖实时风控、库存预拆分、多仓路由、跨境隔离。
- consumed_event 表与补偿任务机制实现（归 STORY-009-05-01，本 Story 复用其接口）。
- ORDER_COMPLETED 下游统计/通知消费者实现。

## 3. 业务规则

- [契约对齐] 4 个 Tag 与 Payload 字段严格按 §41，变更须先改契约文档（规则 5/AC-018）。
- [发布原子性] 事件写入与业务同事务（经 Outbox），失败回滚业务事务（规则 2/AC-018）。
- [双重幂等] 业务幂等（reservationNo，复用 M2 confirm/release 语义）+ 消费幂等（eventId，consumed_event）双层防护（规则 7/10/AC-021）。
- [乱序裁决] 以订单聚合当前状态为准，不依赖消息内状态快照；乱序场景跳过+告警（规则 11/AC-022）。
- [降级一致] 同步降级与异步路径业务结果一致且记降级日志（规则 4/AC-024）。
- [DLQ 衔接] 消费失败 DLQ 后由补偿任务接管（规则 17/AC-023）。

## 4. 接口与字段规格

- order-events Topic 四 Tag Payload（§41 为准）：
  - ORDER_CREATED: orderId/orderNo/memberId/reservationNo/orderAmount/currency/paymentDeadline
  - PAYMENT_SUCCEEDED: orderId/orderNo/paymentNo/reservationNo/paymentAmount/currency/paidAt
  - ORDER_CANCELLED: orderId/orderNo/reservationNo/cancelReason/cancelledAt
  - ORDER_COMPLETED: orderId/orderNo/memberId/completedAt
- mall-order 内部查询 API（新增 internal，SERVICE 身份）：`GET /internal/orders/{orderId}/status`（供库存消费者乱序判断；是否复用既有内部端点由 design 评估）。
- mall-inventory 内部 API（M4 既有）：confirm（预留转确认扣减）/ release（释放）——同步降级路径复用。
- 消费者声明（复用 S1 SPI）：inventory-consumer-group 订阅 order-events 的 PAYMENT_SUCCEEDED 与 ORDER_CANCELLED Tag。
- 错误语义：业务处理失败→抛异常交 RocketMQ 重试；乱序跳过→ACK+告警日志（含 eventId/orderId/当前状态）。

## 5. Story 验收标准

requirement-spec.md §5 Story 3 表（AC-018~AC-025），此处不重复。

## 6. 待设计确认（已移至 design 定稿）

- 乱序判断的订单状态查询通道（新增 internal 端点 vs 复用既有）；查询失败时的保守策略（重试 or 跳过+告警）。
- 事件 Payload DTO 与 Envelope 的组装位置（mall-contracts 工厂 vs mall-order 内组装）。
- 同步降级触发判定（开关关闭 vs 发送异常即时降级 vs 混合）。
- 消费者线程/并发参数；与 S5 consumed_event 检查的调用次序细节。
