---
affected-repositories: [repo-1, repo-2, repo-3, repo-4]
---

# Requirement Design（需求级方案设计）— CHG-0024 M6 AI 智能应用

> 层级：Requirement 级；主 Story 细化设计见 stories/STORY-008-01-01/story-design.md，其余 Story 细化设计在该 Story 进入开发时按同模板补产出
> 输入：requirement-spec.md + exploration.md + 《docs/需求/M6/M6.md》
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0024
- spec 来源: CHG-0024/requirement-spec.md（REQ-M6-001~004）
- 相关仓库: repo-1（ai-platform-backend：mall-gateway、mall-identity）、repo-2（ai-platform-frontend：mall-web、mall-admin）、repo-3（ai-platform-ai-service：主战场）、repo-4（ai-platform-infrastructure：compose/.env）
- 受影响仓库数: 4
- 需要 Migration: yes（repo-4 MySQL 初始化新增 ai_service 库与 ai_action_audit 表；repo-1 mall-identity V12 知识库权限码/菜单种子 DML；均为新增，不改既有表）

## 1. 当前状态

- **repo-3 ai-service（M0 基线骨架）**：`app/main.py` FastAPI lifespan 初始化 `java_http`/`llm`，仅注册 health 路由；`app/core/config.py` pydantic-settings 已含 `JAVA_API_*`、`LLM_PROVIDER/KEY/MODEL`、`EMBEDDING_*` 配置位；`app/infrastructure/llm/client.py` LLM Client 抽象（chat/chat_stream/structured_chat）+ `factory.py` PROVIDER_REGISTRY（仅 mock provider）；`app/infrastructure/java/client.py` httpx 封装，默认注入 `X-Trace-Id`/`X-Request-Source`；`app/middleware/trace_logging.py` 入站 trace 中间件；无 agents/tools/services 业务代码、无数据库/Redis 依赖、无 langgraph；pytest+uv 基线就绪。
- **repo-1 网关与安全**：mall-gateway `GatewaySecurityConfiguration` JWT → ROLE_ADMIN/ROLE_MEMBER 双向隔离（subject_type claim），`/api/mall/orders/**` 等要求 MEMBER；`IdentityPropagationFilter`（order=-1）；`TraceIdWebFilter`（CHG-0023）入站 trace 生成/透传/响应回写。`MemberOrderController`：memberId 只取 `SecurityContextFacade.currentSubject()`，入参不得指定会员；`GET /api/mall/orders`（status/startAt/endAt/page/size）、`GET /{orderNo}`、`POST /{orderNo}/cancel`；`OrderCancelService` 仅待支付可取消、CAS 状态机、释放库存预留、重复取消幂等——**M6 订单 Tool 可零改动复用**。
- **repo-1 查询端点**：mall-search `GET /api/mall/search/products`（keyword/category/brand/price/sort/page/size，GUEST 可访问）；mall-product `GET /api/mall/products/{id}` 公开详情 + `/api/internal/products/**` 内部契约（SKU 快照/批量可售/搜索投影）；mall-inventory `POST /api/internal/inventory/availability`（批量可售，X-Internal-Token）。
- **repo-1 配置**：mall-common-config SystemParameterProvider/FeatureGate 模式（CHG-0022）；mall-identity Flyway 当前 V11。
- **repo-2**：mall-web axios（`src/api/http.ts`）注入 `Authorization: Bearer` + `X-Trace-Id`，会员态 pinia `stores/member.ts`（内存+refresh cookie 恢复）；views 含 Home/Search/ProductList/ProductDetail/Cart/Checkout/Order/Member/Auth；mall-admin element-plus + `stores/auth.ts` + CHG-0023 ImageUploader 上传组件模式。
- **repo-4 infra**：docker-compose.infra.yml 已有 MySQL 8.4.11、Redis 7.4.11、ES 8.17.4、MinIO、Nacos（共享 `ai-platform-network`）；README 明确当前不含向量库/应用容器。

## 2. 提议方案

### 2.0 总体策略

**ai-service 单点吸收全部 AI 复杂度，Java 侧最小改动，调用一律经网关复用既有认证链。**

1. **调用拓扑**：mall-web/mall-admin → mall-gateway `/api/ai/**` → ai-service；ai-service → mall-gateway `/api/mall/**`（公开数据走 GUEST 端点，会员数据透传原始 MEMBER Bearer）；ai-service → ES/MinIO/Redis/MySQL（infra 网络内直连）。**AI 不直连任何 Java 业务库**（经网关 HTTP），**mall-order/mall-search/mall-product 零改动**（归属校验/幂等/CAS/库存释放由 M4 既有链路端到端保证）。
2. **身份传播**：网关 `/api/ai/members/**` 强制 ROLE_MEMBER、`/api/ai/admin/**` 强制 ROLE_ADMIN（mall-gateway 安全配置扩展两行）；ai-service 配置共享 JWT secret 本地解析 token（subject_type/memberId），**memberId 永不接受为请求参数**；ai-service 调 `/api/mall/orders/**` 时透传原始 Bearer，Java SecurityContext 链路零改动 → Member A 永远只能拿到自己的订单（Integration Gate 场景五由架构保证）。
3. **Workflow 选型定稿：自研轻量节点链**（不引 LangGraph）。理由：四条流程均为"线性+条件分支"小图（意图→澄清?→Tool 循环→合成），M0 骨架零第三方 Agent 依赖，自研节点即用即测、依赖面最小，符合"Workflow 服务业务流程"原则。实现为 `app/agents/` 下 `Workflow`（节点注册+顺序/条件边）+ 各业务 `Agent` 类。
4. **向量库定稿：Elasticsearch 8 kNN**（dense_vector + script_score/kNN search）。理由：M5 已引入 ES 8.17.4 且已在 infra 网络内，零新增中间件；满足写/删/查/metadata/topK 全部要求；知识检索投影与全文可同索引管理。备选（pgvector：无 PG；Milvus/Qdrant：新增运维面；Redis Stack：需换镜像）全部否决。
5. **LLM/Embedding Provider 定稿：扩展 M0 factory 模式，新增 `openai` 兼容 provider**（可配 baseUrl/model/key → 兼容通义/DeepSeek/OpenAI），默认仍 mock 保证无真实 key 时全链路测试闭环；Embedding 同模式（`app/infrastructure/embedding/` client + factory + openai/mock）。真实 Provider 联调留 Integration Gate。
6. **Tool 注册表 Read/Write 分档**：`app/agents/tools/registry.py` 每个工具声明 tier=READ/WRITE；WRITE 工具执行强制三件套：用户确认令牌（前端二次确认回传）+ 审计落库 + 幂等（依赖 mall-order CAS）；Prompt Security 注入 System Prompt 固定安全条款 + Tool Schema 参数白名单 + Java 端所有权校验三层兜底。
7. **FeatureGate 定稿**：ai-service 启动+每 60s 经网关拉取 mall-system FeatureGate 状态（M5 已交付公开 features 查询端点），缓存内存；`ai.*.enabled=false 或读取失败 → 对应 AI 端点 403 拒绝（fail-closed，AI 为增强能力不影响交易主链路）`；mall-web 经既有 features 查询控制入口显隐。

### 2.1 新增模块（repo-3 ai-service，主战场）

```
app/
├── api/v1/
│   ├── shopping.py        POST /api/ai/shopping/recommendations
│   ├── compare.py         POST /api/ai/compare
│   ├── support.py         POST /api/ai/support/chat
│   ├── orders_assistant.py POST /api/ai/orders/assistant(+ /confirm)
│   └── admin_knowledge.py POST/GET/PATCH/DELETE /api/ai/admin/knowledge/documents(+ /rebuild)
├── agents/
│   ├── workflow.py        节点链引擎（register/条件边/run，traceId 贯穿）
│   ├── shopping_agent.py  意图→澄清?→search→detail→合成 recommendations
│   ├── compare_agent.py   批量详情→属性归一→维度选择→对比+总结
│   ├── support_agent.py   检索→有知识?→引用回答/无知识兜底
│   ├── orders_agent.py    意图→查单→识别→详情/写意图→ProposedAction
│   └── tools/
│       ├── registry.py    Tool 注册表（tier=READ/WRITE；WRITE 强制确认+审计+幂等）
│       ├── product_tools.py   search_products / get_product_detail(s)（经网关调 /api/mall/**）
│       └── order_tools.py     get_my_orders / get_my_order_detail / cancel_order（Bearer 透传）
├── services/
│   ├── conversation.py    Redis 会话（conversationId→最近 N 轮，TTL 24h）
│   ├── feature_gate.py    ai.* 开关拉取/缓存/fail-closed
│   ├── knowledge.py       知识管道编排（upload→parse→chunk→embed→index）
│   └── audit.py           ai_action_audit 写入（MySQL）
├── infrastructure/
│   ├── llm/providers/openai.py    openai 兼容 chat provider
│   ├── embedding/         client.py + factory.py + providers/{openai,mock}.py
│   ├── es/                es_client.py + knowledge_store.py（documents/chunks 索引，dense_vector，kNN topK）
│   ├── minio/             minio_client.py（knowledge/ 前缀 PUT/GET/DELETE）
│   ├── storage/           redis_client.py、mysql_client.py（ai_action_audit）
│   └── java/client.py     扩展：Bearer 透传构造器（会员调用）
└── core/
    ├── security.py        JWT 本地解析（subject_type=ADMIN/MEMBER + memberId）
    └── config.py          扩展：JWT_SECRET、ES_/MINIO_/REDIS_/MYSQL_、ai.* 开关键名
```

关键端点契约（入参/出参/错误码）：
- `POST /api/ai/shopping/recommendations` 入 `{conversationId?, message}`（MEMBER/GUEST 均可，Bearer 可选）→ 出 `{conversationId, message, recommendations:[{productId,productName,image,price,reason}], clarifyingQuestion?}`；错误 400 参数无效 / 403 开关关闭 / 502 LLM 或 Java 上游失败（响应含 traceId）。
- `POST /api/ai/compare` 入 `{productIds:[2..6], question?}` → 出 `{comparisonDimensions:[{dimension, values:{productId:value|"暂无该项数据"}}], products:[...], summary}`；错误 400（<2 个或含无效 id）/ 403 / 502。
- `POST /api/ai/support/chat` 入 `{conversationId?, question}`（GUEST 可用）→ 出 `{answer, sources:[{documentId,title,snippet}]}`；无可靠知识时 answer="当前知识库中没有足够信息…" 且 sources=[]；错误同上。
- `POST /api/ai/orders/assistant` 入 `{conversationId?, message}`（**强制 MEMBER**）→ 出 `{message, orders?:[...], pendingAction?:{actionId, type:"cancel_order", orderNo, orderStatus, summary}}`；`POST /api/ai/orders/assistant/confirm` 入 `{conversationId, actionId, confirm:true}` → 执行 cancel_order；未确认（无 actionId 或 confirm≠true）不执行（409 pending_action_required）；错误 401/403/404 越权与不存在统一 404 口径 / 409 状态不允许取消（透传 Java 业务错误）。
- 知识管理（**强制 ADMIN**）：`POST /api/ai/admin/knowledge/documents`（multipart file，Markdown/TXT，≤5MB，魔数/扩展名校验，MinIO knowledge/ 前缀）→ `{documentId,status:"PENDING"}`；`GET .../documents`（列表+处理状态）；`PATCH .../documents/{id}`（enabled/disable）；`DELETE .../documents/{id}`（MinIO+双索引+chunk 同步删除）；`POST .../documents/{id}/rebuild`（旧 chunk/embedding 失效重建）。

### 2.2 新增改动（repo-1 backend，最小化）

- **mall-gateway**：路由表新增 `/api/ai/**` → ai-service（lb://ai-service 或 http 直连，随既有路由模式）；安全配置追加两条：`/api/ai/members/**` hasRole("MEMBER")、`/api/ai/admin/**` hasRole("ADMIN")、`/api/ai/shopping/**`、`/api/ai/compare/**`、`/api/ai/support/**` permitAll（GUEST 可用，开关在 ai-service 内 fail-closed）。
- **mall-identity V12__ai_knowledge_permissions.sql**：知识库管理权限码 knowledge:doc:list/upload/update/delete/rebuild + 超管授权 + mall-admin 菜单种子（知识库管理入口）——纯 DML，模式复刻 V10/V11。
- mall-order/mall-search/mall-product/mall-inventory：**零改动**（ai-service 经网关消费既有公开/会员端点）。

### 2.3 新增改动（repo-2 frontend）

- **mall-web**：`src/api/ai.ts`（recommendations/compare/support/orders 接口封装，Bearer+X-Trace-Id 复用 http.ts）；`views/ai/AssistantView.vue`（导购对话+推荐商品卡片+澄清追问态）；`views/ai/CompareView.vue`（商品选择器+维度对比表格+AI 总结）；`views/ai/SupportView.vue`（客服问答+引用列表+新会话）；`views/ai/OrderAssistantView.vue`（订单问答+取消二次确认弹窗：展示 actionId/orderNo/状态 → 确认调 /confirm）；路由与 features 开关联动显隐。
- **mall-admin**：`src/api/knowledge.ts` + `views/knowledge/KnowledgeListView.vue`（列表/状态徽标/上传 Markdown|TXT/启停/删除/重建索引，上传组件复用 ImageUploader 模式改文档类型）；v-permission 用 V12 权限码。

### 2.4 新增改动（repo-4 infrastructure）

- docker-compose.infra.yml 或应用 compose 增 `ai-service` 服务定义（uv 运行，环境注入 JAVA_API_BASE_URL（网关地址）、JWT_SECRET、ES_/MINIO_/REDIS_/MYSQL_、LLM_PROVIDER/MODEL/KEY/BASE_URL、EMBEDDING_*，与 `.env.example` 同步）；MySQL init 目录新增 `ai_service` 库与 `ai_action_audit` 表 DDL（id BIGINT PK AUTO_INCREMENT、member_id、conversation_id、tool_name、business_id、params_summary TEXT、result VARCHAR(32)、trace_id VARCHAR(64)、occurred_at DATETIME，index(trace_id)、index(member_id, occurred_at)）。

## 2.1 备选方案对比（Alternatives Considered）

| 决策点 | 采用 | 备选 | 理由 |
|---|---|---|---|
| Workflow | 自研轻量节点链 | LangGraph | 四流程均为线性+条件小图；避免重依赖；M0 骨架零 Agent 依赖 |
| 向量库 | ES 8 kNN | pgvector/Redis Stack/Milvus/Qdrant | 复用 M5 既有 ES，零新增中间件与运维面 |
| 会员数据获取 | 经网关透传 Bearer 调 /api/mall/orders/** | mall-order 新增 internal 端点+X-Member-Id | 归属校验留在 Java SecurityContext 端到端链，mall-order 零改动，memberId 不可伪造面最小 |
| ai-service 身份 | 共享 JWT secret 本地解析 | 每请求回调 Java 校验 | 免每请求一跳；secret 仅 infra 网络内分发；网关已是第一道认证 |
| LLM Provider | openai 兼容 provider + mock 默认 | 绑定单一云厂商 | 可配 baseUrl 多厂商兼容；无真实 key 时 mock 保测试闭环 |
| 会话存储 | Redis TTL 24h | MySQL 表/内存 | infra 已有 Redis；会话天然短生命周期；多实例共享 |
| 审计存储 | MySQL ai_service 库 | ES/文件 | 写操作审计要求可靠结构化存储；SQL 便于按 member/trace 检索 |
| 知识元数据 | ES 双索引（documents/chunks） | MySQL 元数据+ES 向量 | 管理查询（状态/列表）与检索同引擎，避免双写一致性 |
| 对比商品传参 | 前端显式 productIds | 仅会话上下文 | 幂等可重放、可测试；会话上下文仅作辅助解析 |

## 3. 仓库影响（Repository Impact）

- **repo-1**：mall-gateway（路由+安全两行）；mall-identity（V12 DML）。其余模块零改动。
- **repo-2**：mall-web（api/ai.ts + 4 个 AI 视图 + 路由/开关联动）；mall-admin（knowledge api + 管理页 + v-permission）。
- **repo-3**：app/ 全量新增 agents/tools/services/infrastructure 扩展（见 §2.1），main.py 注册 5 组路由；pyproject 新增依赖：elasticsearch、redis、pymysql（或 mysql-connector-python）、minio、pyjwt；pytest 全覆盖。
- **repo-4**：compose ai-service 定义 + .env.example + MySQL ai_service 初始化 DDL。

## 4. 跨仓协作契约

- **API Contract（网关为唯一 Java↔AI 边界）**：
  - mall-web/mall-admin → 网关 `/api/ai/**` → ai-service：见 §2.1 契约；错误统一 UnifyResult 风格信封 + `X-Trace-Id` 响应头。
  - ai-service → 网关 `/api/mall/search/products`（GUEST）、`/api/mall/products/{id}`（GUEST）、`/api/mall/orders/**`（透传 MEMBER Bearer）：出入参以 M2/M4/M5 既有契约为准，ai-service 侧只消费不定义。
- **Event Contract**：无（M6 不引入异步消息；知识重建为 ai-service 内后台任务，状态经 documents 索引可查）。
- **Data Contract**：知识文件 MinIO `knowledge/{documentId}/{filename}` 归 ai-service 写；ES 索引 `ai_knowledge_documents`/`ai_knowledge_chunks` 归 ai-service 独占读写；MySQL `ai_service.ai_action_audit` 归 ai-service 独占写；Java 库 ai-service 只读不经（HTTP only）。
- **Repository Dependencies**：repo-2 依赖 repo-3 端点契约；repo-3 依赖 repo-1 网关路由与 M2/M4/M5 既有查询契约、repo-4 中间件；启动顺序 infra → backend → ai-service → frontend 联调。
- **Integration Boundary**：网关 `/api/ai/**` 路由与角色矩阵；JWT_SECRET 共享（infra .env）；ES/MinIO/Redis/MySQL 连接配置（ai-service env）；FeatureGate 键 ai.shopping/compare/rag/order-assistant.enabled（M5 配置模型，值默认 false）。
- **Cross-Repository Sequence**：DU-INFRA-001 → DU-BE-001（路由）→ DU-AI-001（导购）→ {DU-AI-002、DU-AI-004} → DU-AI-003（RAG 可与 002/004 并行）；各 DU-FE-0xx 依赖对应 DU-AI-0xx 契约冻结；全部完成后 test/review。

## 5. 数据变更

- repo-4 MySQL init（新增库表，无既有表变更）：
```sql
-- Migration: ai_service.audit（ai-service 审计，repo-4 init 脚本）
CREATE DATABASE IF NOT EXISTS ai_service DEFAULT CHARACTER SET utf8mb4;
CREATE TABLE ai_service.ai_action_audit (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  member_id BIGINT NOT NULL,
  conversation_id VARCHAR(64) NOT NULL,
  tool_name VARCHAR(64) NOT NULL,
  business_id VARCHAR(64) NOT NULL,
  params_summary TEXT NULL,
  result VARCHAR(32) NOT NULL,
  trace_id VARCHAR(64) NULL,
  occurred_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_trace (trace_id), KEY idx_member_time (member_id, occurred_at)
);
```
- repo-3 ES 索引（启动 ensure，非 Flyway）：`ai_knowledge_documents`（documentId/title/source/storageKey/enabled/status/version/chunkCount/createdAt/processedAt）、`ai_knowledge_chunks`（documentId/chunkIndex/text/title/dense_vector(embedding.dimension, cosine)/metadata；documentId+chunkIndex 唯一；kNN search topK+score 阈值）。
- repo-1 mall-identity V12：knowledge:doc:* 权限码 + 超管授权 + mall-admin 菜单种子（DML，模式同 V10/V11）。

## 5. Story 设计分派（Story Design Assignments）

### 5.1 Story 拆分（4 Story，1 REQ → 1 L2 → 1 L3 → 1 Story，均已在 feature-tree）

| Story | 标题 | domain.id | 仓库 | Story 设计 | 覆盖 AC |
|---|---|---|---|---|---|
| STORY-008-01-01 | AI 智能导购（主） | FEAT-008-01-01 | repo-3 主 + repo-1/2 | stories/STORY-008-01-01/story-design.md | AC-001~013 |
| STORY-008-02-01 | AI 商品对比 | FEAT-008-02-01 | repo-3 + repo-2 | 本 Story 进入开发时补 story-design.md | AC-014~021 |
| STORY-008-03-01 | RAG 智能客服与知识库 | FEAT-008-03-01 | repo-3 主 + repo-1/2/4 | 同上 | AC-022~029 |
| STORY-008-04-01 | AI 订单助手 | FEAT-008-04-01 | repo-3 + repo-2 | 同上 | AC-030~037 |

### 5.2 DU 划分总表（design 产物，sdd-task 仅消费；du create 登记于主 Story，其余 Story 的 DU 在各自 story-design 产出后登记）

| DU | 仓库 | 职责（实现哪些 DES） | covers AC | depends on |
|---|---|---|---|---|
| DU-INFRA-001 | repo-4 | ai-service compose 定义 + .env + MySQL ai_service/ai_action_audit DDL | AC-022, AC-039 | — |
| DU-BE-001 | repo-1 | mall-gateway /api/ai/** 路由+角色矩阵；mall-identity V12 权限码/菜单种子 | AC-012, AC-022, AC-029 | — |
| DU-AI-001 | repo-3 | S1 导购：openai/LLM+Embedding provider、Tool 注册表、search_products/get_product_detail、导购 Workflow、Redis 会话、FeatureGate 消费、recommendations 端点、pytest | AC-001~007, AC-009~013 | DU-BE-001 |
| DU-AI-002 | repo-3 | S2 对比：get_products_detail 批量、属性归一化、维度选择、对比 Workflow+端点、pytest | AC-014~019, AC-021 | DU-AI-001 |
| DU-AI-003 | repo-3 | S3 RAG：MinIO 对接、Parser/Chunker/Embedding/ES kNN Store/Retrieval、知识管理端点、注入防护、客服端点、pytest | AC-023~028 | DU-INFRA-001 |
| DU-AI-004 | repo-3 | S4 订单助手：订单 Tool（Bearer 透传）、cancel_order Write Tool（确认令牌+审计+幂等）、ai_action_audit 写入、多步 Workflow、注入测试 | AC-030~037 | DU-AI-001 |
| DU-FE-001 | repo-2 | mall-web AI 导购入口（AssistantView+api/ai.ts+开关联动） | AC-008, AC-012 | DU-AI-001 |
| DU-FE-002 | repo-2 | mall-web 对比页（CompareView） | AC-020 | DU-AI-002 |
| DU-FE-003 | repo-2 | mall-admin 知识库管理页 + mall-web 客服入口 | AC-022, AC-028 | DU-AI-003 |
| DU-FE-004 | repo-2 | mall-web 订单助手入口 + 取消二次确认弹窗 | AC-030, AC-035 | DU-AI-004 |

依赖无环；DU-AI-003 与 DU-AI-002/004 可并行；每 DU 单仓可独立红绿灯（pytest/vitest/编译+路由测试）。

## 6. 风险评估

| 风险项 | 级别 | 缓解措施 |
|---|---|---|
| LLM 编造商品/订单（真实数据约束） | 高 | Tool Schema 白名单出参 + 推荐 ID 回溯断言（AC-004/015/033 测试）+ System Prompt 硬条款；mock provider 下行为确定性可测 |
| Prompt Injection 越权（场景五/七） | 高 | 三层防护：ai-service 不信任参数 memberId（JWT 解析）+ Java SecurityContext 端到端归属 + RAG Context 隔离注入；注入用例进 pytest（AC-027/034） |
| JWT_SECRET 共享泄露面 | 中 | 仅 infra 网络内 .env 分发、不入库不入前端；网关为外部第一道认证，ai-service 本地解析仅为降级直连兜底 |
| ES kNN 检索质量（chunk/阈值） | 中 | chunk_size/overlap、topK、score 阈值做成 ai-service 配置项，dev 阶段用样例文档实测调参并记录证据；无知识兜底文案防编造 |
| openai 兼容 provider 真实联调不可用 | 中 | mock provider 保 CI 闭环；真实 provider 留 Integration Gate，provider factory 使切换零业务改动 |
| cancel_order 重复确认/并发 | 中 | actionId 一次性消费（Redis 原子删除）+ mall-order CAS/幂等既有保证 + 审计全记录（AC-036） |
| 网关路由改动影响既有流量 | 低 | 仅新增 /api/ai/** 前缀路由，不触碰既有 matcher；gateway 路由测试回归 |
| 前端四入口 FeatureGate 状态同步 | 低 | 复用 M5 features 查询，入口显隐与 ai-service 403 双保险（AC-012/029/037） |

## 7. 待澄清问题

- spec §4.F-24 中除下述外全部已在本设计定稿（见 §2.0/§2.5）：Workflow=自研节点链；向量库=ES kNN；Embedding/LLM=openai 兼容+mock；会话=Redis TTL 24h；审计=MySQL ai_service 库；对比传参=显式 productIds；身份=JWT 本地解析+Bearer 透传。
- 留待 dev 阶段实测定值（不阻塞设计）：chunk_size/overlap/topK/score 阈值具体数（做成配置，样例文档实测后固化默认值并记录证据）。
- 留待 Integration Gate：真实 LLM/Embedding Provider 联调；M6 七场景运行态实测。
