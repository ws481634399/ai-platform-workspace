# Convergence — CHG-0024 M6 AI 智能应用

## 0. 元信息

- change-id：CHG-0024
- 标题：M6 AI 智能应用（智能导购 / 商品对比 / RAG 智能客服与知识库 / AI 订单助手）
- 完成时间：2026-09-20
- 生命周期：当前 testing；本文件仅作收敛判断与知识登记，completed 由流程审批推进
- 参与仓库：repo-1（ai-platform-backend）、repo-2（ai-platform-frontend）、repo-3（ai-platform-ai-service）、repo-4（ai-platform-infrastructure）
- standards-need-update：yes（新增 1 篇 AI 应用运行标准）
- product-need-update：yes（Spec 晋升候选 1 篇 product/specs/AI 智能应用.md，待人工评审后落库）
- featuretree-need-update：yes（4 个 Story 节点 planned → delivered）
- glossary-need-update：yes（新建 product/glossary/terms.md，首批 AI 领域术语）
- review 结论：4 个 Story 均 approved；0 blocker / 0 major；观察项全部归入 C 类 Integration Gate，无代码缺口
- 仓指针对账：repository-result 已由 `openspec du sync-status CHG-0024` 回填（repo-1 9efde17、repo-2 f38873a、repo-3 c6b18dd、repo-4 8fe65bb）

## 1. 知识变化总结

本 Change 首次交付面向消费者的 AI 业务应用层，在 M0 工程骨架之上沉淀 6 类可跨 Change 复用的工程模式：

1. **AI 能力 fail-closed 开关语义**：ai.shopping/compare/rag/order-assistant.enabled 关闭或读取失败时，ai-service 拒绝（403）+ mall-web 隐藏入口，双端生效；与 M5 系统配置 fail-open 的参数消费语义形成场景区分——主交易路径 fail-open，新增 AI 能力 fail-closed。
2. **Grounding 防幻觉实施模式**：不靠 System Prompt 单点约束——Tool 注册表 + 返回字段白名单 + `enforce_grounding` 包装（LLM 引用的商品/属性必须可回溯到本次 Tool 返回）+ 缺失即声明（"暂无该项数据"）；推荐/对比 ID 不可回溯即判失败。
3. **Prompt Injection 三层防护**：① SystemPrompt 角色与边界约束；② Tool Schema 身份隔离（memberId 只来自身份上下文，Tool 参数无该字段）；③ Backend Authorization 终裁（Java 归属校验 DENY→404）；RAG Context 作为不完全可信输入隔离注入，不覆盖 System Prompt、不提升 Tool 权限；Secret 在 Prompt 拼接前双向脱敏。
4. **高风险写操作人机确认模式**：LLM 意图 ≠ 执行——Intent → Proposed Action（pendingAction，Redis GETDEL 一次性令牌 + memberId 绑定 + TTL，Redis 故障降级内存令牌）→ 用户确认 → confirm 端点执行 → Java Domain 终裁；重复消费 409、幂等透传；ai_action_audit 成功/失败各一条。
5. **混合栈响应契约**：ai-service 成功响应直出业务结构（无 UnifyResult 信封），错误经 `{success,code,message,traceId}` 信封返回；前端按成功直出/错误 axios reject 消费；出站 Java 调用携带入站 X-Trace-Id，一次请求一个 traceId 贯穿 mall-web→ai-service→Java API。
6. **Java 依赖隔离测试范式**：pytest 以 JavaMock/httpx mock 模拟全部 Java 上游（含 DENY 404/业务 409/幂等/并发分支），mock provider 确定性意图分类，不依赖真实 LLM key 与 Java 运行态；RAG 以语义同构 stub 出证；真实端到端统一归 C 类 Integration Gate。

## 2. 更新判断

### 2.1 Standards（新建 1 篇）

- 文件：standards/engineering/ai/ai-application-standard.md（新建）
- 操作：新增
- 内容概要（映射 §1 六类模式）：
  1. AI 能力开关 fail-closed 双端语义及与 M5 fail-open 的场景区分；
  2. Grounding 工程兜底四件套（Tool 注册表/字段白名单/enforce_grounding/缺失即声明）；
  3. Prompt Injection 三层防护与 RAG 不完全可信输入隔离；
  4. 写操作人机确认状态机（GETDEL 一次性令牌/身份绑定/TTL/降级/审计/幂等）；
  5. 混合栈成功直出 + 错误信封契约与 X-Trace-Id 传播；
  6. Java 依赖隔离测试范式（JavaMock + mock provider + 语义同构 stub）。
- 理由：四项 AI 应用冻结的安全与可靠性模式是后续一切 AI 能力扩展（更多 Tool、更多写动作、多 Agent）的共性基线；现有 standards/engineering/ai/ 六篇为通用方法论，尚无运行时落地模式标准。
- 复用场景：后续 AI Tool/Agent 新增、写操作扩白名单、AI 与 Java 域协作、AI 测试设计。

### 2.2 Product（Spec 晋升候选，人工评审后落 product/specs/）

- 文件：product/specs/AI 智能应用.md（评审通过后创建）
- 操作：新增
- 草稿要点（产品行为规则，来源 requirement-spec.md §4 业务规则总纲）：
  - 真实数据约束：AI 只展示 Tool 返回的真实商品/价格/库存/订单；缺失信息明确声明不推测；价格附"以结算页为准"；
  - 结论有据：推荐/对比结论必须引用真实属性，禁止无依据的"A 最好"；
  - 身份与权限：订单查询仅本人（memberId 不可由用户参数指定，后端二次归属校验）；知识库管理仅 ADMIN（ai:knowledge:list/upload/update/delete/rebuild 五码，V12 种子为准）；
  - 写操作白名单：首期仅 cancel_order，强制二次确认；改价/支付状态/他人订单一律不开放；
  - RAG 客服边界：知识问答附来源；无可靠知识答"没有足够信息"；私有实时问题引导订单助手；
  - 四项 AI 能力均可经开关整体启停（fail-closed）。
- 状态：候选草稿，待人工评审；本阶段不写入 product/specs/。

### 2.3 Feature Tree（4 节点，planned → delivered）

- STORY-008-01-01（AI 智能导购）：planned → delivered
- STORY-008-02-01（AI 商品对比）：planned → delivered
- STORY-008-03-01（RAG 智能客服与知识库）：planned → delivered
- STORY-008-04-01（AI 订单助手）：planned → delivered
- 方式：`openspec feature update <ID> --status delivered`

### 2.4 Glossary（新建）

- 文件：product/glossary/terms.md（新建，首批条目）
- 内容：RAG（检索增强生成）、Grounding（接地：回答须基于可溯数据）、Chunk（知识分块）、Embedding（向量嵌入）、kNN（向量近邻检索）、Prompt Injection（提示词注入）、待确认动作（pendingAction）、引用来源（sources）、fail-closed（失败即拒绝）
- 理由：M6 引入一批 AI 领域概念，团队对叫法与含义需统一；glossary 目录当前为空。

### 2.5 No Update

- 各端点 JSON 字段级明细：属实现细节，契约已冻结在 requirement-design 与 Spec 候选中。
- RAG chunk_size/overlap、ES topK/score 阈值默认值：留联调样例实测，测试以语义同构 stub 出证，不沉淀为规则。
- Redis 故障内存 TTL 令牌、fakeredis 用法：属测试/降级实现选择。

## 3. 知识沉淀过程

1. 通读 Change 级产物（requirement/exploration/requirement-spec/requirement-design/implementation）与 4 个 Story 各 6 篇 Artifact，提取知识项并分类（1 standards + 1 spec 候选 + 4 feature-tree + glossary 9 术语 + 3 no-update）。
2. 对照 4 份 Story review-report 核实观察项去向：真实端到端串联统一归 C 类 Integration Gate，无 blocker/major。
3. 执行 `openspec du sync-status CHG-0024`：10 个 DU baseline/result 全部回刷，CHG repository-result 与四仓 HEAD 对齐，供 submodule-pointer-aligned 机检消费。
4. 逐条核对 40 条 AC（37 Story AC + 3 横切 AC）与真实自动化证据形成 §4；横切 AC 证据补充核实：X-Trace-Id 出站透传（java/client.py）、redact_secrets 用例（test_support_agent.py）、错误信封 traceId 断言（四端点 api 测试）。
5. standards/glossary 本阶段仅作判断登记，实际写回在 Change 审批通过后随收口提交；Spec 候选待人工评审，未直接写入 product/specs/。

## 4. 全局验收标准对照

证据口径：repo-3 pytest 81/81（导购 28 / 对比 15 / RAG 22 / 订单 16）；repo-2 mall-web vitest 129/129、mall-admin 114/114；repo-1 网关切片 7 例；ruff/vue-tsc/eslint/build 全过。代码提交：repo-1 eab992d、repo-2 5dd4508/f2fd7ca、repo-3 bc984bc/06b0610/e2734f9/736f828、repo-4 cf5c18c（均本地未 push）。

| ID | 验收点 | 覆盖 Story | 证据引用 | 结论 |
| --- | --- | --- | --- | --- |
| AC-001 | 导购返回 message + recommendations[] 五元组 | S1 | TC-001：约束提取→Tool 入参映射、结构断言 | 通过 |
| AC-002 | 类别/预算/品牌/价格范围约束提取并入 Tool 入参 | S1 | TC-001 参数映射断言 | 通过 |
| AC-003 | 信息不足 ≤2 澄清且不搜索；充分直接执行 | S1 | TC-002 clarifyingQuestion 两分支 | 通过 |
| AC-004 | 推荐 ID 均可回溯本次 Tool 返回 | S1 | TC-003 推荐 ID ⊆ Tool 结果 | 通过 |
| AC-005 | 诱导不存在商品不返回 Tool 外商品/SKU/价格 | S1 | TC-003 诱导分支 | 通过 |
| AC-006 | 展示价格逐条 == Tool 当前价 | S1 | TC-004 价格一致断言 | 通过 |
| AC-007 | 推荐理由引用真实属性、不虚构未提供能力 | S1 | TC-004 reason 引用断言 | 通过 |
| AC-008 | AssistantView 卡片/Loading/Error 渲染 | S1 | TC-010 AssistantView 6 例 | 通过 |
| AC-009 | 多轮"第二台再说说"命中上轮候选 | S1 | TC-005 续轮上下文 | 通过 |
| AC-010 | ES 不可用降级 mall-product；均败明确失败 | S1 | TC-006 降级/502 分支 | 通过 |
| AC-011 | 无业务库直连，仅经 Tool→Java API | S1 | TC-007 架构扫描无连接串 | 通过 |
| AC-012 | ai.shopping.enabled=false → 入口隐藏 + 403 | S1 | TC-009 fail-closed 两态 | 通过 |
| AC-013 | 导购核心 pytest + ruff 通过 | S1 | TC-008 全绿 | 通过 |
| AC-014 | 对比返回 comparisonDimensions + products + summary | S2 | TC-202 结构与 values 键断言 | 通过 |
| AC-015 | 每个 productId 均经批量 Tool 实时详情 | S2 | TC-201 JavaMock 调用断言，无纯名称路径 | 通过 |
| AC-016 | 同类商品合理维度；异类不强求统一 Schema | S2 | TC-203 维度集断言 | 通过 |
| AC-017 | 缺失属性显示"暂无该项数据"无推测 | S2 | TC-204 占位断言 | 通过 |
| AC-018 | 价格/库存状态逐格 == Tool 值 | S2 | TC-205 逐格一致断言 | 通过 |
| AC-019 | 场景化结论引用具体属性 | S2 | TC-206 grounding 总结断言 | 通过 |
| AC-020 | CompareView 表格 + 总结渲染 | S2 | TC-209 CompareView 5 例 | 通过 |
| AC-021 | 不直连 Product DB；对比核心 pytest 通过 | S2 | TC-207 配置扫描 + pytest/ruff | 通过 |
| AC-022 | 知识文档上传（.md/.txt）落 MinIO + 四状态列表 | S3 | TC-301 KnowledgeListView 契约 + 校验 | 通过 |
| AC-023 | Parser→Chunking→Embedding→Vector 全链路与元数据 | S3 | TC-302 PENDING→COMPLETED、chunkCount>0 | 通过 |
| AC-024 | 命中回答基于召回 Chunk 且附 sources[] | S3 | TC-303 引用结构断言 | 通过 |
| AC-025 | 低置信固定兜底文案、不编造 | S3 | TC-304 sources=[] 兜底 | 通过 |
| AC-026 | rebuild/delete 后旧投影失效 | S3 | TC-305 knn 失效断言 | 通过 |
| AC-027 | 文档注入不执行/不泄密/不提升 Tool 权限 | S3 | TC-306 注入三层断言 | 通过 |
| AC-028 | SupportView 问答/引用/Loading/Error/新会话 | S3 | TC-309 SupportView 6 例 | 通过 |
| AC-029 | ai.rag.enabled=false → 403；RAG pytest 通过 | S3 | TC-307/308 开关与全绿 | 通过 |
| AC-030 | "最近订单" Bearer 透传 + 本人真实列表 | S4 | TC-401 透传断言 + TC-409 卡片渲染 | 通过 |
| AC-031 | "待支付订单" status 映射 + 真实列表 | S4 | TC-402 PENDING_PAYMENT 入参断言 | 通过 |
| AC-032 | 多步按商品识别订单→详情→真实状态回答 | S4 | TC-403 多步 Workflow | 通过 |
| AC-033 | 订单字段 == Tool；PAID 诱导仍按 PAID 解释 | S4 | TC-404 硬条款断言 | 通过 |
| AC-034 | 注入无法指定他人 memberId；DENY→404 | S4 | TC-405 参数无 memberId + 404 透传 | 通过 |
| AC-035 | 待确认动作不执行；confirm 才执行；异常 409 | S4 | TC-406 状态机 + TC-409 前端确认流 | 通过 |
| AC-036 | 重复消费 409；审计成功/失败字段完整 | S4 | TC-407 幂等 + 审计断言 | 通过 |
| AC-037 | ai.order-assistant.enabled=false → 403；pytest 全绿 | S4 | TC-408 fail-closed + ruff | 通过 |
| AC-038 | 出站 Java 调用携带入站 traceId，错误信封回传 | 横切 | java/client.py X-Trace-Id：trace_id_var；四 api 测试 traceId 断言 | 通过（真实多服务串联随 Integration Gate） |
| AC-039 | LLM 故障四入口明确业务错误 + 降级文案 | 横切 | 各端点 502/错误映射用例（test_*_api） | 通过 |
| AC-040 | Prompt 拼接前 Secret 过滤 | 横切 | redact_secrets 模式用例 + Context 拼接断言（test_support_agent） | 通过 |

**汇总结论**：40 条 AC 全部有自动化或静态审计证据支撑；真实多服务端到端（网关 8080、ES kNN 召回质量、真实取消含库存释放）统一归 C 类 M6 Integration Gate 七场景，联调环境串验，无阻断收敛的开放项。

## 5. 完成确认

- [x] 全部前序 Artifact 已读取（Change 级 + 4 Story × 6 篇 + DU 证据）
- [x] 知识分类完成（1 standards / 1 spec 候选 / 4 feature-tree / glossary 9 术语 / 3 no-update）
- [x] 仓指针经官方命令对账（du sync-status，repository-result == 四仓 HEAD）
- [x] 40 条全局 AC 已逐条对照真实证据，无裸用例占位
- [x] 无未解决 blocker/major；观察项均归 Integration Gate
- [x] standards 写回、Spec 候选人工评审、feature-tree delivered、glossary 落库与索引重建按审批后收口执行
