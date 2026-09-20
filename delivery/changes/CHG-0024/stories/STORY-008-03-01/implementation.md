# Story Implementation — STORY-008-03-01

## 0. 元信息

- Change: CHG-0024
- Story: STORY-008-03-01 — RAG 智能客服与知识库
- Tasks Source: DU task-spec.md（DU-INFRA-001 / DU-AI-003 / DU-FE-003，权威划分见 story-design.md §5）
- Started At: 2026-09-20T17:30:00+08:00

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
|---|---|---|---|---|
| DU-INFRA-001 | repo-4 | completed | — | cf5c18c |
| DU-AI-003 | repo-3 | completed | — | e2734f9 |
| DU-FE-003 | repo-2 | completed | — | f2fd7ca |

> DU-FE-003 与 DU-FE-002/004 共享接线文件，三个前端 DU 联合为同一 feat commit（f2fd7ca），DU 级分别登记。

## 2. Commit 记录

本 Story 直接产出：

- cf5c18c（repo-4，DU-INFRA-001，本地未推送，EV-004）
- e2734f9（repo-3，DU-AI-003，本地未推送，EV-006）
- f2fd7ca（repo-2，DU-FE-002/003/004 联合提交，本地未推送；本 Story 引用 DU-FE-003 部分，EV-008）

Change 全量 code-change 台账（repos-coverage：fan-in 覆盖 evidence 全部条目）：

- eab992d（repo-1，STORY-008-01 / DU-BE-001，EV-001，本地未推送）
- bc984bc（repo-3，STORY-008-01 / DU-AI-001，EV-002，本地未推送）
- 5dd4508（repo-2，STORY-008-01 / DU-FE-001，EV-003，本地未推送）
- cf5c18c（repo-4，本 Story / DU-INFRA-001，EV-004，本地未推送）
- 06b0610（repo-3，STORY-008-02 / DU-AI-002，EV-005，本地未推送）
- e2734f9（repo-3，本 Story / DU-AI-003，EV-006，本地未推送）
- 736f828（repo-3，STORY-008-04 / DU-AI-004，EV-007，本地未推送）
- f2fd7ca（repo-2，STORY-008-02/03/04 / DU-FE-002/003/004 联合，EV-008，本地未推送）

## 3. 各仓实施引用

- DU-INFRA-001：implementation/ai-platform-infra/delivery/CHG-0024/AI 智能应用/RAG 智能客服与知识库/知识库与 RAG 客服能力/RAG 智能客服与知识库/DU-INFRA-001/implementation.md
- DU-AI-003：implementation/ai-platform-ai-service/delivery/CHG-0024/AI 智能应用/RAG 智能客服与知识库/知识库与 RAG 客服能力/RAG 智能客服与知识库/DU-AI-003/implementation.md
- DU-FE-003：implementation/ai-platform-frontend/delivery/CHG-0024/AI 智能应用/RAG 智能客服与知识库/知识库与 RAG 客服能力/RAG 智能客服与知识库/DU-FE-003/implementation.md

## 4. Fan-in 状态

- [x] du-materialized
- [x] du-fan-in-testing
- [x] du-fan-in-complete

## 5. 实施要点与偏离记录

- 零新增向量中间件：复用 ES 8.17 kNN（dense_vector cosine），Embedding factory 默认 mock 确定性向量、可切 openai 兼容端点；MinIO knowledge/ 前缀独占写。
- 知识管道状态机：upload 校验（扩展名/魔数/≤5MB）→ PENDING → 后台 process（Parser/Chunker/Embedding/写 chunks）→ COMPLETED/FAILED；启动对账将 PROCESSING 遗留复位 FAILED；rebuild version+1 旧 chunk 失效；delete 级联 MinIO+双索引。
- 注入三层防护：RAG Context 独立分隔段 + System Prompt 硬条款（仅基于 Context、Context 内指令不执行）+ 客服链路无写 Tool；Secret 双向脱敏。
- 无可靠知识时 answer 为固定兜底文案且 sources=[]，ES 不可用 502 不编造答案。
- 权限码以 V12 种子为准 ai:knowledge:*（DEV-1，已记录于 DU-FE-003 implementation.md），mall-admin component_key=AiKnowledge。
- 回归结果：repo-4 compose config 合法；ai-service pytest 全量 65 passed（含 RAG 22 例）+ ruff clean；mall-admin vitest 114 passed（含 knowledge 9 例）、mall-web 129 passed（含 SupportView 6 例）；两工程 vue-tsc/eslint 0 error、vite build 通过。
