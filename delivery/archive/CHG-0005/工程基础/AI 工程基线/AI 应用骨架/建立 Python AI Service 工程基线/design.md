---
affected-repositories: [repo-3] # Phase 2.4：受影响仓库 id 列表（对应 .sdd/repositories.yaml）。本变更仅落在 repo-3（Python AI Service 新仓），repo-1/2 零回退（exploration §3 + PRD §3.2 Out）。
---

# Design

> 阶段：sdd-design 产物
> 输入：CHG-0005/prd.md + exploration.md + requirements(REG-M0-003.md) + standards/*
> 产出状态：designed

本文档制定 AI Service 工程基线的技术方案。

**职责边界（硬约束）**：Design 回答「系统如何实现、哪些仓受影响、跨仓如何协作」；**不产生正式交付单元**（DU-XXX 编号不得出现；正式拆分是 sdd-task 的职责，本文 §8 仅保留 Requirement 建议的任务域到章节映射表，供 task 阶段对齐）。

## 0. 元信息

- Change ID: CHG-0005
- PRD 来源: `delivery/changes/CHG-0005/工程基础/AI 工程基线/AI 应用骨架/建立 Python AI Service 工程基线/prd.md`（STORY 四级目录）
- 状态流转: specified → designed
- 涉及仓库：repo-3（`implementation/ai-platform-ai-service`，远程 https://github.com/ws481634399/ai-platform-AIService.git）
- 受影响仓库数：1
- 是否需 Migration：no
- **PRD §5.1 六项"待 Design 事项"的决策映射**（本设计交付的核心增量，对应 PRD 闭环表 6 项「待 Design」）：
  1. **Java API Client 参数签名与 Retry**（PRD §5.1 #5）：见 §2.9 `JavaAPIClient.__init__` 四扩展参数位（http_client / settings / retry_policy=None / headers 扩展）、M0 默认关闭 retry，Settings 预声明 `JAVA_API_RETRY_ENABLED=False`，tenacity 暂不引入
  2. **LLM Adapter 注册模式与接口签名**（PRD §5.1 #6）：见 §2.8 `LLMClient(ABC)` `chat/chat_stream/structured_chat` 三个签名 + ChatMessage/ChatResponse/ChatChunk Pydantic Models + `PROVIDER_REGISTRY` dict 工厂注册（M6 新增 Provider = 追加 entry + 文件）
  3. **错误码 NNN 具体分配 + 响应 JSON 形状**（PRD §5.1 #7）：见 §2.5 `AI-<CAT>-NNN` 分类前缀 + 首码分配表（PARAM 001/002；CONFIG 101/102；JAVA_API 201/202；LLM 301/302/303；SYSTEM 901）+ 响应 UnifyResult 5 字段包裹 `{success, code, message, data, traceId}`（与 Java 侧一致）
  4. **Logging dictConfig / TraceId Middleware / X-Trace-Id 注入位置**（PRD §5.1 #8）：见 §2.7 `LOG_FORMAT` 最终字符串 + TraceIdFilter(contextvar) + Starlette Middleware（access log 接管）+ uvicorn `log_config=None`；Java/LLM 两端 HTTPX 请求均在 `_request` 内部从 trace_id_var 读取并 setdefault Header
  5. **Ruff / Pyright 规则集 + 命令名**（PRD §5.1 #10）：见 §2.10 pyproject.toml 三段配置（`[tool.ruff]` + `[tool.ruff.lint]` select=10 规则集 + `[tool.ruff.format]` 双引号 + `[tool.pyright]` typeCheckingMode=strict）；命令约定：`ruff check / ruff format / pyright / pytest / uvicorn`
  6. **Lifespan 启动顺序（5+6+7+8+10 关联）**（PRD §5.1 关联项）：见 §2.4 5 步顺序 `Settings → Logging → Java HTTPX → LLM Factory → Depends`，shutdown 侧 `aclose()` 两个 HTTPX 客户端

## 1. 当前状态

**repo-3 为空仓库**（main 分支，零提交零代码），在 CHG-0005 explore 阶段才首次登记到 `.sdd/repositories.yaml`。因此本设计是**从零初始化**（与 CHG-0004 前端基线同构：无迁移负担、无兼容性问题，方案完全由规范 + 需求推导）。

### 1.1 工程上下文

| 上下文维度 | 现状 | 设计必须遵守的约束 |
|---|---|---|
| **仓库布局** | repo-3 空仓（main） | 根 = 应用根（PRD §5.1 #1 决策）；不套 `ai-service/` 子层 |
| **版本基线** | M0 尚未装任何 Python 工具链 | `.python-version=3.11` + `requires-python=">=3.11,<3.12"`；uv + hatchling build backend（PRD #2 #3） |
| **AI 规范体系** | `standards/engineering/ai/` 六篇规范（exploration 知识检索注入） | prompt/tool-calling/agent-framework/rag/llm-integration/evaluation 六文档必须在各自边界位目录 README 中引用 |
| **架构原则** | `standards/engineering/architecture-principles.md` §分层 §接口边界 §一致性 §测试四原则 | 三层（api → service → infrastructure）+ 依赖倒置 + TestClient 最小验证 |
| **编码规范** | `standards/engineering/coding-standard.md`（Java 侧 §1-14） | Python 侧 M0 先按需求 §十六 + §2.10 Ruff/Pyright 落实；Python 编码规范在 converge 阶段升规（不阻塞本次 Design） |
| **API 响应契约** | `standards/engineering/api-design-standard.md` + CHG-0003 §2.3 UnifyResult + X-Trace-Id | 异常/正常响应 5 字段包裹 + `X-Trace-Id` Header 名统一 |
| **Java 网关锚点** | CHG-0003 分配 mall-gateway=8080（CHG-0001 配置） | Settings `JAVA_API_BASE_URL=http://localhost:8080` 作为默认值 |
| **repo-1 / repo-2** | Java + 前端基线均已交付（CHG-0001~0004 归档） | repo-1 / repo-2 **零修改**（§3 仓库影响明确；跨仓仅为 HTTP 运行时调用关系，不产生代码改动） |
| **PRD 13 条业务规则** | R-01~R-13（条件→结果） | 每条规则在 §2 有设计落点（R-01 版本锁死 → §2.3；R-05 DB 红线 → §2.2 无 DB 依赖 + §5 Migration=no；R-11 禁提前实现 → §2.2 边界位仅 __init__.py/README） |
| **PRD 11 条 SMART AC** | AC-01~AC-11（与 REG-M0-003 编号保持一致） | §2 各节明确标注 AC 归属（AC-01 → §2.3；AC-02 → §2.3；AC-04 → §2.5；AC-05 → §2.6；AC-06 → §2.9；AC-07 → §2.8；AC-08 → §5 no；AC-09 → §2.11；AC-10 → §2.2 9 锚点 + main.py ≤50 行；AC-11 → §2.2 边界位结构约束） |

### 1.2 架构红线必须以代码形式落地（对应 §1 背景）

REG-M0-003 §十八 / §十九 / §二十二 三项架构红线，在 Design 中转化为以下**可量化的结构设计**，不靠人工自觉：

1. **禁直连 DB（AC-08）** → §2.3 依赖清单**不含任何 Python DB Driver**（Architecture Check = `grep` pymysql/psycopg/sqlalchemy/asyncpg → 零命中）；§5 Migration=no
2. **写操作二次确认预留** → §2.9 Java Client 预留 `confirmation_required=true` 参数扩展位；§2.2 tools/ 目录 README 引用 `tool-calling-standard.md` 明确 schema 字段
3. **Provider 依赖倒置（AC-07）** → §2.8 `PROVIDER_REGISTRY` + 抽象基类；Architecture Check：`grep -rn "from openai" app/ agents/ services/` → 零命中（仅 infrastructure/llm/providers 允许）

## 2. 提议方案

### 设计原则落地

- **单一职责**：根配置 / app/（主应用）/ 6 个业务边界位目录各司其职；`main.py` 仅负责装配（≤50 行，AC-10）
- **开闭原则**：LLM Provider 注册（PROVIDER_REGISTRY 追加即支持新 Provider）；Java API Retry 扩展位（settings.JAVA_API_RETRY_ENABLED 打开即引入 tenacity，无需改业务）；Logger Filter 链式扩展
- **依赖倒置**：Service / API 层 → LLMClient(ABC) → Provider Adapter → SDK；Service / API → JavaAPIClient(Facade) → HTTPX Impl；高层不依赖具体 SDK
- **复用优先**：复用 pydantic-settings 官方；httpx AsyncClient 连接池（单例复用）；Starlette 生态 middleware；pytest ASGI TestClient 模式。不造自定义容器 / 不重复造 HTTP Client / 不重复造 format 工具（Ruff 合并 black+isort）

### 2.1 方案概要

**单仓单应用 FastAPI 分层骨架**：repo-3 根即应用根，目录组织满足 AC-10 要求的 9 个职责锚点 + 6 个边界位目录。基线 = Lifespan 启动五部曲（§2.4）+ Health API（§2.5）+ 全局异常处理（UnifyResult 包裹 + `AI-*-NNN` 错误码）+ 日志/TraceId 全链路（§2.7）+ LLM 抽象 + MockProvider + Factory（§2.8）+ Java HTTPX 封装（§2.9）+ Ruff/Pyright 集中配置（§2.10）+ Pytest 三用例（§2.11）+ 凭据/环境/.gitignore 安全（§2.6）。

### 2.2 工程目录结构（深度 ≤ 3，锚点 AC-10 9 职责位）

```
ai-platform-ai-service/                 # repo-3 仓库根 = 应用根（PRD §5.1 #1 决策）
├── .gitignore                          # 屏蔽：.venv/ .env __pycache__/ .pytest_cache/ dist/ .ruff_cache/ *.pyc
├── .python-version                     # 精确内容 "3.11"（AC-01 精确匹配）
├── pyproject.toml                      # 构建系统 + 全部依赖 + [tool.ruff] / [tool.pyright] / [tool.pytest]（PRD §5.1 #11 全部集中）
├── uv.lock                             # 提交 Git；唯一版本权威（=前端 pnpm-lock.yaml 同构角色）
├── .env.example                        # 10+ 配置变量清单（AC-05）
├── README.md                           # 快速开始：uv sync → uv run uvicorn app.main:app → curl /health
│
├── app/
│   ├── main.py                         # FastAPI 装配入口；≤50 行（AC-10）；lifespan + include_router + exception_handler
│   ├── api/
│   │   ├── __init__.py
│   │   └── v1/
│   │       ├── __init__.py
│   │       └── health.py               # APIRouter /health → 200 {"service":"ai-service","status":"UP"}（AC-04）
│   │
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py                   # Settings(BaseSettings)：13 项配置（§2.6 表格）
│   │   ├── exceptions.py               # AIBaseException + 5 个子类（PARAM/CONFIG/JAVA_API/LLM_PROVIDER/SYSTEM）
│   │   └── logging.py                  # setup_logging(settings) → dictConfig + TraceIdFilter + uvicorn log 接管
│   │
│   ├── middleware/
│   │   ├── __init__.py
│   │   └── trace_logging.py            # TraceIdMiddleware（X-Trace-Id 读/生成/写响应头 + access log 记录）
│   │
│   ├── services/                       # Service 层（M0 仅占位空 + AC-06/07 的间接调用层，M6 业务 Service 在此扩展）
│   │   └── __init__.py
│   │
│   └── infrastructure/                 # 具体外部依赖适配层（所有 SDK / HTTP 调用必须在此；Service 不能越过）
│       ├── __init__.py
│       ├── java/
│       │   ├── __init__.py
│       │   └── client.py               # JavaAPIClient(Facade)：HTTPX 封装 + 四扩展参数位 + X-Trace-Id 透传 + retry 位
│       └── llm/
│           ├── __init__.py
│           ├── client.py               # LLMClient(ABC) 抽象 + ChatMessage/ChatResponse/ChatUsage/ChatChunk Pydantic Models
│           ├── factory.py              # LLMClientFactory.create(settings) → 查 PROVIDER_REGISTRY
│           └── providers/
│               ├── __init__.py
│               └── mock.py             # MockProvider(LLMClient)：echo mock 验证依赖倒置方向（AC-07）
│
├── agents/                             # 边界位（M6 Agent；M0 仅 __init__.py + README.md：引用 agent-framework-standard.md + "禁止提前写业务"警告）
├── workflows/                          # 边界位（M6 LangGraph；M0 仅 .gitkeep）
├── tools/                              # 边界位（M6 Tool Calling；M0 仅 __init__.py + README.md：引用 tool-calling-standard.md + confirmation_required 字段约定）
├── prompts/
│   ├── README.md                       # 引用 prompt-standard.md：System/Template/Version/参数化四项说明 + 禁业务代码硬编码 Prompt
│   └── .gitkeep
├── rag/                                # 边界位（M6 RAG；M0 仅 .gitkeep + README.md：引用 rag-standard.md + vector-db 归属说明）
│
└── tests/
    ├── __init__.py
    ├── conftest.py                     # fixtures: app/ (test Settings) + client(ASGI TestClient) + test_settings_override
    ├── test_settings.py                # ① test_settings_load_from_env → AC-09
    ├── test_health_endpoint.py         # ② test_health_endpoint_ok /health 200 + JSON Schema → AC-09
    └── test_llm_client.py              # ③ test_llm_client_mock_returns_structured_response → AC-09
```

**AC-10 验收映射**：9 个职责锚点 = `app/api/` + `app/core/config.py` + `infrastructure/`（内含 `llm/` + `java/` 两子域） + `agents/` + `workflows/` + `tools/` + `prompts/README.md` + `rag/` + `tests/`（全部 9 项在上面目录树中存在）。`app/main.py` 行数**设计目标 ≤ 40 行**（预留 buffer 到 50 行上限）。

**AC-11 边界位业务量约束映射**：`agents/__init__.py` 与 `tools/__init__.py` 内容 = 模块 docstring 引用标准文档 + 导出名（不超过 15 SLOC）；`workflows/` / `rag/` M0 **只含 `.gitkeep` / README.md，不含任何 `.py` 业务文件**。grep "ProductAgent / OrderAgent / search_products" → 0 命中（注释/字符串文档中允许说明"属 M6，M0 未实现"）。

### 2.3 技术栈与版本策略

| 类别 | 选型 | 精确版本 | 设计依据 / 关联 AC |
|---|---|---|---|
| 语言 | **CPython 3.11** | `.python-version=3.11`；`requires-python=">=3.11,<3.12"`（patch 任意） | PRD §5.1 #2 + AC-01 |
| 构建后端 | **hatchling** | `build-system.requires = ["hatchling>=1.24"]`（uv 原生推荐） | PRD §5.1 #3 |
| 依赖管理 | **uv** | Evidence 实测记录（≥ 0.4，精确以 Environment Evidence 为准） | PRD §3.1 In-1 / AC-02 |
| Web 框架 | **FastAPI** | 0.115+（含 Pydantic v2）；uvicorn[standard] 为 async worker | §六 FastAPI HTTP 应用基础 / AC-03 |
| 配置 | **pydantic-settings 2.x** + python-dotenv | `pip install pydantic-settings`；自动 `model_config = SettingsConfigDict(env_file=".env", extra="ignore")` | §七 Config / AC-05 |
| HTTP Client | **httpx[http2]** | 0.27+（M0 默认 HTTP/1.1，http2 可开；AsyncClient 连接池复用） | §九 Java API / §十 LLM Provider 通信 |
| LLM Provider 抽象 | **ABC + Pydantic** | 仅 M0 内定义（零外部 SDK；M6 按需在 dependency-groups.llm-<name> 中引） | §九 / AC-07 |
| 测试 | **pytest 8.x** + httpx ASGI Transport | `dependency-groups.dev = ["pytest>=8", "httpx>=0.27"]` | §十五 / AC-09 |
| 质量：Lint + Format | **Ruff**（合并替代 black + isort + flake8） | 0.6+；`select=["E","F","I","N","W","UP","B","A","SIM","RUF"]`（10 规则子集） | §十六 禁止重复工具 / PRD §5.1 #4（Ruff+Pyright） |
| 质量：类型检查 | **Pyright** | 1.1+；`typeCheckingMode="strict"`；reportMissingTypeStubs=false | §十六 / PRD §5.1 #4 |
| 版本权威 | **uv.lock 提交 Git** | | 对齐前端 pnpm-lock.yaml 、后端 mall-bom（唯一权威） |
| Python 源策略 | PyPI 默认 | 失败时在 Evidence 记录；用户侧可通过 `UV_INDEX_URL` env 切换镜像，不写死 | 与 CHG-0004 `.npmrc` 同构：保持灵活，不锁死远程 |

### 2.4 Lifespan 启动事件顺序（解决 PRD 5+6+7+8+10 关联）

```
app = FastAPI(lifespan=lifespan)

async def lifespan(app: FastAPI):
    # ── startup ──────────────────────────────────────────────────────
    # 1️⃣ Settings（优先：保证后续步骤全部用配置）
    settings = Settings()                             # 读 env + .env；Pydantic 自动类型校验；必填缺失 → AI-CONFIG-102 直接抛
    app.state.settings = settings

    # 2️⃣ Logging（在任何 Logger 被实例化前完成；接管 uvicorn → log_config=None 配合 uvicorn.run 参数）
    setup_logging(settings)                           # dictConfig + TraceIdFilter + LOG_FORMAT

    # 3️⃣ Java HTTPX AsyncClient（连接池复用 + lifespan 保证关闭）
    java_http = httpx.AsyncClient(
        base_url=settings.JAVA_API_BASE_URL.rstrip("/"),
        timeout=httpx.Timeout(settings.JAVA_API_TIMEOUT, connect=3.0),
    )
    retry_policy = None  # M0：settings.JAVA_API_RETRY_ENABLED=False → None；M6 打开 → tenacity.AsyncRetrying(...)
    java_client = JavaAPIClient(http_client=java_http, settings=settings, retry_policy=retry_policy)
    app.state.java_http_client = java_http
    app.state.java_client       = java_client

    # 4️⃣ LLM Client（Factory 按 settings.LLM_PROVIDER 查 PROVIDER_REGISTRY）
    llm_client = LLMClientFactory.create(settings)    # 未知 provider → 抛 AI-CONFIG-102
    app.state.llm_client = llm_client

    yield

    # ── shutdown ─────────────────────────────────────────────────────
    await java_http.aclose()
    # LLM 适配器如果持有内部 HTTPX session（M6 真实 Provider 会），调其 close 方法；Mock 无资源
    close_fn = getattr(llm_client, "aclose", None)
    if close_fn:
        await close_fn()
```

→ 依赖注入（Depends）在 API 层：`get_settings` / `get_java_client` / `get_llm_client` 三个函数，统一从 `request.app.state.*` 取，保证与 lifespan 实例一致。

### 2.5 API 契约 + 全局异常响应形状（PRD §5.1 #7 错误码决策）

#### 2.5.1 v1 Router 结构

| 端点 | 归属模块 | 入参 | 出参（HTTP 200） |
|---|---|---|---|
| `GET /health` | `app/api/v1/health.py` | 无 | `{"service":"ai-service","status":"UP"}`（AC-04 精确字段名+值；不套 UnifyResult，与 infra/health 其他服务一致） |
| `/api/v1/*` | `app/api/v1/__init__.py`（M0 仅占位 include 入口；无业务路由） | 由 M6 AI 业务定义 | 统一使用 UnifyResult 包裹（`success=true, code="AI-OK", message="", data=..., traceId`） |

#### 2.5.2 全局异常响应（UnifyResult 包裹，对齐 Java 侧契约）

```jsonc
// 异常响应（任何 AIBaseException 触发；其他未预期 Exception → AI-SYSTEM-901 兜底）
{
  "success": false,
  "code": "AI-PARAM-001",         // AI-<CATEGORY>-NNN 格式（见下表）
  "message": "参数验证失败：name 字段缺失",
  "data": null,
  "traceId": "550e8400-e29b-41d4-a716-446655440000"  // 来自 Middleware 的 X-Trace-Id
}
```

#### 2.5.3 错误码 NNN 首码分配（PRD §5.1 #7 闭环）

| Category | 范围 | 首码（M0 实际使用） | 示例语义 |
|---|---|---|---|
| **PARAM**（请求参数类） | 001–099 | `AI-PARAM-001` 字段缺失；`AI-PARAM-002` 字段格式非法（enum/pydantic type error） | 由 FastAPI RequestValidationError → 全局 Handler 统一映射 |
| **CONFIG**（配置类） | 101–199 | `AI-CONFIG-101` .env 文件损坏（Pydantic ValidationError on startup）；`AI-CONFIG-102` 必填项缺失 / 未知 LLM_PROVIDER（Factory create fail） | 启动时 / Factory 时抛出 |
| **JAVA_API**（Java 调用失败） | 201–299 | `AI-JAVA_API-201` 5xx / 连接超时 / DNS 失败（Java 基础不可用）；`AI-JAVA_API-202` Java 业务返回非 success=true（解析原 UnifyResult 的 code/message 引用到 message 原文） | 由 JavaAPIClient._request 统一抛出 |
| **LLM_PROVIDER**（Provider 失败） | 301–399 | `AI-LLM_PROVIDER-301` 超时；`AI-LLM_PROVIDER-302` 鉴权失败（401/403）；`AI-LLM_PROVIDER-303` 速率限制（429） | 由各 Provider Adapter 捕获原生异常后转换 |
| **SYSTEM**（兜底） | 901–999 | `AI-SYSTEM-901` 未预期异常（Python 原生 Exception → 捕获后统一） | 兜底 Handler 中使用 |

→ 所有异常响应中 **不包含 Python Traceback**（日志中保留详细堆栈；HTTP 响应仅返回可对外暴露的 code/message/traceId 三要素）。

### 2.6 Settings 与环境变量（Scope In-3 + AC-05）

```python
# app/core/config.py
from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore", env_file_encoding="utf-8")

    APP_NAME:              str  = "ai-service"
    APP_ENV:               str  = "development"        # development/staging/production
    APP_HOST:              str  = "0.0.0.0"
    APP_PORT:              int  = 8000                 # 本地默认 AI Service 端口
    LOG_LEVEL:             str  = "INFO"               # Python logging level
    JAVA_API_BASE_URL:     str  = "http://localhost:8080"  # mall-gateway（CHG-0001/3）
    JAVA_API_TIMEOUT:      float = 10.0                # 秒
    JAVA_API_RETRY_ENABLED:bool = False                # M0 关闭；M6 开 → 引入 tenacity
    LLM_PROVIDER:          str  = "mock"               # 仅 mock；M6 在 Factory 中扩展 literal
    LLM_API_KEY:           SecretStr | None = None     # Pydantic SecretStr：dump 时自动脱敏
    LLM_MODEL:             str  = "mock-model"
    EMBEDDING_PROVIDER:    str  = "mock"               # M0 占位（RAG 用）
    EMBEDDING_MODEL:       str  = "mock-embedding"
```

**AC-05 凭据安全映射**：

1. `.env.example` 列出 13 项变量（与上表字段名 1:1），示例值全部为 `changeme` / `"http://localhost:8080"` 等占位，**不含任何真实凭据**
2. `.env` 文件在 `.gitignore` 中；LLM_API_KEY / Password / Token 任何真实密文不得进入 git 跟踪文件
3. 敏感字段类型：`LLM_API_KEY` = `SecretStr`（`.get_secret_value()` 才取明文；日志 `%s` 输出显示为 `SecretStr('**********')`）
4. Settings Credentials Scan：dev 阶段 Architecture Check = grep 跟踪文件中 `sk-` 前缀 + `password=` / `secret=`（高熵正则）→ 0 命中（AC-05 第二要求）

### 2.7 Logging / TraceId / uvicorn 日志接管（PRD §5.1 #8 闭环）

#### 2.7.1 dictConfig 格式最终字符串

```python
# app/core/logging.py
LOG_FORMAT    = "%(asctime)s | %(levelname)-7s | trace_id=%(trace_id)s | %(name)s | %(message)s"
DATE_FORMAT   = "%Y-%m-%d %H:%M:%S"
FILTER_MASKED = [r"sk-[A-Za-z0-9]{20,}", r"(?i)(password|token|secret)(=|:)[^\s,;&\"]{4,}"]  # 正则替换为 ***
```

- TraceId 存储：`contextvars.ContextVar("trace_id", default="-")`
- `TraceIdFilter(logging.Filter)`：从 ContextVar 读 trace_id → 注入 LogRecord.trace_id
- **脱敏 Filter**：`record.getMessage()` 后对 FILTER_MASKED 正则逐一 `re.sub(..., "***")`

#### 2.7.2 TraceIdMiddleware（Starlette BaseHTTPMiddleware）

```
请求进入：
  1. trace_id = request.headers.get("X-Trace-Id") or uuid4().hex
  2. token = trace_id_var.set(trace_id)   # 绑定到当前 asyncio task 的 contextvar
  3. 调用 await self.call_next(request) → response
  4. response.headers["X-Trace-Id"] = trace_id
  5. 记录 access 日志：METHOD PATH STATUS DURATION(ms) trace_id=...（接管 uvicorn 默认 access log）
  6. trace_id_var.reset(token)
```

→ **uvicorn log 接管**：`uvicorn.run(app, host=..., port=..., log_config=None)`（关闭 uvicorn 默认 dictConfig）；uvicorn 内置 logger（`uvicorn`, `uvicorn.error`, `uvicorn.access`）在 `setup_logging` 中按自定义 handlers/formatters 重新分配（继承 trace_id 注入 + 脱敏）。最终 **所有日志 = 一套 format，不存在两套日志系统并存**。

#### 2.7.3 HTTPX 出站 X-Trace-Id 注入

```python
# JavaAPIClient._request  &  LLM Provider Adapter._http_call（统一模式）
headers.setdefault("X-Trace-Id", trace_id_var.get("-"))
headers.setdefault("X-Request-Source", "ai-service")
```

→ 跨仓一致性：Java 侧 `X-Trace-Id` 被 Spring Cloud Gateway（mall-gateway）识别并透传到下游；Java 业务日志的 traceId 列与 AI 日志 traceId 列值相同。

### 2.8 LLM Client 抽象 + Adapter 注册模式（PRD §5.1 #6 闭环）

```python
# ── infrastructure/llm/client.py ──────────────────────────────────
from abc import ABC, abstractmethod
from collections.abc import AsyncIterator
from enum import Enum
from typing import Generic, TypeVar
from pydantic import BaseModel, Field

T = TypeVar("T", bound=BaseModel)

class ChatMessageRole(str, Enum):
    SYSTEM    = "system"
    USER      = "user"
    ASSISTANT = "assistant"
    TOOL      = "tool"

class ChatMessage(BaseModel):
    role:    ChatMessageRole
    content: str
    name:    str | None = None

class ChatUsage(BaseModel):
    prompt_tokens:     int = 0
    completion_tokens: int = 0

class ChatResponse(BaseModel):
    message:            ChatMessage
    usage:              ChatUsage = Field(default_factory=ChatUsage)
    model:              str
    provider_trace_id:  str | None = None

class ChatChunk(BaseModel):
    delta_content: str
    finish_reason: str | None = None

class LLMClient(ABC):
    @abstractmethod
    async def chat(self, messages: list[ChatMessage], **kwargs) -> ChatResponse: ...

    @abstractmethod
    async def chat_stream(self, messages: list[ChatMessage], **kwargs) -> AsyncIterator[ChatChunk]: ...

    @abstractmethod
    async def structured_chat(self, messages: list[ChatMessage], response_model: type[T], **kwargs) -> T: ...

# ── infrastructure/llm/providers/mock.py ──────────────────────────
class MockProvider(LLMClient):
    def __init__(self, settings: Settings):
        self._settings = settings

    async def chat(self, messages, **kwargs):
        last = messages[-1].content if messages else ""
        return ChatResponse(
            message=ChatMessage(role=ChatMessageRole.ASSISTANT, content=f"[mock echo] {last}"),
            model=self._settings.LLM_MODEL,
        )
    async def chat_stream(self, messages, **kwargs):
        yield ChatChunk(delta_content="[mock echo] ", finish_reason=None)
        yield ChatChunk(delta_content=(messages[-1].content if messages else ""), finish_reason="stop")
    async def structured_chat(self, messages, response_model: type[T], **kwargs) -> T:
        # 构造 response_model 默认实例（或 dict 全部走默认值）→ validate 返回
        sample = {f: ... for f in response_model.model_fields}  # 按各字段类型填充 mock 值（实现略）
        return response_model.model_validate(sample)

# ── infrastructure/llm/factory.py ─────────────────────────────────
PROVIDER_REGISTRY: dict[str, type[LLMClient]] = {
    "mock": MockProvider,
    # M6 Provider 接入 = ① 建 providers/<name>.py ② 在这里 append entry ③ 依赖在 pyproject [dependency-groups.llm-<name>]
}

class LLMClientFactory:
    @staticmethod
    def create(settings: Settings) -> LLMClient:
        key = settings.LLM_PROVIDER.lower()
        if key not in PROVIDER_REGISTRY:
            raise AIConfigException("AI-CONFIG-102", f"未知 LLM_PROVIDER={settings.LLM_PROVIDER}；已注册: {list(PROVIDER_REGISTRY)}")
        return PROVIDER_REGISTRY[key](settings)
```

**AC-07（LLM 依赖方向）映射**：在 `app/` / `agents/` / `services/` / `tools/` 等业务代码中 `grep -rn "from openai" "import anthropic"` → 零命中；具体 Provider SDK 只能在 `infrastructure/llm/providers/<name>.py` 中出现。M0 验证路径：AC-09 第 3 用例 `test_llm_client_mock_returns_structured_response` 中，通过 Factory.create 拿到 MockProvider 并断言返回的 `ChatResponse.message.role == ASSISTANT`（验证接口一致性）。

### 2.9 Java API Client 封装（PRD §5.1 #5 闭环）

```python
# infrastructure/java/client.py
from app.core.config import Settings
from app.core.exceptions import AIJavaAPIException
from app.core.logging import trace_id_var  # 导出的 contextvar

class JavaAPIClient:
    """Java 业务数据唯一入口（架构红线强制所有 Java 数据访问经此）。
    M0 不实现 ProductClient / OrderClient 等业务方法（§二十二 Scope Out），仅实现统一 _request 入口与 4 个扩展位签名。
    """
    def __init__(self,
                 *,
                 http_client: "httpx.AsyncClient",   # lifespan 注入的全局单例（连接池复用）
                 settings:    Settings,              # 提供 base_url / timeout / retry_enabled
                 retry_policy = None,                # PRD §5.1 #5：M0 = None；M6 → tenacity.AsyncRetrying(...)
                 extra_default_headers: dict[str,str] | None = None):  # 未来加 Authorization 等
        self._http     = http_client
        self._settings = settings
        self._retry    = retry_policy
        self._default_headers = {"X-Request-Source": "ai-service"} | (extra_default_headers or {})

    async def _request(self, method: str, path: str, **kwargs) -> Any:
        """统一请求入口。所有未来的业务方法都必须调用本方法，不得直接 self._http.request。"""
        headers = (kwargs.pop("headers", None) or {}) | self._default_headers
        tid = trace_id_var.get("-")
        headers.setdefault("X-Trace-Id", tid)  # 全链路 TraceId 透传（§2.7.3）
        kwargs["timeout"] = kwargs.get("timeout") or self._settings.JAVA_API_TIMEOUT

        async def _do():
            try:
                resp = await self._http.request(method, path, headers=headers, **kwargs)
            except (httpx.NetworkError, httpx.TimeoutException) as exc:
                raise AIJavaAPIException("AI-JAVA_API-201", f"Java API 不可达: {exc.__class__.__name__}") from exc
            if resp.status_code >= 500:
                raise AIJavaAPIException("AI-JAVA_API-201", f"Java 服务端错误: HTTP {resp.status_code}")
            body = resp.json()
            if resp.status_code >= 400 or (isinstance(body, dict) and body.get("success") is False):
                raise AIJavaAPIException("AI-JAVA_API-202",
                    f"Java 业务失败: code={body.get('code')}, message={body.get('message')}",
                )
            return body.get("data") if isinstance(body, dict) else body

        if self._retry is not None:
            async with self._retry:
                return await _do()
        return await _do()

    # ── M0 预留业务方法占位（注释形式，保证 IDE grep 能定位；非真实实现）──
    # 未来 M6 ProductClient 实现示例（仅作锚点引用，不产生代码）：
    # async def get_product(self, product_id: str) -> ProductDTO:
    #     data = await self._request("GET", f"/api/v1/products/{product_id}")
    #     return ProductDTO.model_validate(data)
    #
    # Tool Calling 二次确认占位（confirmation_required=true schema 引用；见 tools/README.md + R-07）：
    # async def cancel_order(self, order_id: str, *, confirmation: bool) -> CancelOrderResp:
    #     if not confirmation:
    #         raise AIParamException("AI-PARAM-001", "取消订单需二次确认(confirmation_required=true)")
    #     return await self._request("POST", ...)
```

**AC-06（Java Client 边界）映射**：`grep -rn "httpx.AsyncClient("` → 仅在 `infrastructure/java/client.py`（本文件）+ lifespan 注入处 两处命中；`app/api/` / `app/services/` / `agents/` / `tools/` → 零直接实例化。参数签名包含 `base_url` 注入（self._settings.JAVA_API_BASE_URL）、`timeout`、`default_headers`、`error_handler`（AI-JAVA_API-201/202 映射）、`retry_policy`（关闭）五项扩展位。

### 2.10 Ruff / Pyright 集中配置（PRD §5.1 #10 + #11 闭环）

**全部集中在 pyproject.toml**（PRD §5.1 #11 决策；不拆 ruff.toml / pyrightconfig.json 多文件）：

```toml
# pyproject.toml
[build-system]
requires      = ["hatchling>=1.24"]
build-backend = "hatchling.build"

[project]
name            = "ai-platform-ai-service"
version         = "0.1.0"
description     = "AI Platform AI Service (FastAPI + uv) – M0 Engineering Baseline"
requires-python = ">=3.11,<3.12"
dependencies = [
  "fastapi>=0.115",
  "uvicorn[standard]>=0.30",
  "pydantic-settings>=2.4",
  "python-dotenv>=1.0",
  "httpx[http2]>=0.27",
  "starlette>=0.38",
]

[dependency-groups]
dev = [
  "pytest>=8",
  "pytest-asyncio>=0.23",
  "ruff>=0.6",
  "pyright>=1.1.370",
]

[tool.ruff]
line-length    = 120
target-version = "py311"

[tool.ruff.lint]
select   = ["E", "F", "I", "N", "W", "UP", "B", "A", "SIM", "RUF"]
ignore   = ["E501"]   # line-length 由 formatter 管
fixable  = ["ALL"]

[tool.ruff.format]
quote-style  = "double"   # 与前端 Prettier singleQuote=false（双引号）保持跨栈同构
indent-style = "space"
indent-width = 4

[tool.pyright]
pythonVersion          = "3.11"
typeCheckingMode       = "strict"
include                = ["app", "tests"]
exclude                = ["**/__pycache__", "**/.venv", "**/.ruff_cache"]
reportMissingTypeStubs  = false   # 第三方库无 .pyi stub 时不报错（可容忍）

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths    = ["tests"]
python_files = ["test_*.py"]
```

**命令约定（对齐前端 scripts：dev/build/preview/lint/type-check/format/test）**：

| 意图 | 命令（工作目录 = repo-3 根） | 关联 AC / DoD |
|---|---|---|
| Dev server | `uv run uvicorn app.main:app --reload --log-level info` | AC-03 |
| Lint | `uv run ruff check app tests` | §十六 代码质量 |
| Format（检查） | `uv run ruff format --check app tests` | §十六 |
| Format（写入） | `uv run ruff format app tests` | §十六 |
| Type check | `uv run pyright` | §十六 + 类型优先 |
| Test | `uv run pytest -q` | AC-09 |
| Architecture Scan（手动/脚本） | `grep -rn "pymysql\|psycopg\|sqlalchemy\|asyncpg" pyproject.toml app tests agents tools`（AC-08） + `grep -rn "from openai\|import anthropic\|import openai" app/ agents/ services/ tools/`（AC-07） | AC-07 / AC-08 / R-05 |

### 2.11 Pytest 组织与三用例（AC-09 精确命中）

```python
# tests/conftest.py
import pytest
from fastapi import FastAPI
from httpx import AsyncClient, ASGITransport
from app.core.config import Settings

@pytest.fixture
def test_settings(monkeypatch):
    """注入最小测试用覆盖（避免依赖用户本机 .env）"""
    monkeypatch.setenv("APP_NAME", "ai-service-test")
    monkeypatch.setenv("LLM_PROVIDER", "mock")
    monkeypatch.setenv("JAVA_API_BASE_URL", "http://localhost:1")
    return Settings()

@pytest.fixture
def app(test_settings):
    """构造带测试设置的 FastAPI 实例（与 production 同装配流程；此处骨架写法）"""
    from app.main import create_app  # main.py 导出 create_app(settings) 工厂，便于替换设置
    return create_app(test_settings)

@pytest.fixture
async def client(app: FastAPI):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

# tests/test_settings.py          → 验证 Settings 读值覆盖（test_settings 注入后，APP_NAME == "ai-service-test"）
# tests/test_health_endpoint.py   → 验证 client.get("/health") → status_code=200；json() == {"service":"ai-service","status":"UP"}
# tests/test_llm_client.py        → 验证 MockProvider：client.chat(...) 返回 ChatResponse，且 message.role=ASSISTANT；structured_chat 返回 pydantic 模型类型正确
```

→ AC-09 验收：`uv run pytest -q` 退出码 0，测试数量 ≥ 3，名称包含上述三条（可加补充，但不可缺少）。

## 3. 仓库影响（Repository Impact）

> front-matter `affected-repositories: [repo-3]` 与此处分仓清单**一一对应**（task 阶段 du-coverage 机检输入；严格遵守 SKILL.md §3.3 一致性约束）。
>
> 工作区仓（ai-platform workspace repo）除 design.md 本文件外，前序 artifact（requirement.md / exploration.md / prd.md / references/REG-M0-003.md / evidence.yaml）均未修改，已在 checklist 中自查。

### 3.1 repo-3（implementation/ai-platform-ai-service）

- 技术职责: 承载 Python AI Service 工程基线全量实现，支撑 AC-01~AC-11 全部验证与 Evidence 六组命令
- 修改概要: **从零初始化（首次提交）**；main 分支零提交 → 建立 §2.2 目录树中所有文件（根级 7 个文件 + app/ 分层包 15+ 模块 + 6 个边界位目录 README/__init__/.gitkeep + tests/ 4 个文件）
- 涉及模块/文件清单（与 §2.2 1:1 对应，不列出重复）：
  - 根级：`.gitignore` / `.python-version` / `pyproject.toml` / `uv.lock` / `.env.example` / `README.md`
  - `app/` 分层主包：`main.py` / `api/v1/health.py` / `core/config.py` / `core/exceptions.py` / `core/logging.py` / `middleware/trace_logging.py` / `services/__init__.py` / `infrastructure/java/client.py` / `infrastructure/llm/client.py` / `infrastructure/llm/factory.py` / `infrastructure/llm/providers/mock.py`
  - 边界位：`agents/` + `workflows/` + `tools/` + `prompts/` + `rag/`（全部 AC-11 约束级别）
  - 质量 & 测试：`tests/conftest.py` + `tests/test_settings.py` + `tests/test_health_endpoint.py` + `tests/test_llm_client.py`
- 不包含：数据库 DDL（§5 no）、M6 业务实现（AC-11 禁止）、基础设施 SDK（§二十 不依赖先行）

## 4. 跨仓协作（Cross-Repository Contract）

虽然本次 Change 代码实现只有 repo-3（单仓代码改动），但 AI Service 架构红线要求所有业务数据必须经 Java API（禁止直连 DB），因此跨仓契约是设计不可缺少的部分。

- **API Contract（AI → Java，HTTP 同步）**：
  - 调用方向：repo-3 → repo-1 mall-gateway
  - 基础 URL：`{JAVA_API_BASE_URL}`（Settings 默认 `http://localhost:8080`，= CHG-0003 mall-gateway 端口）
  - 路径前缀：`/api/v1/**`（与 CHG-0003 路由契约一致）
  - 请求头统一：`X-Trace-Id`（全链路一致）、`X-Request-Source: ai-service`、未来 M1+ `Authorization: Bearer <内部JWT>`（扩展位见 JavaAPIClient `extra_default_headers`）
  - 响应包裹：Java 侧 UnifyResult = `{success, code, message, data, traceId}` → AI 侧 JavaAPIClient 在 `_request` 中判断 success=false 时抛 AI-JAVA_API-202 并引用原业务 `code/message`
  - 错误码版本策略：`AI-` 前缀独立（§2.5.3 表），与 Java `PROD-` / `ORDER-` 等业务错误码不会冲突；内层引用原业务 code，便于 M6 排错
- **Event Contract（异步）**：M0 不引入消息队列，无事件；全部 Java 调用走同步 HTTP（M6 LangGraph 需要时在对应 Requirement 增加 RocketMQ/Kafka 接入）
- **Data Contract（数据归属）**：
  - 商品 / SKU / 库存 / 订单 / 用户 / 购物车 / 优惠券 = **repo-1 专属写权限**，repo-3 只读（经 Java API）
  - AI 侧数据（日志/Trace/Prompt 模板/评估记录/向量库索引）= 未来 repo-3 写权限（M6 Requirement 建表，M0 无）
  - 本 Change = **无数据定义**（§5 no）
- **Repository Dependencies 方向**：repo-3 运行时 HTTP 依赖 repo-1 gateway。**repo-1（Java）/ repo-2（前端）在本 Change 中零代码回退**（与 exploration §3 影响分析一致）
- **Integration Boundary 集成清单**：
  - `JAVA_API_BASE_URL` 环境变量：默认 `http://localhost:8080`，prod 注入
  - 路径：M0 仅验证 Client 类存在与签名；M6 业务方法再核对具体路径
  - 凭据：LLM_API_KEY / Java API 内部 Token 等一律走 Settings + .env + `.gitignore` 屏蔽
- **Cross-Repository Sequence 跨仓时序**：
  - M0 阶段（本 Change）：repo-1 gateway 无需在线。Java Client 测试 = httpx mock transport 返回固定 UnifyResult；LLM = MockProvider
  - M6 任意 AI 业务：必须先确认 Java 内部 API Contract 已冻结（有正式 ProductClient/OrderClient 的方法签名），再开始 AI Agent/Tool 开发
  - 写操作链路（取消/修改订单）：必须严格遵守 Agent → Tool（schema 含 `confirmation_required=true`）→ JavaAPIClient.cancel_order(confirmation=True) → mall-order 写 API 的顺序；任何跳过 confirmation 参数的实现一律违反 R-07

## 5. 数据变更

- 是否需 Migration: **no**
- 变更摘要: 纯工程骨架 + 边界位目录初始化（无数据库 Schema、无数据文件、无缓存定义、无 Vector DB 索引、无配置中心配置、无 MQ Topic 创建）
- 后续数据变更（M6 RAG/Embedding/向量库/日志落库等）归属于对应 Requirement 的独立 Change，不占用本 Change Migration

## 6. 风险

| 风险项 | 级别 | 触发条件 | 影响 | 缓解措施 |
|---|---|---|---|---|
| Python 3.11 / uv 在执行环境不可用或版本过低 | 中 | Environment Evidence：`uv run python --version` 不显示 3.11.x；`uv --version` < 0.3 | 后续步骤全阻塞；`.python-version` 无匹配解释器 | dev 阶段**必做**环境核验先行 → 版本不符时如实 FAIL，不伪称 PASS；可提示用户安装 pyenv/uv 官方安装命令（Evidence 中记录原文） |
| PyPI 网络超时 → `uv sync` 失败 | 中 | 大陆网络环境 / DNS 解析失败；默认 PyPI 直连超时 30s | 依赖安装失败 → 后续 dev/test 全阻塞 | `UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple` 或 `https://mirrors.aliyun.com/pypi/simple` 作为 env 切换方案（Evidence 记录切换原文）；**不在 pyproject.toml 写死**镜像源（尊重部署环境） |
| Pyright strict 级别在 M0 骨架阶段报大量类型错误 | 低 | `from __future__ import annotations` 未统一启用 / 第三方 httpx/fastapi 缺 stub | type-check 失败 = Quality DoD 不通过 | §2.10 已 `reportMissingTypeStubs=false`；内部模块全部补类型；M0 代码量小（<30 文件；<500 SLOC），可在 dev 阶段逐文件过 |
| 架构红线突破：直连 DB / 提前写 M6 业务（M6 风险，M0 需前置设计） | 潜在中→高 | 业务赶工时临时 `pip install sqlalchemy` + 直连 mall_product | 违反 AC-08 / §十八 → 后果：绕过 Java 规则写数据 | Architecture Scan 命令（§2.10 表）= `grep -rn "pymysql/psycopg/sqlalchemy"`；在 Code Review Checklist 中**固定为必查项**；pyproject.toml dependencies 显式不列入任何 DB 驱动 |
| 日志泄露 LLM_API_KEY | 高 | 某次 Exception message 把完整 SecretStr 打印进日志 | 凭据泄露 → 必须立即撤销并重发 | `SecretStr` 类型 + `setup_logging` 脱敏 Filter 两条防线；Error Handler 中 message 字段统一经过脱敏；生产日志级别默认 INFO（不含 DEBUG full request/response） |
| X-Trace-Id 透传失败（contextvar 丢失） | 中 | 某些 asyncio.to_thread / 后台任务脱离 context → trace_id="-" | 跨仓日志不可 trace，排错困难 | TraceIdMiddleware 在后台任务（M6 引入）启动时显式 `contextvars.copy_context()`；M0 仅 HTTP 同步请求链路，不存在此问题 |
| `reason` 字段含冒号破坏 YAML 解析（项目 harness 已知问题） | 低 | 手动写 metadata.yaml 时，`reason: "cat: value"` 不带引号 → 解析错误 | 下一阶段 gate 验证报错；Change 状态无法推进 | 本 session 全程遵循：任何 metadata `reason` 值**一律加双引号**；在 checklist §3 中自查 |
| 空仓库首次推送权限/远程网络失败 | 低 | 用户未在 github 上配置 SSH / 网络波动 | 本地提交无法 push | 严格遵守用户 Profile：对外/推送等难逆操作必须**先询问用户**；本地提交（`git add . && git commit -m "CHG-0005 baseline"`）与远程推送**解耦** |
| 6 个边界位目录被误写业务代码 | 低 | 某位开发者在 M5 前先写 `agents/product_agent.py` 测试 | AC-11 扫到 = 不通过（但需要 review 阶段才发现） | 每个边界位目录 README.md 顶部显式大字警告「禁止在 CHG 属 M6 AI 业务之前写业务实现」；静态 scan（§2.10 Architecture Scan）可扩展为检查目录 .py 文件数（agents/ 除 __init__ 外 = 0） |
| uvicorn 默认 access log 与自定义 Middleware 日志重复（PRD §5.1 #8 / #12） | 低 | 启动时忘了传 `log_config=None` | access log 一行打印两次 | §2.4 lifespan 处 + README.md 启动命令处**两处同时注明** `uvicorn.run(app, log_config=None)` / `uv run uvicorn app.main:app --log-config <(echo '{}')`（或等价）保证重复日志不会出现 |

## 7. 待澄清问题

**阻塞性待澄清问题数量 = 0**。

PRD §5.1 12 条未知问题，在 §2 各具体节中**100% 落地到可实现的具体方案**：6 项「否」级已经决策完成（#1 #2 #3 #4 #9 #11 #12 共 7 项，数量差异系 PRD 闭环表中 #12 也属于否级），6 项「待 Design」级在 §0 元信息的 PRD 决策映射中明确到具体章节号与签名/配置项。

可微调的非阻塞项（sdd-task / dev 阶段按 Evidence 实测记录即可）：
- Python 3.11 具体 patch level（3.11.8 vs 3.11.9，不影响功能）
- Ruff lint 的具体规则子项：`["E","F","I","N","W","UP","B","A","SIM","RUF"]` 是否在实际跑时关掉 1~2 条（如 W503 与 line-length 冲突）→ 可在 dev 阶段按 Evidence 结果调整，需回写 design.md 的变更说明
- PyPI 镜像是否切换为国内（由执行网络决定）
- `.env.example` 中变量的描述文案（不影响结构）

## 8. 任务域建议（REG-M0-003 §二十三 TASK-001~008 建议映射）

> **注：本节为需求文档建议的 TASK 到 Design 章节的映射表，用于 sdd-task 阶段快速对齐；**不是** DU 拆分（正式 DU 拆分是 sdd-task 的职责，design.md 不得出现 DU-XXX 编号）。

| 建议 TASK（来自需求文档 §二十三） | 对应的 Design 章节 / 交付物 | 涉及的 AC / DoD 点 |
|---|---|---|
| TASK-001 建立 Python 环境与项目基础（uv/pyproject/依赖） | §2.2 根文件树 / §2.3 版本策略 / §2.10 pyproject.toml 完整配置 | AC-01 / AC-02 / DoD 1~4 |
| TASK-002 搭建 FastAPI 基础工程（App/Lifespan/Health） | §2.2 app 主包 / §2.4 lifespan / §2.5 API / §2.7 Middleware | AC-03 / AC-04 / DoD 6~10 |
| TASK-003 配置/环境/凭据/日志/异常/错误体系 | §2.6 Settings + .env.example + .gitignore / §2.7 Logging+Trace / §2.5.3 错误码 / `core/exceptions.py` | AC-05 / DoD 11~24 / R-08 R-09 R-10 |
| TASK-004 LLM Client 抽象 + Provider 适配层 + Factory | §2.8 LLMClient(ABC) / providers/mock.py / factory.py PROVIDER_REGISTRY | AC-07 / R-04 / 依赖倒置原则 |
| TASK-005 Java Backend HTTP Client 基础封装 | §2.9 JavaAPIClient 四扩展参数位签名 + _request 统一入口 + 错误映射 | AC-06 / R-06 R-07 / 全链路 TraceId 透传 |
| TASK-006 AI 工程边界预留：Agent/Tool/Workflow/Prompt/RAG 目录结构 | §2.2 边界位目录结构 + 6 个 README.md 内容（各自引用对应标准文档） | AC-11 / R-11 / R-13 |
| TASK-007 Pytest 测试 + Ruff/Pyright 质量基线 + 启动规范 | §2.10 Ruff/Pyright 配置 + 命令约定 / §2.11 Pytest 三用例 + conftest | AC-09 / §十六 / DoD 质量与启动验证 |
| TASK-008 Evidence 记录（Environment/Dependency/Service/Health/Test/Architecture Scan 六组 + 日志归档到 evidence/logs/） | §2.11 末尾 + §3.1 涉及模块的六组命令清单 | DoD 第 25~28（Evidence 诚信 §二十六） |

→ sdd-task 阶段可以按上表 8 行 × 单仓（repo-3）→ 考虑是否合并（如 TASK-001+007 同属配置层；TASK-002+003 属 core 工程基础；TASK-004+005 属 integration；TASK-006 属边界位；TASK-008 单独 Evidence）产出不超过 5~6 个 DU-AI-00X，满足 fan-out 合理、fan-in 收口的 DU 管理原则。
