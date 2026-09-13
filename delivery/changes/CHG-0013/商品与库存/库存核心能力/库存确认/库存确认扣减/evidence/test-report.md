# Test Report — 库存确认扣减 STORY-002-04-04-01

> 阶段：sdd-test 产物
> 状态流转: developing → testing

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-04-01（库存确认扣减）
- 执行时间: 2026-09-13
- 覆盖 AC: AC-015, AC-016, AC-017

## 1. 测试范围

确认扣减（total 和 locked 同时扣减）、幂等、状态机校验。

### TC 逐条执行

| TC | 归属 DU | 执行方式 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| TC-001 | DU-BE-404 | InventoryTest.confirmDeduction：total-=q、locked-=q，available 不变 | passed | repo-1 DU-BE-404 evidence |
| TC-002 | DU-BE-404 | InventoryReservationTest.confirmIdempotent：重复扣减不变 | passed | 同上 |
| TC-003 | DU-BE-404 | Inventory.confirmDeduction 超额 → InventoryException；非 LOCKED 状态拒绝 | passed | 同上 |

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 后端单元（mall-inventory） | 13 | 13 | 0 | 0 |
| 后端回归（mall-product） | 61 | 61 | 0 | 0 |

- 自动化通过率: 后端 74 tests passed。
- 缺陷: 无。

## 3. 证据清单

- repo-1 DU-BE-404：implementation/ai-platform-backend/delivery/CHG-0013/商品与库存/库存核心能力/库存确认/库存确认扣减/DU-BE-404/evidence/
- Change 级索引：evidence/evidence.yaml EV-013
