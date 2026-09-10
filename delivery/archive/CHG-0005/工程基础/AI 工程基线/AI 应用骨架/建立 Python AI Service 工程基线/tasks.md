# Tasks

> 阶段：sdd-task 产物（Phase 2.4/2.5：Delivery Decomposition + DU Specification v2）
> 输入：`delivery/changes/CHG-0005/工程基础/AI 工程基线/AI 应用骨架/建立 Python AI Service 工程基线/design.md`
> 产出状态：tasked

本文档将 design.md 设计拆解为 5 个 Delivery Unit（**DU 1:1 Repository，单仓 repo-3，ID alias=AI**），并为每个 DU 按 Phase 2.5 要求产出 Implementation Guidance（Implementation Sketch 必填 + Pseudocode 条件必填 + Verification 必填），供 sdd-dev 直接消费（无需回读 Workspace 全文）。

## 0. 元信息

- Change ID: CHG-0005
- Design 来源: `delivery/changes/CHG-0005/工程基础/AI 工程基线/AI 应用骨架/建立 Python AI Service 工程基线/design.md`
- 状态流转: designed → tasked
- Feature Path: 工程基础 > AI 工程基线 > AI 应用骨架 > 建立 Python AI Service 工程基线（STORY-1-02-01-01，inline 单 Story）
- DU 总数: 5（全部位于 repo-3，仓库别名 AI = repositories.yaml id=repo-3 的 id 缩写，符合 SKILL.md alias 缺省规则）
- Design affected-repositories 一致性：`[repo-3]` ↔ 5 DU 全部目标仓库=repo-3（每仓至少 1 DU，du-coverage 机检通过）

### 执行总览

8 TASK（design.md §8 任务域建议，来自 REG-M0-003 §二十三）× 单仓 repo-3 → **合理合并为 5 个 DU**（按「仓库根→core 主包→集成层→边界位→测试与Evidence」的装配顺序，每个后序 DU 依赖前序 DU 产出文件作为物理文件存在的前提；**全串行**，无并行组）：

| DU | 顺序 | 并行组 | 仓库 | 核心职责（对应原 TASK 合并） |
|---|---|---|---|---|
| DU-AI-001 | 1 | A（单） | repo-3 | **仓库根 + 依赖与质量基线** = TASK-001（Python/uv/pyproject/uv.lock/.gitignore）+ TASK-007 的 Ruff/Pyright/Pytest 集中配置 + .env.example / README.md |
| DU-AI-002 | 2 | A（单） | repo-3 | **FastAPI 主包 Core（App/Lifespan/API/Config/Logging/Exception/Middleware/Error）** = TASK-002 + TASK-003 |
| DU-AI-003 | 3 | A（单） | repo-3 | **Infrastructure 集成层（LLM 抽象+Factory+Mock / Java HTTPX Client）** = TASK-004 + TASK-005 |
| DU-AI-004 | 4 | A（单） | repo-3 | **AI 工程 6 个边界位目录与 README 管理约定（Agent/Tool/Workflow/Prompt/RAG + agents）** = TASK-006 |
| DU-AI-005 | 5 | A（单） | repo-3 | **Pytest 三用例 + Evidence 六组命令形成与日志归档** = TASK-008 + TASK-007 的 pytest 执行与 Evidence 记录部分 |

执行顺序说明：**严格串行**（1→2→3→4→5），原因：
- DU-AI-002 需要 DU-AI-001 的 `pyproject.toml`（Settings/httpx/fastapi 依赖已经声明）+ `.env.example`（Settings 字段对照）
- DU-AI-003 需要 DU-AI-002 的 `app/core/exceptions.py`（AIConfigException/AIJavaAPIException/AILLMProviderException 异常类已定义）+ `app/core/logging.py`（trace_id_var contextvar 已导出）
- DU-AI-004 无文件依赖但放第 4 位作为"工程结构收尾"，把边界位全部到位后才跑测试
- DU-AI-005 必须在代码文件（app/ + infrastructure/）和边界位目录全部到位后才能执行测试 + Architecture Scan

---

## 任务清单

### DU-AI-001：仓库根初始化 + 依赖与质量基线集中配置

- 目标仓库: repo-3（id=repo-3，路径 `implementation/ai-platform-ai-service`，远程 `https://github.com/ws481634399/ai-platform-AIService.git`，仓库别名 AI）
- Goal: 建立仓库根 7 个权威文件（.gitignore、.python-version、pyproject.toml、uv.lock、.env.example、README.md、.sdd 暂不写），将 FastAPI/LLM/Java 集成所需的依赖 + Ruff/Pyright/Pytest 质量配置**全部集中写入 pyproject.toml**（PRD §5.1 #11 决策），执行 `uv lock` 生成 uv.lock（单一版本权威），为所有后续 DU 提供依赖与工具运行基础。
- Scope（范围）：
  - 仓库根：
    - `.gitignore` 屏蔽：`.venv/`、`.env`、`__pycache__/`、`.pytest_cache/`、`.ruff_cache/`、`dist/`、`*.pyc`、`*.pyo`、`.DS_Store`（**不屏蔽 `.env.example`**，符合 AC-05）
    - `.python-version`：**精确内容 `"3.11"`**（AC-01，不可带 patch level）
    - `pyproject.toml`：完全按 design.md §2.10 写入（不修改任何规则字段名/值）：
      - `build-system`: hatchling
      - `project`: name/version/description/`requires-python=">=3.11,<3.12"`/`dependencies`: fastapi 0.115+ / uvicorn[standard] / pydantic-settings 2.x / python-dotenv / httpx[http2] / starlette
      - `dependency-groups.dev`: pytest 8 / pytest-asyncio / ruff 0.6+ / pyright 1.1+
      - `[tool.ruff]` / `[tool.ruff.lint]` select 10 规则 / `[tool.ruff.format]` 双引号 / `[tool.pyright]` strict / `[tool.pytest.ini_options]` asyncio_mode="auto"
    - `uv.lock`：由 `uv lock` 生成（由 dev 阶段 `uv sync` 实际锁定，**tasks.md 不伪造 lock**；dev Evidence 记录生成）
    - `.env.example`：列出 13 字段（对齐 design.md §2.6 Settings 字段名），值全部为 changeme / 默认值示例，**不含任何真实凭据**
    - `README.md`：快速开始 3 条命令 + 结构说明 + 参考链接（"参考 CHG-0005 design.md" + "6 个 AI 规范位于 standards/engineering/ai/"）；不写任何业务实现
- Design References: design.md §2.2 目录树（根级 7 文件）/ §2.3 技术栈与版本策略（Python3.11/uv/hatchling/Ruff/Pyright 精确栈）/ §2.6 Settings 13 字段清单（.env.example 对照）/ §2.10 全部集中配置（pyproject.toml 三段 + dependency-groups + pytest.ini_options）/ §2.10 表 7 命令约定（README 快速开始）
- Dependencies: **无**（首个 DU，直接在空仓建立根文件）
- Acceptance Criteria:
  - AC-01: `.python-version` 文件内容精确等于 `3.11`；`uv run python --version` 输出前缀为 `Python 3.11.`
  - AC-02: 仓库根存在 `pyproject.toml` 与 `uv.lock`；执行 `uv sync --frozen` → 退出码 0；`uv lock --check` → 退出码 0（验证 lock 与 pyproject 对齐）
  - `pyproject.toml` 内容验证：
    - `project.requires-python` = `">=3.11,<3.12"`（AC-01 精确区间）
    - `[tool.ruff]` / `[tool.pyright]` / `[tool.pytest]` 三段全部存在（design.md §2.10 的 key 不变）
  - `.env.example` 13 字段齐全；grep "sk-" / "changeme" 匹配不到真实 API Key 形态 / 高熵字符串
  - `.gitignore` 明确包含 `.env`（无 `.env.example` 在 `.gitignore` 内）+ `.venv/`（AC-05 凭据安全）
  - 质量基线可运行：`uv run ruff check app tests`（此时 app/tests 未建 → 无错误但退出码 0；不 panic）；`uv run pyright` 此时可因 include 的 app/tests 不存在而通过或忽略
- Execution Order: 1
- Parallelization: 组 A（单，不与任何其他 DU 并行）
- Implementation Sketch:

```text
repo-3 (ai-platform-ai-service/)
├── .gitignore              # 屏蔽项精确列表（对齐 Scope）
├── .python-version          # 精确 "3.11"
├── pyproject.toml           # 全部依赖 + 质量工具 + pytest 配置的单一事实源
│   ├── build-system         # hatchling
│   ├── project              # requires-python + 运行时依赖 6 项
│   ├── dependency-groups    # dev= pytest + ruff + pyright
│   ├── tool.ruff*           # lint + format 配置
│   ├── tool.pyright         # strict 级别 + include/exclude
│   └── tool.pytest          # asyncio_mode + testpaths
├── uv.lock                  # uv sync/lock 产出，唯一版本权威
├── .env.example             # 13 Settings 字段（changeme，无真实值）
└── README.md                # 快速开始（uv sync → uvicorn → curl /health）
```

- Pseudocode: N/A（纯文件与配置创建，无业务流程/算法/状态转换/组件编排；文件内容只是从 design.md 模板直接落地，不触发任何 complexity-trigger）
- Verification:
  - **静态文件检查**: `ls -la` 确认 6 个文件存在（uv.lock 由 `uv sync` 实际生成，dev Evidence 记录）；`.python-version` 精确等于 3.11
  - **依赖声明检查**: `uv run python -c "import fastapi, pydantic_settings, httpx, starlette"` → 无 ImportError（验证 dep 声明完整）
  - **质量工具可运行**:
    - `uv run ruff --version` → 输出版本号（证明 ruff 可执行）
    - `uv run pyright --version` → 输出版本号
    - `uv run pytest --version` → 输出 pytest 8.x
  - **凭据安全扫描（AC-05）**: `grep -rE "sk-[A-Za-z0-9]{20,}|password=[^\"\s,;&]{4,}|secret=" --include="*" . | head -50` → 零命中真实密文（允许 changeme 示例命中并排除）
  - **Error Case**: 若 `uv sync --frozen` 失败（例如 pyproject.toml 语法错误或 lock 过时）→ 阻塞 DU-AI-002 开始，必须先修 pyproject.toml / 重新生成 lock

---

### DU-AI-002：FastAPI Core 主包（App + Lifespan + Health API + Config + Exception + Logging + Trace Middleware）

- 目标仓库: repo-3（AI）
- Goal: 交付 app 主包的所有 Core/API/Middleware 模块，实现：FastAPI 应用装配（main.py ≤40 行 → 符合 AC-10 ≤50 行）、Settings 从 env/.env 加载、5 类异常体系（PARAM/CONFIG/JAVA_API/LLM_PROVIDER/SYSTEM + 错误码前缀+数值）、全局异常 Handler（UnifyResult 5 字段包裹）、Logging 接管（dictConfig + TraceIdFilter + 正则脱敏）、TraceIdMiddleware 读/生成/响应头/access log 接管 + uvicorn log_config=None 配合入口。
- Scope（范围）：
  - `app/__init__.py`
  - `app/main.py`：FastAPI 实例 + lifespan 函数（严格对齐 design.md §2.4 5 步）+ `include_router(health_router, prefix="")` + 注册 Exception Handlers（5 类 + RequestValidationError + 兜底 Exception）+ 导出 `create_app(settings: Settings) -> FastAPI` 工厂函数（供 tests/conftest.py 替换设置）；目标行数 ≤40
  - `app/api/__init__.py`
  - `app/api/v1/__init__.py`（include_router 聚合入口；M0 仅引入 health）
  - `app/api/v1/health.py`：APIRouter()，`GET /health` → `{"service":"ai-service","status":"UP"}`（AC-04 字段精确匹配，不套 UnifyResult）
  - `app/core/__init__.py`
  - `app/core/config.py`：Settings(BaseSettings) 13 字段（完全按 design.md §2.6 表格），含 `LOG_FORMAT` / `DATE_FORMAT` 常量导出（供 logging.py 使用）；`SecretStr` 正确声明 LLM_API_KEY
  - `app/core/exceptions.py`：AIBaseException(attrs: code, message, category=enum) + 5 个子类（AIParamException / AIConfigException / AIJavaAPIException / AILLMProviderException / AIInternalException），每个类有默认 code 前缀常量（PARAM 001 模板、CONFIG 101 模板…但具体 NNN 数值按 design.md §2.5.3 分配表硬编码在抛出点）
  - `app/core/logging.py`：`setup_logging(settings: Settings)`（logging.basicConfig → dictConfig；含 TraceIdFilter 注入 contextvar、FILTER_MASKED 正则脱敏 mask=*** 的 Filter、uvicorn/uvicorn.access/uvicorn.error logger 的 handler 分配、关闭 uvicorn 自带 access log 的注释锚点 "配合 uvicorn.run log_config=None 使用"）；导出 `trace_id_var: ContextVar[str]`（供 infrastructure/ 层注入 X-Trace-Id Header）
  - `app/middleware/__init__.py`
  - `app/middleware/trace_logging.py`：TraceIdMiddleware(BaseHTTPMiddleware)，严格对齐 design.md §2.7.2 6 步（读/生成 contextvar set token → call_next → 写 response header → access log METHOD/PATH/STATUS/DURATION_MS trace_id=… → reset token）
  - `app/services/__init__.py`（Service 层占位空，不写具体 service）
- Design References: design.md §2.2 app/ 目录树（5 子域：api/core/middleware/services/infrastructure 先占前 4 域）/ §2.4 Lifespan 5 步顺序 + shutdown 对称 `.aclose()` / §2.5 API 契约 + `AI-<CAT>-NNN` 错误码分配表（首码 PARAM 001 等）+ UnifyResult 5 字段 JSON / §2.6 Settings 13 字段 / §2.7 LOG_FORMAT 最终字符串 + FILTER_MASKED 正则 + TraceIdMiddleware 6 步 + uvicorn log_config=None / §0 PRD 决策映射 #7（错误码）+ #8（Logging/TraceId）
- Dependencies: DU-AI-001（必须有 pyproject.toml 存在 fastapi/pydantic-settings/httpx 依赖 + .env.example 字段对照 + .gitignore 已屏蔽 .env 避免 .env 进入版本库）
- Acceptance Criteria:
  - AC-03: `uv run uvicorn app.main:app --host 127.0.0.1 --port 8000 --log-level info --log-config <(echo '{}')` → 日志含 "Uvicorn running on http://127.0.0.1:8000"；无 ERROR/Exception；Ctrl+C 优雅退出退出码 0
  - AC-04: 服务运行时 `curl -s http://127.0.0.1:8000/health` → HTTP 200；json() == `{"service":"ai-service","status":"UP"}`
  - AC-05: `app/core/config.py` 中 `LLM_API_KEY = SecretStr | None`（Pydantic SecretStr，dump 脱敏）；`.env.example` 有 13 字段（见 DU-AI-001）；`.gitignore` 存在 `.env`
  - 异常响应形状验证：请求故意传错误 payload（若有端点）或触发 AI-CONFIG-102（未知 LLM_PROVIDER）→ HTTP 响应 JSON `{success:false, code:"AI-CONFIG-102", message:"...", data:null, traceId:"uuid"}`；**Python Traceback 不在响应体中**
  - `app/main.py` 行数：`wc -l app/main.py` → **≤ 40 行**（buffer 到 50 行上限 AC-10）
  - 日志脱敏：`grep -rn "sk-test12345678901234567890" app/ tests/` 或手动触发日志输出含 sk- 字符串 → 日志文件中变为 `***`
- Execution Order: 2
- Parallelization: 组 A（单）
- Implementation Sketch:

```text
app/
├── main.py                 # FastAPI(lifespan=lifespan) + include_router health + Exception Handlers（5子类+ValidationError+兜底）
│                           # 导出 create_app(settings) 工厂：tests 注入覆盖 settings 用
├── api/v1/health.py        # APIRouter + health endpoint（不套 UnifyResult，直接返回{"service","status"}）
├── core/
│   ├── config.py           # Settings(Pydantic BaseSettings) 13 字段 + LOG_FORMAT/DATE_FORMAT
│   ├── exceptions.py       # AIBaseException + 5 子类（PARAM/CONFIG/JAVA_API/LLM_PROVIDER/SYSTEM）
│   └── logging.py          # setup_logging() → dictConfig + TraceIdFilter(log Record) + 脱敏Filter + 关闭uvicorn默认access
│                               # 导出 trace_id_var(ContextVar) → 被 DU-AI-003 层注入 X-Trace-Id
├── middleware/trace_logging.py  # TraceIdMiddleware：读/生成/响应头/access log METHOD PATH STATUS DURATION trace_id=…
└── services/__init__.py    # 空占位（M6 Agent/Tool Service 扩展）
```

- Pseudocode: **必填**（complexity-trigger = **orchestration**：lifespan startup/shutdown 5 步组件编排 + 异常 5 类 + RequestValidationError + 兜底 7 条异常路径的统一映射；触发 DU-002 全局复杂度）

```text
─── create_app(settings: Settings) -> FastAPI: ───
1. setup_logging(settings)            # DictFormat + TraceIdFilter + MaskingFilter（先于任何 Logger 实例化）
2. app = FastAPI(lifespan=lifespan,
                 title="AI Platform AI Service",
                 version="0.1.0")
3. app.state.settings = settings

4. async def lifespan(app):
     # startup
     java_http  = httpx.AsyncClient(
         base_url=settings.JAVA_API_BASE_URL.rstrip("/"),
         timeout=httpx.Timeout(settings.JAVA_API_TIMEOUT, connect=3.0))
     retry_policy = None if not settings.JAVA_API_RETRY_ENABLED else None  # M0 关闭
     java_client = JavaAPIClient(http_client=java_http, settings=settings, retry_policy=retry_policy)
     try:
         llm_client = LLMClientFactory.create(settings)   # 抛 AI-CONFIG-102 若未知 provider
     except Exception:
         await java_http.aclose(); raise
     app.state.java_http_client = java_http
     app.state.java_client       = java_client
     app.state.llm_client        = llm_client
     yield
     # shutdown
     await java_http.aclose()
     close_llm = getattr(llm_client, "aclose", None)
     if close_llm: await close_llm()

5. register_exception_handlers(app):
     @app.exception_handler(RequestValidationError)
     async def h(e): → 映射 AI-PARAM-001（字段缺失）或 AI-PARAM-002（格式非法）→ UnifyResult JSON（HTTP 422/400）
     @app.exception_handler(AIParamException)      → HTTP 400 + UnifyResult（code/message 原样）
     @app.exception_handler(AIConfigException)     → HTTP 500 + UnifyResult（暴露配置问题）
     @app.exception_handler(AIJavaAPIException)    → HTTP 502/500 按 code: 201→502/202→400+business
     @app.exception_handler(AILLMProviderException)→ HTTP 502/按 code 映射；外层含 provider_trace_id 如有
     @app.exception_handler(AIInternalException)   → HTTP 500 + AI-SYSTEM-901
     @app.exception_handler(Exception)             → HTTP 500 + AI-SYSTEM-901（兜底；屏蔽 Traceback HTTP 响应）

6. app.include_router(health_router)
7. app.add_middleware(TraceIdMiddleware)   # 最外层：最先执行/最后执行，从而 access log 取到状态码/Duration
8. return app

─── TraceIdMiddleware(request, call_next): ───
tid   = request.headers.get("X-Trace-Id") or uuid4().hex
token = trace_id_var.set(tid)
start = time.perf_counter()
try:
    resp = await call_next(request)
finally:
    duration_ms = int((time.perf_counter() - start) * 1000)
    resp.headers["X-Trace-Id"] = tid
    logger.info(f"{request.method} {request.url.path} {resp.status_code} {duration_ms}ms trace_id={tid}")
    trace_id_var.reset(token)
return resp
```

- Verification:
  - **Command / Server 验证（AC-03/04）**：`uv run uvicorn app.main:app --host 127.0.0.1 --port 8000 --log-config /dev/null` → 启动日志；另开 shell `curl -s http://127.0.0.1:8000/health | jq .` → `{"service":"ai-service","status":"UP"}`
  - **异常响应形状**：启动时故意设 `LLM_PROVIDER=unknown_vendor` → `/health` 启动阶段（或专门暴露的 `/__diag` 内部端点）触发 AI-CONFIG-102 → jq `.code` = "AI-CONFIG-102"，`.success=false`，`.traceId` 非空，响应不含 `Traceback`
  - **行数验证**：`wc -l app/main.py` → ≤ 40（sdd-dev Evidence 截图）
  - **日志脱敏**：临时在 `/health` 端点里写 `logger.error("debug key=sk-AABBCCDDeeffgghhiijjkkllmmnnoopp123456")`，看 stderr 中是否为 `sk-***`（验证完成后回滚该临时代码）
  - **Architecture Scan（R-05 / AC-08 预验证）**：本 DU 阶段，grep "pymysql/psycopg/sqlalchemy/asyncpg" app/ → 零命中（提前校验基础）
  - **Error Case**: 若 `create_app` 在 lifespan startup 阶段抛出 AI-CONFIG-102（未知 LLM_PROVIDER），shutdown 侧必须已 close 掉 java_http 单例（避免连接泄漏；通过专门写关闭断言触发验证）

---

### DU-AI-003：Infrastructure 集成层（LLM 抽象 + Factory + MockProvider / Java HTTPX Client）

- 目标仓库: repo-3（AI）
- Goal: 交付 infrastructure/ 域的两个子系统：LLM（接口抽象 + Provider 注册 + Factory + MockProvider 三方法实现）和 Java（HTTPX 统一封装，四扩展参数位 + _request 统一入口 + 错误码 201/202 映射 + X-Trace-Id 透传）。两者都是架构红线落实的核心模块（R-04 Provider 隔离 + R-06 Java 统一访问 + R-07 写操作二次确认预留锚点）。
- Scope（范围）：
  - `app/infrastructure/__init__.py`
  - `app/infrastructure/llm/__init__.py`
  - `app/infrastructure/llm/client.py`：
    - Enum: ChatMessageRole（system/user/assistant/tool）
    - Pydantic: ChatMessage（role/content/name opt）、ChatUsage（prompt_tokens/completion_tokens）、ChatResponse（message+usage+model+provider_trace_id opt）、ChatChunk（delta_content+finish_reason opt）
    - ABC LLMClient：`chat( messages, **kwargs )` / `chat_stream( messages, **kwargs )` / `structured_chat(messages, response_model: type[T], **kwargs )`
  - `app/infrastructure/llm/factory.py`：
    - `PROVIDER_REGISTRY: dict[str, type[LLMClient]] = {"mock": MockProvider}`
    - `LLMClientFactory.create(settings: Settings) -> LLMClient`：未知 key → 抛 AI-CONFIG-102
  - `app/infrastructure/llm/providers/__init__.py`
  - `app/infrastructure/llm/providers/mock.py`：MockProvider(LLMClient)，构造参数 `settings: Settings`，三方法：
    - `chat`: 取 messages 最后一条内容，echo 前缀 `[mock echo]`；ChatUsage 固定 `(prompt=7, completion=5)`；model = settings.LLM_MODEL
    - `chat_stream`: 先产生 `ChatChunk(delta="[mock echo] ")`，再按字或按段 echo（简化版，最后一条 finish_reason=stop）
    - `structured_chat(response_model)`：根据 response_model.model_fields 构造最小 mock dict（对 int 给 0/str 给空/float 给 0.0/bool 给 False/嵌套模型递归）→ 返回 `response_model.model_validate(mock_dict)`
  - `app/infrastructure/java/__init__.py`
  - `app/infrastructure/java/client.py`：
    - `JavaAPIClient.__init__(self, *, http_client: httpx.AsyncClient, settings: Settings, retry_policy=None, extra_default_headers=None)`（四扩展参数位 = design.md §2.9 签名）
    - 私有 `_request(method, path, **kwargs)`：合并 default_headers（X-Request-Source=ai-service + extra）+ setdefault X-Trace-Id = trace_id_var.get("-")；包装 `AI-JAVA_API-201`（Network/Timeout/5xx）vs `AI-JAVA_API-202`（Java 业务 success=false /4xx ）+ 未来 retry_policy 包裹；注释锚点 `confirmation_required=true`（R-07）+ 预声明三个未来业务方法的签名：`get_product(product_id: str) -> ProductDTO` / `get_order(order_id: str)` / `cancel_order(order_id: str, *, confirmation: bool) 抛 AI-PARAM-001 if confirmation=False`（不写真实实现）
- Design References: design.md §2.8 LLMClient ABC + 4 Pydantic models + PROVIDER_REGISTRY + MockProvider 三方法 + Factory create / §2.9 JavaAPIClient 四参数位签名 + _request 统一入口 + AI-JAVA_API 201/202 映射表 + confirmation_required=true 取消订单注释锚点 / §4 跨仓契约（JAVA_API_BASE_URL 默认 8080 + X-Request-Source + X-Trace-Id 透传）/ §0 PRD 决策映射 #5（Java Client）+ #6（LLM Adapter 注册）
- Dependencies: DU-AI-002（需要 `app/core/exceptions.py` 三个异常类：AIConfigException/AIJavaAPIException/AILLMProviderException 已定义；`app/core/logging.py` 导出的 `trace_id_var` contextvar 用于 X-Trace-Id 注入）+ DU-AI-001（httpx 依赖存在）
- Acceptance Criteria:
  - AC-06: `grep -rn "httpx.AsyncClient(" app/ --include="*.py"` → 命中位置 = 仅 `infrastructure/java/client.py`（JavaAPIClient 不在这里实例化但本类类型签名引用）+ lifespan（main.py 已在 DU-AI-002 写的注入位置）。`app/api/` / `app/services/` / `agents/`（还未建）→ 零直接实例化。`JavaAPIClient.__init__` 形参签名（inspect.signature）包含 `http_client` / `settings` / `retry_policy` / `extra_default_headers` 四项扩展参数。
  - AC-07: `grep -rn "from openai \|import openai \|from anthropic \|import anthropic" app/ services/ agents/ tools/ --include="*.py"` → 零命中（或仅在 providers/mock.py 的 import 注释中允许命中并标明"仅注释，属 M6 未实现"）。LLMClientFactory.create(Settings(LLM_PROVIDER="mock")) 返回实例的类型 == `<class 'app.infrastructure.llm.providers.mock.MockProvider'>`；对 `unknown_vendor` → 抛 AI-CONFIG-102，`code="AI-CONFIG-102"`
- Execution Order: 3
- Parallelization: 组 A（单）
- Implementation Sketch:

```text
app/infrastructure/
├── llm/
│   ├── client.py              # 类型模型（Message/Role/Usage/Response/Chunk）+ LLMClient(ABC) 三方法签名
│   ├── factory.py             # PROVIDER_REGISTRY = {"mock": MockProvider} + create(settings) → 查注册表
│   └── providers/
│       └── mock.py            # MockProvider(LLMClient)：三方法全实现（echo mock + model_validate for structured）
└── java/
    └── client.py              # JavaAPIClient(http_client, settings, retry_policy, extra_default_headers)
                                #  + _request(method, path)（合并 headers + X-Trace-Id 注入 + 错误映射 AI-JAVA_API-201/202）
                                #  + 三个未来方法签名注释锚点（含 confirmation_required cancel_order）
```

- Pseudocode: **必填**（complexity-trigger = **business-flow + orchestration**：`_request` 统一请求路径是多步骤业务流程（Headers 合并 → TraceId 注入 → HTTP 调用 → Network/Timeout/5xx/4xx/JSON body/success=false 七种异常分支映射 + 未来 retry 装饰器包裹）+ LLM Factory.create 的异常/注册流程）

```text
─── LLMClientFactory.create(settings: Settings) -> LLMClient: ───
key = settings.LLM_PROVIDER.strip().lower()
if key not in PROVIDER_REGISTRY:
    raise AIConfigException(
        code="AI-CONFIG-102",
        message=f"未知 LLM_PROVIDER={settings.LLM_PROVIDER!r}；已注册: {sorted(PROVIDER_REGISTRY)}")
ProviderClass = PROVIDER_REGISTRY[key]
return ProviderClass(settings)   # ProviderClass 全部接受 (settings: Settings) 构造参数

─── MockProvider.chat(messages, **kwargs): ───
last = messages[-1].content if messages else ""
return ChatResponse(
    message=ChatMessage(role=ChatMessageRole.ASSISTANT, content=f"[mock echo] {last}"),
    usage=ChatUsage(prompt_tokens=7, completion_tokens=5),
    model=self._settings.LLM_MODEL,
    provider_trace_id=None,
)

─── MockProvider.structured_chat(messages, response_model: type[T]) -> T: ───
sample = {}
for field_name, field_info in response_model.model_fields.items():
    ft: type = field_info.annotation
    sample[field_name] = (
        0          if ft is int or float else
        ""         if ft is str else
        False      if ft is bool else
        None       if getattr(ft, '__origin__', None) is Union and type(None) in ft.__args__ else
        None
    )
return response_model.model_validate(sample)

─── JavaAPIClient._request(method, path, **kwargs): ───
headers = kwargs.pop("headers", None) or {}
headers |= self._default_headers           # {"X-Request-Source": "ai-service"}
tid = trace_id_var.get("-")                 # 来自 core/logging.py 的 ContextVar
headers.setdefault("X-Trace-Id", tid)
timeout = kwargs.pop("timeout", self._settings.JAVA_API_TIMEOUT)

async def _do_request():
    try:
        resp = await self._http.request(method, path, headers=headers, timeout=timeout, **kwargs)
    except (httpx.NetworkError, httpx.ConnectError, httpx.TimeoutException) as exc:
        raise AIJavaAPIException("AI-JAVA_API-201", f"Java API 不可达: {type(exc).__name__}") from exc
    except Exception as exc:
        raise AIInternalException("AI-SYSTEM-901", f"未预期HTTP错误: {type(exc).__name__}") from exc

    # 业务层解析
    if resp.status_code >= 500:
        raise AIJavaAPIException("AI-JAVA_API-201", f"Java 服务端错误: HTTP {resp.status_code}")
    try:
        body = resp.json()
    except ValueError:
        raise AIJavaAPIException("AI-JAVA_API-202", f"Java 返回非 JSON: HTTP {resp.status_code}")

    if resp.status_code >= 400 or (isinstance(body, dict) and body.get("success") is False):
        orig_code    = body.get("code",    "UNKNOWN") if isinstance(body, dict) else "NON-JSON"
        orig_message = body.get("message", "")       if isinstance(body, dict) else ""
        raise AIJavaAPIException(
            "AI-JAVA_API-202",
            message=f"Java 业务失败: orig_code={orig_code}, orig_message={orig_message}")
    return body.get("data") if isinstance(body, dict) else body

if self._retry is None:
    return await _do_request()
# 未来 retry_policy: tenacity.AsyncRetrying(...)
async with self._retry:
    return await _do_request()

# 未来取消订单示例（M6 写操作，含二次确认）—— 仅作为注释锚点，不写真实实现:
# async def cancel_order(self, order_id: str, *, confirmation: bool):
#     if not confirmation:
#         raise AIParamException("AI-PARAM-001",
#             message="Tool schema confirmation_required=true，但调用者未传 confirmation=True")
#     return await self._request("POST", f"/api/v1/orders/{order_id}/cancel", json={})
```

- Verification:
  - **AC-06 边界扫描**：grep 如上，仅 infrastructure/java 有类型签名
  - **AC-07 架构扫描 + Factory 行为**：
    - `grep -rn "from openai"` → 0 命中（仅注释允许，有则 grep 注释字符串不算代码 import）
    - `uv run python -c "from app.core.config import Settings; from app.infrastructure.llm.factory import LLMClientFactory; s=Settings(LLM_PROVIDER='mock'); c=LLMClientFactory.create(s); print(type(c).__name__)"` → 输出 `MockProvider`
    - 设 `LLM_PROVIDER=unknown_vendor` → 同一命令抛 AIConfigException 且 code=`AI-CONFIG-102`
  - **LLM 接口一致性（Mock.chat + structured）**：
    - `MockProvider(Settings(LLM_MODEL='mock-model')).chat([ChatMessage(role='user', content='Hello')]).message.content.startswith('[mock echo] Hello')` → True
    - `MockProvider.structured_chat([], PydanticModelA {a: int, b: str})` 返回的 model 对象类型正确、a=0、b=''
  - **Java Client 错误路径映射**：
    - 构造 httpx.MockTransport 处理 `/ok` 返回 200 + `{"success":true,"data":{"x":1}}` → JavaAPIClient._request("GET", "/ok") → 返回 `{"x":1}`
    - 处理 `/500` 返回 500 → 抛 AIJavaAPIException code=AI-JAVA_API-201
    - 处理 `/fail` 返回 400 + `{"success":false,"code":"PROD-042","message":"产品不存在"}` → 抛 AIJavaAPIException，code=AI-JAVA_API-202，message 原文包含 "PROD-042" + "产品不存在"
  - **X-Trace-Id 透传**：设置 `trace_id_var.set("my-trace-id-123")` 后，用 MockTransport 捕获请求 headers → `headers["X-Trace-Id"]` 精确等于 `my-trace-id-123`；且 `headers["X-Request-Source"]` = `"ai-service"`
  - **Error Case**: MockTransport 模拟网络异常 httpx.NetworkError → AI-JAVA_API-201 被抛出（捕获并比对 code）

---

### DU-AI-004：AI 工程 6 个边界位目录与 README 管理约定

- 目标仓库: repo-3（AI）
- Goal: 建立 6 个 M6 AI 扩展位的目录骨架 + README / __init__.py / .gitkeep，并在 README 中显式引用对应 `standards/engineering/ai/*.md` 规范 + 顶部大字警告"禁止在 M6 前写业务实现"，使架构红线 AC-11 / R-11 / R-13 由**结构**落实（不是靠自觉）。
- Scope（范围）：
  - `agents/__init__.py`：Module docstring 引用 `standards/engineering/ai/agent-framework-standard.md` + "属 M6 Agent 实现域。CHG 非 M6 AI 业务类 Change 禁止在此目录新增任何业务 .py 文件（除 __init__.py 外）。违规 = AC-11 Fail"
  - `agents/README.md`：复制文档内容，显式列出"允许创建 / 禁止创建的文件类型"；引用 `agent-framework-standard.md` 三原则（依赖倒置 / 状态图 / Mermaid 工作流）
  - `workflows/.gitkeep`：LangGraph 占位（M6）；不建任何 .py
  - `workflows/README.md`：引用 LangGraph 标准片段 + "M6 Workflow/State Machine 实施域，CHG-M0-xxx 禁止写任何 workflow 代码"
  - `tools/__init__.py`：Module docstring 引用 `standards/engineering/ai/tool-calling-standard.md` + "M6 Tool Calling 域。所有写操作 Tool schema 必须显式声明 `confirmation_required: bool = True`（对齐 design.md §2.9 cancel_order 注释锚点 R-07）。CHG-M0 禁止创建真实 Tool 实现"
  - `tools/README.md`：Tool Calling 标准文件格式约定（`description` / `input_schema` / `confirmation_required` 三必填字段）+ 引用标准
  - `prompts/README.md`：引用 `standards/engineering/ai/prompt-standard.md` 四原则（System Prompt/Template 版本 / 参数化命名）+ "业务代码中禁止硬编码 f-string Prompt Template（R-13 违规）。Prompt 文件必须放 prompts/ 目录，命名 = `<业务域>_<用途>_v<版本号>.jinja2`。M0 不创建任何 Prompt"
  - `prompts/.gitkeep`
  - `rag/.gitkeep`：RAG 占位（M6 向量库索引 / Embedding / 知识库召回域）
  - `rag/README.md`：引用 `standards/engineering/ai/rag-standard.md` 五组件（Document Load → Split → Embedding → Store → Retrieve）+ "M6 RAG 实施域，M0 不引入任何 Vector DB SDK"
  - `tests/__init__.py`：空占位（供 pytest 收测；与 DU-AI-005 的 tests 文件不冲突，DU-AI-005 负责写具体 test 文件）
- Design References: design.md §2.2 6 边界位目录的 AC-10 9 锚点 + AC-11 约束 / §2.9 Java Client 取消订单 confirmation_required=true 锚点（tools/README 中引用）/ R-11 禁提前实现 + R-13 Prompt 不在业务代码硬编 / standards/engineering/ai 6 规范（exploration 阶段知识检索注入）
- Dependencies: 无（与前面 DU 无文件依赖；但放第 4 位作为结构收尾，便于随后统一测 AC-11）
- Acceptance Criteria:
  - AC-11 静态扫描（骨架 + 边界检查）：
    - `find agents/ -name "*.py" ! -name "__init__.py" | wc -l` → **0**
    - `find tools/  -name "*.py" ! -name "__init__.py" | wc -l` → **≤ 1**（等于 0 更好）
    - `find workflows/ rag/ -name "*.py" ! -name "__init__.py" | wc -l` → **0**
    - `grep -rlnE "ProductAgent|OrderAgent|search_products|get_product_detail|compare_products|get_order|search_knowledge|RAGRetriever|LangGraphState" agents/ workflows/ tools/ prompts/ rag/` → **0 命中真实函数名**（注释/字符串文档中命中时需同时包含"属 M6，M0 未实现"这句话）
  - 6 个边界位目录的 README 都存在（agents/README.md 等 6 篇或按实际创建文件数 ≥ 5 篇），且每篇 README 正文至少包含一次对应规范文件名的引用（或等价中文标题引用）
  - `tools/__init__.py` / README 中**明确出现 `confirmation_required=True` 或 `confirmation_required: bool = True` 字样**（R-07 写操作二次确认锚点落实）
  - `prompts/README.md` 中**明确包含"禁止在业务代码中以 f-string 硬编码 Prompt"或等价表述**（R-13）
- Execution Order: 4
- Parallelization: 组 A（单）
- Implementation Sketch:

```text
repo-3 root
├── agents/
│   ├── __init__.py     # Module doc：引用 agent-framework-standard + M6 before rule
│   └── README.md       # Agent 框架三原则引用（可写 2-3 行说明，不许写伪代码）
├── workflows/
│   ├── .gitkeep
│   └── README.md       # 引用 LangGraph，M6 域声明
├── tools/
│   ├── __init__.py     # Module doc：tool-calling-standard.md 引用 + confirmation_required=True 强制
│   └── README.md       # 三必填字段：description / input_schema / confirmation_required
├── prompts/
│   ├── .gitkeep
│   └── README.md       # prompt-standard.md 引用 + 命名规则 + 禁 f-string 硬编码 Prompt（R-13）
├── rag/
│   ├── .gitkeep
│   └── README.md       # rag-standard.md 引用（五组件流程，M0 不引 Vector DB）
└── tests/__init__.py   # 占位。测试文件由 DU-AI-005 负责。
```

- Pseudocode: N/A（纯目录 + README/注释级文档创建，不涉及任何业务流程/算法/状态转换/多组件编排；README 只是引用规范的声明，不触发 complexity-trigger。骨架性结构任务。）
- Verification:
  - **Static Scan（AC-11 精确命中）**：按上面 AC-11 三条 find + 一条 grep 跑命令，退出码必须匹配（0 / ≤1 / 0 / 0）。全部记录到 Evidence Architecture Scan 条目
  - **README 存在检查**：列出 6 README（agents, workflows, tools, prompts, rag）全存在
  - **关键断言扫描（R-07 / R-13）**：
    - `grep -l "confirmation_required" tools/ -r` → 至少命中 tools 下一个文件
    - `grep -l "f-string\|硬编码.*Prompt" prompts/README.md` → 包含"禁止"或"不许"或等价中文
  - **Error Case**: 如果某 README 丢失或引用规范不到位 → 阻塞 DU-AI-005 因为 Architecture Scan 会跑扫

---

### DU-AI-005：Pytest 三用例实现 + Evidence 六组命令形成与日志归档

- 目标仓库: repo-3（AI）
- Goal: 交付 `tests/` 三个文件（conftest 三 fixtures + test_settings / test_health / test_llm_client），三个测试名精确匹配 PRD AC-09 的要求（`test_settings_load_from_env` / `test_health_endpoint_ok` / `test_llm_client_mock_returns_structured_response`）。同时交付 **Evidence 形成手册脚本与目录结构**：`evidence/` 目录 + `evidence/logs/`（按 DoD §26 提交 Evidence 时必须留日志，`delivery/archive/**/evidence/logs/` 在 `.gitignore` 中有例外）。六组命令（Environment/Dependency/Service/Health/Test/Architecture Scan）的具体命令串写入 README，sdd-dev 阶段即可按顺序执行 + 重定向日志归档。
- Scope（范围）：
  - `tests/conftest.py`：
    - `pytest_plugins = ["pytest_asyncio"]`（或由 pytest-asyncio auto mode 处理）
    - fixture `test_settings(monkeypatch)`：monkeypatch 注入最小 5 个 env 变量（APP_NAME=ai-service-test / LLM_PROVIDER=mock / JAVA_API_BASE_URL=http://localhost:1 / LLM_API_KEY=sk-test-key（Pydantic SecretStr 脱敏测试）/ LOG_LEVEL=WARNING）；返回 Settings() 实例验证
    - fixture `app(test_settings)`：调用 `create_app(test_settings)` 返回 FastAPI 实例（工厂函数来自 DU-AI-002 导出的 create_app）
    - fixture `client(app)`：httpx AsyncClient(transport=ASGITransport(app=app), base_url="http://test") + async with → yield
  - `tests/test_settings.py`：函数名 **精确** `test_settings_load_from_env` → 断言 settings.APP_NAME == "ai-service-test"，settings.LLM_PROVIDER == "mock"；SecretStr: `settings.LLM_API_KEY.get_secret_value()` == "sk-test-key"，`str(settings.LLM_API_KEY)` 包含 `***` 而非明文
  - `tests/test_health_endpoint.py`：函数名 **精确** `test_health_endpoint_ok` → `await client.get("/health")` → assert status_code=200；json() == `{"service":"ai-service","status":"UP"}`
  - `tests/test_llm_client.py`：函数名 **精确** `test_llm_client_mock_returns_structured_response` →
    - ① `MockProvider(settings).chat(...)` 返回 ChatResponse；`message.role == ASSISTANT`；内容以 "[mock echo]" 开头；usage 字段存在
    - ② 定义临时 Pydantic `SampleModel(ts: int, name: str)`；`structured_chat([], SampleModel)` 返回值的类型 == SampleModel；`ts` = 0；`name` = ""
  - `evidence/` 目录：
    - `evidence.yaml` 骨架（id 从 EV-001 递增、recorded-at ISO、type=code-change 或 test-run）→ M0 在 sdd-dev 阶段填充，此处仅建 skeleton
    - `evidence/logs/`（创建 `.gitkeep`）：明确"六组命令 stdout/stderr 按命令名分别归档到此目录，文件名 = `<YYYYMMDD-HHMMSS>_<命令名>.log`"
    - `README.md`（Evidence 操作手册）：列出六组命令与预期结果、重定向日志名、对 AC 的对应：
      - **Environment（Env/Python/uv）** → AC-01 Evidence：`uv run python --version > $LOG`；`uv --version >> $LOG`
      - **Dependency（uv sync）** → AC-02 Evidence：`uv sync --frozen > $LOG 2>&1`；`uv lock --check >> $LOG 2>&1`
      - **Service（启动）** → AC-03 Evidence：timeout 15s uv run uvicorn app.main:app --log-config /dev/null > $LOG 2>&1 &  （启动 10s 后 kill，日志含启动成功行）
      - **Health** → AC-04 Evidence：启动后 `curl -s -o $BODY -w "%{http_code}\n" http://127.0.0.1:8000/health > $LOG`；`cat $BODY >> $LOG`
      - **Test** → AC-09 Evidence：`uv run pytest -q > $LOG 2>&1`（退出码 0）；同时执行 `uv run ruff check app tests >> $LOG` + `uv run pyright >> $LOG`（质量三命令）
      - **Architecture Scan** → AC-07/AC-08/AC-11 Evidence：写一个 `arch_check.sh / arch_check.ps1`（PowerShell 版本）跑三条 grep 并把结果写入 $LOG，全部退出码 0（或预期计数）
- Design References: design.md §2.11 tests 三用例精确名 / §3.1 涉及模块（tests/ 四文件 = conftest + 三测）/ §2.10 命令约定表（7 命令，本 DU 只列出执行 Test+Arch 三条）/ R-12 Evidence 诚信（README 中用大号文字警告：「任何命令未实际执行不得标记为 PASS」）/ §二十六 Evidence 提交规则
- Dependencies: DU-AI-001（pytest/ruff/pyright 已在 pyproject.toml dependency-groups.dev 声明）+ DU-AI-002（create_app 工厂已导出；test_settings / test_health 依赖 Settings / FastAPI）+ DU-AI-003（MockProvider / LLMClient 类型 + JavaAPIClient 已存在）+ DU-AI-004（AC-11 Architecture Scan 需要边界位骨架已就位）
- Acceptance Criteria:
  - AC-09: `uv run pytest -q` → 退出码 0；测试数量 ≥ 3（实际 3 个精确名 + 可选补充但必须 ≥3）；三函数名完全匹配：`test_settings_load_from_env` / `test_health_endpoint_ok` / `test_llm_client_mock_returns_structured_response`；pytest -v 输出中这三个名字各出现一次
  - 三个测试文件内容通过「单测的单测」：
    - 断言语义覆盖（SecretStr 脱敏 / Health 200 / Structured 返回类型）
  - `evidence/` 目录与文件骨架存在（evidence.yaml + evidence/logs/.gitkeep + README）；`arch_check.ps1`（PowerShell 版 Windows 脚本）已写入 evidence/ 目录（或 tests 根目录）
- Execution Order: 5
- Parallelization: 组 A（单）
- Implementation Sketch:

```text
tests/
├── __init__.py          # 来自 DU-AI-004 骨架占位
├── conftest.py          # test_settings(monkeypatch) / app(test_settings) / client(app) 三 fixture
├── test_settings.py     # test_settings_load_from_env → SecretStr 脱敏 + APP_NAME/Provider 值覆盖
├── test_health_endpoint.py  # test_health_endpoint_ok → /health 200 + JSON精确字段名
└── test_llm_client.py   # test_llm_client_mock_returns_structured_response
                          # ① Mock.chat() → ChatResponse；② structured_chat(SampleModel {ts:int,name:str}) → 类型正确+默认值

evidence/
├── evidence.yaml        # 初始骨架：空条目，sdd-dev 按 EV-001~N 填
├── logs/.gitkeep
├── README.md            # 六组命令具体命令串（Windows PowerShell 兼容语法）+ 重定向 $LOG 文件名模板
└── arch_check.ps1       # Architecture Scan 三条 grep + 预期退出码（PowerShell 兼容）
```

- Pseudocode: N/A（pytest 测试用例是声明式 `assert` + fixtures 装配；不包含复杂 business-flow/algorithm/state-transition/orchestration 逻辑。Fixture 与 Test 只是对前面 DU 的断言，不属于「需要逻辑流程图指导」的复杂度触发器；Guidance 已在 Verfication 给出具体断言）
- Verification:
  - **Pytest 三用例全通过**：`uv run pytest -q` 退出码 0；`-v` 输出出现三个精确函数名
  - **质量三命令**：
    - `uv run ruff check app tests` → exit 0（无 E* 错误）
    - `uv run pyright` → exit 0（strict 模式下无类型错误）
    - `uv run ruff format --check app tests` → exit 0
  - **Evidence 手册可执行验证**：手动跑 `evidence/arch_check.ps1`（PowerShell）→ 预期三条 grep 全 PASS
  - **Error Case**: pytest 报 `ImportError: cannot import name 'create_app' from 'app.main'` → 阻塞；回到 DU-AI-002 的 main.py export 检查 create_app 已导出

---

## 覆盖率矩阵

### 设计变更点覆盖（design.md §2.x 每个变更点 → 归属 DU，1:1 或 N:1，不允许遗漏）

| design.md §2.x 变更点章节 | 归属 DU |
|---|---|
| §2.2 工程目录结构（仓库根 7 个文件 + 6 边界位 + app/ 9 锚点） | DU-AI-001（根文件）+ DU-AI-002（app core/api/mw/services）+ DU-AI-003（infrastructure）+ DU-AI-004（边界位） |
| §2.3 技术栈与版本策略（Python3.11/uv/hatchling/FastAPI/httpx/Ruff 0.6+/Pyright strict） | DU-AI-001（pyproject.toml 全部声明 + .python-version） |
| §2.4 Lifespan 5 步启动顺序 + shutdown 对称 `.aclose()` | DU-AI-002（main.py create_app/lifespan 装配 + Pseudocode 精确步序） |
| §2.5 API 契约（health endpoint）+ UnifyResult 5 字段 + `AI-<CAT>-NNN` 错误码分配表（5 类首码） | DU-AI-002（health.py Router + Exception Handlers）+ DU-AI-003（Java 201/202 码注入） |
| §2.6 Settings 13 字段 + SecretStr + model_config env_file=".env" | DU-AI-001（.env.example 模板）+ DU-AI-002（core/config.py 真实定义） |
| §2.7 LOG_FORMAT 最终字符串 / TraceIdFilter + 脱敏正则 / TraceIdMiddleware 6 步 / uvicorn log_config=None 接管 | DU-AI-002（core/logging.py + middleware/trace_logging.py + main.py create_app） |
| §2.8 LLMClient ABC + 4 Pydantic 模型 + PROVIDER_REGISTRY dict + Factory create + MockProvider 三方法 | DU-AI-003（infrastructure/llm/* 全套 + Pseudocode） |
| §2.9 JavaAPIClient 四扩展参数位 + _request 统一入口 + 错误 201/202 映射 + X-Trace-Id 注入 + cancel_order 注释锚点 | DU-AI-003（infrastructure/java/client.py 全套 + Pseudocode） |
| §2.10 Ruff 10 规则子集 select / Pyright strict / 全部集中 pyproject.toml + 7 命令约定 | DU-AI-001（配置声明）+ DU-AI-005（Evidence README 列出 Test+Arch 命令执行） |
| §2.11 Pytest 三用例（Settings/Health/LLM）+ conftest 三 fixture | DU-AI-005（tests/ 三文件 + 三函数精确名） |

### 仓库覆盖

affected-repositories: **[repo-3]** → DU-AI-001 ✓ / DU-AI-002 ✓ / DU-AI-003 ✓ / DU-AI-004 ✓ / DU-AI-005 ✓（5 个 DU 全部在 repo-3，符合 Phase 2.4 「每个仓至少 1 个 DU」规则）

### PRD 验收标准覆盖（11 条 AC → 归属 DU 矩阵）

| AC | 归属 DU（主要验证） | 说明 |
|---|---|---|
| AC-01 Python 版本（.python-version 精确 "3.11" / uv run python --version） | DU-AI-001 | 建 `.python-version`；Evidence 验证命令 |
| AC-02 uv 依赖管理（pyproject/uv.lock + uv sync --frozen 0） | DU-AI-001 + DU-AI-005 Evidence | 001 建文件 + 005 README 列出 uv sync 命令串 |
| AC-03 FastAPI 可启动（uvicorn 日志 + Ctrl+C 优雅退） | DU-AI-002（create_app/uvicorn log_config=None）+ 005 Service Evidence | 002 建入口；005 README timeout 15s 启动并 kill 日志验证 |
| AC-04 Health API 200 + JSON 字段精确 | DU-AI-002（health.py Router）+ 005 curl 命令 | 002 端点；005 Evidence 脚本 curl 并重定向 |
| AC-05 配置+凭据安全（.env.example 13 字段/SecretStr/.gitignore 屏蔽 .env + 扫描 0 密文命中） | DU-AI-001（模板/.gitignore）+ DU-AI-002（config.py SecretStr）+ 005 Arch Scan 脚本 grep | 三方协同落实 AC-05 三要求 |
| AC-06 Java API Client 边界（仅 infrastructure 实例化 httpx.AsyncClient + 签名四扩展位） | DU-AI-003（JavaAPIClient 类）+ 005 Arch Scan 脚本 grep "httpx.AsyncClient(" 精确位置 | 003 代码；005 grep 命令 + 预期命中数（=2 处：lifespan + JavaAPIClient 类型签名，无其他） |
| AC-07 LLM 抽象依赖倒置（业务零 from openai + Factory 映射 mock/unknown） | DU-AI-003（infrastructure/llm/* + Factory Pseudocode）+ 005 Arch Scan 脚本 grep + pytest mock_vendor 测试 | 003 Factory.create 逻辑；005 Arch Scan 禁 provider SDK 裸 import |
| AC-08 AI 数据边界（零 Python DB Driver 依赖 / 零 connect() 代码） | DU-AI-001（pyproject dependencies 零引入）+ DU-AI-005 Arch Scan 脚本 grep pymysql/psycopg/sqlalchemy | 001 配文件；005 grep 双验证 |
| AC-09 Test（pytest 三用例名精确 + 退出码 0） | DU-AI-005（tests/ 三文件） | 直接在本 DU 定义三用例 |
| AC-10 工程可维护性（9 职责目录 + main.py ≤ 50 行=目标 ≤40） | DU-AI-001~004（各 DU 负责目录创建）+ DU-AI-005 Arch Scan 脚本 find 列目录 + wc -l main.py | 四 DU 联合创建目录；005 脚本统一验收 |
| AC-11 不提前实现 AI 业务（边界位 SLOC 限额 + ProductAgent 等 grep 0 命中） | DU-AI-004（骨架 + README 声明）+ DU-AI-005 Arch Scan 脚本 grep + find 计数 | 004 结构；005 验证命令脚本 |

→ **覆盖检查：11 条 AC 全部至少 1 个 DU 归属，无遗漏**。

### DoD（REG-M0-003 §二十四 28 项 DoD → 归属 DU 概述）

（清单级概述，不逐项展开避免冗余）
- DoD 1~13（Environment/uv/依赖/SCM/配置/健康/日志/异常/Java/LLM/接口/Agent边界/Prompt）：DU-AI-001~004 分段交付
- DoD 14~23（目录分层/分层纪律/质量四工具：Ruff/Pyright/Pytest/format、测试三用例最低数、启动/退出、凭据/部署参数走 Settings）：DU-AI-001 + 005
- DoD 24~28（凭据不入库/AC 全部通过、命令可复现、Evidence 诚信、日志归档到 evidence/logs/）：DU-AI-005 Evidence README + arch_check.ps1

## 依赖与跨仓契约

- **接口契约**：
  - 单仓实现，无代码层面跨仓代码调用；但运行时依赖 repo-1 mall-gateway（`JAVA_API_BASE_URL=http://localhost:8080` design.md §4 跨仓契约）。M0 不阻塞（JavaAPIClient 用 mock transport 验证）
  - `X-Trace-Id` header 名统一 + UnifyResult 响应 5 字段形状 = 与 Java 侧一致（CHG-0003 design 契约）
  - 凭据（LLM_API_KEY / Java 内部 Token）全走 Settings + .env（gitignore），与前后端的凭据纪律一致
- **仓库依赖方向**：repo-3 → repo-1（运行时 HTTP 依赖）；repo-1 / repo-2 零回退（本 Change 不修改任何 Java/前端仓库文件，du-coverage 机检不涉及）
- **集成边界**：JAVA_API_BASE_URL 默认值 / JAVA_API_TIMEOUT 默认值；M6 正式 AI 业务时在独立 Change 中扩展 PROVIDER_REGISTRY 与 JavaAPIClient 的业务方法（不影响本次 5 DU 交付）
- **跨仓时序**：M0 基线可与 CHG-0001~0004 后的任何 Java 代码版本并行（无需 gateway 在线）；M6 AI 业务必须先冻结对应 Java 内部 API 契约后进入对应的 AI Change 开发；写操作链路（取消/修改订单）必须满足：M1+ 身份 Change 交付内部 JWT → Java 写 API 带 confirmation_required → Tool schema 声明 → LLM 确认 → 二次确认字段传 True。时序不阻塞本 Change。

## 风险缓解映射到 DU

| design.md §6 风险表 10 条（按出现顺序） | 负责 DU（落实缓解措施） |
|---|---|
| Python 3.11/uv 执行环境不可用 → 缓解：Environment Evidence 记录 FAIL/实测版本 | DU-AI-005 Evidence README（Environment 组命令） |
| PyPI 超时导致 uv sync 失败 → 缓解：`UV_INDEX_URL` 切换中科大镜像；Evidence 记录失败原文 | DU-AI-001（README 快速开始写明 env 切换）+ 005 说明 |
| Pyright strict 级别报错 → 缓解：reportMissingTypeStubs=false + M0 文件量小（<500 SLOC）可逐文件过 | DU-AI-001（pyproject.toml 已设 reportMissingTypeStubs=false）；005 README 指明 pyright 先行命令 |
| 架构红线突破：直连 DB/提前写 M6 → 缓解：Ruff 自定义规则位 + grep 命令 Architecture Scan | DU-AI-005（`arch_check.ps1` 三条 grep = AC-07/08/11；正则库 pymysql/psycopg + 边界位 SLOC 计数） |
| 日志泄露 LLM_API_KEY → 缓解：SecretStr + logging MaskingFilter sk- 正则脱敏 | DU-AI-002（core/logging.py FILTER_MASKED；Pseudocode 测试用 `sk-` 键触发日志脱敏）；005 README 中列「日志泄露专项检查」命令 |
| X-Trace-Id contextvar 丢失 → 缓解：background 任务（M6）用 copy_context()；M0 仅 HTTP 同步链路 → 0 风险 | DU-AI-002（Middleware Pseudocode 中 trace_id_var.reset(token) 明确书写，防上下文泄漏）；005 grep 验证 响应头 `X-Trace-Id` 存在 |
| harness bug：reason 含冒号破坏 YAML → 缓解：写 metadata 时 reason 一律加双引号 | 不是 DU 层面任务（属 Workspace 操作，本 Change 已在 sdd-explore/prd/design 三处人审 writeHumanGate 时全部遵守；tasks 阶段 Gate 时仍遵守）。作为「DU-Global Checklist 公共项」挂在 DU-AI-005 Gate approve 自查清单。 |
| 首次推送权限/网络失败 → 缓解：按用户 Profile 「对外/推送等难逆操作先询问」，不自动 push | DU-Global（不由 tasks 控制）。在 DU-AI-005 验收后，提交到 repo-3 本地前先询问用户确认是否允许 commit。 |
| 6 个边界位目录被误写业务代码 → 缓解：README 顶部大字警告 + 静态扫描 AC-11 = 0 命中 | DU-AI-004（5 README 声明）+ DU-AI-005（arch_check.ps1 grep "ProductAgent" + find 计数 SLOC） |
| uvicorn 默认 access log 与 Middleware 日志重复 → 缓解：uvicorn.run `log_config=None` + setup_logging 统一接管 uvicorn logger | DU-AI-002（main.py 启动 Pseudocode 中传 `log_config=None`；README 中启动命令写明 `--log-config /dev/null` 或等价空 dict） |

## 全局检查清单（质量自检对齐 SKILL.md §4 14 项 + 2 条行为约束）

- [x] affected-repositories=[repo-3] 的每个仓均有 DU：repo-3=5 个 DU ✓
- [x] 每个 DU 1:1 一仓库：全 repo-3 ✓
- [x] DU ID 唯一规范（AI 别名合理合法，SKILL.md §2.1 缺省规则；DU-AI-001~005 无重复）✓
- [x] design.md 每个 §2.x 变更点 → 落入某 DU Scope（见覆盖率矩阵 §2.x 10 行）✓
- [x] PRD 11 AC 均映射到 DU（覆盖率矩阵 11 行覆盖 AC 1~11）✓
- [x] 跨仓依赖无循环（repo-3 → repo-1 单向，无反向）✓
- [x] 5 DU 全部有非空 Implementation Sketch（含 2 个 ASCII 图 + 3 个结构描述）✓
- [x] complexity-trigger：DU-AI-002 orchestration（lifespan 7 异常 Handler + Middleware）+ DU-AI-003 business-flow+orchestration（_request 7 分支 + Factory create）→ 均写完整 Pseudocode 主流程 + 异常分支；其他 3 个 DU Pseudocode=N/A 且给出理由（纯配置/骨架/声明式）✓
- [x] 伪代码未引入 design.md 之外的新接口/新表：cancel_order 仅注释（design.md §2.9 已有）；Error 码 201/202 与 design.md §2.5.3 分配表完全一致；Provider 注册只扩 mock 一条 → design.md §2.8 PROVIDER_REGISTRY={"mock": MockProvider} 一致 ✓
- [x] 未下沉系统级决策到 DU：所有决策在 design.md 有锚点（Python 3.11、pyproject 集中配置、错误码值、X-Trace-Id 名等）✓
- [x] 5 DU 全部有非空 Verification 清单（含命令/grep/断言/Error Case）✓
- [x] 5 DU 描述足够详细（sdd-dev 拿 tasks.md 与 DU 子 metadata 即可实施，无需回读整个 design.md 正文 + 全部 standards 正文 → 因为每个 DU Design References 都引用了具体 design.md 子节号）✓
- [x] 不修改 design.md / prd.md / requirement.md / exploration.md（本阶段仅新增 tasks.md 到 STORY 目录；遵守行为约束 298-300 条）✓
- [x] 未写 implementation/ 任何代码（遵守行为约束 300-301：sdd-dev 再落）✓
- [x] 未调用 `openspec du create` 或 materialize（遵守行为约束 302-304：用户 Gate 批准后再 `du create` 5 条）✓
- [x] feature-path 已在 explore 阶段 bind 为（工程基础>AI工程基线>AI应用骨架>STORY-1-02-01-01）且 candidate=false ✓
