# Test Report（Change 级聚合）— CHG-0011

> 阶段：sdd-test 聚合产物（多 Story Change）
> 位置：CHG-0011/evidence/test-report.md
> TC 逐条执行明细在各 Story evidence/test-report.md，本文件仅聚合汇总与跨 Story 回归结论。

## 0. 元信息

- Change ID: CHG-0011
- Implementation 来源: implementation.md + 两 Story implementation.md
- 状态流转: developing → testing
- 执行时间: 2026-09-13
- Evidence 索引: evidence/evidence.yaml（EV-011~012 test-run，EV-008~010 evidence-ref）

## 1. 测试范围

- 覆盖 DU: DU-BE-304 / DU-BE-305 / DU-FE-303
- 覆盖 Story: 商品 SPU 管理（TC-001~011）、SKU 与规格管理（TC-001~008），逐条结果见：
  - 商品与库存/商品与 SKU 管理/商品主数据/商品 SPU 管理/evidence/test-report.md
  - 商品与库存/商品与 SKU 管理/SKU 与规格/SKU 与规格管理/evidence/test-report.md

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 单元测试（后端 Product/Sku domain） | 含于 36 | 全通过 | 0 | 0 |
| 集成测试（后端 ProductAdminApiTest MockMvc/H2） | 9 | 9 | 0 | 0 |
| 前端自动化（vitest 全量终态） | 28 | 28 | 0 | 0 |
| 前端质量门（vue-tsc / eslint / build） | 3 门 | 3 门通过 | 0 | 0 |
| E2E（浏览器手工联调） | 1 | 0 | 0 | 1（待集成环境） |

- 后端单次 `mvn -pl mall-services/mall-product -am test`：36 passed（商品 9 + 分类 21 + 品牌 14 - 重复计数，实际全模块 36），跨 Story 回归一次验证。
- 前端 mall-admin 单次 pnpm 全量：28 passed，type-check 0 error、eslint 0 error、build 成功。
- 自动化通过率: 后端 36/36 + 前端 28/28 = 100%。
- 未闭环缺陷: 无；dev 期 Red 轮次（4 项）均在各 DU red-green.md 闭环并有复测证据。

## 3. 证据清单

- repo-1：DU-BE-304 evidence/test-output.log、DU-BE-305 evidence/test-output.log
- repo-2：DU-FE-303 evidence/logs/
- Change 级：evidence/evidence.yaml EV-011~012（test-run）、EV-008~010（evidence-ref）
