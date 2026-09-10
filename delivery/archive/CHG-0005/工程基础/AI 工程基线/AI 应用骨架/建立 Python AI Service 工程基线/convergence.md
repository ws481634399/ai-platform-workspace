# Convergence

> change-id: CHG-0005
> completed-at: 2026-09-07T17:30:00Z
> from-state: testing
> to-state: completed
> standards-need-update: yes
> product-need-update: no
> featuretree-need-update: yes
> glossary-need-update: no

## 1. 知识变化总结

本 Change 是 AI Service Python 工程基线的首次建立（M0），产出可跨 Change 复用的技术知识 1 条（Python 质量工具配置规范），Feature Tree 中 1 个 Story 状态需更新（planned → delivered）。

### 新规则/新模式

- **Python 质量工具配置规范**：Ruff 10 规则集 + Pyright strict 模式配置经验（含第三方库无 stub 的 Unknown* 关闭策略），可跨后续 M6+ AI Change 复用，晋升为 standards。

### No Update（本次特有/不具备复用价值）

- hatchling `[tool.hatch.build.targets.wheel] packages` 配置：项目名 ≠ 包目录名时的 build 配置补充，属一次性实现细节
- Pydantic v2 `model_fields` FieldInfo.annotation 取类型方式：框架 API 细节，不具备独立规范价值
- FastAPI 异常 handler `cast(AIBaseException, e)` 类型处理：框架特定 quirk，不晋升规范
- PowerShell 不支持 heredoc（git commit 用 `-F` 文件方式）：开发环境兼容性，不晋升规范
- 具体的 UnifyResult 5 字段响应格式：属实现细节，已在 design.md 定义
- 具体的 AI-*-NNN 错误码分配表：属设计决策，已在 design.md 记录

## 2. 更新判断

### Standards 晋升

- 文件: `standards/engineering/ai/python-quality-standard.md`
- 操作: 新增
- 内容: Python 质量工具配置规范（Ruff lint 10 规则集 + format 双引号 + Pyright strict 模式 + 第三方库 Unknown* 关闭策略 + pytest asyncio_mode=auto）
- 理由: 本 Change 首次建立 Python 工程质量基线，Ruff/Pyright 配置经验可被后续 M6+ AI 业务 Change 直接复用
- 复用场景: 后续所有涉及 Python 代码的 Change

### Spec 晋升候选

无。本 Change 是工程基线（M0），不涉及产品业务规则。AI 工程边界约定（R-01~R-13）已由需求文档 REG-M0-003 和 design.md 定义，不需要额外 Spec 沉淀。

### Feature Tree 更新

- 节点: STORY-1-02-01-01（建立 Python AI Service 工程基线）
- 操作: 状态变更 planned → delivered
- 方式: `openspec feature update STORY-1-02-01-01 --status delivered`
- 前提: 全部 5 个 DU 已 completed，repo-3 commit 36cb941 已推送远程

### Glossary 更新

无。本 Change 未引入需要统一的新业务术语。技术术语（LLMClient/TraceId/MockProvider 等）已在 design.md 和代码注释中定义，不需要 glossary 沉淀。

### No Update

见 §1 末尾清单（6 项，均为实现细节或一次性知识）。

## 3. 知识沉淀过程记录

1. 读取全部前序 Artifact（requirement/exploration/prd/design/tasks/implementation/test-report/review-report）
2. 从 review-report.md §1.4 提取 5 条知识同步候选
3. 按 4 问分类法判断：1 条晋升 standards，4 条 no-update
4. 写入 standards/engineering/ai/python-quality-standard.md（新建文件）
5. 执行 `openspec feature update STORY-1-02-01-01 --status delivered`
6. 重建索引

## 4. 全局验收标准对照

| AC | 验收标准 | 证据来源 | 结论 |
|----|---------|----------|------|
| AC-01 | `.python-version=3.11`；`uv run python --version` → Python 3.11. | EV-004 架构扫描 + Environment logs | PASS |
| AC-02 | `uv.lock` 存在；`uv sync --frozen` 退出码 0 | EV-004 架构扫描 | PASS |
| AC-03 | uvicorn 启动日志含 `Uvicorn running on http://127.0.0.1:8000` | EV-007 test-run（uvicorn 启动日志） | PASS |
| AC-04 | `GET /health` → HTTP 200 + `{"service":"ai-service","status":"UP"}` | EV-001 pytest test_health_endpoint_ok + EV-006 evidence-ref | PASS |
| AC-05 | `.env.example` ≥10 字段；凭据扫描 0 命中；`.env` in .gitignore | EV-004 架构扫描 + EV-001 pytest test_settings | PASS |
| AC-06 | `httpx.AsyncClient(` 仅在 infrastructure/ | EV-004 架构扫描（2 处：main.py lifespan + java/client.py） | PASS |
| AC-07 | `from openai` / `import anthropic` 0 命中 | EV-004 架构扫描 | PASS |
| AC-08 | DB 驱动 0 命中 | EV-004 架构扫描 | PASS |
| AC-09 | `uv run pytest -q` 全 passed，≥3 用例 | EV-001 test-run（3 passed） | PASS |
| AC-10 | 9 职责锚点全部存在；main.py ≤50 行 | EV-004 架构扫描（46 非空行） | PASS |
| AC-11 | 边界位非 init .py = 0 | EV-004 架构扫描 | PASS |

**跨 Story 集成点**：本 Change 单仓（repo-3）单 Story（STORY-1-02-01-01），无跨 Story 集成。repo-1（Java 后端）和 repo-2（前端）零修改（PRD §3.2 明确排除）。

## 5. 完成确认

- [x] 全部前序 Artifact 已读取
- [x] 知识分类完成（standards 1 条 / spec 0 / feature-tree 1 / glossary 0 / no-update 6）
- [x] standards 更新已写入（python-quality-standard.md）
- [x] Spec 晋升候选无（工程基线不涉及业务规则）
- [x] Glossary 无需更新
- [x] Feature Tree Story 状态已更新（planned → delivered）
- [x] 索引已重建
- [x] 无未解决的 Conflict 或 Unresolved 问题
