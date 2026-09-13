# Test Report（Change 级聚合）— CHG-0010

> 阶段：sdd-test 聚合产物（多 Story Change）
> 位置：CHG-0010/evidence/test-report.md
> TC 逐条执行明细在各 Story evidence/test-report.md，本文件仅聚合汇总与跨 Story 回归结论。

## 0. 元信息

- Change ID: CHG-0010
- Implementation 来源: implementation.md + 两 Story implementation.md
- 状态流转: developing → testing
- 执行时间: 2026-09-13
- Evidence 索引: evidence/evidence.yaml（EV-015~018 test-run，EV-011~014 evidence-ref）

## 1. 测试范围

- 覆盖 DU: DU-BE-302 / DU-FE-301 / DU-BE-303 / DU-FE-302
- 覆盖 Story: 分类管理（TC-001~012）、品牌管理（TC-001~009），逐条结果见：
  - 商品与库存/分类与品牌管理/分类管理/分类管理/evidence/test-report.md
  - 商品与库存/分类与品牌管理/品牌管理/品牌管理/evidence/test-report.md

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 单元测试（后端 domain） | 15 | 15 | 0 | 0 |
| 集成测试（后端 MockMvc/H2，含冒烟与 TC-009 并发） | 21 | 21 | 0 | 0 |
| 前端自动化（vitest 全量终态） | 28 | 28 | 0 | 0 |
| 前端质量门（vue-tsc / eslint / build） | 3 门 | 3 门通过 | 0 | 0 |
| E2E（浏览器手工联调，2 个页面） | 2 | 0 | 0 | 2（待集成环境） |

- 后端单次 `mvn -pl mall-services/mall-product -am test`：36 passed（分类 22 + 品牌 14 + 冒烟 1），跨 Story 回归一次验证。
- 前端 mall-admin 单次 pnpm 全量：28 passed，type-check 0 error、eslint 0 error、build 成功。
- 自动化通过率: 67/67 = 100%。
- 未闭环缺陷: 无；dev 期 Red 轮次（6 项）均在各 DU red-green.md 闭环并有复测证据。

## 3. 证据清单

- repo-1：DU-BE-302 evidence/test-output.log、DU-BE-303 evidence/test-output.log
- repo-2：DU-FE-301 evidence/logs/、DU-FE-302 evidence/logs/
- Change 级：evidence/evidence.yaml EV-015~018（test-run）、EV-011~014（evidence-ref）
