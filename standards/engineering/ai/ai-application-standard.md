---
title: AI 应用运行安全与可靠性标准
tags: [ai, agent, security, llm, rag]
repos: [repo-2, repo-3, repo-4]
related-changes: [CHG-0024]
created-at: 2026-09-20T23:00:00+08:00
updated-at: 2026-09-20T23:00:00+08:00
---

# AI 应用运行安全与可靠性标准

> 本标准沉淀 CHG-0024（M6 AI 智能应用）交付的运行时落地模式，是新增 AI Tool / Agent / 写动作时必须遵循的工程基线。通用方法论见同目录 prompt/agent/tool-calling/knowledge 标准，本文件只规定运行时强制模式。

## 1. AI 能力开关 fail-closed

- 每项 AI 能力绑定独立开关（ai.shopping/compare/rag/order-assistant.enabled）；显式 `false` **或读取失败**时：ai-service 拒绝请求（403），mall-web 隐藏对应入口，双端生效。
- 场景区分：主交易路径的参数消费 fail-open（见 backend/dynamic-config-standard），**新增 AI 能力一律 fail-closed**，禁止 AI 因配置基础设施故障而默认放行。
- 前端入口隐藏不是安全边界：直达路由/直调端点必须由后端 403 收口。

## 2. Grounding 防幻觉工程兜底

不得只依赖 System Prompt，必须四件套同时存在：

1. **Tool 注册表**：LLM 只能调用注册 Tool，Tool 有明确输入/输出 Schema；
2. **字段白名单**：Tool 只返回业务既有公开字段，ai-service 不新增业务字段语义；
3. **enforce_grounding 包装**：LLM 输出引用的商品/属性必须可回溯到本次 Tool 返回；推荐/对比 ID 不可回溯即判失败；
4. **缺失即声明**：Tool 未返回的字段显示"暂无该项数据"，不得推测补齐。

价格/库存/订单状态必须逐格 == Tool 实时返回值；结论必须引用具体属性数据，禁止无依据的"A 最好"。

## 3. Prompt Injection 三层防护

| 层 | 强制要求 |
| --- | --- |
| ① Prompt 层 | SystemPrompt 规定角色与边界；RAG Context 作为不完全可信输入隔离注入，不覆盖 System Prompt / Security Policy，不提升 Tool 权限 |
| ② Tool Schema 层 | 身份参数（memberId 等）不出现在 Tool 可填参数中，只从可信身份上下文注入 |
| ③ Backend 授权层 | Java Backend 对归属/状态/权限二次校验并最终裁决，DENY 错误（404/403）原样透传；ai-service 的过滤不替代后端校验 |

Secret（API Key/Token/会员敏感字段）必须在 Prompt 拼接前过滤，输出同样脱敏。

## 4. 高风险写操作人机确认

- LLM 意图 ≠ 执行。写操作统一状态机：Intent → Proposed Action（pendingAction）→ 用户确认 → confirm 端点执行 → Java Domain 终裁。未确认不执行。
- pendingAction 要求：**一次性令牌**（Redis GETDEL 语义，重复消费 → 409）、**memberId 绑定**（令牌仅本人可消费）、**TTL** 过期失效；Redis 故障可降级内存 TTL 令牌并打 WARN。
- 写操作白名单制：首期仅 cancel_order；新增写动作必须显式扩白名单并经评审。
- 写操作必须落审计（memberId/conversationId/toolName/businessId/parameters summary/result/traceId/occurredAt），成功/失败各一条。

## 5. 混合栈响应契约

- ai-service **成功响应直出业务结构**（无 UnifyResult 信封）；错误经 `{success,code,message,traceId}` 信封返回，前端按 axios reject 消费，不对成功体 unwrap。
- 错误分类：400 参数（含无效 id/数量越界，不静默剔除）/ 401 未认证 / 403 开关或权限 / 404 不存在 / 409 冲突（令牌重复/状态不符）/ 502 LLM 或 Java 上游失败。
- 出站 Java 调用必须携带入站 X-Trace-Id（一次请求一个 traceId 贯穿 mall-web → ai-service → Java API）。

## 6. Java 依赖隔离测试范式

- pytest 以 JavaMock/httpx mock 模拟全部 Java 上游（含 DENY 404 / 业务 409 / 幂等 / 并发分支）；mock provider 做确定性意图分类；RAG 中间件以语义同构 stub 出证。
- 测试不得依赖真实 LLM key、Java 运行态或外部中间件；红灯失败原因必须是"功能未实现"。
- 真实多服务端到端统一归 Integration Gate，单测出证不豁免联调验收。
