# Story Implementation — STORY-008-04-01

## 0. 元信息

- Change: CHG-0024
- Story: STORY-008-04-01 — AI 订单助手
- Tasks Source: DU task-spec.md（DU-AI-004 / DU-FE-004，权威划分见 story-design.md §5）
- Started At: 2026-09-20T20:30:00+08:00

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
|---|---|---|---|---|
| DU-AI-004 | repo-3 | completed | — | 736f828 |
| DU-FE-004 | repo-2 | completed | — | f2fd7ca |

> DU-FE-004 与 DU-FE-002/003 共享接线文件，三个前端 DU 联合为同一 feat commit（f2fd7ca），DU 级分别登记。
> 审计表 ai_service.ai_action_audit 由 STORY-008-03-01 的 DU-INFRA-001 DDL 交付（Story 间复用）。

## 2. Commit 记录

本 Story 直接产出：

- 736f828（repo-3，DU-AI-004，本地未推送，EV-007）
- f2fd7ca（repo-2，DU-FE-002/003/004 联合提交，本地未推送；本 Story 引用 DU-FE-004 部分，EV-008）

Change 全量 code-change 台账（repos-coverage：fan-in 覆盖 evidence 全部条目）：

- eab992d（repo-1，STORY-008-01 / DU-BE-001，EV-001，本地未推送）
- bc984bc（repo-3，STORY-008-01 / DU-AI-001，EV-002，本地未推送）
- 5dd4508（repo-2，STORY-008-01 / DU-FE-001，EV-003，本地未推送）
- cf5c18c（repo-4，STORY-008-03 / DU-INFRA-001，EV-004，本地未推送）
- 06b0610（repo-3，STORY-008-02 / DU-AI-002，EV-005，本地未推送）
- e2734f9（repo-3，STORY-008-03 / DU-AI-003，EV-006，本地未推送）
- 736f828（repo-3，本 Story / DU-AI-004，EV-007，本地未推送）
- f2fd7ca（repo-2，STORY-008-02/03/04 / DU-FE-002/003/004 联合，EV-008，本地未推送）

## 3. 各仓实施引用

- DU-AI-004：implementation/ai-platform-ai-service/delivery/CHG-0024/AI 智能应用/AI 订单助手/订单助手能力/AI 订单助手/DU-AI-004/implementation.md
- DU-FE-004：implementation/ai-platform-frontend/delivery/CHG-0024/AI 智能应用/AI 订单助手/订单助手能力/AI 订单助手/DU-FE-004/implementation.md

## 4. Fan-in 状态

- [x] du-materialized
- [x] du-fan-in-testing
- [x] du-fan-in-complete

## 5. 实施要点与偏离记录

- 越权防护由架构保证：ai-service 调 mall-order 时透传原始 MEMBER Bearer（memberId 永不接受为请求参数），Java SecurityContext 零改动；确认令牌绑定 memberId，非本人无法消费。
- 写操作确认状态机：OrdersAgent 只签发 pendingAction（actionId uuid4，Redis SET NX EX 600），confirm 端点 GETDEL 原子一次性消费（拒绝也消费，符合一次性语义）；重复 confirm/Java 业务拒绝 → 409 透传 message；幂等双保险（actionId 消费 + mall-order CAS）。
- LLM 不参与状态措辞：statusText 按 F-23 确定性映射，PAID→"已支付等待发货"硬条款，多笔待支付走澄清分支。
- cancel_order 成功/失败均写 ai_action_audit，审计失败 ERROR 日志兜底不阻断主链路；Redis 故障降级内存 TTL 令牌。
- 前端 OrderAssistantView 原生模态二次确认（展示 orderNo/当前状态），"再想想"无写副作用；确认后卡片状态刷新；路由 requiresMember + 401 登录引导；入口同时受开关与登录态控制。
- 回归结果：ai-service pytest 全量 81 passed（含订单 16 例）+ ruff clean；mall-web vitest 129 passed（含 OrderAssistantView 7 例）、vue-tsc/eslint 0 error、vite build 通过。
