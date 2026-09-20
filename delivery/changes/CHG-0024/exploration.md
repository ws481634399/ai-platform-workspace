# Exploration（需求探索报告）

> 阶段：sdd-explore 产物
> 输入：《docs/需求/M6/M6.md》（M6 AI 智能应用，2026-09-20）
> 产出状态：exploring

## 1. 需求要点

- 做什么：在 M0 AI 工程基线（Python FastAPI + LLM/Java API Client + Agent/Tool/Workflow/RAG 扩展边界）与 M2~M5 真实电商业务能力（商品/库存/订单/会员/搜索/配置/Trace）已经建立的基础上，构建平台核心 AI 应用层——**让 AI 真正接入既有业务能力，而不是另起一套业务系统**。M6 覆盖四个 SDD 级 Requirement：
  1. **REQ-M6-001 AI 智能导购**（P1）：消费者用自然语言表达购物需求（"预算 5000 适合开发的笔记本"），AI 完成意图识别→约束提取→澄清→商品搜索 Tool→商品详情 Tool→真实候选商品分析→结构化推荐 + 推荐解释 + 多轮上下文。
  2. **REQ-M6-002 AI 商品对比**（P1）：用户选多个真实商品询问差异，AI 复用商品详情 Tool（含批量）获取属性，按类型/场景选择维度做结构化对比表格 + 自然语言总结 + 场景化推荐结论，缺失属性不虚构。
  3. **REQ-M6-003 RAG 智能客服与知识库**（P1）：平台规则/购物/支付/配送/售后等知识文档经 Parser→Chunking→Embedding→Vector Store→Retrieve→LLM→Answer+Reference 流程；mall-admin 文档管理（MinIO）+ mall-web 客服入口；Prompt Injection 防护基础。
  4. **REQ-M6-004 AI 订单助手**（P2）：MEMBER 身份安全传播→订单查询/详情 Tool（仅本人订单，后端二次校验归属）→多步 Workflow→状态解释→二次确认→写 Tool（cancel_order）→后端领域最终校验+审计+读写 Tool 权限隔离+Prompt Injection 三层防护。
- 给谁：商城消费者（导购/对比/客服、订单助手要求 MEMBER 登录）；运营/管理员（知识库文档管理）；后续 M6 Integration Gate 联调与平台演示。
- 解决什么问题：
  1. AI 从"聊天 Demo"升级为真正嵌入电商业务流程的应用层，AI 能理解用户意图并通过受控 Tool 使用真实商品/知识/订单数据完成电商任务；
  2. **同时不破坏已有领域边界和安全模型**——AI Service 负责意图理解（Agent/Workflow/Tool Calling/RAG/LLM），Java Backend 负责业务事实（规则/权限/商品/库存/订单），AI 不直接访问业务数据库；
  3. 把 M2~M5 已成型的商品/搜索/会员/订单/配置能力通过 AI 应用层串成面向消费者的端到端体验。
- 必须守住的边界（贯穿四 REQ 的核心约束）：
  1. **真实数据约束**：AI 推荐的商品/价格/库存、对比属性、订单号/状态/金额，全部必须来自 Tool 返回的真实业务数据；禁止 LLM 凭自身知识"猜商品/生成不存在的 SKU/编价格/编订单状态"；Tool 没有的字段必须明确"暂无该项数据"，不得自行推测。
  2. **AI ≠ 第二套业务系统**：AI 不直接访问 Java 业务数据库；获取商品/库存/订单/会员数据必须通过 Java API 或已定义的业务 Tool；展示价/对比价 ≠ 成交价，下单仍由 M4 重新校验；AI 展示库存 ≠ 交易库存保证。
  3. **身份与权限模型不降级**：REQ-M6-004 订单助手必须通过安全上下文传播 MEMBER，不接受 memberId 作为可信来源；Tool 只查本人订单；Java Backend 二次校验 Order.memberId = CurrentMember.memberId；写操作 Intent→Proposed Action→User Confirmation→Tool Execution→Java Domain Validation；后端是最终规则执行者，AI 无权绕过 Order Domain。
  4. **安全三层防护**：Prompt Security + Tool Schema + Backend Authorization 共同保证 Prompt Injection 不能越权；绝不能只依赖 System Prompt；RAG Context 不允许覆盖 System Prompt / Security Policy，Tool 调用权限不能由知识文档提升。
  5. **复用既有通道不新起炉灶**：商品 Tool 复用 mall-search/mall-product 内部查询契约（M2/M5）；身份传播复用 M3 SecurityContext + M1 Gateway Token 边界；Feature 开关复用 M5 FeatureGate（ai.shopping.enabled / ai.compare.enabled / ai.rag.enabled / ai.order-assistant.enabled）；TraceId 复用 M5 闭环 50 的 X-Trace-Id 头约定并扩展到 ai-service→Java 调用；文件存储复用 M0 MinIO + M5 头像上传通道模式（品牌 Logo/商品图片已在 CHG-0023 落地）。
  6. **M6 首期写操作只开放低风险边界明确项**：REQ-M6-004 仅开放 cancel_order（取消待支付订单）作为演示，不开放修改金额/修改支付状态/强制发货/修改他人订单/直接修改库存等高风险操作。
- 知识检索结果（引用来源）：
  - 《M6.md》§推荐依赖关系、§Integration Gate、§Definition of Done（本 Change 的 SSOT，已归档至 `delivery/changes/CHG-0024/references/M6.md`）；
  - `product/feature-tree.yaml`：M0 AI 工程基线（FEAT-1-02 → STORY-1-02-01-01 已 delivered）提供 Agent/Tool/Workflow/RAG 扩展边界，是 M6 的工程前置；
  - M2 商品/库存 internal 契约（FEAT-002-03-03 内部查询契约与商品快照语义 STORY-002-03-03-01、FEAT-002-04 库存核心能力）、M3 会员与 SecurityContext（FEAT-003-01）、M4 订单查询/详情/取消与状态机（FEAT-004-01/02/03）、M5 搜索查询 API 与索引同步（FEAT-005）、M5 系统配置与 FeatureGate（FEAT-006）均已 delivered 或 planned，是 M6 Tool 调用与开关的现成底座；
  - `standards/architecture-principles.md` 分层架构与依赖规则（Controller→Service→Repository→Model，横向不依赖，依赖倒置）——M6 AI Tool 调用 Java API 属于跨层横切，必须经 Java Controller/Service 暴露的 internal API，不直连 Repository；
  - CHG-0023（M5 验收缺口补强，testing）：A3 跨服务 Trace 贯通（X-Trace-Id 拦截器接入全部 internal RestClient）、A2 品牌/商品图片 MinIO 上传通道、A4 系统参数消费——M6 直接复用其成果；
  - M0 REQ-M0-003（AI Service 工程基线 STORY-1-02-01-01 delivered）：已定义 LLM Client / Java API Client / Agent / Tool / Workflow / Prompt / RAG 扩展边界与 Pytest 基线，M6 在此扩展边界内实现应用，不重新搭建基线。
- 隐含需求（用户未明说但工程必须覆盖）：
  1. AI 调用链 TraceId 贯通（mall-web→ai-service→Java API 多跳），M5 闭环 50 的 Trace 承诺需扩展到 AI 调用链；
  2. LLM 调用失败/超时/限流的明确错误处理与可观测（M6 DoD AI 基础要求已列）；
  3. Java API 调用失败的明确错误处理（fail-open/fail-closed 策略，与 M5 A4 参数消费 fail-open 口径一致）；
  4. Secret 不进入 Prompt（API Key/Token/会员敏感字段过滤）；
  5. Read Tool 与 Write Tool 权限隔离的工程化实现（Tool 注册表分档，Write Tool 强制 Confirmation/Audit/Idempotency）；
  6. AI 操作审计的存储模型（与 compensation_task.trace_id 同源思路，可在 ai-service 侧建 ai_action_audit 表或在 Java 侧统一审计）；
  7. 多轮会话存储（Conversation/Session，M6 不要求长期记忆但需基本上下文）；
  8. AI 输出结构化协议（recommendations[] / comparisonDimensions+products+summary / sources[] / 订单状态解释结构），便于 mall-web 渲染。

## 2. Story 归属判定

- Feature ID: **FEAT-008**（新建 L1：AI 智能应用，承载 M6 全部 AI 应用能力，与既有 MOD-1 工程基础下的 FEAT-1-02 AI 工程基线区分——基线是工程骨架，FEAT-008 是业务应用）。
- Feature 路径: AI 智能应用 → 四个 L2 并行子功能（AI 智能导购 / AI 商品对比 / RAG 智能客服与知识库 / AI 订单助手）→ 每个L2 一个 Story。
- Story 节点（feature-tree.yaml 已新建，本 Change 含 4 个，均 planned，1:1 对应 4 个 REQ）：
  - **STORY-008-01-01 AI 智能导购**（repo-3 ai-service 主，repo-1 mall-product/mall-search/mall-inventory，repo-2 mall-web）：自然语言理解→约束提取→澄清→search_products/get_product_detail Tool→真实候选商品分析→结构化 recommendations + 推荐解释；LangGraph/等价 Workflow 编排；多轮 Conversation/Session；ai.shopping.enabled 开关；mall-web AI 导购入口与商品卡片渲染。
  - **STORY-008-02-01 AI 商品对比**（repo-3 ai-service，repo-1 mall-product，repo-2 mall-web）：复用 get_product_detail + 建立 get_products_detail 批量 Tool；属性归一化（不强求统一 Schema）；维度选择（按类型/场景）；结构化 comparisonDimensions+products+summary；场景化推荐结论带依据；缺失属性"暂无该项数据"；mall-web 对比表格渲染。
  - **STORY-008-03-01 RAG 智能客服与知识库**（repo-3 ai-service 主，repo-1 mall-admin，repo-2 mall-web/mall-admin，repo-4 infra）：mall-admin 文档管理（上传/查看/启停/删除/状态/重建索引，MinIO 存储）；Document Parser→Chunking（按标题/段落/长度/Token，size/overlap Design 定）→Embedding Client（Provider Adapter 抽象）→Vector Store（写/删/查/metadata/topK，具体技术 Design 定）→Retrieve（阈值+无知识兜底"当前知识库中没有足够信息"）→LLM→Answer+sources[]；知识更新/删除同步失效；Prompt Injection 防护（RAG Context 不覆盖 System Prompt/Security Policy，Tool 权限不提升）；mall-web 客服入口（输入/回答/引用/Loading/Error/新会话）。
  - **STORY-008-04-01 AI 订单助手**（repo-3 ai-service，repo-1 mall-order/mall-common-web，repo-2 mall-web）：MEMBER 身份安全传播（不接受 memberId 可信来源）；get_my_orders（最近/状态筛选/分页，仅本人）+ get_my_order_detail（Java 二次校验归属）；多步 Workflow（"最近那笔手机订单"→查最近→识别→详情）；真实订单约束（不编造状态）；状态解释（PENDING_PAYMENT→待支付 等，不改语义）；写 Tool cancel_order（Intent→Proposed Action→User Confirmation→Tool Execution→Java Domain Validation）；后端最终规则（Ownership/Status/幂等/库存释放）；Read/Write Tool 权限隔离；AI 操作审计（memberId/conversationId/toolName/businessId/parameters/result/traceId/occurredAt）；Prompt Injection 三层防护；mall-web 订单助手入口。
- is-new-candidate: 否。FEAT-008 为新建 L1 业务域，4 个 Story 全部源自 M6.md SSOT 的 4 个 REQ，无未确认候选；不触发 Candidate 兜底分支。
- 组划分理由：M6.md 明确建议"保持 4 个 SDD 级 Requirement"，每个 REQ 独立可交付，1 REQ → 1 L2 → 1 Story 的 1:1:1 映射最清晰；M6 推荐依赖关系图（001/002/003 可高度并行，004 等 M4 订单查询契约稳定后启动）也支持 4 Story 并行/串行编排。Design 阶段如某 Story 过大（如 RAG 含 11 子项 DoD），可在该 Story 内部拆 DU 分批实施，不破坏 L2→Story 1:1 结构。
- 主 Story 绑定：本 Change 在 explore 阶段绑定 **STORY-008-01-01（AI 智能导购）** 作为 feature-path 主 Story（M6 第一个 REQ，是商品 Tool 基础，002 复用其 Tool，004 的 Agent/Workflow 模式也参考它）；其余 3 Story 已在 feature-tree.yaml 创建，将在 design/story-splitting 阶段补绑至 stories[] 索引。

## 3. 证据评估

- 业务依据：M6.md §阶段目标明确"M6 做完后，AI 已经从'聊天 Demo'升级为真正嵌入电商业务流程的应用层"，是平台从 M0 工程基线→M2 商品→M3 会员→M4 订单→M5 搜索/配置 的自然延伸；M6 Integration Gate 七大场景（导购/对比/RAG/订单查询/越权 DENY/取消确认/Prompt Injection）逐项对应 4 REQ 验收标准，证据链完整。
- 工程依据：
  - M0 STORY-1-02-01-01（AI Service 工程基线 delivered）已提供 FastAPI/uv/LLM Client/Java API Client/Agent/Tool/Workflow/Prompt/RAG 扩展边界与 Pytest/Ruff 基线，M6 在此边界内实现应用，无工程基线空白；
  - M2 商品/库存/订单 internal 契约（STORY-002-03-03-01 内部查询契约与商品快照、FEAT-002-04 库存核心能力）、M4 订单查询/详情/取消（FEAT-004-03 会员订单查询与确认收货、FEAT-004-02 模拟支付与订单取消含 CAS+幂等+库存 release）均已 delivered 或 planned，是 AI Tool 调用的现成 Java API；
  - M5 搜索查询 API（FEAT-005-01-02 关键词搜索/筛选/排序，STORY-005-01-02-01 delivered）、FeatureGate（FEAT-006-02 STORY-006-02-01-01/012 delivered）、TraceIdFilter 与 X-Trace-Id 拦截器（CHG-0023 A3 横切 12 个 internal Client）均已就绪；
  - CHG-0023 A2 品牌/商品图片 MinIO 上传通道（testing）为 REQ-M6-003 知识文档 MinIO 存储提供同桶策略/校验模式样板；
  - mall-web/mall-admin 前端基线（Router/Pinia/Axios/Layout/Element Plus）就绪，新增 AI 入口与客服/对比/订单助手 UI 在既有模式内。
- 影响面：
  - **repo-3 ai-platform-ai-service**（主战场）：Agent/Tool/Workflow/RAG/Embedding/Vector Store/Conversation/审计全部新增，是工作量最大的仓；
  - **repo-1 ai-platform-backend**：mall-product 扩展 internal API 供 get_product_detail/get_products_detail 调用（M2 已有内部查询契约，可能需补批量端点）；mall-search 暴露 internal 搜索端点供 search_products Tool（M5 已有公开 /api/mall/search/**，需评估是否复用或新增 internal）；mall-order 暴露 get_my_orders/get_my_order_detail/cancel_order internal 端点（M4 已有会员订单查询与取消 API，需评估是否复用或新增 ai-service 专用 internal 端点，归属校验在 mall-order 侧强制）；mall-admin 新增知识库文档管理页（前端为主）；mall-common-web X-Trace-Id 拦截器扩展到 ai-service→Java 调用（复用 CHG-0023 A3 模式）；mall-system 配置项扩展（ai.shopping/compare/rag/order-assistant.enabled，复用 M5 配置模型与缓存分发）；
  - **repo-2 ai-platform-frontend**：mall-web 新增 AI 导购入口/对比页/客服入口/订单助手入口与结构化结果渲染；mall-admin 新增知识库文档管理页；
  - **repo-4 ai-platform-infrastructure**：Docker Compose 可能新增向量数据库/Embedding 服务依赖（Design 阶段定）。
- 风险评估：
  - 最高风险在 REQ-M6-004 写操作（cancel_order）跨 AI→Java 的安全边界，需 Prompt Security + Tool Schema + Backend Authorization 三层防护与审计，且必须实测 Prompt Injection 越权场景（Integration Gate 场景五/七）；
  - REQ-M6-003 RAG 文档 Chunk/Embedding/Vector Store 选型与性能直接影响检索质量与可观测性，向量数据库技术选型（自建 PG/Redis vs 专用如 Milvus/Qdrant vs Elastic kNN）需 Design 评估；
  - REQ-M6-001 真实商品约束的工程化兜底，单靠 System Prompt 不可靠，需 Tool Schema 限定返回字段 + 后端二次校验共同保证 LLM 不编造；
  - AI 调用链 TraceId 传播需贯通 mall-web→ai-service→Java API 多跳，ai-service 调用 Java 的 RestClient 需复用 CHG-0023 的 X-Trace-Id 拦截器；
  - LLM/Embedding 模型与 Provider 选型、密钥管理、限流与成本控制需 Design 阶段定。
- 证据结论：**充分**。M6.md SSOT 完整（4 REQ 各含需求目标/Tool/约束/验收/非范围/DoD + Integration Gate 七场景 + DoD 全清单）；M0~M5 既有能力足以支撑（基线/契约/API/开关/Trace/上传通道/前端基线全部就绪或 testing）；无阻断性技术未知；待澄清项均为 Design 阶段需定的技术选型与具体 Schema/参数，不构成 explore 阻断。

## 4. 冲突点检测

- 与 specs/standards 冲突：
  - `standards/architecture-principles.md` 分层架构与依赖规则——AI Tool 调用 Java API 属跨进程横切，不属本仓内 Controller→Service→Repository 链；M6 必须确保 ai-service→Java 调用经 Java Controller/Service 暴露的 internal API（如 mall-product 内部查询契约端点、mall-order 会员订单查询端点），不绕过到 Repository 或直连数据库，与"AI 不直接访问业务数据库"原则一致，**无冲突**；
  - M5 dynamic-config-standard.md——M6 新增 ai.shopping/compare/rag/order-assistant.enabled 配置键，沿用 FeatureGate/SystemParameterProvider 既有 TTL/键约定与 fail-open 口径，**无冲突**；
  - 安全/审计标准（M1/M4 既有 RBAC + 审计 + 补偿 trace_id）——REQ-M6-004 AI 写操作审计字段（memberId/conversationId/toolName/businessId/parameters/result/traceId/occurredAt）与既有 admin_action_audit / compensation_task.trace_id 模式同源，可复用审计存储或新建 ai_action_audit 表，**无冲突，具体存储位置 Design 定**。
- 与已交付/进行中 Change 的关系：
  - **CHG-0023**（testing）：A3 X-Trace-Id 拦截器（12 个 internal RestClient）需扩展到 ai-service→Java 调用，属同模式扩展不重开；A2 MinIO 上传通道为 RAG 文档存储提供样板；A4 参数消费为 ai.* 开关消费提供 FeatureGate 模式——M6 复用其成果，不冲突；
  - **CHG-0019**（M4 订单交易闭环 completed）：M4 已交付订单查询/详情/取消 API 与状态机（FEAT-004-03-01/02 + FEAT-004-02-01），REQ-M6-004 订单助手复用 mall-order 既有 API（可能新增 ai-service 专用 internal 端点或在现有端点上扩展 ai-service 调用方鉴权），属同源 API 扩展不重开；
  - **CHG-0020/0021**（M5 搜索 completed）：REQ-M6-001 search_products Tool 复用 mall-search 查询能力（公开 /api/mall/search/** 已就绪，但 ai-service 调用可能需 internal 端点或 SERVICE 身份鉴权），属同源扩展不冲突；
  - **CHG-0022**（M5 系统配置 completed）：ai.* 开关复用配置模型与缓存分发，不改变键名/TTL 契约；
  - **CHG-0016**（M3 商城会员 completed）：MEMBER 身份与 SecurityContext 是 REQ-M6-004 身份传播的底座；
  - **CHG-0010~0013**（M2 商品/分类/品牌/SKU/库存 completed）：商品 Tool 调用 mall-product internal 契约（STORY-002-03-03-01）与库存可售状态（STORY-002-04-01-01），属同源 API 复用。
- 与 feature-tree 已规划 Story 重复/矛盾：
  - **MOD-1 > FEAT-1-02 AI 工程基线 > STORY-1-02-01-01 建立 Python AI Service 工程基线**（delivered）——是 M6 的工程前置，**不重复**：FEAT-1-02 是工程骨架（FastAPI/uv/Client 抽象/扩展边界），FEAT-008 是业务应用（导购/对比/RAG/订单助手），二者职责清晰分层；
  - FEAT-001/002/003/004/005/006 各业务域 Story 是 M6 Tool 调用对象，**不重复**；
  - FEAT-007 平台验收补强（CHG-0023）是补强类工作，**与本 Change 范围无重叠**。
- 数据库演进冲突：M6 可能新增 ai_action_audit 表（REQ-M6-004 审计）、ai_knowledge_document/ai_knowledge_chunk 表（REQ-M6-003 知识索引元数据）、ai_conversation/ai_message 表（多轮会话），均属新表新增，不涉及既有表结构变更；向量数据库选型如选 pgvector 则在既有 PostgreSQL（如有）扩展，如选独立向量库则 infra 增容器；Flyway/数据库迁移按既有版本号递增，无回填要求。
- 处理决策：
  - 全部既有 Change 均 completed 或 testing，不重开生命周期；M6 独立交付，完成后在相关 Story 的 convergence 附录追加交叉引用；
  - FEAT-008 作为新 L1 承载 M6 全部 AI 应用能力，与 MOD-1 > FEAT-1-02 工程基线分层共存，不合并；
  - AI Tool 调用 Java API 的具体端点（复用既有 vs 新增 ai-service 专用 internal）属 Design 阶段定，本 explore 不预判；
  - 向量数据库/Embedding Provider/LLM Provider 选型属 Design 阶段技术决策，explore 不预判。

## 5. 待澄清问题

以下为 Design 阶段需定/需澄清项，按 REQ 分组列出（context-rules v0.4+ 注入下游，本清单下游 requirement-spec/design 直接可见）：

### REQ-M6-001 AI 智能导购
1. **Agent/Workflow 选型**：使用 LangGraph 还是等价 Workflow 机制（如自研状态机/函数链）？M6.md 不强制 LangGraph 但要求"服务于业务流程不展示技术栈"；
2. **search_products Tool Schema**：keyword/category/brand/minPrice/maxPrice/sort/pageSize 的具体类型与必填项；调用 mall-search 公开 API（/api/mall/search/**，GUEST 可访问）还是新增 internal 端点（SERVICE 身份鉴权）？
3. **get_product_detail Tool**：复用 mall-product 既有内部查询契约（STORY-002-03-03-01）还是新增 ai-service 专用端点？返回字段集合（名称/品牌/SKU/属性/当前价格/图片/介绍/可售状态）的 DTO 形态；
4. **库存状态查询**：是否需要独立 get_inventory_status Tool，还是合入 get_product_detail？AI 展示库存 ≠ 交易保证的工程化兜底（前端文案 + 下单 M4 重新校验）；
5. **多轮会话存储**：Conversation/Session 存 Redis 还是 ai-service 数据库？会话保留时长？上下文窗口策略？
6. **结构化推荐 DTO**：recommendations[] 的完整字段（productId/productName/image/price/reason 是否够，是否加 skuId/category/score）；
7. **澄清触发条件**：信息不足的判定阈值（如缺预算/缺类别才澄清，还是缺任意关键约束即澄清）；避免无意义追问的工程化规则；
8. **ai.shopping.enabled 关关时**：mall-web 隐藏入口 + ai-service 拒绝调用？还是仅前端隐藏？与 M5 FeatureGate ensureEnabled 口径一致？

### REQ-M6-002 AI 商品对比
1. **get_products_detail 批量 Tool**：是新建批量端点还是循环调 get_product_detail？批量上限？性能考虑；
2. **属性归一化策略**：不同类别属性结构差异如何处理（保持异构 vs 强制统一 Schema）？M6.md 倾向不强求统一；
3. **对比维度选择算法**：按商品类型预设维度表（电脑维度/手机维度）还是 LLM 动态选？维度缺失的"暂无该项数据"在结构化对比表中的占位形态；
4. **对比结果 DTO**：comparisonDimensions/products/summary 的具体结构；mall-web 渲染对比表的列固定 vs 动态生成；
5. **商品来源上下文**：从 AI 导购结果/搜索结果/商品详情页/用户主动选择传入对比 Tool 的 productId 列表如何传递（会话上下文 vs 显式参数）？

### REQ-M6-003 RAG 智能客服与知识库
1. **向量数据库选型**：pgvector（复用 PostgreSQL 扩展）/ Redis Stack（复用 Redis）/ 独立向量库（Milvus/Qdrant/Weaviate）/ Elasticsearch kNN（M5 已引入 ES）？需评估查询性能/运维成本/与既有栈一致度；
2. **Embedding Provider**：OpenAI text-embedding-3-small / 阿里通义 / 智源 BGE / 本地模型？Provider Adapter 抽象的接口契约；模型配置键（embedding.provider / embedding.model / embedding.dimension）；
3. **Chunk 策略**：chunk_size / chunk_overlap 的具体值（按 Token 计数，需结合 Embedding 模型上下文窗口与检索召回率实测）；按标题/段落/固定长度切分的优先级；
4. **文档解析器**：支持哪些格式（Markdown/TXT/PDF/Word/HTML）？是否引入 Unstructured/自研 Parser？
5. **知识库元数据表**：ai_knowledge_document（id/title/source/storageKey/status/version/createdAt/processedAt）+ ai_knowledge_chunk（id/documentId/chunkIndex/text/embeddingRef/metadata）的 Schema；向量存储与元数据库的双向引用；
6. **检索阈值与 topK**：相似度阈值（如 cosine ≥ 0.75）与 topK（如 5）的具体值；无知识命中时的兜底文案；
7. **Prompt Injection 防护实现**：RAG Context 在 Prompt 中的注入位置（user message vs system message 的隔离）；Tool 权限不提升的工程化校验点；
8. **知识更新同步**：文档更新→旧 Chunk 失效→旧 Embedding 删除/失效的同步机制（同步 vs 异步重建）；重建索引的并发与限流；
9. **mall-admin 文档管理页**：上传组件复用 CHG-0023 A2 品牌/商品图片上传组件模式（multipart+类型/大小/魔数校验）还是独立实现？文档列表/启停/删除/重建索引的 RBAC 权限码（knowledge:doc:list/upload/update/delete/rebuild）；
10. **mall-web 客服入口 UI**：聊天窗口的会话管理（新会话/历史会话列表/继续）；引用 sources[] 的展示形态（可点击跳转文档片段？）。

### REQ-M6-004 AI 订单助手
1. **身份传播机制**：ai-service 如何接收当前 MEMBER？mall-web 调 ai-service 时 Authorization Bearer Token 透传，ai-service 解析后传入 Java Tool 调用？还是 ai-service 调 mall-order 时附 X-Member-Id（SERVICE 身份+ai-service 可信传播）？与 M3 SecurityContext 链路如何对接？
2. **get_my_orders/get_my_order_detail Tool Schema**：参数（status/page/pageSize/orderNo/orderId）与返回（订单列表/详情含商品快照/地址快照/金额/状态历史）；复用 mall-order 既有 /api/mall/orders 端点（M4 已有会员订单查询）还是新增 internal 端点？
3. **cancel_order 写 Tool**：参数（orderNo + 用户确认 token？）与返回（取消结果/幂等键）；与 mall-order 既有取消 API（FEAT-004-02-01 模拟支付与订单取消，CAS+幂等+库存 release）的对接；二次确认的交互形态（前端弹窗确认 vs AI 文本确认）；
4. **AI 操作审计存储**：ai_action_audit 表（在 ai-service 数据库还是 mall-order 数据库？）；与 compensation_task.trace_id 同源 traceId 贯通；
5. **Read/Write Tool 权限隔离实现**：Tool 注册表分档（Read Tool vs Write Tool），Write Tool 强制 Confirmation/Audit/Idempotency 的中间件/装饰器；
6. **多步 Workflow 编排**：LangGraph 状态机节点（意图识别→查最近订单→识别目标→查详情→生成回答→写操作 Intent→确认→执行）的具体节点设计；
7. **Prompt Injection 越权测试场景**：Integration Gate 场景五/七的具体测试用例（"查询用户 10001 的全部订单"→Tool 调用→mall-order Ownership Check DENY→AI 不得获得订单数据）；
8. **ai.order-assistant.enabled 开关**：关闭时 mall-web 隐藏订单助手入口 + ai-service 拒绝调用？写操作开关是否独立（ai.order-assistant.write.enabled 默认关闭）？

### 跨 REQ 共性待澄清
1. **TraceId 跨 AI 调用链传播**：mall-web→ai-service 段如何生成/透传 X-Trace-Id？ai-service→Java API 段复用 CHG-0023 A3 ClientHttpRequestInterceptor 模式扩展到 ai-service 的 Java API Client？ai-service 内部 LLM/Embedding 调用是否也带 traceId 便于观测？
2. **LLM 调用失败/超时/限流的错误处理**：统一错误码与降级策略（如 LLM 不可用时 RAG/导购返回明确错误而非崩溃）；与 M5 fail-open 口径的关系；
3. **Secret 不进 Prompt 的工程化校验**：API Key/Token/会员敏感字段在 Prompt 拼接前的过滤机制；
4. **AI Service 数据库选型**：ai-service 是否独立数据库（PostgreSQL/MySQL）？还是复用 mall-order/mall-system 既有库？审计表/会话表/知识元数据的归属；
5. **多仓 DU 拆分**：M6 跨 repo-1/2/3/4，dev/test 阶段需按 DU 物化（Phase 4.4）；DU 边界按 REQ 划分（DU-AI-001 导购/DU-AI-002 对比/DU-AI-003 RAG/DU-AI-004 订单助手）还是按仓划分（DU-BE-XXX/DU-FE-XXX/DU-AI-XXX/DU-INFRA-XXX）？design/task 阶段需明确。

### 唯一在联调阶段验证项
- M6 Integration Gate 七大场景（导购 E2E/对比/RAG 检索与引用/订单查询/订单越权 DENY/AI 取消订单含二次确认/Prompt Injection 越权防护）需在运行态实测，本 Change 以单测/集成测试/Tool 接线核对为自动化边界，Integration Gate 联调在 M6 收尾阶段执行。
