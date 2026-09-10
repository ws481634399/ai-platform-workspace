---
id: "REQ-M0-003"
name: "AI Service 基础工程（Python FastAPI + uv 独立基线）"
content: "建立 AI 智能电商微服务平台独立的 Python AI Service 工程基线（独立仓 repo-3），为后续 AI 智能导购、商品对比、RAG 智能客服、订单助手和 Agent Workflow 等能力提供统一运行基础。覆盖 Python 3.11 工具链、uv 依赖管理、FastAPI HTTP 服务、配置/日志/异常/健康检查、LLM Client 抽象、Java Backend API Client 抽象、AI Tool/Agent/Workflow/RAG/Prompt 工程边界、Pytest 测试基础与代码质量基线。单个完整 SDD Change 管理（M0，P0，repo-3 implementation/ai-platform-ai-service/**）"
source: user
created-at: "2026-09-04T13:50:00+08:00"
---

# Requirement

> 本文件记录需求来源原文，由 sdd-explore 在探索阶段写入。
> 与 exploration.md 分离：本文件是输入沉淀，exploration.md 是分析产物（Feature 归属/影响分析）。
> 原始需求文档（1117 行）已完整归档至 `references/REG-M0-003.md`，未做改写；本文件为结构化导航摘录。

## 需求描述

> 以下为需求文档关键内容的忠实摘录（保持原话，未做改写），完整原文以 `references/REG-M0-003.md` 为准。

**Requirement ID**：REQ-M0-003；**名称**：AI Service 基础工程；**Stage**：M0 项目初始化；**Priority**：P0；**前置依赖**：无强依赖，可与 REQ-M0-001、REQ-M0-002、REQ-M0-004 并行开发；**Repository**：AI Service 独立代码仓库 repo-3 `implementation/ai-platform-ai-service`；**远程地址**：https://github.com/ws481634399/ai-platform-AIService.git

**管理方式**：本 Requirement 作为一个完整 SDD Change 一次性建立 AI Service 单仓 Python 工程基线，不拆成多个独立 Change（§二十三）。

### 一、需求目标

建立 AI 智能电商微服务平台独立的 Python AI Service 工程基线，为后续 AI 智能导购、商品对比、RAG 智能客服、订单助手和 Agent Workflow 等能力提供统一运行基础。完成本需求后，AI Service 应具备：独立 Python 工程；独立依赖管理；独立启动能力；FastAPI HTTP 服务；配置管理；日志能力；健康检查；LLM Client 抽象；Java Backend API Client 抽象；AI Tool 扩展基础；自动化测试基础；环境变量与密钥管理；可独立构建和运行的工程规范。本需求只建立 AI 工程基础，不实现正式 AI 业务功能。

### 二、技术基线

统一采用 Python 3.11 + uv + pyproject.toml + uv.lock + FastAPI + Pydantic + Pytest；HTTP Client 采用适合异步 FastAPI 服务的 HTTPX；后续 AI 能力规划使用 LangGraph / Tool Calling / LLM Provider SDK / Embedding / Vector Database / RAG（M0 不要求将这些能力全部实现）。

### 三、Python 版本管理与依赖管理

固定使用 Python 3.11，.python-version 文件声明 `3.11`，开发环境通过 uv 创建和使用项目独立 Python 环境；依赖管理使用 uv + pyproject.toml + uv.lock，禁止同时维护 requirements.txt / Poetry / Pipenv / Conda 等竞争体系；uv.lock 必须提交 Git，.venv/ 不提交 Git。

### 四、工程结构与 FastAPI 应用基础

清晰分层结构（app/main.py + api/ + core/ + schemas/ + agents/ + workflows/ + tools/ + rag/ + prompts/ + models/ + infrastructure/ + tests/），**禁止为匹配模板创建大量长期为空的目录和文件**（§五）。FastAPI 至少提供 Application 创建入口、API Router、配置加载、应用启动、基础异常处理与健康检查接口 `GET /health`（返回 service + status）。M0 不需要创建 AI Chat 等正式业务接口。

### 五、配置管理与日志能力

统一配置来源支持环境变量 + .env 本地开发配置；至少为 APP_NAME/APP_ENV/APP_HOST/APP_PORT、JAVA_API_BASE_URL、LLM_PROVIDER/LLM_API_KEY/LLM_MODEL、EMBEDDING_PROVIDER/EMBEDDING_MODEL 等配置预留能力；必须提供 .env.example；真实 API Key / Token / Password / Secret 不得提交 Git。日志至少支持日志级别、时间、Logger Name、请求基础信息、异常日志、TraceId 扩展能力；不得直接打印 LLM API Key / Access Token / Password / Secret / 完整敏感用户数据；为 Java → AI → LLM 调用链 Trace 传播预留能力。

### 六、LLM Client 抽象与 Java Backend API Client 抽象

LLM 调用基础抽象，推荐依赖方向为 Agent/Workflow → LLM Client Interface → Provider Adapter → Provider SDK；业务 Agent 不应到处直接实例化 ProviderClient 或直接读取 LLM_API_KEY；M0 可以只提供接口和最小实现骨架。AI Service 不直接访问 Java 微服务数据库，获取商品/SKU/订单/用户/库存等业务数据时必须通过 Java Backend 提供的 API，因此建立统一 Java API Client 基础，预留 Base URL / Timeout / Header / TraceId / 身份信息 / 错误转换 / 重试策略扩展；M0 不需要实现正式的 ProductClient/OrderClient/InventoryClient 完整业务能力。

### 七、AI Tool / Agent / Workflow / Prompt / RAG 扩展边界

后续 Tool 可能包含 search_products、get_product_detail、compare_products、get_order、search_knowledge 等，但本阶段只建立 Tool 的工程边界和组织方式，**禁止 M0 为了展示提前写大量假业务 Tool**（§十一）。为 LangGraph / Agent Workflow 预留工程能力，明确 agents/、workflows/、tools/、prompts/、rag/ 各目录职责；Prompt 不应大量硬编码在 service.py / agent.py / router.py 等业务逻辑中，应提供独立管理位置（System Prompt / Prompt Template / Prompt Version / 参数化 Prompt）。M0 只建立管理约定，不提前创建正式 AI 业务 Prompt。

### 八、异常处理、测试基础与代码质量

建立 AI Service 基础异常体系，至少区分参数错误、配置错误、Java API 调用失败、外部 AI Provider 调用失败、系统内部异常；API 不应直接向调用方暴露完整 Python StackTrace；日志中不得泄露敏感数据。Pytest 测试能力至少包含 Pytest 配置、FastAPI 基础测试、Health API 测试、配置加载测试、基础 Client 可测试结构；测试应支持 `uv run pytest`。代码质量至少具备代码检查、格式检查、类型检查、测试等基本工程能力，可以在 Design 阶段选择 Ruff / Pyright / 其他必要工具，**不要同时安装大量重复作用的 Python 工具**（§十六）。

### 九、与 Java 后端的边界与写操作安全边界

必须明确：Java Backend = 业务权威数据和业务规则；AI Service = AI 推理、Agent、Workflow、RAG、Tool Orchestration；AI Service 不成为第二套业务系统；禁止 AI Service 直接连接 Java 业务数据库；禁止直接修改商品/订单/库存表；正确方式为 AI → Tool → Java API → Java Domain。后续涉及取消订单、修改订单、修改用户数据等高风险写操作必须经过 Agent → Tool → Java Backend API 链路，不能由模型直接操作数据存储，高风险写操作应为二次确认机制预留能力。

### 十、建议 SDD Task / Delivery Unit 划分（单 Change 内）

TASK-001 Python / uv 工程基线 / TASK-002 FastAPI Application 基础 / TASK-003 Config / Environment 基础 / TASK-004 Logging / Exception 基础 / TASK-005 LLM Client / Java API Client 抽象 / TASK-006 Agent / Tool / Workflow 工程边界 / TASK-007 Pytest / Code Quality / TASK-008 Build / Run / Evidence。可进一步形成 DU：DU-AI-001 Python Foundation、DU-AI-002 API Foundation、DU-AI-003 Integration Foundation、DU-AI-004 AI Architecture Foundation、DU-AI-005 Test & Verification。具体划分由 Design 阶段确定，不要拆成多个独立 Change。

### 十一、验收标准（AC-01 ~ AC-11）

AC-01 项目固定使用 Python 3.11，可通过 uv 正常使用；
AC-02 存在 pyproject.toml + uv.lock，执行 `uv sync` 成功；
AC-03 AI Service 可以独立启动（如 `uv run uvicorn app.main:app --reload`）；
AC-04 访问 GET /health 能够获得正常健康响应；
AC-05 配置能够从环境变量加载，不存在真实 API Key/Password/Token/Secret 提交到 Git；
AC-06 存在统一 Java Backend HTTP Client 基础，业务代码不需要自行重复创建 HTTP Client；
AC-07 存在清晰 LLM Client 抽象，Agent/Workflow 不与具体 Provider 强绑定；
AC-08 AI Service 中不存在直接连接 Java 业务数据库的实现；
AC-09 执行 `uv run pytest` 已有测试全部通过；
AC-10 至少能够明确区分 API / Config / Infrastructure / Agent / Workflow / Tool / Prompt / RAG / Test 等职责，不得将全部代码堆积在 main.py 中；
AC-11 不存在为了 M0 验收提前实现的大量 Product Agent / Order Agent / RAG / Vector DB / 正式 Prompt 业务代码。

### 十二、Definition of Done 与 Evidence

DoD（28 项）：Python 3.11 基线完成、uv 管理完成、pyproject.toml 完成、uv.lock 生成、.python-version 完成、.gitignore 完成、.env.example 完成、FastAPI Application 完成、Router 基础完成、Health API 完成、Config 基础完成、Logging 基础完成、Exception 基础完成、LLM Client 基础抽象完成、Java API Client 基础抽象完成、Agent/Workflow/Tool 边界明确、Prompt 管理边界明确、RAG 扩展位置明确、Pytest 基础完成、Health API 测试通过、代码质量工具可以执行、uv sync PASS、AI Service 启动 PASS、uv run pytest PASS、AI Service 未直接访问 Java 业务数据库、Git 中不存在真实 Secret、未提前实现 M6 AI 业务、实际测试结果形成 Evidence。

Evidence 至少记录 Environment（Python Version / uv Version）、Dependency（uv sync PASS/FAIL）、Service（启动 PASS/FAIL）、Health（GET /health PASS/FAIL）、Test（uv run pytest PASS/FAIL）、Architecture Check（六项架构合规检查）；**任何未实际执行的验证不得记录为 PASS**（§二十六）。

### 十三、非本需求范围（§二十二）

AI 智能导购、商品自然语言搜索、AI 商品对比、RAG 知识库、Embedding、Vector Database、AI 客服、AI 订单助手、多 Agent、正式 LangGraph Workflow、Prompt Evaluation、AI Monitoring、AI 写订单能力。这些由 M6 及后续 Requirement 完成。

## 补充信息

- 需求来源：`docs/需求/M0/REG-M0-003.md`（原始文档 1117 行，已完整归档至本 Change `references/REG-M0-003.md`；文件名前缀 REG- 为需求文档命名习惯，文档内部自标识为 REQ-M0-003）
- 关联历史：无 AI 独立仓相关已归档 Change（CHG-0001/0002/0003 均为 Java 后端工程需求，CHG-0004 为前端工程基线；本 Change 独立实现 repo-3，通过 Java Gateway API 与后端微服务联调，M0 不要求后端完成即可推进）
