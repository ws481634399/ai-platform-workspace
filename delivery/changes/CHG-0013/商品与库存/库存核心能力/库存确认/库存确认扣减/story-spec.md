---
story-id: "STORY-002-04-04-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S6, S7, S9]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 对应行 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-04-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

提供库存确认扣减能力。支付成功后基于已锁定（LOCKED）的 reservation 确认扣减：total -= quantity、locked -= quantity，reservation 状态 DEDUCTED。以 reservationId 为幂等键，重复支付事件不得重复扣库存；基于非 LOCKED 状态 reservation 扣减拒绝。

## 2. Scope（范围）

### 2.1 包含

- 库存确认扣减（S6）：基于 LOCKED reservation 扣减 total 与 locked，reservation 状态 DEDUCTED。
- DEDUCT 流水（S7）。
- 幂等（S9）：同一 reservationId 重复确认不重复扣减。

### 2.2 不包含

- 库存锁定/释放（STORY-002-04-03-01，提供锁定底座）。
- 库存初始化/查询/调整（STORY-002-04-01/02）。

## 3. 业务规则

- 确认扣减：必须基于存在且状态为 LOCKED 的 reservation；扣减 total -= quantity、locked -= quantity；reservation 状态 DEDUCTED；同一 reservationId 重复确认不重复扣减（幂等）。
- 状态机：reservation 仅 LOCKED → DEDUCTED 合法；RELEASED 或已 DEDUCTED 的 reservation 再次确认拒绝（INVALID_STATE）。
- 流水：DEDUCT 记录 before/after（total 与 locked 变化）。

## 4. 接口与字段规格

确认扣减请求：

| 字段 | 类型 | 约束 |
| --- | --- | --- |
| reservationId | string | 必填，已锁定的预留单号 |

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-015 | 确认扣减：基于 LOCKED reservation → total -= quantity、locked -= quantity，状态 DEDUCTED |
| AC-016 | 同一 reservationId 重复确认扣减 → 不重复扣减，返回成功 |
| AC-017 | 确认扣减基于非 LOCKED reservation → 拒绝，错误 INVALID_STATE |
| AC-018 | 确认扣减记录 DEDUCT 流水 |
