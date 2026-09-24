---
story-id: "STORY-009-02-01"
change-id: "CHG-0025"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
feature-path: "FEAT-009/FEAT-009-02/FEAT-009-02-01/STORY-009-02-01"
---

# Story Design（Story 技术设计）— Outbox 可靠投递

## 0. 元信息

- Change ID：CHG-0025；Story ID：STORY-009-02-01（REQ-M7-002，P0）
- 两 DU：DU-BE-002（repo-1 mall-order outbox_event + Writer + 投递任务 + mall-admin 后端 Outbox API）、DU-FE-001（repo-2 mall-admin Outbox 管理页）
- 前置依赖：DU-BE-001（IntegrationEventProducer / Envelope / rocketmq.enabled 开关）
- 实施顺序：DU-BE-002 → DU-FE-001（前端依赖后端 API 契约）

### DU 划分表

| DU ID | 仓库 | 范围 | 覆盖 AC | 前置 DU |
|---|---|---|---|---|
| DU-BE-002 | repo-1 | mall-order outbox_event 表 + OutboxRecordWriter + OutboxDeliveryTask（CAS/退避/同聚合顺序/eventType 路由）+ mall-admin 后端 Outbox 查询/重投 API + 权限码 DML | AC-010~015, AC-017 | DU-BE-001 |
| DU-FE-001 | repo-2 | mall-admin Outbox 管理页（筛选/payload 抽屉/重投/审计展示） | AC-016 | DU-BE-002 |

### 现状事实（已核实）

- mall-order（M4/M5）已有 OrderCancelService、CompensationService/CompensationTask 聚合（businessType/businessId/operation/status/retryCount/lastError/nextRetryAt/trace_id，幂等登记 + 有界退避 + 人工重试端点）、OrderStatusHistory、@Scheduled 调度（30s 扫描）。
- mall-common mq 子模块（STORY-009-01-01）已交付 `IntegrationEventProducer.sendSync(Envelope)`、Envelope 七字段、keys=eventId、`rocketmq.enabled` 开关。
- mall-admin 后端已有 RBAC（M5 CHG-0023）、审计日志模式、`v-permission` 前端约定。
- Flyway 版本号 dev 阶段核对 mall-order 最新后递增。

## 1. 模块改动（Module Changes）

### repo-1（DU-BE-002）

#### 1.1 mall-order：outbox/ 包

- `OutboxStatus` 枚举：PENDING / SENDING / SENT / FAILED。
- `OutboxEvent` 实体（JPA）：id / aggregateId / eventType / payload(String, Envelope JSON) / status / retryCount / nextRetryAt / traceId / lastError / createdAt / sentAt。
- `OutboxEventRepository`（Spring Data JPA）：
  - `findPendingDue(Pageable)`：`status=PENDING AND (next_retry_at IS NULL OR next_retry_at <= now()) ORDER BY aggregate_id, created_at`（同聚合按 created_at 排序，分组投递时取每组首条）。
  - `claim(id)`：`UPDATE outbox_event SET status='SENDING', sent_at=NOW() WHERE id=? AND status='PENDING'`（CAS 抢占，返回影响行数；0 行=被其他实例抢走，跳过）。
  - `markSent(id)`：`UPDATE ... SET status='SENT' WHERE id=? AND status='SENDING'`。
  - `markFailedWithBackoff(id, lastError, nextRetryAt, retryCount+1)`：若 retryCount+1 >= maxRetries → `status='FAILED', last_error=?`；否则 `status='PENDING', retry_count=?, next_retry_at=?, last_error=?`。
  - `resetForRetry(id)`：`UPDATE ... SET status='PENDING', retry_count=0, next_retry_at=NULL, last_error=NULL WHERE id=? AND status='FAILED'`（手动重投，重置计数）。
  - 管理查询：`findByFilters(status, eventType, aggregateId, Pageable)`。
- `OutboxRecordWriter`：
  - `append(aggregateId, eventType, envelope)`：在调用方事务内 `outboxEventRepository.save(...)`；status=PENDING、retryCount=0、nextRetryAt=NULL；trace_id 取 envelope.traceId。写入失败抛异常，由调用方事务回滚（AC-010）。
  - 注意：payload 列存 Envelope 完整 JSON（含七字段），投递时直接反序列化为 Envelope 发送；事件 Schema 单一事实源仍在 mall-contracts（Envelope.payload 业务字段）。
- `OutboxDeliveryTask`（`@Component @Scheduled(fixedDelayString="${outbox.delivery.fixed-delay:5000}")`）：
  1. 拉取 `findPendingDue(PageRequest.of(0, batchSize=100))`。
  2. 按 aggregateId 分组，每组只取 created_at 最早的一条 PENDING（同聚合顺序，AC-014）。
  3. 对每条执行 `claim(id)`：CAS 成功才继续；失败跳过（多实例并发安全）。
  4. 反序列化 payload → Envelope，按 eventType 路由：
     - `EventRouter.route(eventType, envelope)` → `SendTarget{topic, delayLevel}`。默认路由：订单四事件 → aimall-order-events（delayLevel=0）。延迟路由（PAYMENT_TIMEOUT_CHECK → aimall-order-delay + delayLevel）由 STORY-009-04-01 注册（本 Story 留扩展点，未知 eventType 记 WARN 标 FAILED）。
  5. `integrationEventProducer.sendSync(envelope, target.topic, target.delayLevel)`（sendSync 已支持 delayLevel 参数化，见 STORY-009-01-01 实现）。
  6. 成功 → `markSent(id)`；失败（含 MQ 连接异常）→ `markFailedWithBackoff(...)`：MQ 停止时 status 回 PENDING + 退避（AC-012），超限才 FAILED（AC-015）。
  7. 任务自身异常记 ERROR 不中断调度（下一轮继续）。
- `OutboxBackoffPolicy`（组件）：`nextRetryAt(retryCount)` = now + initialDelay * (factor ^ retryCount)，封顶 maxDelay；`maxRetries` 配置（默认 10）。退避参数走配置属性 `outbox.delivery.backoff.*`。
- `EventRouter`（组件，可扩展）：`Map<String, SendTarget>` 路由表；`@PostConstruct` 注册默认订单事件路由；提供 `register(eventType, target)` 供 STORY-009-04-01 扩展。

#### 1.2 mall-admin 后端：OutboxAdminApi

- `OutboxAdminController`（`/api/admin/outbox/events`）：
  - `GET ?status=&eventType=&aggregateId=&page=&size=` → 分页列表（含 payload/traceId/createdAt/sentAt/lastError）。
  - `GET /{id}` → 详情。
  - `POST /{id}/retry` → `resetForRetry(id)` + 写审计（操作人/时间/前后状态 FAILED→PENDING/traceId）。RBAC 权限码 `system:outbox:list` / `system:outbox:retry`。
- 审计复用 mall-admin 既有审计切面/日志模式。
- Flyway：mall-order 库 `add_outbox_event`（DDL 见 requirement-design §5）；mall-identity 权限码/菜单种子 DML 两条（system:outbox:list、system:outbox:retry）。

### repo-2（DU-FE-001）

- `src/api/distributed.ts`：Outbox 三组接口封装（list/get/retry）。
- `views/distributed/OutboxListView.vue`：状态/事件类型/聚合 ID 筛选 + 分页表格 + payload 抽屉 + 重投按钮（FAILED 可点）+ 审计展示；`v-permission="system:outbox:retry"`。
- 菜单/路由注册（复用既有分布式模块分组）。

## 2. 接口契约细化

- SSOT 见 requirement-design.md §2.1/§4；Story 侧补充：
  - 投递任务对 `rocketmq.enabled=false` 的处理：发送调用走 sendSync，若 mq 未装配抛 Bean 缺失异常 → catch 后按失败退避保留 PENDING（不标 FAILED），与 MQ 停止同语义（AC-012/013）。
  - EventRouter 未知 eventType 不重试（配置错误），直接 FAILED + lastError 说明。
  - 手动重投重置 retry_count=0（给人工介入充分重试空间，区别于自动退避超限）。
  - keys=eventId 由 IntegrationEventProducer 统一处理（取 envelope.eventId）。

## 3. 数据变更

- mall_order 库 Flyway：`CREATE TABLE outbox_event (...)`（DDL 同 requirement-design §5，含 idx_status_retry / idx_aggregate）。
- mall_identity 库 DML：权限码 system:outbox:list / system:outbox:retry + 菜单。
- 无既有表结构变更，无回填。

## 4. 关键流程

### 4.1 投递任务一轮循环（同聚合顺序）

```
findPendingDue(batch=100, order by aggregate_id, created_at)
  → group by aggregateId, take first each
  → for each: claim(id) CAS
       → success: route → sendSync → markSent | markFailedWithBackoff
       → fail(0 rows): skip
```

### 4.2 事务原子写入

业务方法（如订单创建）`@Transactional` 内调 `outboxRecordWriter.append(...)`；若 append 抛异常，整个事务回滚（AC-010）。Outbox 记录与业务数据同 commit 点可见。

## 5. 非功能

- 性能：批量 100、fixedDelay 5s；单实例吞吐 ~20 msg/s（足够首期）；多实例靠 CAS 水平扩展。
- 可靠性：at-least-once（重投），消费端幂等（consumed_event，STORY-009-05-01）去重。
- 可观测：投递任务每轮 INFO 日志（扫描数/发送成功/失败/退避数）；FAILED 记 ERROR + lastError；traceId 贯穿日志。
