# PRD

> 阶段：sdd-prd 产物
> 输入：CHG Context（exploration.md + requirement.md）
> 产出状态：specified

本文档将 REQ-M0-003（AI Service 基础工程）转化为产品规格，供后续设计（design.md）与交付（tasks.md → development → testing）使用。

## 0. 元信息

- Change ID: CHG-0005
- Requirement: REQ-M0-003（原始文档 1117 行完整归档于 `references/REG-M0-003.md`；本 PRD 的 Scope/业务规则/AC 逐条映射原文章节并标注章节号）
- Feature ID: STORY-1-02-01-01（路径：MOD-1 工程基础 > FEAT-1-02 AI 工程基线 > FEAT-1-02-01 AI 应用骨架；单 Story inline 模式，一次机检/人审双语义，Change PRD 与 Story Spec 合并）
- 状态流转: exploring → specified

## 1. 背景

CHG-0001（Maven 四层体系 + mall-bom 版本权威）、CHG-0002（mall-common/contracts 8+2 公共模块边界）、CHG-0003（Java 微服务 Gateway + 8 服务骨架 + 数据访问 + 测试基线）、CHG-0004（mall-web + mall-admin 双前端 Vue3 工程基线）均已通过全部 Gate 并交付归档，项目的 Java 后端技术栈 + 前端技术栈的"工程插座"已全部就绪。

**唯独 AI Service（Python + FastAPI + LLM/Agent 体系）是项目平台「三仓鼎立」的最后一块空白拼图**：

- `.sdd/repositories.yaml` 在 CHG-0005 explore 阶段才首次登记 repo-3（implementation/ai-platform-ai-service，远程 https://github.com/ws481634399/ai-platform-AIService.git 为空仓库）
- M6 AI 业务需求即将进入实施（导购 / 商品自然语言对比 / RAG 智能客服 / 订单助手 / LangGraph 多 Agent Workflow / AI 写订单二次确认链路等 14 项 AI 能力均已在 REG-M0-003 §二十二 明确列为 M6+ 范围）
- 与 CHG-0004 前端零起点同构，AI Service 同样是"无存量代码、无迁移负担、全零起建"；若 M6 业务紧急时再临时拼凑，极有可能在赶工期中发生三类架构红线被突破的风险：
  1. LLM Provider SDK 被散落到 Agent 业务代码中（切换 Provider 引发大面积修改）
  2. 为了快速取数，AI 工程直接连接 mall_order/mall_product 等 Java 业务数据库（绕过 Java 业务规则与权限校验）
  3. 修改订单/用户等高风险写操作被模型直接触发（无 Tool → Java API → 二次确认链路保护）

需求文档专门用 §十八、§十九 两节独立章节写入架构红线（禁止直连数据库 / 禁止修改业务表 / 写操作必须走 Java API + 二次确认预留），正是希望 M0 工程阶段就以代码形式落实边界（分层 + 接口 + Adapter + Mock），而非事后靠 Code Review 抓违规。

本 Change 是**启用 repo-3 后第一个 Python 独立仓 SDD Change**。exploration.md §3 影响分析明确：repo-1（Java 后端）零修改、repo-2（前端）零修改；所有实现仅落在 repo-3 + 工作区交付文档。

## 2. 用户价值

- **目标用户**:
  - 主要：M6+ AI 业务需求的实施者（Python / LLM Agent 开发工程师、Tool 开发者、Prompt 工程师）
  - 次要：Java 后端工程师（提供给 AI 的内部 API 设计时需对齐 Java API Client 边界）
  - 间接：平台架构/合规角色（核查 AI 工程是否架构合规）、商城终端用户（M6 上线后间接受益于稳定 AI 能力）
- **痛点摘要**:
  - Python 工程完全空白——工具链(Python/uv)、FastAPI 脚手架、配置/日志/异常体系、LLM 适配层、Java 集成层全部从零，每个 M6 业务若独立处理，将发生**版本漂移**（Python 3.10 vs 3.12 混用，不同开发者装不同的 LLM SDK）
  - 架构红线无代码保障——"禁止直连数据库"仅凭文档约束，后续业务赶工时极易违反
  - 质量基线缺失——没有统一测试入口（pytest）、lint（ruff）、类型（pyright），M6 迭代后 Engineering Quality 回归风险陡增
- **预期价值（JTBD）**:
  - **AI 实施者**: When I 开始开发 M6 任意 AI 业务（导购/客服/订单助手）, I want to 在已经具备 FastAPI + Pydantic Settings + Logging(TraceId) + GlobalException + LLM Interface + Java HTTPX Client + Ruff/Pyright 的工程骨架上直接写 Agent/Tool/Prompt, So that 我不需要重复处理"Python 怎么装依赖""uv sync 为什么失败""日志怎么加 TraceId""Java API 怎么调"这些工程问题，同时 Provider 切换无痛、架构红线自动生效。
  - **架构/合规角色**: When I 校验 AI 工程合规性, I want to 通过 `uv sync`（依赖）+ `uv run pytest`（测试）+ `uv run uvicorn app.main:app`（启动）+ `curl /health`（健康）+ `ruff check` / `pyright`（质量）+ Architecture Scan（禁直连DB） 六组命令一键验证, So that 28 项 DoD + 11 项 AC 均可量化核验。
  - **平台（间接）**: When I 未来切换 LLM Provider（如从 OpenAI 切到国内模型）, I want to 只改 Settings 的 LLM_PROVIDER + 新增一个 Provider Adapter 类, So that 上层 Agent/Tool 代码不需要任何修改（依赖倒置原则落地）。

## 3. 范围

### 3.1 包含（Scope In）

聚合需求文档建议 TASK-001~008 与 DU-AI-001~005，全部为 P0 必须，单 Change 交付：

1. **Python / uv 版本与依赖管理基线**（映射 §三~四）：Python 3.11 固定（`.python-version=3.11`，`requires-python=">=3.11,<3.12"`）；uv 为唯一依赖与运行工具；`pyproject.toml` 声明 build-system、dependencies、dev-dependencies；`uv.lock` 必须提交 Git；`.venv/` 不入库。
2. **FastAPI HTTP 应用基础**（映射 §六）：Application 创建入口（lifespan startup/shutdown）；`app/api/` 目录通过 APIRouter 组织（health router 至少一个）；配置加载（Settings 依赖注入模式）；全局异常处理（区分五类异常，屏蔽 Python Traceback 到 HTTP 响应）；Health API `GET /health` 暴露 `service=ai-service` 与 `status=UP` 两字段。
3. **Config / Environment / 日志 / 异常 工程基础**（映射 §七~八、§十四）：Pydantic Settings 模型支持环境变量 + `.env` 文件；`.env.example` 声明 APP_NAME/APP_ENV/APP_HOST/APP_PORT、JAVA_API_BASE_URL、LLM_PROVIDER/LLM_API_KEY/LLM_MODEL、EMBEDDING_PROVIDER/EMBEDDING_MODEL 共 8 类配置；统一 Logger（级别/时间戳/Logger Name/请求信息/TraceId 注入/异常堆栈结构化）；异常体系五类：Param（参数）、Config（配置）、JavaAPIFailed（Java API 调用失败）、LLMProviderFailed（外部 Provider 失败）、Internal（系统内部）。
4. **集成基础：LLM Client 抽象 + Java API Client 基础**（映射 §九~十）：LLM Client Interface（独立于具体 Provider SDK） + Provider Adapter 模式（业务代码经 Interface → Adapter → Provider SDK）；M0 提供 MockProvider 作最小验证（验证依赖倒置方向）。Java API Client：基于 HTTPX AsyncClient 的统一封装；Base URL/Timeout/Header 从 Settings 读取；预声明 TraceId 透传、身份信息 Header、错误转换、重试策略四个扩展点；M0 不实现正式 ProductClient/OrderClient/InventoryClient 方法。
5. **AI 工程边界预留：Tool / Agent / Workflow / Prompt / RAG**（映射 §十一~十三）：为后续 LangGraph / Tool Calling / Prompt 管理 / RAG 确定目录组织与最小边界位；`prompts/` 提供 README.md 管理约定（模板命名 / version / 参数化引用 `standards/engineering/ai/prompt-standard.md`）；`agents/`、`workflows/`、`tools/`、`rag/` 四目录建立最小边界（__init__.py 或 .gitkeep 级别），禁止提前写业务实现。
6. **Pytest 测试 + 代码质量基线**（映射 §十五~十六）：Pytest 配置；Health API 集成测试（ASGI TestClient）；Settings 加载单元测试；LLM Client 接口一致性测试（MockProvider）。质量工具采用 Ruff（lint + format 合并，避免重复装 black/isort）+ Pyright（类型检查），禁止同时装大量重复工具。
7. **启动规范、凭据安全、Evidence 形成**（映射 §十七、§七 Secret、§二十四 DoD 第 24、§二十六）：`uv run uvicorn app.main:app --reload` 可启动；`.gitignore` 屏蔽 `.env`、`.venv` 等；Evidence 至少记录六组：Environment（Python Version/uv Version）、Dependency（uv sync）、Service（启动）、Health（GET /health）、Test（uv run pytest）、Architecture Check（六项架构合规检查）。未实际执行的验证**不得**记录 PASS。

### 3.2 不包含（Scope Out）

严格对齐 REG-M0-003 §二十二「非本需求范围」+ §二十「不依赖基础设施先行」+ §二十三「不拆独立 Change」三项排除原则：

1. **不包含任何正式 AI 业务功能实现**（属 M6 及后续 Requirement）：
   - AI 智能导购、商品自然语言搜索、AI 商品对比、RAG 知识库召回、Embedding 处理、Vector Database 接入
   - AI 客服对话、AI 订单助手、多 Agent 协作、正式 LangGraph 状态机
   - Prompt Evaluation、AI Monitoring、AI 写订单能力（取消/修改订单）
2. **不包含正式业务的 LLM Provider / Java API Client 接入**：M0 只建 LLM Provider 抽象 + MockProvider；只建 Java API Client 抽象不实现 ProductClient/OrderClient/InventoryClient 等业务方法
3. **不包含正式业务 Agent/Tool**：不实现 search_products / get_product_detail / compare_products / get_order / search_knowledge 等真实 Tool 逻辑
4. **不包含基础设施 SDK**：MySQL、Redis、Nacos、MinIO、Elasticsearch、Vector DB（Milvus/pgvector 等）的 SDK 引入与连接（M0 不依赖它们，需求 §二十）
5. **不包含 LangGraph / LangChain / Tool Calling 等重量级框架引入**：M0 只建目录边界与接口抽象位，框架在对应 M6 Requirement 决策引入
6. **不包含 CI/CD 流水线、Docker 镜像、生产部署、Kubernetes 等 DevOps 工作**：归属于后续独立 DevOps Requirement
7. **不拆成多个 Change**（需求 §二十三 明确禁止）：本 PRD Scope In 的 7 个能力域必须在单个 CHG-0005 中一次性交付。

## 4. 业务规则

每条规则采用 `[规则名]：[条件] → [结果/处置]` 格式，可追踪到需求文档章节：

- **[R-01 Python 版本锁死]**（映射 §三 AC-01）运行环境 Python 版本不在 3.11.x 区间 → 通过 `.python-version` + `pyproject.toml requires-python=">=3.11,<3.12"` 双重拒绝 → `uv sync` 阶段报错，项目无法初始化
- **[R-02 依赖工具唯一]**（映射 §四 DoD-03/04）仓库中出现 requirements.txt / Poetry(pyproject.toml 内 `[tool.poetry]`) / Pipfile / Conda environment.yml 任一竞争体系文件 → 直接违反 DoD → 标记 Architecture Check FAIL，评审阶段阻断
- **[R-03 FastAPI 分层纪律]**（映射 §五 AC-10）`app/main.py` 行数 > 50 行，或 api 层直接写业务逻辑、或 infrastructure 的 Client 直接被路由 Handler 跳过 service 层调用 → 违反 AC-10 第 9 职责分层要求 → Code Review 阻断
- **[R-04 LLM Provider 隔离]**（映射 §九 AC-07）业务层（agents/ / workflows/ / services/）的 Python 源文件中出现 `import openai` 或其他具体 Provider SDK 的 import（未落在 infrastructure/llm/provider_adapters/ 下） → 直接违反 AC-07 → Architecture Check FAIL
- **[R-05 数据库边界红线]**（映射 §十八 AC-08）pyproject.toml 依赖中出现 mysql/psycopg/sqlalchemy/asyncpg 等任何 Java 业务数据库直连驱动，或代码中出现 `pymysql.connect()` / SQL 字符串 → 违反 AC-08 + §十八 禁止条款 → Architecture Check FAIL，并触发凭据安全复核
- **[R-06 Java 数据访问方式]**（映射 §十）AI 获取商品/SKU/订单/用户/库存数据 → 必须经过 Java API Client（HTTPX Async Client → Java Gateway / Internal API → Java Microservices）→ 任何绕过 Java API 方式立即违反 R-05
- **[R-07 写操作二次确认预留]**（映射 §十九）未来涉及取消订单/修改订单/修改用户数据等高风险写操作 → 必须经过 Agent → Tool → Java Backend API 三级链路 → Tool Schema 中预声明 `confirmation_required: true`（M0 阶段在 `standards/engineering/ai/tool-calling-standard.md` 接口级对齐，不实现真实写 Tool）
- **[R-08 凭据安全]**（映射 §七 AC-05 + DoD-24）git 跟踪文件中 grep 匹配真实 LLM API Key（sk- 前缀）、Password 明文、Access Token（长度 + 熵阈值） → 违反 AC-05 → 必须立即重置密钥并在 Evidence 中记录整改结果
- **[R-09 环境变量纪律]**（映射 §七 DoD-23）JAVA_API_BASE_URL、LLM_API_KEY 等部署/安全参数硬编码在 Python 源码字符串中 → 违反 DoD → 必须改写为 Settings 读取（环境变量 + .env）
- **[R-10 日志脱敏]**（映射 §八）Logger 输出中出现完整 LLM API Key、Access Token、Password、用户身份证/银行卡等敏感数据正则 → 违反 §八 → 修改日志格式化逻辑为脱敏掩码（前 3 + 后 4 + ***）
- **[R-11 禁止提前实现 AI 业务]**（映射 §十一/十二/十三/二十二 AC-11）`agents/` 目录中 .py 业务代码 > 1 个文件（除去 __init__.py），或 `tools/`/`workflows/`/`rag/` 中出现与 M6 业务同名的 ProductAgent/OrderAgent/RAGRetriever/LangGraphState 等 → 违反 AC-11 → 立即回退
- **[R-12 Evidence 诚信]**（映射 §二十六 末）任何未实际执行的 verify/test/run 被记录为 PASS → 违反 Evidence 要求 → 必须改为 FAIL 或补充实际执行 log 归档到 evidence/logs/ 再改 PASS
- **[R-13 Prompt 不在业务代码硬编码]**（映射 §十三）业务 Python 文件（service.py / agent.py / router.py 等）中出现以 `f"你是一个..."` 形式硬编码的 System Prompt / Prompt Template → 违反 §十三 → 必须迁移到 prompts/ 目录按 prompt-standard.md 管理

## 5. 验收标准

> 编号沿用需求文档 AC-01~AC-11（跨阶段稳定，供 task/dev DU 按号引用），每条严格 SMART：

- [ ] **AC-01 Python 版本**：仓库根 `.python-version` 文件内容精确为 `3.11`；执行 `uv run python --version` → stdout 前缀为 `Python 3.11.`（次版本号任意，Evidence 记录完整版本号）
- [ ] **AC-02 uv 依赖管理**：仓库根存在 `pyproject.toml` 与 `uv.lock`；执行 `uv sync --frozen` → 退出码 0（成功），无 error 级日志（Evidence: 同步日志 + `uv lock --check` 结果）
- [ ] **AC-03 FastAPI 可启动**：执行 `uv run uvicorn app.main:app --host 127.0.0.1 --port 8000 --log-level info` → 服务启动日志含 `Uvicorn running on http://127.0.0.1:8000`，无 ERROR/Exception；健康接口验证后 Ctrl+C 退出码 0（Evidence: 启动日志 + 进程存在性）
- [ ] **AC-04 Health API**：服务启动后执行 `curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/health` → 返回 HTTP 200；响应体 JSON 精确含 `{"service": "ai-service", "status": "UP"}`（字段名与值完全匹配，响应包装格式在设计阶段定，但此两字段语义稳定；Evidence: curl 原始响应 + 状态码）
- [ ] **AC-05 配置管理与凭据安全**：仓库根存在 `.env.example`，列出 APP_NAME / APP_ENV / APP_HOST / APP_PORT / JAVA_API_BASE_URL / LLM_PROVIDER / LLM_API_KEY / LLM_MODEL / EMBEDDING_PROVIDER / EMBEDDING_MODEL 至少 10 个配置项；对所有 git 跟踪文件执行敏感凭据扫描（sk- / Bearer / password= / secret= 等正则 + 熵阈值）→ **零命中真实密文**；`.env` 文件在 `.gitignore` 中
- [ ] **AC-06 Java API Client 基础**：代码中存在统一 Java Backend HTTP Client 基础设施模块（如 `infrastructure/java_client.py`），业务代码路径搜索 `httpx.AsyncClient(` → **仅在 infrastructure/ 目录出现**（API/Service 层无直接实例化）；Client 类初始化参数签名至少包含 base_url / timeout / default_headers / error_handler / retry_policy 五项（M0 阶段 retry_policy 可为 None，但参数位必须存在）
- [ ] **AC-07 LLM Client 基础抽象**：存在 LLM Client 抽象（Protocol / ABC / 抽象基类，文件名如 `infrastructure/llm/client.py`）与至少一个 Adapter（MockProvider ，文件名如 `infrastructure/llm/providers/mock.py`）；通过 Settings 的 `LLM_PROVIDER` 环境变量值可切换 Adapter（如 `mock` → 使用 MockProvider）；在 `agents/` 或预留的调用层代码中 grep `from openai` / `import openai` → **零命中**（或仅在 provider_adapters 内命中）
- [ ] **AC-08 AI 数据边界**：对 pyproject.toml 的 `dependencies` + `dependency-groups` 进行依赖清单检查 → **不存在** mysqlclient / pymysql / psycopg / psycopg2-binary / asyncpg / sqlalchemy / aiomysql 等任何 Java 业务数据库直连驱动；Python 源文件 grep `connect(` 带 database/user/password 参数 → **零命中**
- [ ] **AC-09 Test**：执行 `uv run pytest -q` → 全部测试 PASSED，退出码 0；测试用例数量 ≥ 3 且至少覆盖三类：① Settings 从环境变量加载（含覆盖值）② `/health` 端点 200 + JSON schema（FastAPI TestClient） ③ LLM Client 接口一致性（MockProvider 返回符合 ChatResponse Pydantic Model）（Evidence: pytest 完整终端输出）
- [ ] **AC-10 工程可维护性（目录分层）**：`find` 命令至少能定位到 9 个职责目录或文件锚点：① `app/api/`（接口）② `app/core/config.py`（配置）③ `infrastructure/`（Client 适配层，含 llm/ + java/ 两子域）④ `agents/`（Agent 扩展位）⑤ `workflows/`（Workflow 扩展位）⑥ `tools/`（Tool 扩展位）⑦ `prompts/README.md`（Prompt 管理约定）⑧ `rag/`（RAG 扩展位）⑨ `tests/`（测试）；`app/main.py` 行数统计结果 **≤ 50 行**
- [ ] **AC-11 不提前实现 AI 业务**（静态扫描）：
  - `agents/` 下所有 `.py` 文件（不含 `__init__.py`）的数量统计 = 0，或仅含 1 个占位级 `__init__.py`
  - `tools/` 下 `.py` 业务代码（`__init__.py` 除外）数量 ≤ 1 且内容仅为接口抽象（不含真实 search_products / get_product_detail / compare_products / get_order / search_knowledge 函数实现）
  - `workflows/` / `rag/` 下所有 `.py` 业务文件（排除 `__init__.py`）数量合计 = 0
  - `prompts/` 下禁止存在任何 Python Prompt Template 文件（允许 `README.md` 说明规范 + 少量 `.jinja2` 占位但 M0 建议仅放 README）
  - 代码中 grep "ProductAgent" / "OrderAgent" / "RAG" / "LangGraph" / "search_products" / "get_order" → **零命中**（注释/字符串文档中允许，需注释标注 "属 M6，M0 未实现"）

### 5.1 未知问题闭环（承接 exploration.md §4 12 条）

exploration §4 列出的 12 条"留待 PRD/设计阶段澄清"的问题，在本 PRD 阶段逐条定向决策：

| # | 未知问题（原文标题） | PRD 阶段决策 | 决策依据 / 归属章节 | 是否仍待 Design |
|---|---|---|---|---|
| 1 | repo-3 仓库根布局（ai-service/ 子层 vs 仓库根即应用根） | **仓库根 = 应用根**（pyproject.toml / app/ / agents/ ... 直接在 `implementation/ai-platform-ai-service/` 下，不套 `ai-service/` 子层） | 对齐 repo-1 "仓库根 = Maven 根"、repo-2 "仓库根 = 双应用根集合"先例 | 否 |
| 2 | uv 版本、Python 3.11 精确 patch level | Python 精确以 `.python-version=3.11`（实测 Evidence 记录）+ `requires-python=">=3.11,<3.12"`；uv 版本以 Environment Evidence 实测为准（建议 ≥ 0.4） | §三 / §四 / DoD 第 1、2 条 | 否（Evidence 阶段实测记录） |
| 3 | pyproject.toml 构建后端（hatchling vs setuptools） | 采用 **hatchling**（`build-system.requires = ["hatchling"]`，uv 官方推荐、配置简洁） | §四 "uv + pyproject.toml 为唯一依赖声明" | 否 |
| 4 | 代码质量工具组合（Ruff vs Ruff+Pyright vs Ruff+mypy vs 重复黑/蓝/isort） | **Ruff（lint + format 合并）+ Pyright（类型检查）**；彻底避免 black/isort/mypy 三工具重复 | §十六 禁止重复工具 + 社区 Python FastAPI 标配 | 否（阈值/规则集细节待 Design） |
| 5 | Java API Client 实现（lifespan 全局单例 + HTTPX + tenacity 重试） | 生命周期 lifespan startup 创建一个全局 `httpx.AsyncClient(base_url=settings.java_api_base_url, timeout=...)` 供依赖注入；Retry 策略参数在 Settings 中预声明（默认关闭，`tenacity` 库暂不引入，M0 只建 retry_policy=None 接口位，后续 Requirement 启用时引入 tenacity 并实现） | §十 Java API Client 预留 Header/TraceId/Timeout/重试 + R-06 Java 访问方式 | 是（参数与启用时机待 Design） |
| 6 | LLM Client 接口签名（complete/chat/stream/Structured Output） + Adapter 注册模式 | 接口最小签名：`chat(messages: list[ChatMessage]) -> ChatResponse`、`chat_stream(messages) -> Iterator[ChatChunk]`；预声明 `structured_chat(messages, response_model: type[BaseModel]) -> T`（M0 MockProvider 返回 pydantic 模型验证一致性即可）；Adapter 通过 Factory 根据 Settings `LLM_PROVIDER` 字符串实例化（`mock` → MockProvider） | §九 LLM 依赖方向图 + R-04 Provider 隔离 | 是（具体 Adapter 命名与 M6 新 Provider 注册流程待 Design） |
| 7 | FastAPI 异常错误码体系（是否与 Java 侧对齐） | 五类异常 → 统一错误码前缀 `AI-<CATEGORY>-NNN`：PARAM(001-099) / CONFIG(101-199) / JAVA_API(201-299) / LLM_PROVIDER(301-399) / SYSTEM(901-999)；与 Java 侧（`product/10-API与事件契约.md`）的 REST 响应外层结构保持一致（`{code, message}` 双字段），但前缀独立 `AI-` 以一眼区分来源 | §十四 异常分类 + standards/engineering/api-standard.md 响应包裹 | 是（NNN 具体分配与响应 JSON 最终形状待 Design） |
| 8 | Log Middleware vs lifespan、TraceId Header 名、uvicorn 日志重叠 | 方案：Starlette Middleware 做请求日志 + TraceId 注入；Header 名统一 `X-Trace-Id`（与 Java Gateway 对齐）；Middleware 从 Request 读 Header，缺失时自动生成 UUID；`logging.Filter` 把 TraceId 注入 LogRecord；Java API Client / LLM Client 发出的 HTTPX 请求 headers 自动带 `X-Trace-Id`；uvicorn 通过 `log_config=None` 关闭默认 access log，由 Logging dictConfig 统一配置 + Middleware 写 access 日志 | §八 TraceId 扩展 + §十 Java Client Header TraceId + Instruction architecture-principles §分层 | 是（dictConfig 具体 format 字符串待 Design） |
| 9 | Prompt 管理最小约定（是否建空模板 vs 仅 README） | `prompts/` 目录仅创建：① `README.md`（引用 `standards/engineering/ai/prompt-standard.md` 总规范：System Prompt / Template / Version / 参数化四项说明 + 禁止业务代码硬编码）② `.gitkeep`（若需要）；**不创建任何实际业务 Prompt Template 文件（.jinja2 / .yaml / .py）** | §十三 M0 只建管理约定不提前创建 + R-13 | 否 |
| 10 | Pytest 范围与最低测试数、是否引入 coverage | ≥ 3 个用例（Settings 单元 / Health 集成 / LLM 接口一致性）；`uv run ruff check` + `uv run pyright` 必须同样可执行并通过；**Coverage 不强制（M0 仅骨架，避免为凑覆盖率写水测）**，但须 Evidence 记录三项工具的实际退出码与日志 | §十五 Pytest 基础 + §十六 代码质量四能力（检查/格式/类型/测试） | 是（Pyright 严格级别 / Ruff 具体规则 / 三项命令最终脚本名待 Design） |
| 11 | Ruff / Pyright 配置位置（pyproject.toml 集中 vs 拆多文件） | **全部集中在 pyproject.toml**：`[tool.ruff]`（lint + format 两部分）、`[tool.pyright]` 两 config 段；不拆 ruff.toml / pyrightconfig.json 多文件 | §四 "pyproject.toml 是唯一依赖声明"的统一管理精神 | 否 |
| 12 | HTTPX / uvicorn access log 重复 | 采用 R-08 条的 Middleware + uvicorn `log_config=None` 方案（见 #8）；统一由 Python `logging.basicConfig` / dictConfig 接管，避免两套日志系统各自输出 | §八 日志基础 + #8 决策 | 否 |

> 上表"仍待 Design"的 6 项（#5/#6/#7/#8/#10）已在 PRD 中给出**方向/范围/约束**，但实现细节（参数值、具体规则集、错误码具体编号、配置具体内容）留到 design.md 阶段，不影响本 PRD §5 验收标准的可测试性。
