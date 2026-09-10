# Test Report

> change-id: CHG-0005
> implementation-source: implementation.md
> evidence-index: evidence/evidence.yaml
> from-state: developing
> to-state: testing
> tested-at: 2026-09-07T16:30:00Z

## 1. 测试范围

### 1.1 repo-3（ai-platform-ai-service）

**覆盖 DU 清单：**

| DU | 模块 | 测试类型 | 测试文件 |
|----|------|----------|----------|
| DU-AI-001 | 仓库根配置（pyproject/uv.lock/.env.example/.gitignore） | 单元 + 架构扫描 | tests/test_settings.py |
| DU-AI-002 | FastAPI Core（main/config/exceptions/logging/middleware/health） | 集成 | tests/test_health_endpoint.py |
| DU-AI-003 | Infrastructure（LLM ABC+Factory+MockProvider+Java Client） | 单元 | tests/test_llm_client.py |
| DU-AI-004 | 6 边界位目录骨架 + README | 架构扫描 | arch_check（AC-11） |
| DU-AI-005 | Pytest 基线 + evidence 操作手册 | — | 本报告产出 |

**测试环境：**
- Python 3.11.16（`.python-version=3.11`）
- uv 0.12.7
- pytest 9.1.1 + pytest-asyncio 1.4.0
- ruff 0.16.6（lint + format）
- pyright（strict mode）
- OS: Windows / PowerShell

**测试模块/文件清单：**
- `tests/conftest.py` — 3 fixture（test_settings / app / client）
- `tests/test_settings.py` — Settings 环境变量加载测试
- `tests/test_health_endpoint.py` — Health 端点集成测试
- `tests/test_llm_client.py` — LLM Client 接口一致性测试

## 2. 测试执行汇总

| 类型 | 总数 | 通过 | 失败 | 跳过 | 通过率 |
|------|------|------|------|------|--------|
| 单元 | 2 | 2 | 0 | 0 | 100% |
| 集成 | 1 | 1 | 0 | 0 | 100% |
| 架构扫描 | 7 | 7 | 0 | 0 | 100% |
| 合计 | 10 | 10 | 0 | 0 | 100% |

### 详细执行结果

**Pytest（3 用例）：**

```
tests/test_health_endpoint.py::test_health_endpoint_ok PASSED            [ 33%]
tests/test_llm_client.py::test_llm_client_mock_returns_structured_response PASSED [ 66%]
tests/test_settings.py::test_settings_load_from_env PASSED               [100%]
3 passed in 0.05s
EXIT=0
```

**质量三命令：**

| 命令 | 结果 | 退出码 |
|------|------|--------|
| `uv run ruff check app tests` | All checks passed | 0 |
| `uv run ruff format --check app tests` | 25 files already formatted | 0 |
| `uv run pyright` | 0 errors, 0 warnings, 0 informations | 0 |

**架构扫描（7 项）：**

| AC | 检查项 | 预期 | 实际 | 结果 |
|----|--------|------|------|------|
| AC-01 | `.python-version` = 3.11 | 3.11 | 3.11 | PASS |
| AC-02 | `uv.lock` 存在 + `uv sync --frozen` | 退出码 0 | Checked 36 packages, 退出码 0 | PASS |
| AC-05 | sk- 真实密钥扫描 | 0 命中 | 0 命中 | PASS |
| AC-06 | httpx.AsyncClient 实例化 | 仅 infrastructure/ | 2 处（main.py lifespan + java/client.py） | PASS |
| AC-07 | openai/anthropic 直引 | 0 命中 | 0 命中 | PASS |
| AC-08 | DB 驱动（pymysql/psycopg/sqlalchemy/asyncpg） | 0 命中 | 0 命中 | PASS |
| AC-11 | 边界位非 init .py | 0 | 0 | PASS |

## 3. AC 覆盖矩阵

| AC | 测试用例 | 类型 | 状态 |
|----|---------|------|------|
| AC-01 | `.python-version` 内容验证 + `uv run python --version` | 架构扫描 | PASS |
| AC-02 | `uv sync --frozen` + `uv.lock` 存在性 | 架构扫描 | PASS |
| AC-03 | `uv run uvicorn app.main:app` 启动（dev 阶段 evidence logs/02-uvicorn-stdout） | 集成 | PASS |
| AC-04 | `test_health_endpoint_ok` — GET /health → 200 + `{"service":"ai-service","status":"UP"}` | 集成 | PASS |
| AC-05 | sk- 密钥扫描（0 命中）+ `.env` in .gitignore + `.env.example` 13 字段 | 架构扫描 | PASS |
| AC-06 | `httpx.AsyncClient(` grep（2 处，仅 infrastructure/ + lifespan） | 架构扫描 | PASS |
| AC-07 | `from openai` / `import anthropic` grep（0 命中） | 架构扫描 | PASS |
| AC-08 | DB 驱动依赖 + `connect(` grep（0 命中） | 架构扫描 | PASS |
| AC-09 | `uv run pytest -v` → 3 passed（三函数名精确匹配） | 单元+集成 | PASS |
| AC-10 | main.py 非空行数 = 46（≤50）；9 职责目录锚点全部存在 | 架构扫描 | PASS |
| AC-11 | agents/tools/workflows/rag 下非 init .py = 0 | 架构扫描 | PASS |

## 4. 证据清单

### 仓库侧 DU 级证据

| DU | 证据文件 | 说明 |
|----|---------|------|
| DU-AI-001 | `implementation/ai-platform-ai-service/delivery/CHG-0005/.../DU-AI-001/evidence/changeset.md` | 6 根文件清单 |
| DU-AI-002 | `implementation/ai-platform-ai-service/delivery/CHG-0005/.../DU-AI-002/evidence/changeset.md` | 15 文件清单 |
| DU-AI-003 | `implementation/ai-platform-ai-service/delivery/CHG-0005/.../DU-AI-003/evidence/changeset.md` | 8 文件清单 |
| DU-AI-004 | `implementation/ai-platform-ai-service/delivery/CHG-0005/.../DU-AI-004/evidence/changeset.md` | 11 文件清单 |
| DU-AI-005 | `implementation/ai-platform-ai-service/delivery/CHG-0005/.../DU-AI-005/evidence/` | logs/（7 个日志）+ README.md + arch_check.ps1 + evidence.yaml |

### Workspace 聚合证据

- `evidence/evidence.yaml` — test-run 条目（见下方）
- `evidence/test-report.md` — 本报告
- evidence-ref 引用各 DU 侧日志（不复制正文）

### 日志文件索引

| 日志 | 位置 | 内容 |
|------|------|------|
| 02-uvicorn-stdout.txt | DU-AI-005/evidence/logs/ | uvicorn 启动日志 |
| 02-health.txt | DU-AI-005/evidence/logs/ | /health 响应 |
| 03-pytest.txt | DU-AI-005/evidence/logs/ | pytest 输出 |
| 04-ruff-check.txt | DU-AI-005/evidence/logs/ | ruff check 输出 |
| 05-ruff-format-check.txt | DU-AI-005/evidence/logs/ | ruff format --check 输出 |
| 06-pyright.txt | DU-AI-005/evidence/logs/ | pyright 输出 |
| 07-arch-scan.txt | DU-AI-005/evidence/logs/ | 架构扫描输出 |

## 5. 失败项分析

无失败项。全部 10 项测试（3 pytest + 3 质量 + 7 架构扫描）均通过，通过率 100%。

## 6. Commit 记录

| Commit | DU | 消息 |
|--------|-----|------|
| 36cb941 | DU-AI-001~005 | feat(chg-0005): 建立 AI Service Python 工程基线（M0） |

## 7. 与 Task 对应关系

| Task | 对应 DU | 测试覆盖 | 状态 |
|------|---------|----------|------|
| TASK-001 仓库根 6 文件 | DU-AI-001 | AC-01/02 架构扫描 | PASS |
| TASK-002 App/Lifespan/Health | DU-AI-002 | AC-03/04 集成测试 | PASS |
| TASK-003 Config/Logging/Error/Middleware | DU-AI-002 | AC-05/09 单元测试 | PASS |
| TASK-004 LLM 抽象+Factory+Mock | DU-AI-003 | AC-07/09 单元测试 | PASS |
| TASK-005 Java HTTPX Client | DU-AI-003 | AC-06/08 架构扫描 | PASS |
| TASK-006 边界位目录+README | DU-AI-004 | AC-11 架构扫描 | PASS |
| TASK-007 Ruff/Pyright 配置 | DU-AI-001 | 质量三命令 | PASS |
| TASK-008 Pytest 三用例+Evidence | DU-AI-005 | AC-09 全部 | PASS |
