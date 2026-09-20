# Story Implementation — STORY-008-02-01

## 0. 元信息

- Change: CHG-0024
- Story: STORY-008-02-01 — AI 商品对比
- Tasks Source: DU task-spec.md（DU-AI-002 / DU-FE-002，权威划分见 story-design.md §5）
- Started At: 2026-09-20T18:00:00+08:00

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
|---|---|---|---|---|
| DU-AI-002 | repo-3 | completed | — | 06b0610 |
| DU-FE-002 | repo-2 | completed | — | f2fd7ca |

> DU-FE-002 与 DU-FE-003/004 共享接线文件（api/ai.ts、router、MallLayout），三个前端 DU 联合开发、合并为同一 feat commit（f2fd7ca），DU 级分别登记，见 §3。

## 2. Commit 记录

本 Story 直接产出：

- 06b0610（repo-3，DU-AI-002，本地未推送，EV-005）
- f2fd7ca（repo-2，DU-FE-002/003/004 联合提交，本地未推送；本 Story 引用 DU-FE-002 部分，EV-008）

Change 全量 code-change 台账（repos-coverage：fan-in 覆盖 evidence 全部条目）：

- eab992d（repo-1，STORY-008-01 / DU-BE-001，EV-001，本地未推送）
- bc984bc（repo-3，STORY-008-01 / DU-AI-001，EV-002，本地未推送）
- 5dd4508（repo-2，STORY-008-01 / DU-FE-001，EV-003，本地未推送）
- cf5c18c（repo-4，STORY-008-03 / DU-INFRA-001，EV-004，本地未推送）
- 06b0610（repo-3，本 Story / DU-AI-002，EV-005，本地未推送）
- e2734f9（repo-3，STORY-008-03 / DU-AI-003，EV-006，本地未推送）
- 736f828（repo-3，STORY-008-04 / DU-AI-004，EV-007，本地未推送）
- f2fd7ca（repo-2，STORY-008-02/03/04 / DU-FE-002/003/004 联合，EV-008，本地未推送）

## 3. 各仓实施引用

- DU-AI-002：implementation/ai-platform-ai-service/delivery/CHG-0024/AI 智能应用/AI 商品对比/商品对比能力/AI 商品对比/DU-AI-002/implementation.md
- DU-FE-002：implementation/ai-platform-frontend/delivery/CHG-0024/AI 智能应用/AI 商品对比/商品对比能力/AI 商品对比/DU-FE-002/implementation.md

## 4. Fan-in 状态

- [x] du-materialized
- [x] du-fan-in-testing
- [x] du-fan-in-complete

## 5. 实施要点与偏离记录

- 对比链路零新增中间件：批量详情 Tool 经网关调 mall-product（asyncio.gather 并发、单点失败降级占位不阻断），ai-service 不直连业务库。
- 维度对比严格 grounding：表格单元格只取 Tool 原值，缺键统一"暂无该项数据"；AI 总结硬条款必须引用 dimensions 真实属性，缺失属性不得作为依据。
- 前端商品选择器支持关键词搜索勾选 2~6 件，表格行=维度列=商品；页面含"价格以结算页为准"；403 空态/5xx 可重试。
- 回归结果：ai-service pytest 全量 43 passed（含对比 15 例）+ ruff clean；mall-web vitest 129 passed（含 CompareView 5 例）、vue-tsc/eslint 0 error、vite build 通过。
