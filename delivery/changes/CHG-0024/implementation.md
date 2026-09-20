# Implementation（跨仓实施汇总）— CHG-0024 M6 AI 智能应用

> 阶段：sdd-dev 产物。本文件为 Change 级跨 Story 汇总，各 Story 实施正文见对应 Story 目录，本文件只引用不复制。

## 0. 元信息

- Change ID：CHG-0024（M6 AI 智能应用）
- 实施日期：2026-09-20
- 范围：AI 智能导购（S1）、AI 商品对比（S2）、RAG 智能客服与知识库（S3）、AI 订单助手（S4）
- 参与仓库：repo-1 / repo-2 / repo-3 / repo-4

## 1. Story 实施总览

| Story | DU | 仓库 | 状态 |
| --- | --- | --- | --- |
| STORY-008-01-01 AI 智能导购 | DU-BE-001 / DU-AI-001 / DU-FE-001 | repo-1 / repo-3 / repo-2 | completed |
| STORY-008-02-01 AI 商品对比 | DU-AI-002 / DU-FE-002 | repo-3 / repo-2 | completed |
| STORY-008-03-01 RAG 智能客服与知识库 | DU-INFRA-001 / DU-AI-003 / DU-FE-003 | repo-4 / repo-3 / repo-2 | completed |
| STORY-008-04-01 AI 订单助手 | DU-AI-004 / DU-FE-004 | repo-3 / repo-2 | completed |

## 2. Commit 记录

| Commit | 仓库 | DU | 说明 |
| --- | --- | --- | --- |
| eab992d | repo-1 | DU-BE-001 | 网关 /api/ai/** 路由（8120）、permitAll 与角色矩阵、V12 知识库权限种子、切片/契约 7 例 |
| bc984bc | repo-3 | DU-AI-001 | 导购五节点链 + enforce_grounding、Tool 注册/搜索降级、JWT/会话/FeatureGate、推荐端点、pytest 28 例 |
| 5dd4508 | repo-2 | DU-FE-001 | AssistantView 对话/澄清/卡片/403 空态、路由与导航开关、vitest 6 例 |
| cf5c18c | repo-4 | DU-INFRA-001 | compose ai-service 容器（四中间件 health）、.env.example AI 段、ai_service 库 + ai_action_audit DDL |
| 06b0610 | repo-3 | DU-AI-002 | 批量详情 Tool（2~6/单点降级）、对比五节点链、/api/ai/compare 契约、pytest 15 例 |
| e2734f9 | repo-3 | DU-AI-003 | RAG 管道（MinIO/Embedding/ES kNN/MySQL）、SupportAgent 注入防护与脱敏、五端点、pytest 22 例 |
| 736f828 | repo-3 | DU-AI-004 | order_tools/OrdersAgent/pendingAction 确认流/审计/双端点、pytest 16 例 |
| f2fd7ca | repo-2 | DU-FE-002/003/004 | mall-web Compare/Support/OrderAssistant 三视图 + mall-admin KnowledgeListView 与五端点、vitest 全绿 |

以上均为本地提交，未 push。

## 3. 各 Story 实施引用

- AI 智能导购：[stories/STORY-008-01-01/implementation.md](stories/STORY-008-01-01/implementation.md)
- AI 商品对比：[stories/STORY-008-02-01/implementation.md](stories/STORY-008-02-01/implementation.md)
- RAG 智能客服与知识库：[stories/STORY-008-03-01/implementation.md](stories/STORY-008-03-01/implementation.md)
- AI 订单助手：[stories/STORY-008-04-01/implementation.md](stories/STORY-008-04-01/implementation.md)

## 4. Fan-in 状态

- [x] du-materialized：10 个 DU 全部物化到对应仓
- [x] du-fan-in-testing：四 Story 测试证据回传
- [x] du-fan-in-complete：10 个 DU 全部 completed，result commit 经 `openspec du sync-status CHG-0024` 与各仓 HEAD 对齐

## 5. 关键技术决策

1. **成功直出/错误信封混合契约**：ai-service 成功响应直出业务结构；错误为 `{success,code,message,traceId}` 信封经 axios reject，前端不 unwrap 成功体。
2. **AI fail-closed 开关**：四能力开关显式 false 或读取失败 → 403 + 入口隐藏；与 M5 fail-open 参数消费按场景区分。
3. **Grounding 工程兜底**：Tool 注册表 + 字段白名单 + enforce_grounding + 缺失即声明，ID 不可回溯即判失败。
4. **写操作人机确认**：Intent→pendingAction（GETDEL 一次性令牌 + memberId 绑定 + TTL，Redis 故障降级内存令牌）→confirm→Java 域终裁；首期写白名单仅 cancel_order。
5. **Java 依赖隔离测试**：JavaMock/httpx mock 全部上游、mock provider 确定性意图分类；真实端到端归 C 类 Integration Gate。
