# Test Report（Change 级聚合）— CHG-0024 M6 AI 智能应用

## 0. 元信息

- Change ID：CHG-0024（M6 AI 智能应用）
- 日期：2026-09-20
- 本文件为 Change 级聚合，各 Story 执行细节见 stories/STORY-008-0X-01/evidence/test-report.md

## 1. 测试范围

- repo-1：网关 /api/ai/** 路由与角色矩阵切片
- repo-3：导购/对比/RAG/订单四链路 pytest + ruff
- repo-2：mall-web 四 AI 视图、mall-admin 知识库视图 vitest + type-check/eslint/build
- repo-4：compose ai-service 容器与 DDL 配置校验

## 2. 测试执行汇总

| 套件 | 命令 | 结果 | 用例数 |
| --- | --- | --- | --- |
| mall-gateway 切片/契约（repo-1） | `mvn -pl mall-gateway test` | passed | 7（新增） |
| ai-service pytest（repo-3，全量） | `uv run pytest tests/ -q` | passed | 81（导购 28 / 对比 15 / RAG 22 / 订单 16） |
| ai-service ruff | `uv run ruff check app tests` | clean | — |
| mall-web vitest（repo-2） | `pnpm vitest run` | passed，26 文件 | 129（Assistant 6 / Compare 5 / Support 6 / OrderAssistant 7） |
| mall-admin vitest（repo-2） | `pnpm vitest run` | passed，28 文件 | 114（knowledge 9） |
| mall-web / mall-admin type-check | `pnpm type-check` | passed | — |
| eslint | `pnpm exec eslint src` | 0 error | — |
| vite build | `pnpm build` | passed | — |
| infrastructure compose | `docker compose config` | passed（配置合法） | — |

## 3. AC 覆盖汇总

- AC-001~013（导购）：TC-001~010 全绿，见 Story1 test-report §3
- AC-014~021（对比）：TC-201~209 全绿，见 Story2 test-report §3
- AC-022~029（RAG）：TC-301~309 全绿，见 Story3 test-report §3
- AC-030~037（订单）：TC-401~409 全绿，见 Story4 test-report §3
- AC-038~040（横切）：X-Trace-Id 出站透传、LLM 故障错误映射、redact_secrets 过滤，均有用例

40 TC 全绿，40 AC 全覆盖，无 TC-NOT-TESTABLE 项。

## 4. 缺口备注

- 真实多服务端到端（网关 8080、真实 ES kNN 召回质量、真实取消含库存释放）归 C 类 M6 Integration Gate 七场景：单测以 JavaMock/语义同构 stub 出证，联调环境串验。
- ES topK/score 阈值默认值留联调样例实测。
