# Test Report（Change 级聚合）— CHG-0013

> 阶段：sdd-test 聚合产物（多 Story Change）
> 位置：CHG-0013/evidence/test-report.md
> TC 逐条执行明细在各 Story evidence/test-report.md，本文件仅聚合汇总与跨 Story 回归结论。

## 0. 元信息

- Change ID: CHG-0013
- Implementation 来源: implementation.md + 四 Story implementation.md
- 状态流转: developing → testing
- 执行时间: 2026-09-13
- Evidence 索引: evidence/evidence.yaml（EV-013~014 test-run，EV-008~012 evidence-ref）

## 1. 测试范围

- 覆盖 DU: DU-BE-401 / DU-BE-402 / DU-BE-403 / DU-BE-404 / DU-FE-401
- 覆盖 Story: 库存初始化与查询、库存调整与流水、库存锁定与释放、库存确认扣减，逐条结果见各 Story evidence/test-report.md。

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 后端单元（mall-inventory） | 13 | 13 | 0 | 0 |
| 后端全模块回归（mall-product） | 61 | 61 | 0 | 0 |
| 前端质量门（type-check / build） | 2 门 | 2 门通过 | 0 | 0 |

- 后端单次 `mvn -pl mall-services/mall-inventory,mall-services/mall-product -am test`：74 passed，跨 Story 回归一次验证。
- 前端 mall-admin 单次全量：type-check 0 error、build 成功。
- 自动化通过率: 后端 74/74 = 100%；前端质量门全过。
- 未闭环缺陷: 无。

## 3. 证据清单

- repo-1：DU-BE-401/402/403/404 evidence/
- repo-2：DU-FE-401 evidence/
- Change 级：evidence/evidence.yaml EV-013~014（test-run）、EV-008~012（evidence-ref）
