# Test Report — 库存调整与流水 STORY-002-04-02-01

> 阶段：sdd-test 产物
> 状态流转: developing → testing

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-02-01（库存调整与流水）
- 执行时间: 2026-09-13
- 覆盖 AC: AC-008, AC-009, AC-018

## 1. 测试范围

库存调整（正/负 delta）、防负校验、流水记录。

### TC 逐条执行

| TC | 归属 DU | 执行方式 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| TC-001 | DU-BE-402 | InventoryTest.adjustUpdatesTotal：正数加、负数减，available 同步 | passed | repo-1 DU-BE-402 evidence |
| TC-002 | DU-BE-402 | InventoryTest.adjustRejectsNegativeResult：调整后 total<0 拒绝 | passed | 同上 |
| TC-003 | DU-BE-402 | InventoryLog 记录 operationType=ADJUST，含 before/after/quantity/businessId | passed | 同上 |

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 后端单元（mall-inventory） | 13 | 13 | 0 | 0 |
| 后端回归（mall-product） | 61 | 61 | 0 | 0 |

- 自动化通过率: 后端 74 tests passed。
- 缺陷: 无。

## 3. 证据清单

- repo-1 DU-BE-402：implementation/ai-platform-backend/delivery/CHG-0013/商品与库存/库存核心能力/库存调整/库存调整与流水/DU-BE-402/evidence/
- Change 级索引：evidence/evidence.yaml EV-013
