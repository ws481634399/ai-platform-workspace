---
story-id: "STORY-009-05-01"
change-spec-ref: "requirement-spec.md#3-功能范围"
scope-refs: [S5, S6]
---

# Story Spec（Story 产品规格）— 消费幂等与补偿机制

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3 [S5]/[S6]、§4、§5（AC-033~040）
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0025
- Story ID: STORY-009-05-01 消费幂等与补偿机制（REQ-M7-005，P0）
- Change spec 引用: requirement-spec.md#3-功能范围（S5/S6）
- 仓库分工: repo-1 mall-inventory（consumed_event 表/消费者幂等）+ mall-order（CompensationTask 扩展 3 类型）+ mall-common（幂等检查组件）+ repo-2 mall-admin（补偿任务查询与人工介入）
- 前置依赖: STORY-009-01-01（基础设施）+ STORY-009-03-01（消费场景）；复用 M4 CompensationTask 聚合与 CompensationService（30s 扫描）

## 1. Story 目标

为 M7 全部异步消费者与延迟任务建立最终一致性兜底：

1. consumed_event 幂等表统一消费幂等（eventId 唯一键）；
2. 复用 CompensationTask 聚合扩展 3 种补偿类型（库存确认扣减/库存释放/订单自动取消），不新建补偿体系；
3. DLQ 由补偿任务接管；TraceId 全链路贯通；mall-admin 可查可介入全审计。

## 2. Scope（范围）

### 2.1 包含

- [S5] mall-inventory Flyway 新增 consumed_event 表：event_id（唯一键）/event_type/consumer_group/aggregate_id/processed_at/result/trace_id；索引由 design 定稿。
- [S5] 消费幂等组件（mall-common 提供、mall-inventory 先行接入）：消费处理前 INSERT（依赖唯一键冲突检测）——已存在直接 ACK 跳过；处理成功标记 result；处理失败回滚登记（交 RocketMQ 重试，重试成功后正常登记）。
- [S5] CompensationTask 扩展 3 种类型：INVENTORY_CONFIRM_DEDUCT（调 mall-inventory confirm 内部 API）/ INVENTORY_RELEASE（调 release 内部 API）/ ORDER_AUTO_CANCEL（调 OrderCancelService）；复用既有幂等登记（同一业务操作仅一条任务）+有界退避+30s 扫描。
- [S5] DLQ 衔接：消费失败超限进 DLQ 后，补偿任务接管（登记时机与扫描方式 design 定）；不要求实时处理 DLQ；DLQ 来源可在 mall-admin 筛选。
- [S5] mall-admin 补偿任务管理：按类型/状态/聚合 ID 筛选、查看 payload、手动重试、手动标记完成；审计含操作人/时间/操作前后状态；RBAC 权限码 design 定。
- [S6] TraceId 贯通：eventId/traceId 在生产→Outbox→投递→消费→补偿全链路记录/日志贯通；补偿任务执行沿用原事件 traceId（compensation_task.trace_id 列 M5 CHG-0023 A3 已具备）。
- [S5] 幂等与补偿单测+集成测试（重复消费并发/任务登记唯一性/扫描重试/超限 FAILED/人工介入/TraceId）。

### 2.2 不包含

- Seata/2PC/TCC/Saga 编排引擎、全量事件回溯重建。
- DLQ 积压告警（M8 可观测能力，M7 不强制）。
- mall-order 侧消费幂等（首期消费者仅在 mall-inventory；组件预留扩展，mall-order 延迟回查幂等靠订单状态，见 STORY-009-04-01）。

## 3. 业务规则

- [幂等键] 统一 eventId，禁用业务字段（规则 7/10/AC-033/034）。
- [幂等先行] 消费前查 consumed_event，已存在直接 ACK 跳过；不依赖业务状态判断幂等（规则 10/AC-034）。
- [补偿唯一] 同一业务操作只保留一条 CompensationTask，幂等登记（规则 13/AC-035）。
- [复用不重建] 补偿复用 M4 聚合与 30s 扫描，不引入新调度器（规则 16/AC-036）。
- [超限人工] 超最大重试标 FAILED 等人工介入（规则 17 关联/AC-037）。
- [审计] 手动重试/标记完成记审计含前后状态（规则 18/AC-038）。
- [TraceId 贯通] 全链路同 eventId+traceId，补偿沿用原 traceId（规则见 §6 横切/AC-039）。

## 4. 接口与字段规格

- consumed_event（mall_inventory 库，Flyway）：event_id VARCHAR 唯一键/event_type/consumer_group/aggregate_id/processed_at/result(SUCCESS|FAILURE|SKIPPED)/trace_id。
- 幂等组件 API（mall-common）：`tryConsume(eventId, consumerGroup, aggregateId, traceId): ConsumeResult`（FIRST_PROCESSED/DUPLICATE）；处理成功后 `markResult(eventId, result)`。
- CompensationTask 扩展：businessType 新增枚举 INVENTORY_CONFIRM_DEDUCT/INVENTORY_RELEASE/ORDER_AUTO_CANCEL；payload 存原事件关键参数（orderId/reservationNo/eventId/traceId）；字段是否扩展由 design 评估。
- mall-admin API：`GET /api/admin/compensation/tasks?type=&status=&aggregateId=&page=` / `POST /api/admin/compensation/tasks/{id}/retry` / `POST /api/admin/compensation/tasks/{id}/complete`（均审计）。
- 错误语义：幂等检查 DB 异常→消费异常交 RocketMQ 重试（不 ACK，避免漏处理）；补偿执行失败→记重试状态有界退避。

## 5. Story 验收标准

requirement-spec.md §5 Story 5 表（AC-033~AC-040），此处不重复。

## 6. 待设计确认（已移至 design 定稿）

- 幂等检查与业务处理的时序细节（先 INSERT 再处理 vs 处理成功后 INSERT 的取舍——首期"先 INSERT 占位+失败回滚登记"策略 design 复核）。
- DLQ 衔接实现（定时扫描 DLQ vs 进 DLQ 时触发登记）；DLQ 来源筛选字段。
- CompensationTask 表字段扩展范围（event_type/event_version/original payload）；Flyway 版本号衔接。
- mall-admin 三类任务页（Outbox/延迟/补偿）信息架构与 RBAC 权限码统一。
