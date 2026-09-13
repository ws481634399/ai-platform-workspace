---
story-id: "STORY-002-04-03-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S4, S5, S7, S9]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 对应行 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-03-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

提供库存锁定与释放能力。锁定时通过 SQL 条件更新（`WHERE total - locked >= quantity`）保证不超卖与并发正确，以 reservationId 为幂等键；释放时基于 LOCKED 状态 reservation 释放，重复释放不重复减少 locked。建立 inventory_reservation 表与 LOCK/RELEASE 流水。

## 2. Scope（范围）

### 2.1 包含

- 库存锁定（S4）：基于 reservationId 锁定可用库存，available >= quantity 才成功，locked += quantity。
- 库存释放（S5）：基于 LOCKED reservation 释放，locked -= quantity，reservation 状态 RELEASED。
- LOCK/RELEASE 流水（S7）。
- 幂等与并发（S9）：reservationId 幂等；SQL 条件更新防超卖。

### 2.2 不包含

- 库存确认扣减（STORY-002-04-04-01）。
- 库存初始化/查询/调整（STORY-002-04-01/02）。

## 3. 业务规则

- 锁定：reservationId 全局唯一（幂等键）；锁定前校验库存存在；SQL 条件更新 `UPDATE inventory_stock SET locked = locked + ? WHERE sku_id = ? AND (total - locked) >= ?`，affected rows = 1 才成功；锁定后创建 inventory_reservation 记录（状态 LOCKED）；同一 reservationId 重复锁定返回原结果。
- 释放：必须基于存在且状态为 LOCKED 的 reservation；locked -= quantity；reservation 状态 RELEASED；同一 reservationId 重复释放不重复减少 locked（幂等）。
- 流水：LOCK 记录 before/after（locked 变化）；RELEASE 记录 before/after。
- 不变量：locked >= 0、available = total - locked >= 0。

## 4. 接口与字段规格

Reservation 字段：

| 字段 | 类型 | 约束 |
| --- | --- | --- |
| id | long | 主键 |
| reservationId | string | 全局唯一，幂等键 |
| skuId | long | 关联库存 |
| quantity | long | 锁定数量 > 0 |
| status | enum | LOCKED/RELEASED/DEDUCTED |
| createdAt/updatedAt | instant | 时间戳 |

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-010 | 锁定库存：available >= quantity → 成功，locked += quantity，reservation 状态 LOCKED |
| AC-011 | 锁定库存：available < quantity → 拒绝，错误 STOCK_INSUFFICIENT |
| AC-012 | 同一 reservationId 重复锁定 → 返回原锁定结果，不重复增加 locked |
| AC-013 | 释放库存：基于 LOCKED reservation → locked -= quantity，reservation 状态 RELEASED |
| AC-014 | 同一 reservationId 重复释放 → 不重复减少 locked，返回成功 |
| AC-018 | 锁定/释放记录 LOCK/RELEASE 流水 |
| AC-019 | 并发锁定最后 1 件：两个请求同时锁定 quantity=1 → 仅一个成功，另一个 STOCK_INSUFFICIENT |
