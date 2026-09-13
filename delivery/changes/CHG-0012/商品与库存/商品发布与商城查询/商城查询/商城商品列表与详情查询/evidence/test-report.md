# Test Report — 商城商品列表与详情查询 STORY-002-03-02-01

> 阶段：sdd-test 产物
> 位置：Story 级 evidence/test-report.md

## 0. 元信息

- Change ID: CHG-0012
- Story ID: STORY-002-03-02-01（商城商品列表与详情查询）
- Implementation 来源: 同目录 implementation.md（repo-1 DU-BE-307）
- 状态流转: developing → testing
- 执行时间: 2026-09-13
- Evidence 索引: CHG-0012/evidence/evidence.yaml（EV-003 code-change、EV-011 test-run、EV-008 evidence-ref）

## 1. 测试范围

- 测试范围摘要：商城列表仅返回 ON_SALE 商品、分类筛选、分页、创建时间倒序、详情完整信息、非 ON_SALE 404、不含库存字段、/api/mall/** 公开访问。
- 覆盖 DU: DU-BE-307

### TC 逐条执行

| TC | 归属 DU | 执行方式 | 结果 | 证据位置 |
| --- | --- | --- | --- | --- |
| TC-001 | DU-BE-307 | MallProductApiTest.mallListOnlyOnSale：DRAFT 商品不出现在商城列表 | passed | repo-1 DU-BE-307 evidence |
| TC-002 | DU-BE-307 | MallProductApiTest.mallListFilterAndPage：categoryId 筛选 + page/size 分页 | passed | 同上 |
| TC-003 | DU-BE-307 | MallProductApiTest.mallListOrderByCreatedAtDesc：按创建时间倒序 | passed | 同上 |
| TC-004 | DU-BE-307 | MallProductApiTest.mallDetailOnSale：ON_SALE 商品详情含 skus 与价格 | passed | 同上 |
| TC-005 | DU-BE-307 | MallProductApiTest.mallDetailNotOnSale404：DRAFT 商品详情 404 | passed | 同上 |
| TC-006 | DU-BE-307 | MallProductApiTest.mallDetailNoStockField：响应不含 stock | passed | 同上 |

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 后端集成（MallProductApiTest） | 6 | 6 | 0 | 0 |
| 后端全模块回归 | 61 | 61 | 0 | 0 |

- 自动化通过率: mall-product 61 passed（含 MallProductApiTest 6），无回归。

## 3. 证据清单

- repo-1 DU-BE-307：implementation/ai-platform-backend/delivery/CHG-0012/商品与库存/商品发布与商城查询/商城查询/商城商品列表与详情查询/DU-BE-307/evidence/
- Change 级索引：evidence/evidence.yaml EV-011（后端 61 passed）、EV-008（DU-BE-307 evidence-ref）
