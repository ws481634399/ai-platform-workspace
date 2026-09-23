---
story-id: "STORY-009-02-01"
change-spec-ref: "requirement-spec.md#3-功能范围"
scope-refs: [S2]
---

# Story Spec（Story 产品规格）— Outbox 可靠投递

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3 [S2]、§4、§5（AC-010~017）
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0025
- Story ID: STORY-009-02-01 Outbox 可靠投递（REQ-M7-002，P0）
- Change spec 引用: requirement-spec.md#3-功能范围（S2）
- 仓库分工: repo-1 mall-order（主：outbox_event 表/事务写入/投递任务）+ mall-common（复用 S1 生产者封装）、repo-2 mall-admin（Outbox 查询+手动重投页）
- 前置依赖: STORY-009-01-01（生产者封装/Envelope/开关）

## 1. Story 目标

解决"业务事务提交成功但消息发送失败"的原子性问题：

1. 业务事务与 Outbox 记录原子提交（写入失败回滚业务事务）；
2. 独立投递任务异步推送 RocketMQ，MQ 停止不丢事件、恢复自动续投；
3. 失败有界退避、超限进人工队列；同聚合顺序投递；mall-admin 可查可重投。

## 2. Scope（范围）

### 2.1 包含

- [S2] mall-order Flyway 新增 outbox_event 表：id/aggregate_id/event_type/payload(JSON)/status(PENDING|SENT|FAILED)/retry_count/next_retry_at/created_at/sent_at/trace_id；索引（status+next_retry_at、aggregate_id+created_at）由 design 定稿。
- [S2] OutboxRecordWriter：业务事务内写入 Outbox 记录的统一入口（同事务提交；写入失败抛异常回滚业务事务）。
- [S2] OutboxDeliveryTask（@Scheduled 独立任务）：扫描 status=PENDING 且 next_retry_at 到期的记录，调 S1 生产者发送；成功标 SENT+sent_at；失败递增 retry_count 按有界退避更新 next_retry_at；并发控制（乐观锁/SELECT FOR UPDATE）由 design 定。
- [S2] MQ 停止保留：发送异常（连接类）记录保留 PENDING 不删除不标 FAILED；恢复后自动续投。
- [S2] 顺序投递：同 aggregate_id 内按 created_at 顺序发送（前一条 SENT 后才发下一条）；跨聚合不保证。
- [S2] 超限 FAILED：超过最大重试次数标 FAILED+失败原因；FAILED 可在 mall-admin 查询。
- [S2] mall-admin Outbox 管理页：按状态/事件类型/聚合 ID 筛选、查看 payload、手动重投（状态回 PENDING，审计记录操作人/时间/前后状态）；RBAC 权限码由 design 定。
- [S2] 投递消息 keys=eventId（复用 S1）；trace_id 列贯穿（复用 S1 Envelope.traceId）。

### 2.2 不包含

- 业务事件发布点（订单 4 状态迁移写 Outbox 归 STORY-009-03-01；延迟消息归 STORY-009-04-01）——本 Story 只提供写入与投递通用机制。
- CDC/Debezium、跨库 Outbox、事件溯源。
- 消费端幂等（归 STORY-009-05-01）。

## 3. 业务规则

- [原子性] 业务事务提交时 Outbox 一并持久化；禁止先发后写/先写后发；写入失败回滚业务事务（规则 2/AC-010）。
- [停止保留] MQ 不可用保留 PENDING，不删不标失败；恢复自动续投无需人工（规则 3/AC-012/013）。
- [有界退避] 失败退避重试有上限，超限标 FAILED 进人工队列，不允许无限重试（规则 17 关联/AC-015）。
- [顺序] 同聚合按 created_at 顺序投递；跨聚合不保证，消费端不得依赖（规则 9/AC-014）。
- [幂等键] 消息 keys=eventId（规则 7）。
- [审计] 手动重投必须记审计（规则 18/AC-016）。

## 4. 接口与字段规格

- outbox_event（mall_order 库，Flyway）：见 §2.1；status 枚举 PENDING/SENT/FAILED；payload 存 Envelope JSON（或业务 payload+Envelope 元数据分离，design 定）。
- OutboxRecordWriter API（mall-order 内部）：`append(aggregateId, eventType, payload, traceId)`——在调用方事务内执行。
- OutboxDeliveryTask：扫描批量/间隔参数化（design 定）；发送调 `IntegrationEventProducer.sendSync`（异步模式是否采用由 design 评估，首期同步保证顺序与确定性）。
- mall-admin API：`GET /api/admin/outbox/events?status=&eventType=&aggregateId=&page=` / `GET /api/admin/outbox/events/{id}` / `POST /api/admin/outbox/events/{id}/retry`（重投=状态置 PENDING+重置 next_retry_at；是否重置 retry_count 由 design 定）。
- 错误语义：发送失败→捕获记 retry，不向上抛；扫描任务自身异常记日志不中断调度。

## 5. Story 验收标准

requirement-spec.md §5 Story 2 表（AC-010~AC-017），此处不重复。

## 6. 待设计确认（已移至 design 定稿）

- 投递任务并发控制（乐观锁 vs SELECT FOR UPDATE）、扫描批量/间隔、退避参数（初始/倍数/上限/最大次数）。
- payload 存储形态（完整 Envelope vs 业务 payload+元数据分离）；FAILED 重投是否重置 retry_count。
- Outbox FAILED 是否自动登记 CompensationTask（businessType=OUTBOX_DELIVERY）——§4.F-22 已定首期仅人工介入，design 复核。
- Flyway 版本号衔接；mall-admin RBAC 权限码。
