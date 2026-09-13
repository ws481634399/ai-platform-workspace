# Test Report — 商品上下架与发布 STORY-002-03-01-01

> 阶段：sdd-test 产物
> 位置：Story 级 evidence/test-report.md
> 输入：test-design.md + 仓内 DU implementation.md
> 产出状态：testing

本文档记录测试执行情况与证据；仓侧测试日志正文不复制，以 evidence-ref 引用。

## 0. 元信息

- Change ID: CHG-0012
- Story ID: STORY-002-03-01-01（商品上下架与发布）
- Implementation 来源: 同目录 implementation.md（repo-1 DU-BE-306、repo-2 DU-FE-304）
- 状态流转: developing → testing
- 执行时间: 2026-09-13
- Evidence 索引: CHG-0012/evidence/evidence.yaml（EV-011 后端 test-run、EV-012 前端 test-run、EV-007/EV-010 evidence-ref）

## 1. 测试范围

- 测试范围摘要：Product 聚合 publish/unpublish 不变量（主图校验、ENABLED SKU 校验、价格合法、DISABLED 拒绝发布、状态流转）、领域事件注册、管理端 publish/unpublish API 与权限码 product:product:publish、前端上架/下架按钮与 API 客户端。
- 覆盖 DU: DU-BE-306 / DU-FE-304

### TC 逐条执行

| TC | 归属 DU | 执行方式 | 结果 | 证据位置 |
| --- | --- | --- | --- | --- |
| TC-001 | DU-BE-306 | ProductAdminApiTest.publishDraftProduct：DRAFT 商品含主图+ENABLED SKU → POST publish → 200，status=ON_SALE | passed | repo-1 DU-BE-306 evidence |
| TC-002 | DU-BE-306 | ProductAdminApiTest.publishWithoutMainImageRejected：无主图商品 publish → 400 B2150 | passed | 同上 |
| TC-003 | DU-BE-306 | ProductAdminApiTest.publishWithoutEnabledSkuRejected：无 ENABLED SKU publish → 400 B2150 | passed | 同上 |
| TC-004 | DU-BE-306 | ProductAdminApiTest.publishDisabledRejected：DISABLED 商品 publish → 400 B2150 | passed | 同上 |
| TC-005 | DU-BE-306 | ProductAdminApiTest.unpublishOnSaleProduct：ON_SALE 商品 unpublish → 200，status=OFF_SALE | passed | 同上 |
| TC-006 | DU-BE-306 | ProductAdminApiTest.republishAfterUnpublish：OFF_SALE 重新 publish → ON_SALE | passed | 同上 |
| TC-007 | DU-BE-306 | ProductAdminApiTest.publishPermissionEnforced：无 product:product:publish 权限 → 403 | passed | 同上 |
| TC-008 | DU-FE-304 | product.ts publish/unpublish API 客户端类型检查 + build | passed | repo-2 DU-FE-304 evidence |
| TC-009 | DU-FE-304 | ProductListView 上下架按钮装配 + vitest 全仓 28 passed | passed | 同上 |

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 后端单元+集成（mall-product 全模块） | 61 | 61 | 0 | 0 |
| 前端自动化（vitest 全仓） | 28 | 28 | 0 | 0 |
| 前端质量门（vue-tsc / build） | 2 门 | 2 门通过 | 0 | 0 |

- 自动化通过率: 后端 mall-product 61 passed（含 CHG-0012 新增 17 个用例：ProductAdminApiTest 8 + MallProductApiTest 6 + InternalProductApiTest 3），无回归；前端 28 passed + type-check/build 全通过。
- 缺陷: 无未闭环缺陷。

## 3. 证据清单

- repo-1 DU-BE-306：implementation/ai-platform-backend/delivery/CHG-0012/商品与库存/商品发布与商城查询/发布与状态/商品上下架与发布/DU-BE-306/evidence/
- repo-2 DU-FE-304：implementation/ai-platform-frontend/delivery/CHG-0012/商品与库存/商品发布与商城查询/发布与状态/商品上下架与发布/DU-FE-304/evidence/
- Change 级索引：evidence/evidence.yaml EV-011（后端 61 passed）、EV-012（前端 28 passed + 质量门）
