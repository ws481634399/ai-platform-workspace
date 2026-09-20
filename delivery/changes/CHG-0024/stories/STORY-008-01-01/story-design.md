---
story-id: "STORY-008-01-01"
change-id: "CHG-0024"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
feature-path: "FEAT-008/FEAT-008-01/FEAT-008-01-01/STORY-008-01-01"
---

# Story Design（Story 技术设计）— AI 智能导购

## 0. 元信息

- Change ID：CHG-0024；Story ID：STORY-008-01-01（REQ-M6-001，P1）
- 三仓三 DU：DU-BE-001（repo-1 网关路由+安全）、DU-AI-001（repo-3 导购全链路）、DU-FE-001（repo-2 mall-web 入口）
- 实施顺序：DU-BE-001 → DU-AI-001 → DU-FE-001（契约在 requirement-design §2.1 冻结，FE 可在 AI 联调前以 mock 起步）

### 现状事实（已逐文件核实）

- ai-service 仅 M0 骨架：`app/main.py`（lifespan 初始化 java_http/llm，仅 health 路由）、`app/core/config.py`（JAVA_API_*/LLM_*/EMBEDDING_* 配置位）、`app/infrastructure/llm/client.py`（chat/chat_stream/structured_chat 抽象）+ `factory.py`（PROVIDER_REGISTRY 仅 mock）、`app/infrastructure/java/client.py`（httpx，默认 X-Trace-Id/X-Request-Source 头）、`app/middleware/trace_logging.py`（入站 trace）；无 agents/tools/services、无 Redis、无鉴权解析。
- mall-search `GET /api/mall/search/products`（keyword/category/brand/price/sort/page/size，GUEST 可用）为 ES 查询；ES 不可用降级：search 侧既有 SyncFailure 流程外，Tool 层在 5xx/超时后改调 mall-product `GET /api/mall/products?keyword=...` 公开列表兜底（见 §2 降级）。
- mall-product `GET /api/mall/products/{id}` 公开详情（名称/品牌/SKU/规格/价格/图片/介绍/状态）；可售状态经 `POST /api/internal/inventory/availability` 仅限服务间——公开详情如缺库存态，Tool 以商品 status=ON_SALE 为展示基线并在字段缺失时输出"暂无该项数据"（不虚构），库存展示口径见 spec §4.3。
- mall-gateway `GatewaySecurityConfiguration` 以 pathMatchers 角色矩阵；`TraceIdWebFilter` 已回写 X-Trace-Id；mall-web `src/api/http.ts` 已注入 Bearer + X-Trace-Id，`stores/member.ts` 内存 token + refresh 恢复。

## 1. 模块改动（Module Changes）

### repo-1 mall-gateway（DU-BE-001）

- 路由：新增 `/api/ai/**` → ai-service（随既有 route 定义模式，uri 指向 ai-service 服务地址）。
- 安全矩阵追加：`/api/ai/members/**` → hasRole("MEMBER")；`/api/ai/admin/**` → hasRole("ADMIN")；`/api/ai/shopping/**`、`/api/ai/compare/**`、`/api/ai/support/**` → permitAll（GUEST 可用；能力开关由 ai-service fail-closed 把关）。
- 不改既有 matcher/过滤器；网关路由切片测试回归。

### repo-3 ai-service（DU-AI-001）

- `app/core/config.py` 扩展：`JWT_SECRET`、`FEATURE_GATE_TTL_SECONDS=60`、`CONVERSATION_TTL_SECONDS=86400`、`ES_*`/`REDIS_*`（本 DU 仅 Redis 必需）、`SHOPPING_ENABLED_KEY="ai.shopping.enabled"`。
- `app/core/security.py` 新增：pyjwt 本地解析 Authorization Bearer → `AuthSubject{subjectType, memberId, subject}`；MEMBER 端点依赖注入；token 缺失/非法按端点匿名语义处理（导购允许 GUEST）。
- `app/infrastructure/llm/providers/openai.py` 新增 openai 兼容 chat provider（httpx 调 `{LLM_BASE_URL}/chat/completions`，支持 structured 输出提示词约束）；factory 注册 `openai`；默认仍 `mock`（确定性回复供测试）。
- `app/infrastructure/storage/redis_client.py` + `app/services/conversation.py`：conversationId（uuid4）→ list[轮次]，RPUSH+LTRIM 保留最近 12 轮，TTL 24h；`get_context/append`。
- `app/services/feature_gate.py`：启动+60s 定时经网关拉取 mall-system features（既有公开端点），缓存 {key: bool}；`ensure_enabled(key)` 失败/关闭 → `FeatureDisabledError`（映射 403）。
- `app/agents/tools/registry.py`：Tool 注册表（name/description/参数 schema/tier=READ/WRITE/handler）；本 Story 仅 READ 工具。
- `app/agents/tools/product_tools.py`：
  - `search_products(keyword, category?, brand?, minPrice?, maxPrice?, sort?, pageSize≤20)` → 经 java client 调网关 `/api/mall/search/products`；5xx/超时 → 降级调 `/api/mall/products?keyword=`（mall-product 公开列表）+ 结果归一；两路皆败 → ToolFailure（不编造）。
  - `get_product_detail(productId)` → 网关 `/api/mall/products/{id}`；404 透传语义。
- `app/agents/shopping_agent.py` + `app/agents/workflow.py`：节点链 `extract_intent → (needs_clarify? → clarify) → search → (top 候选 ≤3) enrich_detail → synthesize`；extract/synthesize 走 LLM（structured_chat）；needs_clarify 规则：预算与类别/场景均缺失 → 追问（≤2 问，一次打包）；Tool 返回即候选全集，synthesize 提示词硬条款"仅可引用 candidates 内 productId/price，缺失字段写暂无该项数据"。
- `app/api/v1/shopping.py`：`POST /api/ai/shopping/recommendations`（契约见 requirement-design §2.1）；main.py 注册路由；异常处理映射（FeatureDisabled→403 / ToolFailure→502 / 参数→400），响应带 X-Trace-Id（复用 trace middleware）。
- pytest：provider mock 下的约束提取、澄清边界、Tool 降级、真实约束回溯断言（推荐 ID ⊆ Tool 返回）、开关 fail-closed、会话上下文续轮（详见 §6）。

### repo-2 mall-web（DU-FE-001）

- `src/api/ai.ts`：recommendations 封装（入参/出参类型对齐 §2.1 契约）。
- `src/views/ai/AssistantView.vue`：对话式输入 + 澄清追问态（clarifyingQuestion 渲染为追问气泡）+ 推荐商品卡片（图/名/价/理由，复用商品卡片样式）+ Loading/Error；会话内 conversationId 续轮。
- 路由 `/ai/assistant`；features 查询 `ai.shopping.enabled=false` 时隐藏入口（导航不出现，直达路由给空态提示）。
- vitest：api 封装、视图交互（输入→卡片渲染→澄清态→错误态）。

## 2. 接口契约细化

- 见 requirement-design.md §2.1（SSOT，不在此重复）；Story 侧补充：
  - recommendations 出参 `recommendations[]` 每项必含 productId/productName/image/price/reason；price 为 mall 当前价（分→元转换由 ai-service 完成，单位元）。
  - 澄清与推荐互斥：单响应要么 clarifyingQuestion 要么 recommendations（均有 message 文案）。
  - ES 不可用降级链：mall-search 失败 → mall-product 列表 → 均败 502 + "商品服务暂时不可用"文案。

## 3. 数据变更

- 本 Story 无 SQL 迁移；Redis 会话为运行时数据（TTL 24h）。ES/MinIO/MySQL 归 DU-AI-003/DU-AI-004 引入。

## 4. 错误处理

- 400 参数无效（空 message/超长）；403 功能开关关闭（fail-closed，body 说明"AI 导购暂未开启"）；401 仅在强制 MEMBER 端点（本 Story 导购不强制）；502 LLM 或 Java 上游失败（含 traceId，用户文案"AI 服务暂时繁忙，请稍后再试"）；503 Redis 不可用（降级为单轮无上下文并 warn，不阻断）。
- LLM 超时：httpx 超时 30s，一次重试后仍败 → 502；不返回编造内容。

## 5. DU 划分（Delivery Units）

| DU | 仓库 | 范围 | 覆盖 AC | depends on |
| --- | --- | --- | --- | --- |
| DU-BE-001 | repo-1 | 网关 /api/ai/** 路由 + 安全矩阵三条 + 路由/安全测试回归 | AC-012（路由与角色基础） | — |
| DU-AI-001 | repo-3 | openai provider、security/JWT、Redis 会话、feature_gate、Tool 注册表+商品双 Tool、导购 Workflow、recommendations 端点、pytest 全套 | AC-001~007, AC-009~011, AC-013 | DU-BE-001 |
| DU-FE-001 | repo-2 | api/ai.ts + AssistantView + 路由/开关联动 + vitest | AC-008, AC-012 | DU-AI-001 |

## 6. 测试策略

| TC | AC | 位置/类型 | 关键断言 |
| --- | --- | --- | --- |
| TC-101 | AC-001/002 | ai-service pytest shopping_agent_test | "预算5000开发笔记本"→约束含 {category:笔记本, budget:5000}；响应 recommendations 结构完整 |
| TC-102 | AC-003 | pytest clarify_test | 缺预算+场景 → clarifyingQuestion 且不调 search；信息充分 → 直接 search |
| TC-103 | AC-004/005 | pytest grounding_test | 推荐 productId ⊆ Tool 返回；诱导"iPhone 99 Pro"→ 不出现 Tool 外商品 |
| TC-104 | AC-006/007 | pytest price_reason_test | 展示价 == Tool 返回值；reason 引用候选属性字段 |
| TC-105 | AC-009 | pytest conversation_test | 第二轮"第二台再详细说说"→ 基于会话上下文返回第二名商品 |
| TC-106 | AC-010 | pytest search_fallback_test | mock mall-search 5xx → 改调 mall-product 兜底归一；均败 → ToolFailure→502 |
| TC-107 | AC-011 | 架构断言（配置/代码审查证据） | ai-service 无 Java 库连接串；商品数据仅经 java client |
| TC-108 | AC-013 | pytest 合集 | 上述全绿 + ruff 通过 |
| TC-109 | AC-012 | gateway 切片测试 + ai-service pytest feature_gate_test + mall-web vitest | 开关关闭 → ai 403；入口隐藏 |
| TC-110 | AC-008 | mall-web vitest assistant_view.spec | 输入→卡片渲染/澄清态/错误态/续轮 conversationId 复用 |

## 7. 待办与跨 Story 复用

- 本 Story 产出的 provider/会话/Tool 注册表/feature_gate/security 为 DU-AI-002/004 直接复用；DU-AI-003 复用 provider（Embedding 单独扩展）。
- chunk/topK 等参数类定值在 DU-AI-003 dev 阶段实测定稿；本 Story 无。
