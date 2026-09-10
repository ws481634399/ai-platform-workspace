# Review Report

> change-id: CHG-0005
> test-report-source: evidence/test-report.md
> evidence-index: evidence/evidence.yaml
> reviewed-at: 2026-09-07T17:00:00Z

## 1. 检查结论

### 1.1 需求一致性（PRD AC ↔ evidence.yaml test-run 覆盖）

| AC | test-run 证据（covers 字段） | 结论 |
|----|------------------------------|------|
| AC-01 | EV-004（架构扫描） | ✅ |
| AC-02 | EV-004（架构扫描） | ✅ |
| AC-03 | EV-007（评审补充：uvicorn 启动日志 test-run） | ✅ 已闭环（EV-008） |
| AC-04 | EV-001（pytest test_health_endpoint_ok） | ✅ |
| AC-05 | EV-001 + EV-004（pytest + 架构扫描） | ✅ |
| AC-06 | EV-004（架构扫描 httpx.AsyncClient） | ✅ |
| AC-07 | EV-004（架构扫描 openai/anthropic） | ✅ |
| AC-08 | EV-004（架构扫描 DB 驱动） | ✅ |
| AC-09 | EV-001 + EV-002 + EV-003（pytest + ruff + pyright） | ✅ |
| AC-10 | EV-004（架构扫描 9 锚点 + main.py 行数） | ✅ |
| AC-11 | EV-004（架构扫描边界位 .py） | ✅ |

**结论**：11 条 AC 全部有 test-run 覆盖。AC-03 在评审前缺少独立 test-run 条目（仅有 evidence-ref EV-005 引用 uvicorn 日志），已补充 EV-007 test-run 条目闭环。

### 1.2 设计一致性（Design → DU → Implementation Traceability）

**三层链路检查：**

| 检查 | 内容 | 结论 |
|------|------|------|
| a. DU ↔ Design | tasks.md DU 小节与 design.md §2 方案/目录/接口一致 | ✅ 5 个 DU 范围与 design §2.2 目录树完全对应 |
| b. Implementation ↔ DU | 实际实现偏离均记录在各 DU implementation.md `## Deviations` | ✅ 8 条偏离全部记录且合理 |
| c. AC 满足 | 偏离后仍满足 DU Acceptance 与 PRD AC | ✅ 11 条 AC 全部 PASS |

**偏离汇总（8 条，均已在 repo 侧 implementation.md `## Deviations` 记录）：**

| # | 偏离 | 严重度 | 记录位置 | 评估 |
|---|------|--------|----------|------|
| 1 | factory.py `from ..client` → `from .client` | minor | DU-AI-003 | 路径修正，单层点同包导入 |
| 2 | hatchling `[tool.hatch.build.targets.wheel] packages=["app"]` | minor | DU-AI-001 | build 配置补充，不影响设计契约 |
| 3 | ruff ignore N818/RUF001/002/003 | minor | DU-AI-001 | 设计意图命名 + 中文标点 |
| 4 | pyright 关闭 4 项 Unknown* | minor | DU-AI-001 | 第三方库无 stub，保留 strict 对自有代码 |
| 5 | main.py `cast(AIBaseException, e)` | minor | DU-AI-002 | FastAPI handler 类型处理 |
| 6 | lifespan 移除 llm `aclose()` | minor | DU-AI-002 | MockProvider 无资源；design §2.4 graceful degradation 模式可 M6 补 |
| 7 | EXCEPTION_STATUS 移到 exceptions.py | minor | DU-AI-002 | 内部重构减少 main.py 行数 |
| 8 | mock.py `# type: ignore[override]` | minor | DU-AI-003 | pyright async generator quirk |

**结论**：无 blocker/major 偏离。全部 8 条为 minor，均记录且合理。

### 1.3 代码质量（对照 standards/*.md）

| 检查项 | 结果 | 依据 |
|--------|------|------|
| Ruff lint（10 规则集） | 0 issues | `uv run ruff check app tests` EXIT=0 |
| Ruff format | 25 files already formatted | `uv run ruff format --check` EXIT=0 |
| Pyright strict | 0 errors, 0 warnings | `uv run pyright` EXIT=0 |
| Pytest | 3 passed | `uv run pytest -v` EXIT=0 |
| 架构红线 AC-07（禁 openai 直引） | 0 命中 | grep 扫描 |
| 架构红线 AC-08（禁 DB 驱动） | 0 命中 | grep 扫描 |
| 凭据安全 AC-05（sk- 真实密钥） | 0 命中 | grep 扫描（排除 __pycache__） |

**结论**：代码质量全部通过，无规范违规。

### 1.4 知识同步候选清单（供 sdd-converge 消费）

| # | 候选项 | 类型 | 说明 |
|---|--------|------|------|
| 1 | Python Ruff/Pyright 配置规范 | standards 候选 | M0 实测的 Ruff 10 规则集 + Pyright strict 关闭 4 项 Unknown* 的配置经验，可晋升为 `standards/engineering/ai/python-quality-standard.md` |
| 2 | hatchling wheel packages 配置 | 知识库候选 | 项目名 ≠ 包目录名时必须添加 `[tool.hatch.build.targets.wheel] packages` |
| 3 | Pydantic v2 model_fields FieldInfo.annotation | 知识库候选 | Pydantic v2 `model_fields` 值为 FieldInfo，取类型用 `.annotation` 而非直接遍历 |
| 4 | FastAPI 异常 handler 类型处理 | 知识库候选 | `cast(AIBaseException, e)` 处理 FastAPI handler 的 Exception → AIBaseException 类型窄化 |
| 5 | PowerShell 兼容性 | 知识库候选 | PowerShell 不支持 heredoc `<<'EOF'`，git commit 需用 `-F` 文件方式 |

## 2. 发现清单

| ID | target | severity | finding | resolution | 状态 |
|----|--------|----------|---------|------------|------|
| EV-008 | prd.md#AC-03 | minor | AC-03（uvicorn 启动验证）缺少独立 test-run 条目，仅有 evidence-ref 引用 | 已补充 EV-007 test-run 条目（uvicorn 启动日志验证） | 已闭环 |

## 3. 完成确认

- [x] PRD 每条 AC（11 条）都做了对照？
- [x] design.md 关键声明都核对了实现证据？
- [x] 每个 DU 都有 code-change/test-run 证据？
- [x] design.md §4 跨仓协作契约（本 Change 单仓 repo-3，无跨仓）？
- [x] 代码质量 finding 都有明确规范依据？
- [x] 全部 blocker/major 已闭环（本 Change 无 blocker/major）？
- [x] review-finding 条目与 §2 发现清单一一对应？
- [x] 知识同步候选已写入 §1.4？
