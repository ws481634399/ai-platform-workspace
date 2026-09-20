# Story Implementation — STORY-008-01-01

## 0. 元信息

- Change: CHG-0024
- Story: STORY-008-01-01 — AI 智能导购
- Tasks Source: DU task-spec.md（DU-BE-001 / DU-AI-001 / DU-FE-001，权威划分见 story-design.md §5）
- Started At: 2026-09-20T11:20:00+08:00

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
|---|---|---|---|---|
| DU-BE-001 | repo-1 | completed | — | eab992d |
| DU-AI-001 | repo-3 | completed | — | bc984bc |
| DU-FE-001 | repo-2 | completed | — | 5dd4508 |

> Baseline 为空说明：repo-3（ai-platform-ai-service）为本 CHG 前已初始化的独立仓（M0 基线），DU 物化未记录历史基线；
> repo-1 / repo-2 同口径留空（DU metadata.baseline.commit 为空），结果 commit 见 §2。

## 2. Commit 记录

- eab992d（repo-1，DU-BE-001，本地未推送）
- bc984bc（repo-3，DU-AI-001，本地未推送）
- 5dd4508（repo-2，DU-FE-001，本地未推送）

## 3. 各仓实施引用

- DU-BE-001：implementation/ai-platform-backend/delivery/CHG-0024/AI 智能应用/AI 智能导购/智能导购能力/AI 智能导购/DU-BE-001/implementation.md
- DU-AI-001：implementation/ai-platform-ai-service/delivery/CHG-0024/AI 智能应用/AI 智能导购/智能导购能力/AI 智能导购/DU-AI-001/implementation.md
- DU-FE-001：implementation/ai-platform-frontend/delivery/CHG-0024/AI 智能应用/AI 智能导购/智能导购能力/AI 智能导购/DU-FE-001/implementation.md

## 4. Fan-in 状态

- [x] du-materialized
- [x] du-fan-in-testing
- [x] du-fan-in-complete

## 5. 实施要点与偏离记录

- AI 调用链路统一经 mall-gateway 透传（MEMBER Bearer 原样转发），ai-service 不直连 Java 业务库，网关路由 ai-service:8120（stripPrefix=false，随既有直连路由模式）。
- 成功响应直出 §2.1 契约结构（不包 UnifyResult 信封），错误路径走信封（DEV-1，已记录于 DU-AI-001 implementation.md）。
- FastAPI RequestValidationError 统一映射 400（框架默认 422，对齐设计契约错误码）（DEV-2）。
- LLM synthesize 异常时兜底直出 Tool 候选列表，保证服务可用性（DEV-3）。
- 回归结果：mall-gateway surefire 34 tests 0 failures；ai-service pytest 28 passed + ruff clean；mall-web vitest 111 tests + vue-tsc clean。
