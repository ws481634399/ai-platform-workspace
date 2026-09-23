---
story-id: "STORY-009-04-01"
change-spec-ref: "requirement-spec.md#3-功能范围"
scope-refs: [S4]
---

# Story Spec（Story 产品规格）— 延迟订单自动取消

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3 [S4]、§4、§5（AC-026~032）
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0025
- Story ID: STORY-009-04-01 延迟订单自动取消（REQ-M7-004，P1）
- Change spec 引用: requirement-spec.md#3-功能范围（S4）
- 仓库分工: repo-1 mall-order（主：延迟消息/回查消费者/OrderCancelService 复用）+ mall-contracts（延迟消息契约）、repo-2 mall-admin（延迟取消任务查询页）
- 前置依赖: STORY-009-01-01（基础设施）+ STORY-009-02-01（Outbox）+ M4 REQ-M4-001（OrderCancelService/CAS/释放/补偿登记）

## 1. Story 目标

用 RocketMQ 延迟消息替代定时扫描实现"创建订单→延迟到期→回查状态→自动取消"：

1. 订单创建事务提交后经 Outbox 投递延迟消息（超时时间可配置、动态生效）；
2. 到期回查订单聚合当前状态，未支付调 OrderCancelService 自动取消（复用 M4 全流程）；
3. 重复消息幂等；定时补偿兜底双路径一致；mall-admin 可查可介入。

## 2. Scope（范围）

### 2.1 包含

- [S4] 订单创建事务内经 Outbox 写入延迟消息事件（event_type=ORDER_PAYMENT_TIMEOUT_CHECK，与 ORDER_CREATED 同事务）；投递任务发送时按 event_type 路由到 order-delay Topic 并设置延迟级别。
- [S4] 延迟消息 Payload：orderId/orderNo/expireAt；延迟级别映射 SystemParameter `order.payment.timeout-minutes`（默认 30 分钟，动态生效复用 M5；映射算法 design 定）。
- [S4] 回查消费者（order-delay-consumer-group）：到期回查订单聚合当前状态（查库当前态，不依赖消息内快照）：PENDING_PAYMENT → 调 OrderCancelService（cancelReason=PAYMENT_TIMEOUT）；已支付/已取消/已完成 → ACK 跳过。
- [S4] 重复消息幂等：订单已非 PENDING_PAYMENT 直接 ACK 跳过；并发重复投递不重复触发取消。
- [S4] 定时补偿兜底：保留 CompensationService 扫描超时订单路径；延迟消息与定时扫描双路径业务结果一致，并发竞争无双重取消（同一订单 CAS 只成功一次）。
- [S4] 取消失败登记 ORDER_AUTO_CANCEL 补偿任务（复用 S5 机制）。
- [S4] mall-admin 延迟取消任务查询：待取消/已取消/失败任务列表 + 手动触发取消（走 OrderCancelService，审计记录操作人/时间/前后状态）；与既有 CompensationTask 查询入口对齐。

### 2.2 不包含

- XXL-Job 等分布式定时任务框架；秒级超时精度；多级延迟提醒；取消前自动催付通知。
- 支付回调流程改动（M4 既有支付路径不变，仅新增事件发布）。

## 3. 业务规则

- [发送原子性] 延迟消息与订单创建同事务写 Outbox（规则 2 + §4.F-22 定稿/AC-026）。
- [回查裁决] 以订单聚合当前状态为准，不依赖消息内状态快照（规则 11 同源/AC-027/028）。
- [必经聚合] 自动取消必经 OrderCancelService，禁止绕过自行实现（规则 14/AC-027）。
- [幂等] 重复延迟消息基于订单状态幂等；CAS 保证并发只取消一次（规则 12/AC-029）。
- [双路径一致] 延迟消息与定时兜底业务结果一致，无双重取消（规则 15/AC-030）。
- [配置动态生效] timeout-minutes 经 SystemParameter 动态生效（规则 20/AC-031）。
- [审计] 手动触发取消必须记审计（规则 18/AC-032）。

## 4. 接口与字段规格

- order-delay Topic：Tag=PAYMENT_TIMEOUT_CHECK；Payload `{orderId, orderNo, expireAt}`；消息 keys=eventId。
- 延迟级别映射：`order.payment.timeout-minutes` → RocketMQ delayLevel（18 级向最近级别对齐策略 design 定；测试用短延迟级别验证）。
- 回查消费链路：consumer → OrderQueryService.getById(orderId)（服务内聚合查询）→ 状态判断 → OrderCancelService.cancel(orderId, PAYMENT_TIMEOUT, source=DELAY_MESSAGE)。
- mall-admin API：`GET /api/admin/order-delay/tasks?status=&page=` / `POST /api/admin/order-delay/tasks/{orderId}/cancel`（手动取消，审计）。
- 错误语义：回查时订单不存在→ACK+告警（数据异常单查）；取消业务失败→异常交重试，超限登记补偿任务。

## 5. Story 验收标准

requirement-spec.md §5 Story 4 表（AC-026~AC-032），此处不重复。

## 6. 待设计确认（已移至 design 定稿）

- 延迟级别与超时时间对齐算法（向上/向下取整、RocketMQ 5.x 自定义延迟是否采用）。
- 延迟消息走 Outbox 的 event_type 路由机制实现；expireAt 计算与 created_at 关系。
- 与 CompensationService 兜底的并发竞争细节（同一订单双路径同时触发时 CAS 语义验证场景设计）。
- mall-admin 延迟任务页与 Outbox/补偿任务页的信息架构（独立页 vs 统一"分布式任务"页）。
