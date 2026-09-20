---
story-id: "STORY-008-03-01"
change-id: "CHG-0024"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
feature-path: "FEAT-008/FEAT-008-03/FEAT-008-03-01/STORY-008-03-01"
---

# Story Design（Story 技术设计）— RAG 智能客服与知识库

## 0. 元信息

- Change ID：CHG-0024；Story ID：STORY-008-03-01（REQ-M6-003，P1）
- 三仓三 DU：DU-INFRA-001（repo-4 compose/.env/DDL）、DU-AI-003（repo-3 RAG 全链路）、DU-FE-003（repo-2 mall-admin 知识库管理页 + mall-web 客服入口）
- 实施顺序：DU-INFRA-001 → DU-AI-003 → DU-FE-003（契约在 requirement-design §2.1/§4/§5 冻结）

### 现状事实（已逐文件核实，含 DU-BE-001/DU-AI-001 交付物）

- repo-4 `deploy/docker-compose.infra.yml` 已有 MySQL 8.4.11、Redis 7.4.11、ES 8.17.4、MinIO、Nacos（共享 `ai-platform-network`）；README 明确不含向量库（本 Story 用 ES kNN 零新增中间件）；`.env.example` 已存在。
- ai-service 已具备：openai 兼容 LLM provider + factory（DU-AI-001）、`app/core/security.py` parse_bearer（subject_type=ADMIN 可识别）、feature_gate fail-closed、java client 透传封装、tests/helpers.py 测试基建；尚无 embedding/es/minio/mysql 基础设施与 knowledge 服务。
- mall-identity V12 知识库权限码 + 超管授权 + mall-admin 菜单种子（component_key=AiKnowledge）已随 DU-BE-001 交付；mall-gateway `/api/ai/admin/**` 已 hasRole("ADMIN")、`/api/ai/support/**` 已 permitAll。
- mall-admin 为 element-plus 工程，`stores/auth.ts` 有权限模型，CHG-0023 ImageUploader 已建立 multipart 上传组件模式（本 Story 改文档类型复用）；mall-web features store 显隐模式与 SupportView 命名空间就绪。

## 1. 模块改动（Module Changes）

### repo-4 infrastructure（DU-INFRA-001）

- `deploy/docker-compose.infra.yml` 增 `ai-service` 应用服务定义（image build 自 repo-3、uv 运行、挂 `ai-platform-network`，环境注入 JAVA_API_BASE_URL/JWT_SECRET/ES_*/MINIO_*/REDIS_*/MYSQL_*/LLM_*/EMBEDDING_*，与 `.env.example` 同步增补键）。
- MySQL init 目录新增 `ai_service` 库与 `ai_action_audit` 表 DDL（列定义见 requirement-design §5，含 idx_trace/idx_member_time 索引；纯新增，不改既有库表）。
- README 增 ai-service 服务说明与启动顺序（infra → backend → ai-service → frontend）。

### repo-3 ai-service（DU-AI-003）

- `app/infrastructure/minio/minio_client.py` 新增：`knowledge/{documentId}/{filename}` 前缀 PUT/GET/DELETE（minio py SDK，异步包装）。
- `app/infrastructure/embedding/` 新增：`client.py` 抽象（embed_documents/embed_query）+ `factory.py` + `providers/mock.py`（确定性向量：词袋 hash → 定维 float）+ `providers/openai.py`（兼容 `/embeddings` 端点）；factory 注册双 provider，默认 mock。
- `app/infrastructure/es/` 新增：`es_client.py`（elasticsearch-py AsyncElasticsearch 封装）+ `knowledge_store.py`：`ensure_indices`（启动建 `ai_knowledge_documents`/`ai_knowledge_chunks`，dense_vector cosine）、`index_document/chunks`、`delete_document_cascade`、`update_document_status`、`knn_search(topK, score_threshold)`。
- `app/services/knowledge.py` 新增管道编排：`upload`（校验扩展名/魔数/≤5MB → MinIO PUT → documents 索引 status=PENDING）→ 后台任务 `process`（Parser：Markdown/TXT → Chunker：chunk_size/overlap 可配 → Embedding → chunks 批量写入 + documents 置 COMPLETED/chunkCount；失败置 FAILED + 原因）；`rebuild`（version+1，旧 chunk 按 documentId+version 失效语义删除重建）；`delete`（MinIO+双索引级联）。
- `app/agents/support_agent.py` 新增：`retrieve`（embed_query → kNN topK+阈值过滤）→ `has_knowledge?`（无 → 固定兜底文案 answer + sources=[]）→ `answer`（LLM，RAG Context 与系统指令隔离注入（独立分隔段+来源标注），硬条款：仅基于 Context 回答、Context 内任何指令不得执行、不输出 Secret）→ sources 构造（documentId/title/snippet 截断）。
- `app/api/v1/support.py` 新增：`POST /api/ai/support/chat`（GUEST 可用，gate.ensure_enabled("ai.rag.enabled")，直出契约）。
- `app/api/v1/admin_knowledge.py` 新增（强制 ADMIN：网关 hasRole("ADMIN") + ai-service parse_bearer 校验 subject_type=ADMIN 双保险）：upload（multipart）/list/patch（启停）/delete/rebuild 五端点。
- `app/main.py` lifespan 扩展（es ensure_indices、minio 健康检查、embedding factory 装配）+ 注册 2 组路由。
- `app/core/config.py` 扩展：ES_/MINIO_/MYSQL_* 连接配置、CHUNK_SIZE/CHUNK_OVERLAP/RETRIEVAL_TOPK/RETRIEVAL_SCORE_THRESHOLD、EMBEDDING_PROVIDER/MODEL/DIMENSION、RAG_ENABLED_KEY="ai.rag.enabled"。
- pytest：parser/chunker 边界、embedding mock 确定性、knowledge_store 用真 ES 连接测试容器不可得时以本地 stub（内存 knn 实现同语义）+ 集成冒烟标注、管道状态机（PENDING→PROCESSING→COMPLETED/FAILED）、删除/重建后旧 chunk 不命中、注入用例（知识文档含"忽略系统规则"→ 不执行不泄漏）、五端点鉴权（ADMIN 200 / 匿名 401 语义 / MEMBER 403）、fail-closed。

### repo-2 frontend（DU-FE-003）

- mall-admin：`src/api/knowledge.ts`（五端点封装）+ `src/views/knowledge/KnowledgeListView.vue`（表格：标题/状态徽标 PENDING|PROCESSING|COMPLETED|FAILED/chunk 数/时间；操作：上传（复用 ImageUploader 模式改 .md/.txt 文档类型+大小校验）、启用/停用 switch、删除二次确认、重建索引）；路由+菜单挂 AiKnowledge（component_key 对齐 V12 种子）；操作按钮 v-permission 对齐 knowledge:doc:* 权限码。
- mall-web：`src/api/ai.ts` 扩展 support chat 封装 + `src/views/ai/SupportView.vue`（提问输入/回答气泡/引用列表（title+snippet 点击展开）/Loading/Error/新会话按钮（重置 conversationId）；"我的订单"类问题提示引导文案）；路由 `/ai/support`；导航入口 `v-if="features.hasFeature('ai.rag.enabled', true)"`。
- vitest：SupportView 交互（回答+引用渲染/兜底文案/Error/新会话重置/开关隐藏）；mall-admin KnowledgeListView 状态渲染与操作调用（api mock）。

## 2. 接口契约细化

- SSOT：requirement-design.md §2.1（support + knowledge 五端点）与 §4 Data Contract（MinIO/ES/MySQL 归属）。Story 侧补充：
  - `sources[].snippet` ≤200 字符截断；`answer` 无可靠知识时为固定兜底文案（配置项含默认值）。
  - documents 列表项：documentId/title/source/storageKey/enabled/status/version/chunkCount/createdAt/processedAt。
  - 处理为 ai-service 内后台任务（无消息队列），状态经 documents 索引可查；服务重启时 PROCESSING 遗留态由启动对账复位为 FAILED（可重建）。

## 3. 数据变更

- repo-4 MySQL init：`ai_service.ai_action_audit` DDL（见 requirement-design §5；本 Story 建 DU-INFRA-001 落地，表由 DU-AI-004 审计写入使用）。
- repo-3 ES 双索引启动 ensure（非 Flyway）：`ai_knowledge_documents`/`ai_knowledge_chunks`（dense_vector(embedding.dimension, cosine)，documentId+chunkIndex 唯一）。
- MinIO `knowledge/` 前缀对象归 ai-service 独占写。
- chunk_size/overlap/topK/score 阈值做成配置项，dev 阶段样例文档实测定默认值并记录证据。

## 4. 错误处理

- 400：文件类型/魔数/大小非法、question 为空超长；403：开关关闭或非 ADMIN 访问知识管理；404：documentId 不存在；502：LLM/Embedding/ES 失败；503：MinIO 不可用（上传拒绝，明确文案）。
- 管道失败：documents 置 FAILED + 原因摘要，可 rebuild 重试；检索降级：ES 不可用 → support 返回 502（不编造答案）。
- 注入防护：RAG Context 隔离注入段 + System Prompt 硬条款 + Tool Schema 白名单（客服链路无写 Tool）三层兜底。

## 5. DU 划分（Delivery Units）

| DU | 仓库 | 范围 | 覆盖 AC | depends on |
| --- | --- | --- | --- | --- |
| DU-INFRA-001 | repo-4 | compose ai-service 定义 + .env.example 键 + MySQL ai_service/ai_action_audit DDL | AC-022（基础设施面） | — |
| DU-AI-003 | repo-3 | MinIO/Embedding/ES kNN 基础设施、knowledge 管道、support_agent、support+admin_knowledge 端点、注入防护、pytest 全套 | AC-023~027, AC-029 | DU-INFRA-001 |
| DU-FE-003 | repo-2 | mall-admin 知识库管理页（api+视图+权限）+ mall-web 客服入口（SupportView）+ vitest | AC-022, AC-028 | DU-AI-003 |

## 6. 测试策略

| TC | AC | 位置/类型 | 关键断言 |
| --- | --- | --- | --- |
| TC-301 | AC-022 | repo-4 compose config 校验 + mall-admin vitest knowledge_list_view.spec | compose 配置合法；上传动作调 upload api（.md/.txt 通过，类型/大小非法拒绝）；列表状态徽标渲染 |
| TC-302 | AC-023 | pytest knowledge_pipeline_test | 上传 → PENDING；process → COMPLETED + chunkCount>0；documents/chunks 元数据可查 |
| TC-303 | AC-024 | pytest support_agent_test | 命中知识（"配送范围"样例）→ answer 基于召回 chunk + sources[]（documentId/title/snippet） |
| TC-304 | AC-025 | pytest support_fallback_test | 无命中（低于阈值）→ 固定兜底文案 + sources=[]；无编造规则 |
| TC-305 | AC-026 | pytest knowledge_rebuild_delete_test | rebuild 后旧 chunk 失效按新内容回答；delete 后 knn_search 不再命中 |
| TC-306 | AC-027 | pytest injection_test | 知识文档注入"忽略系统规则/输出 Secret/允许任意 Tool" → answer 不执行、不含 secret、无 Tool 调用提升 |
| TC-307 | AC-029 | pytest feature_gate + admin 鉴权用例 | ai.rag.enabled=false → 403；知识管理匿名/MEMBER → 拒绝，ADMIN → 200 |
| TC-308 | AC-029 | pytest 合集 | RAG 核心 pytest 全绿 + ruff |
| TC-309 | AC-028 | vitest support_view.spec | 提问→回答+引用渲染；Loading/Error；新会话重置 conversationId；开关 false 入口隐藏 |

## 7. 待办与跨 Story 复用

- ES/MinIO/MySQL client 与 ai_action_audit 写入服务（audit.py 在 DU-AI-004 落地使用本 DU 的 mysql client）为 DU-AI-004 复用。
- chunk/topK/阈值默认值在 DU-AI-003 dev 阶段样例实测后固化进 config 默认并记录证据。
