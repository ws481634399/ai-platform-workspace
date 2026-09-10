# Exploration

> 阶段：sdd-explore 产物
> 输入：Requirement（requirement.md，原文归档 references/REG-M0-003.md）
> 产出状态：exploring（推进 Change 状态）

本文档记录 sdd-explore 阶段的探索结果。

## 1. 需求理解

**需求类型**：新功能开发（全新工程建设型）——与 CHG-0004「前端零起点建设」同类，AI Service 同样是零起点：远程仓库 ai-platform-AIService（repo-3）为空仓库，无任何存量代码与历史负担；是继 Java 后端（repo-1）、前端（repo-2）之后的第三个独立工程仓库。

**需求本质**（表面描述 vs 实际意图）：

- **表面**：建立 Python AI Service 单仓 12 项基础能力（uv 工程、FastAPI、配置、日志、健康检查、LLM Client、Java API Client、AI Tool/Agent/Workflow/Prompt/RAG 边界、Pytest、质量工具）+ 11 AC + 28 DoD + Evidence。
- **实际包含三层关键意图**：
  1. **第三仓独立基线**：与 repo-1（Maven Java Monorepo）、repo-2（pnpm 双前端）并列，AI Service 是项目体系内的 Python 原生仓，工具链完全不同于前后端（uv 而非 Maven/pnpm），需要在 `.sdd/repositories.yaml` 注册并在 CHG metadata 上声明 repo-3；M0 是"工程三仓鼎立"的最后一块拼图。
  2. **M0 只建"插座"不接"电器"（比 CHG-0004 更强）**：需求 §五 明确"不要为了匹配模板创建大量长期为空的目录和文件"、§十一 禁止"提前写大量假业务 Tool"、§二十二 排除 14 项 AI 业务功能。LLM Client / Java API Client / Tool / Agent / Workflow / Prompt / RAG 七个工程边界，M0 用接口、抽象、最小实现骨架或**纯粹目录占位声明**（非空目录）的方式验证其存在性，禁止写 ProductAgent / OrderAgent / RAG 召回 / LangGraph 状态图 / Prompt Template 等正式实现。关键是**边界可替换**（LLM Provider 可替换、Java API 可扩展、Tool 可注册、写操作不越界）。
  3. **架构边界红线 + 写操作安全**：与 CHG-0003/0004 仅在"技术架构分层"上不同，AI Service 的需求 §十八~十九 用了两节明确写入**禁止直连数据库**、**禁止修改业务表**、**必须走 Java API**、**高风险写操作二次确认预留**——这是 M0 阶段就引入的强架构约束（不同于一般工程基线只谈工具链），目的是防止后续 AI 需求迭代时"为了省事直接查库"。
- **隐含需求**（用户未明说但可从文档推出）：
  1. **Python/uv 工具链版本锁定**：需求 §三~四 要求 Python 3.11 固定和 uv.lock 提交，但未指定 uv 版本、未要求 `uv run python --version` 可验证；Evidence 部分要求记录 Python Version / uv Version（§二十六 Environment），暗示需要在开发环境固化版本号（可能在 pyproject.toml `[tool.uv]` 或 `.python-version` + README 中声明）。
  2. **AI 六维规范引用**：standards/engineering/ai/ 下已有 agent-standard.md、prompt-standard.md、tool-calling-standard.md、knowledge-standard.md、evaluation-standard.md、README.md 共 6 个 AI 规范文件（standards/INDEX.md §AI 应用工程规范段已登记）——尽管是框架骨架，但 M0 设计阶段需要对齐这些规范的接口命名（Tool 注册格式、Prompt 目录层级、RAG 扩展点命名），避免后续晋升（converge 阶段）时出现大量 rename。
  3. **Java → AI → LLM Trace 传播**：需求 §八（TraceId 扩展能力）+ §十（Java Client Header/TraceId）明确要求链路追踪预留——这不是日志框架单体能力，而是**跨服务的调用链上下文**，意味着 Java Gateway 需透传 `X-Trace-Id` Header，FastAPI 中间件读取并注入 Logger Context，LLM Client 与 Java API Client 发出的 HTTP 请求都要携带该 TraceId。M0 不要求接入真实 Jaeger/SkyWalking，但需确保"Header → Log → 外呼"三段链路的结构可扩展。
  4. **秘钥不入库的执行保障**：需求 §六+§七+§二十四 DoD「Git 中不存在真实 Secret」与 Evidence 诚信约束（§二十六 末「任何未实际执行的验证不得记录为 PASS」）——除了 .env.example 与 .gitignore，M0 可能还需 Ruff/Pyright/Pre-commit 级别的 secret scan 或至少有明确的团队约定不提交 .env。
  5. **独立启动 = 无依赖运行**：AC-03 / DoD「AI Service 启动 PASS」意味着 M0 的 FastAPI 启动不应依赖 MySQL / Redis / Nacos / MinIO 任一基础设施（§二十 明确全部不依赖），即使设计阶段引入 settings 读取这些配置，也必须在缺省时以"未配置即跳过"方式降级。

**知识检索命中（sdd-knowledge 能力 D）**：

按需求关键词 `AI 工程基线` `Python` `FastAPI` `LLM Client` `Java API` `RAG` `Agent` `Tool Calling` 在 `.sdd/knowledge-index.json` 中匹配：

- **命中且相关（score ≥ 2）**——注入分析：
  - `standards/engineering/ai/README.md`（tags: ai, engineering, index, agent）[score: tags 命中 ai+engineering=4 / title 精确匹配"AI 应用工程规范入口"]——作为六维 AI 规范总入口引用到 §5 参考文档；Design 阶段需在 exploration 分析的基础上对齐。
  - `standards/engineering/ai/agent-standard.md`（tags: ai, agent, llm, design）[score: tags ai+agent+llm=6]——§九 LLM Client 抽象的"依赖方向：Agent/Workflow → LLM Client Interface"与本规范"工具/记忆/规划与评估闭环"条目一致；AC-07 LLM 抽象验收的设计依据。
  - `standards/engineering/ai/prompt-standard.md`（tags: ai, prompt, llm）[score: tags ai+prompt+llm=6]——§十三 Prompt 管理基础"模板化与版本治理"引用；Design 阶段需为 prompts/ 目录结构确定 Version 字段（如 prompt.yaml version 字段或文件名 v1 编码）。
  - `standards/engineering/ai/tool-calling-standard.md`（tags: ai, tool-calling, function-calling）[score: tags ai+tool-calling=5]——§十一 Tool 基础结构与 §十九 写操作安全边界（二次确认机制）与本规范"工具调用的设计、实现与管理规范"高度一致；Design 阶段 ToolSchema 定义优先参考此规范。
  - `standards/engineering/ai/knowledge-standard.md`（tags: ai, knowledge, rag）[score: tags ai+knowledge+rag=5]——§十二 RAG 扩展位置（rag/ 目录预留）与"知识库构建、索引、检索与更新"条目一致；M0 不建 RAG 但不与后续扩展冲突。
  - `standards/architecture-principles.md`（tags: architecture, solid, layered, patterns）[score: tags architecture+layered+patterns=6，summary 含"分层架构"关键词]——作为 FastAPI 分层（app.api/ /core/ /schemas/ /infrastructure/）的骨架依据，确保不出现"上帝类 main.py"。
  - `standards/engineering/api-standard.md`（tags: api, engineering, design）[score: 3]——§六 FastAPI 接口命名、错误码格式、响应结构的参考；Health API 返回字段应与 Java 后端保持一致（service/status 字段，响应 JSON 包裹格式可在 Design 定）。
  - `standards/engineering/testing-standard.md`（tags: testing, engineering, qa）[score: tags testing+engineering+qa=6]——§十五 Pytest 测试金字塔划分（单元 vs 集成 vs Health API 最小集成）；Design 阶段的测试计划引用本规范。
- **命中但不相关（score = 1）**——仅记录：
  - standards/coding-standards.md（summary 提及 Python snake_case，但内容偏通用；Java/前端更具体的 backend/frontend coding-standard 已在对应规范，但 Python 专属 Coding Standard 暂未建立，需在 Design 阶段或 converged 时产出候选）。
  - product/08-系统与微服务架构.md（§3/§4 提及 Python AI 服务架构，但本需求是工程基线，不修改 product/）。
- **未命中**：无 Python 专属编码规范、无 uv/FastAPI 专属工程约定、无 LLM Provider 版本治理——标注"无历史知识参考，需独立探索并在 converge 时考虑晋升为 standards/project/ 或 engineering/（如新建 engineering/ai/python-foundation-standard.md）"。

## 2. Feature 归属

- Feature ID: STORY-1-02-01-01
- Feature 路径: MOD-1 工程基础 > FEAT-1-02 AI 工程基线 > FEAT-1-02-01 AI 应用骨架 > STORY-1-02-01-01 建立 Python AI Service 工程基线
- 是否新建 candidate: no（正式节点，探索阶段创建并绑定；归属方案经用户确认 2026-09-04：现有 MOD-1 下 FEAT-1/FEAT-2/FEAT-3 分别对应 Maven Java、微服务 Java、前端 Vue 三条基线，AI Service（Python FastAPI 独立仓）不属于任一现有 L2 边界，故在 MOD-1 下新建第四个 L2 兄弟 FEAT-1-02「AI 工程基线」；保留 L3 层 FEAT-1-02-01「AI 应用骨架」，既为 M6 后的子功能（如 LLM 接入 / RAG 接入 / Agent Workflow）预留扩展位，同时避免 harness bind 对「story directly under L2」的已知遍历缺陷（来自 CHG-0004 探索阶段经验）；单 Story 挂 L3 下）
- 复用决策: 新建（无同名或同义的 AI 工程基线 Story 匹配历史；CHG-0003 是 Java 微服务基线、CHG-0004 是前端基线，均为兄弟能力不冲突）

## 3. 影响分析

- 受影响仓库:
  - **repo-3（implementation/ai-platform-ai-service，新建启用）**：全部 Python AI Service 实现落于此仓。explore 阶段已在 `.sdd/repositories.yaml` 注册（remote: https://github.com/ws481634399/ai-platform-AIService.git），远程为空仓库；M0 工程基线将在 dev 阶段初始化提交并推送
  - **工作区仓 ai-platform-workspace**：仅修改 product/feature-tree.yaml（新增 FEAT-1-02 / FEAT-1-02-01 / STORY-1-02-01-01 并 Story status 后续流转为 delivered）、.sdd/repositories.yaml（追加 repo-3，本次 explore 已完成）、delivery/changes/CHG-0005/ 全部交付文档（requirement/exploration/prd/design/tasks/implementation/evidence/review-report/convergence 等）
- 不受影响 / 零修改保证:
  - **repo-1（implementation/ai-platform-backend）**：AI Service 在 M0 不调用任何真实 Java 内部 API，Java API Client 只做抽象不实际连网关（可用本地 Python Mock Server 或 httpx Mock 验证拦截器）；后端基线无任何回退风险
  - **repo-2（implementation/ai-platform-frontend）**：商城端与后台管理端在 M0 不调用 AI Service（AI 聊天/导购页面等属 M6），前端完全零修改
- 影响范围：
  - 全新仓库 + 全新 Feature 分支，无任何存量功能受影响；无数据迁移；对 M6 系列 AI 需求（AI 导购 / 商品对比 / RAG 客服 / 订单助手 / Agent Workflow）直接形成开发基线（"插座就绪"）
  - 多仓交付提示：本 Change 为 workspace 启用 repo-3 后的**首个三仓并行架构下的 Python 独立 Change**，task 阶段 DU 物化（`openspec du materialize`）只涉及 repo-3（以及工作区仓交付文档），但 converge 阶段需同时核验三仓 feature-tree 索引关联和 references 无冲突
- 架构影响（引用 architecture-principles.md）：
  - 与 Java 微服务严格走 API（防腐层 ACL 思想，Java API Client 相当于 AI 侧的 Anti-Corruption Layer）
  - LLM Client 接口层体现依赖倒置原则（D in SOLID）：高层 Agent 不依赖底层 OpenAI SDK
  - FastAPI 分层（app.api/ Controller / app.core 配置+日志 / infrastructure/ Client 与适配 / schemas/ DTO）符合分层架构约束，避免"上帝类 main.py"

## 4. 未知问题

留待 PRD/设计阶段澄清：

1. **repo-3 仓库根目录布局**：仓库根直接就是 ai-service（即 app/ agents/ 等位于仓库根），还是保留 `ai-service/` 一级目录？需求 §五 参考结构写 `ai-service/` 前缀（相对 ai-mall-platform 组合视图的路径），但 §二十一 写 "Repository: AI Service 独立代码仓库"——仓库根是否等于 ai-service 需要 Design 明确（影响 pyproject.toml 的 package dir 与 README）。
2. **uv 版本与 Python 3.11 精确版本**：需求未指定 uv 精确版本、Python 3.11 的 Patch Level（如 3.11.9 vs 3.11.11）；是否以 `requires-python = ">=3.11,<3.12"` + `.python-version` 强制，是否在 README 中声明最小 uv 版本（如 ≥ 0.5.x）需 Design 定。
3. **pyproject.toml 中构建后端选择**：标准为 `hatchling` 还是 `setuptools>=68` 或 `uv` 自身推荐方案；影响 packaging 行为（虽 FastAPI 非库发布，但测试配置、代码质量工具配置集中在 pyproject.toml）。
4. **代码质量工具组合**：Ruff vs Ruff+Pyright vs Ruff+mypy；需求 §十六 警告"不要同时安装大量重复作用的 Python 工具"。建议 Ruff（统一 lint + format）+ Pyright（类型检查）的双通道组合，是否接受 Ruff 作为 format 工具替代 black/isort 需在 Design 定。
5. **Java API Client 的实现选型**：HTTPX 异步 Client vs FastAPI 推荐的 `httpx.AsyncClient` + 依赖注入（lifespan startup 创建全局实例）vs 每个请求独立实例；涉及连接池复用、超时配置、Header 注入（TraceId / Authorization）的实现结构；是否引入 `tenacity` 做重试扩展需 Design 决定。
6. **LLM Client 的接口签名**：`complete()` vs `chat()` vs `stream_chat()`，是否支持 Structured Output（Pydantic Model 返回）；Provider Adapter 的注册方式（显式 factory 类 vs 通过配置名动态加载）；M0 最小实现 MockProvider 的返回结构需要在 Design 确定。
7. **FastAPI 异常处理与错误码对齐**：Java 侧已有统一错误码规范（standards/engineering/backend/api-design-standard.md），AI API 是否在错误码上与 Java 对齐（前缀区分，如 AI-0001 PARAM_ERROR、AI-0002 JAVA_API_FAILED、AI-0003 LLM_PROVIDER_ERROR），还是仅用 HTTP status code；§十四 明确五种异常类型，需对应类层次与全局 Exception Handler 映射。
8. **Logging Middleware vs Lifespan**：TraceId 注入、请求开始/结束日志的实现方式——Starlette Middleware（通用）、APIRouter dependencies（每个路由）、还是 lifespan 注入到 Request.state；与 Java Gateway 透传的 Header 名（`X-Trace-Id` vs `X-Request-Id`）需 Design 与 Java 侧统一。
9. **Prompt 管理的最小约定**：需求 §十三 要求 Prompt 不应硬编码但 M0 "不提前创建正式 AI 业务 Prompt"。prompts/ 目录下是否还需要最小的约定骨架（如 `prompts/README.md` 声明目录规范、或 `prompts/.gitkeep` + 文档化约定即可），避免创建空文件或空模板。
10. **Test 范围界定**：AC-09 `uv run pytest` 全部通过，AC-04 Health API 可访问；Pytest 的具体清单至少需要哪些（配置加载单元测试、Health API 集成测试、LLM Client 接口一致性测试、Java API Client 初始化测试）——是否引入 `httpx.ASGITransport` 作为 TestClient 实现（FastAPI 标准实践），以及是否需要 coverage 最低阈值（如 ≥ 60%）。
11. **Ruff / Pyright 等工具的配置位置**：全部集中在 pyproject.toml（推荐，与单仓工具链配置中心化一致）还是拆分 ruff.toml / pyrightconfig.json；与需求 §四 "pyproject.toml 为唯一依赖声明"的"统一管理"精神一致但未明确。
12. **HTTPX/uvicorn 日志重叠问题**：uvicorn access log 与自定义 Request 日志可能重复，是否禁用 uvicorn 默认 log_config 并用自定义中间件接管；Evidence Service 启动时需确保无重复日志冲突。

## 5. 旧需求沿用判断

- 匹配进行中 Change: 无（`openspec change list` 在 explore 开始时结果为空）
- 匹配 archived Change: 无 AI Service 或 Python 独立仓相关的已归档 Change（CHG-0001/Maven 版本治理、CHG-0002/公共模块、CHG-0003/Java 微服务基线、CHG-0004/前端工程基线）。与本 Change 最近似的是 CHG-0003（"骨架与基础能力"同构）与 CHG-0004（"零起点独立仓"同构），但技术栈与仓库完全不同，无直接 artifact 内容可复用——仅沿用：
  1. 仓库启用流程：在 explore 阶段将 repo-3 追加到 `.sdd/repositories.yaml`（与 CHG-0004 repo-2 启用同模式）
  2. 证据诚信原则：CHG-0004 exploration.md §1 隐含需求段标注"未实际执行的验证不得记录为 PASS"，本需求 REG-M0-003.md §二十六 已明写为规则，可在 Evidence 记录时直接复用该核验方式
  3. Feature Tree L3 保留策略：CHG-0004 首次发现 harness bind 的 "story directly under L2" 遍历缺陷，本 Change 同样保留 L3（FEAT-1-02-01）避免同一 bug
- 决策: **新建 CHG-0005**（全新技术栈+新仓+无历史 AI Change，无任何沿用理由；related-change 留空）

## 参考文档

- `references/REG-M0-003.md` — 用户提供的原始需求文档（1117 行，完整归档，本阶段分析唯一输入源）
- `standards/engineering/ai/README.md` — AI 应用工程规范六维总入口（Agent/Prompt/Tool Calling/Knowledge/Evaluation 五规范 + 索引）
- `standards/engineering/ai/agent-standard.md` — AI Agent 设计规范（§九 LLM Client 依赖方向、Agent 角色职责分层）
- `standards/engineering/ai/prompt-standard.md` — Prompt 模板化与版本治理规范（§十三 prompts/ 目录管理约定依据）
- `standards/engineering/ai/tool-calling-standard.md` — Tool Calling 规范（§十一 Tool 基础结构 + §十九 写操作二次确认机制的设计参考）
- `standards/engineering/ai/knowledge-standard.md` — RAG 知识管理规范（§十二 RAG 扩展位置命名与分层依据）
- `standards/architecture-principles.md` — 分层架构 + SOLID（§五 FastAPI 分层、LLM Client 依赖倒置、Java API Client 防腐层设计原则）
- `standards/engineering/api-standard.md` — API 规范（§六 Health API 命名与响应包裹格式参考，§十四 异常错误码与 Java 对齐依据）
- `standards/engineering/testing-standard.md` — 测试金字塔（§十五 Pytest 分层：Unit/Health API Integration/Client Interface Test）
- `standards/coding-standards.md` §Python 小节 — snake_case 文件命名（§五 app/agents/workflows 等 py 文件命名来源）
- `product/00-项目总览.md` — 项目蓝图与三仓（Java/前端/AI）的整体结构定位
- `product/08-系统与微服务架构.md` §5 双仓结构与 Python AI 服务架构 — 仓库组织形态（独立仓而非 Monorepo Python 子目录）与 Gateway → Java → AI 链路定位
- `product/10-API与事件契约.md` — 统一 HTTP 响应结构与幂等协议（Java API Client 适配时的请求/响应转换原则）
- `.sdd/repositories.yaml` — repo-1/2/3 三仓映射与实现位置（workspace .gitignore 中 implementation/ 的独立管理方式）
