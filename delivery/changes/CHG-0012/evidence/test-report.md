# Test Report（Change 级聚合）— CHG-0012

> 阶段：sdd-test 聚合产物（多 Story Change）
> 位置：CHG-0012/evidence/test-report.md
> TC 逐条执行明细在各 Story evidence/test-report.md，本文件仅聚合汇总与跨 Story 回归结论。

## 0. 元信息

- Change ID: CHG-0012
- Implementation 来源: implementation.md + 三 Story implementation.md
- 状态流转: developing → testing
- 执行时间: 2026-09-13
- Evidence 索引: evidence/evidence.yaml（EV-011~012 test-run，EV-007~010 evidence-ref）

## 1. 测试范围

- 覆盖 DU: DU-BE-306 / DU-BE-307 / DU-BE-308 / DU-FE-304
- 覆盖 Story: 商品上下架与发布、商城商品列表与详情查询、内部查询契约与商品快照，逐条结果见各 Story evidence/test-report.md。

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 后端集成（ProductAdminApiTest publish/unpublish） | 8 | 8 | 0 | 0 |
| 后端集成（MallProductApiTest） | 6 | 6 | 0 | 0 |
| 后端集成（InternalProductApiTest） | 3 | 3 | 0 | 0 |
| 后端全模块回归 | 61 | 61 | 0 | 0 |
| 前端自动化（vitest） | 28 | 28 | 0 | 0 |
| 前端质量门（vue-tsc / build） | 2 门 | 2 门通过 | 0 | 0 |

- 后端单次 `mvn -pl mall-services/mall-product -am test`：61 passed（含 CHG-0012 新增 17 用例），跨 Story 回归一次验证。
- 前端 mall-admin 单次全量：28 passed，type-check 0 error、build 成功。
- 自动化通过率: 后端 61/61 + 前端 28/28 = 100%。
- 未闭环缺陷: 无。

## 3. 证据清单

- repo-1：DU-BE-306/307/308 evidence/
- repo-2：DU-FE-304 evidence/
- Change 级：evidence/evidence.yaml EV-011~012（test-run）、EV-007~010（evidence-ref）
