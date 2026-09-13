# Test Report — 库存初始化与查询 STORY-002-04-01-01

> 阶段：sdd-test 产物
> 位置：Story 级 evidence/test-report.md
> 状态流转: developing → testing

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-01-01（库存初始化与查询）
- 执行时间: 2026-09-13
- 覆盖 AC: AC-001 ~ AC-007

## 1. 测试范围

库存初始化、单查/批查/分页查询，SKU 存在性校验，幂等初始化，负库存拒绝。

### TC 逐条执行

| TC | 归属 DU | 执行方式 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| TC-001 | DU-BE-401 | InventoryTest.initializeSetsQuantities：初始化后 total=入参、locked=0、available=total | passed | repo-1 DU-BE-401 evidence |
| TC-002 | DU-BE-401 | InventoryApplicationService.init：SkuClient.exists=false → InventoryException.skuNotFound | passed | 同上 |
| TC-003 | DU-BE-401 | 重复初始化同一 SKU → InventoryException.alreadyExists (CONFLICT) | passed | 同上 |
| TC-004 | DU-BE-401 | InventoryTest.initializeRejectsNegative：负库存拒绝 | passed | 同上 |
| TC-005 | DU-BE-401 | InventoryAdminController GET /{skuId} 返回 total/locked/available | passed | 同上 |
| TC-006 | DU-BE-401 | InventoryAdminController POST /batch 批量查询 | passed | 同上 |
| TC-007 | DU-BE-401 | InventoryAdminController GET /stocks 分页查询 | passed | 同上 |

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 后端单元（mall-inventory） | 13 | 13 | 0 | 0 |
| 后端回归（mall-product） | 61 | 61 | 0 | 0 |
| 前端质量门（type-check/build） | 2 门 | 2 门通过 | 0 | 0 |

- 自动化通过率: 后端 74 tests passed；前端 type-check + build 通过。
- 缺陷: 无。

## 3. 证据清单

- repo-1 DU-BE-401：implementation/ai-platform-backend/delivery/CHG-0013/商品与库存/库存核心能力/库存基础/库存初始化与查询/DU-BE-401/evidence/
- repo-2 DU-FE-401：implementation/ai-platform-frontend/delivery/CHG-0013/商品与库存/库存核心能力/库存基础/库存初始化与查询/DU-FE-401/evidence/
- Change 级索引：evidence/evidence.yaml EV-013（后端 74 passed）、EV-014（前端质量门）
