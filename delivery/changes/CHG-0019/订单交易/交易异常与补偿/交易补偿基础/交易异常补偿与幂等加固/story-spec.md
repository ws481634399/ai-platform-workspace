---
story-id: "STORY-004-04-01-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S7]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §4.5 + requirement-design.md §2.4
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-04-01-01 交易异常补偿与幂等加固
- 状态流转: specified → specified（细化）

## 1. Story 目标

为同步交易链路建立基本异常恢复：库存锁成功但建单失败、支付/取消状态迁移成功后库存 confirm/release 失败等部分失败，先同步 best-effort 重试一次，失败落 CompensationTask；调度器按指数退避有界自动重试（上限 5 次），超限置 FAILED_DEAD 并提供 admin 查询与人工重试端点；所有补偿操作幂等；关键失败结构化日志（orderNo/traceId/operation，无敏感信息）。

## 2. Scope（范围）

### 2.1 包含

- [S7] Flyway V2：compensation_task 表（含 (business_type,business_id,operation) 唯一键、idx_status_next）。
- [S7] CompensationTask 聚合 + repository；CompensationService（executeWithCompensation：同步尝试 → 失败落/更新任务）；InventoryCompensationHandler（按 operation 调 release/confirm，按 reservation 当前状态判定成功）。
- [S7] 接线：OrderCreateService 锁后落库失败与逐行锁失败后的 release 失败、PaymentService confirm 失败、OrderCancelService release 失败 → 全部走补偿服务（替换前序 Story 的 ERROR-only 挂点）。
- [S7] CompensationRetryScheduler：@Scheduled(30s) 拾取 PENDING&到期 LIMIT 50，退避 30s/1m/2m/5m/10m，达 5 次 FAILED_DEAD。
- [S7] `GET /api/admin/compensations?status=&page=&size=` 与 `POST /api/admin/compensations/{id}/retry`（权限码 order:compensation）。
- [S7] 审计：每次尝试结构化日志（taskId/orderNo/operation/retryCount/result/error），不记录 token/secret/完整敏感信息。

### 2.2 不包含

- Outbox/MQ/死信（M7）、分布式调度锁（M4 单实例）、补偿运维 UI（仅端点）、订单超时取消。

## 3. 业务规则

- 幂等落任务：同 (businessType,businessId,operation) 唯一键；并发落任务冲突时复用既有行。
- 任务状态：PENDING（待重试）/SUCCESS（终态）/FAILED_DEAD（终态，等待人工）。
- 同步路径：业务失败点立即执行一次库存补偿；成功则不落任务（锁后单失败路径成功 release 后无任务）；失败 → UPSERT PENDING 任务，next_retry_at=now+30s。
- 调度：重试成功 → SUCCESS；失败 retry_count+1、lastError 截断 1000、退避；retry_count>=max(5) → FAILED_DEAD（ERROR 告警日志）。
- handler 成功判定：库存侧返回目标状态（RELEASED/DEDUCTED）即成功（重复调用按当前状态幂等）。
- 人工 retry：仅 FAILED_DEAD（或 PENDING 也允许）可触发：retry_count 归零、status=PENDING、next_retry_at=now，并立即执行一次；执行过程同 handler 规则。
- 不无限循环、不吞异常；每次拾取与执行有日志。

## 4. 接口与字段规格

- `GET /api/admin/compensations?status=PENDING|SUCCESS|FAILED_DEAD&page=&size=`（order:compensation）→ PageView<CompensationView>：`{id,businessType,businessId,operation,status,retryCount,maxRetries,lastError,nextRetryAt,createdAt,updatedAt}`。
- `POST /api/admin/compensations/{id}/retry` → CompensationView（立即尝试后的最新状态）；404 任务不存在；400 SUCCESS 任务无需重试。
- 内部无新增端点。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | Lock 成功 + 落库失败：同步 release 成功 → 无任务、reservation RELEASED；release 也失败 → PENDING 任务，调度重试至 SUCCESS（场景 A/十） |
| AC-002 | 取消时 release 首次失败 → 落 PENDING 任务，退避重试成功（场景 B）；支付 confirm 失败同构 |
| AC-003 | 重复 pay/cancel 不产生重复库存副作用（场景 C/D）；补偿 handler 对已处目标态 reservation 直接判成功，不重复增减 |
| AC-004 | 超 5 次重试 → FAILED_DEAD 与 ERROR 日志；GET admin 列表可查；人工 retry 重置并执行成功 → SUCCESS |
| AC-005 | 同单同操作并发生成补偿不产生重复任务行（唯一键复用） |
| AC-006 | 关键失败日志可用 orderNo+traceId 定位（场景 E），日志无 secret/token；每次状态迁移有 history |
| AC-007 | 调度拾取有界（LIMIT）、单条异常不影响下一条；任务无无限重试 |
