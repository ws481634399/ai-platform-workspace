# Python 质量工具配置规范

> 版本：v0.1
> 类型：工程规范
> 作用域：Python 项目（AI Service 及后续 Python Change）
> 来源：CHG-0005（建立 AI Service Python 工程基线）
> related-changes: [CHG-0005]

## 1. 工具组合

Python 项目质量工具采用 **Ruff（lint + format 合并）+ Pyright（类型检查）** 双工具组合，禁止同时引入 black/isort/mypy 等重复工具。

## 2. Ruff 配置（[tool.ruff]）

### 2.1 Lint 规则集

```toml
[tool.ruff.lint]
select = ["E", "F", "I", "N", "W", "UP", "B", "A", "SIM", "RUF"]
ignore = ["E501", "N818", "RUF001", "RUF002", "RUF003"]
```

- **select**：10 规则子集（E pycodestyle / F pyflakes / I isort / N naming / W warnings / UP pyupgrade / B bugbear / A builtins / SIM simplify / RUF ruff-specific）
- **ignore**：
  - `E501`（行长度由 format 统一管理）
  - `N818`（异常类命名后缀，允许自定义命名如 `AIBaseException` 不强制 `Error` 后缀）
  - `RUF001/002/003`（中文标点误报）

### 2.2 Format

```toml
[tool.ruff.format]
quote-style = "double"
indent-style = "space"
```

> 注意：ruff 0.16+ 不支持 `indent-width` 字段（由 `line-length` 隐式管理）。

## 3. Pyright 配置（[tool.pyright]）

```toml
[tool.pyright]
typeCheckingMode = "strict"
reportMissingTypeStubs = false
reportUnknownMemberType = false
reportUnknownParameterType = false
reportUnknownArgumentType = false
reportUnknownVariableType = false
```

- **strict 模式**：对自有代码保持严格类型检查
- **关闭 4 项 Unknown* 报告**：第三方库无 `.pyi` type stub 时避免误报（fastapi/httpx/pydantic 等成熟库的 stub 覆盖不全）

## 4. Pytest 配置（[tool.pytest.ini_options]）

```toml
[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
```

- `asyncio_mode = "auto"`：自动识别 async 测试函数，无需 `@pytest.mark.asyncio` 装饰器

## 5. 配置集中原则

全部质量工具配置集中在 `pyproject.toml`，不拆分 `ruff.toml` / `pyrightconfig.json` / `pytest.ini` 等多文件。
