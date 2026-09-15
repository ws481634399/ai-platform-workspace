# Test Report（Change 聚合兼容层）

## 0. 元信息

- Change ID：CHG-0015（M3 前置就绪修复）
- Implementation 来源：`implementation.md`
- Evidence 索引：`evidence/evidence.yaml`
- 权威来源：`商品与库存/商品发布与商城查询/商城查询/商城商品列表与详情查询/evidence/test-report.md`

## 1. 测试范围

覆盖 AC-001～AC-012（14 条 TC 全部 passed）：网关匿名商城路由与 internal 外拒、服务间凭证、库存分页、五域业务 ID 字符串化与入参双形态、真实价区聚合与无有效 SKU 过滤、mall-admin 五页面零回归、雪花 ID 端到端无精度偏差。

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | ---: | ---: | ---: | ---: |
| 后端 Maven 全量（含 DEV-4 回归） | 198 | 198 | 0 | 0 |
| 前端 Vitest | 31 | 31 | 0 | 0 |
| 前端 type-check / lint(0 error) / build | 3 | 3 | 0 | 0 |
| 真后端端到端冒烟场景 | 9 | 9 | 0 | 0 |

## 3. 证据清单

- Story test report：`商品与库存/商品发布与商城查询/商城查询/商城商品列表与详情查询/evidence/test-report.md`（14 TC 逐条结果）
- repo-1 DU evidence：EV-010（evidence-ref）→ DU-BE-501/evidence/（red-green.md + logs/）
- repo-2 DU evidence：EV-011（evidence-ref）→ DU-FE-501/evidence/（静态门禁日志 + smoke-api-verify.log + smoke/）
- 联调缺陷闭环：EV-012（DEV-4，bd309ec 修复，red→green 20/20）
