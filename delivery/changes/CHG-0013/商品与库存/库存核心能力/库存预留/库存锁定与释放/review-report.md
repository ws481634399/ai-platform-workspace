# Review Report — 库存锁定与释放 STORY-002-04-03-01

> 阶段：sdd-review 产物（Story 级检查点，状态保持 testing）

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-03-01（库存锁定与释放）
- Test Report 来源: 本目录 evidence/test-report.md
- Evidence 索引: CHG-0013/evidence/evidence.yaml
- 状态流转: testing（检查点，状态不变）
- 检查时间: 2026-09-13

## 1. 检查结论

五项检查全部执行；无 blocker/major 开放项。

### 1.1 需求一致性

| AC | 需求要点 | 证据 | 结论 |
| --- | --- | --- | --- |
| AC-010 | 锁定库存：available >= quantity → 成功，locked += quantity，reservation LOCKED | InventoryTest.lockAndRelease | 一致 |
| AC-011 | 锁定库存：available < quantity → 拒绝，STOCK_INSUFFICIENT | Inventory.lock 超额校验 | 一致 |
| AC-012 | 同一 reservationId 重复锁定 → 返回原锁定结果 | InventoryApplicationService.lock 幂等 | 一致 |
| AC-013 | 释放库存：基于 LOCKED reservation → locked -= quantity，状态 RELEASED | Inventory.release | 一致 |
| AC-014 | 同一 reservationId 重复释放 → 不重复减少 locked | InventoryReservationTest.releaseIdempotent | 一致 |
| AC-019 | 并发锁定最后 1 件：SQL 条件更新保证仅一个成功 | InventoryMapper.lockStock WHERE (total-locked)>=? | 一致 |

### 1.2 设计一致性

- Inventory.lock() 使用 SQL 条件更新（`UPDATE ... SET locked = locked + ? WHERE sku_id = ? AND (total - locked) >= ?`），数据库层面保证并发安全，与 story-design §3 一致。
- InventoryReservation 状态机 LOCKED → RELEASED/DEDUCTED，reconstitute 重建状态，与设计一致。
- 内部接口 POST /api/internal/inventory/reservations/lock、POST /release，与设计一致。

### 1.3 跨仓一致性

- repo-1 c93d113→78ffd23，与 DU-BE-403 metadata.yaml 一致。

### 1.4 代码质量

- 全模块 74 测试全绿。
- 并发安全通过 SQL 条件更新实现，无需乐观锁版本字段。
- 未发现 standards/ 规范违规。

### 1.5 知识同步候选

- 并发安全用 SQL 条件更新而非乐观锁版本号，适合库存扣减场景。
- 统一在 Change converge 阶段评估沉淀。

## 2. 发现清单

无 blocker；无 major 开放项。

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 全部 blocker/major finding 已闭环
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对
