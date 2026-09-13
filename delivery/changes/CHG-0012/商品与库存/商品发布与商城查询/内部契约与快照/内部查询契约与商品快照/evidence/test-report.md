# Test Report — 内部查询契约与商品快照 STORY-002-03-03-01

> 阶段：sdd-test 产物
> 位置：Story 级 evidence/test-report.md

## 0. 元信息

- Change ID: CHG-0012
- Story ID: STORY-002-03-03-01（内部查询契约与商品快照）
- Implementation 来源: 同目录 implementation.md（repo-1 DU-BE-308）
- 状态流转: developing → testing
- 执行时间: 2026-09-13
- Evidence 索引: CHG-0012/evidence/evidence.yaml（EV-004 code-change、EV-011 test-run、EV-009 evidence-ref）

## 1. 测试范围

- 测试范围摘要：内部查询返回完整 ProductSnapshot 字段（productId/skuId/productName/skuName/skuAttributes/price/image/currentStatus）、price 单位为分、商品不存在 404、SKU 不属于商品 404。
- 覆盖 DU: DU-BE-308

### TC 逐条执行

| TC | 归属 DU | 执行方式 | 结果 | 证据位置 |
| --- | --- | --- | --- | --- |
| TC-001 | DU-BE-308 | InternalProductApiTest.internalSnapshotFullFields：返回完整快照，price=9900（分），skuAttributes.颜色=黑 | passed | repo-1 DU-BE-308 evidence |
| TC-002 | DU-BE-308 | InternalProductApiTest.internalProductNotFound：商品不存在 → 404 | passed | 同上 |
| TC-003 | DU-BE-308 | InternalProductApiTest.internalSkuNotBelongsToProduct：SKU 不属于商品 → 404 | passed | 同上 |

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 后端集成（InternalProductApiTest） | 3 | 3 | 0 | 0 |
| 后端全模块回归 | 61 | 61 | 0 | 0 |

- 自动化通过率: mall-product 61 passed（含 InternalProductApiTest 3），无回归。

## 3. 证据清单

- repo-1 DU-BE-308：implementation/ai-platform-backend/delivery/CHG-0012/商品与库存/商品发布与商城查询/内部契约与快照/内部查询契约与商品快照/DU-BE-308/evidence/
- Change 级索引：evidence/evidence.yaml EV-011（后端 61 passed）、EV-009（DU-BE-308 evidence-ref）
