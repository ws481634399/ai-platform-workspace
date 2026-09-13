# Test Report — 库存锁定与释放 STORY-002-04-03-01

> 阶段：sdd-test 产物
> 状态流转: developing → testing

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-03-01（库存锁定与释放）
- 执行时间: 2026-09-13
- 覆盖 AC: AC-010, AC-011, AC-012, AC-013, AC-014, AC-019

## 1. 测试范围

库存锁定（SQL 条件更新并发安全）、可用不足拒绝、reservationId 幂等、释放与幂等。

### TC 逐条执行

| TC | 归属 DU | 执行方式 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| TC-010 | DU-BE-403 | InventoryTest.lockAndRelease：锁定后 locked+=q、available=total-locked | passed | repo-1 DU-BE-403 evidence |
| TC-011 | DU-BE-403 | Inventory.lock 超额 → InventoryException.insufficient；lockStock SQL rows=0 | passed | 同上 |
| TC-012 | DU-BE-403 | InventoryApplicationService.lock：reservationId 重复 → 返回已有预留 | passed | 同上 |
| TC-013 | DU-BE-403 | Inventory.release：locked-=q，ReservationStatus → RELEASED | passed | 同上 |
| TC-014 | DU-BE-403 | InventoryReservationTest.releaseIdempotent：重复释放不变 | passed | 同上 |
| TC-019 | DU-BE-403 | lockStock SQL 条件更新 `WHERE (total - locked) >= ?` 保证并发安全 | passed | 同上（设计验证） |

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 后端单元（mall-inventory） | 13 | 13 | 0 | 0 |
| 后端回归（mall-product） | 61 | 61 | 0 | 0 |

- 自动化通过率: 后端 74 tests passed。
- 并发安全：lockStock 使用 SQL 条件更新，数据库层面保证原子性。
- 缺陷: 无。

## 3. 证据清单

- repo-1 DU-BE-403：implementation/ai-platform-backend/delivery/CHG-0013/商品与库存/库存核心能力/库存预留/库存锁定与释放/DU-BE-403/evidence/
- Change 级索引：evidence/evidence.yaml EV-013
