# Test Report — AI 商品对比 STORY-008-02-01

## 0. 元信息

- Change ID：CHG-0024（M6 AI 智能应用）
- Story：STORY-008-02-01
- 日期：2026-09-20
- 证据：workspace evidence.yaml EV-005（repo-3 06b0610）、EV-008（repo-2 f2fd7ca）；
  repo-3 DU-AI-002/evidence/logs（pytest.txt、ruff-check.txt）；
  repo-2 DU-FE-002/evidence/logs（mall-web-vitest/typecheck/eslint/build.txt）

## 1. 测试范围

- repo-3 ai-service：批量详情 Tool（并发/单点降级/查无 400）、对比五节点链（归一/维度选择/建表占位/grounding 总结）、POST /api/ai/compare 契约与 400/403/502；ruff。
- repo-2 mall-web：aiApi.compare 封装、CompareView 全交互（搜索勾选 2~6/维度表格/缺失占位/总结/价格提示/403/5xx 重试）、路由与导航开关；vue-tsc/eslint/build。

## 2. 测试执行汇总

| 套件 | 命令 | 结果 | 用例数 |
| --- | --- | --- | --- |
| ai-service（pytest，STORY 交付时全量） | `uv run pytest tests/ -q` | passed | 43（含对比 15） |
| ai-service（ruff） | `uv run ruff check app tests` | clean | — |
| mall-web（vitest） | `pnpm vitest run` | passed，26 文件全过 | 129（含 CompareView 5） |
| mall-web type-check | `pnpm type-check` | passed | — |
| mall-web eslint | `pnpm exec eslint src` | 0 error（仅风格 warning） | — |
| mall-web build | `pnpm build` | passed | — |

## 3. AC 覆盖

| AC | 自动化证据 | 结果 |
| --- | --- | --- |
| AC-014 | TC-202（结构完整、values 键=productId）、TC-208（<2/>6/重复/无效 → 400） | passed |
| AC-015 | TC-201（JavaMock 断言每个 productId 均经 get_products_detail，无纯名称对比路径） | passed |
| AC-016 | TC-203（两台电脑维度含 CPU/RAM/存储/GPU/屏幕/重量/价格；异类不强求统一 Schema） | passed |
| AC-017 | TC-204（Tool 缺属性 → "暂无该项数据"，无推测值） | passed |
| AC-018 | TC-205（价格/库存状态逐格 == Tool 原值） | passed |
| AC-019 | TC-206（总结引用真实属性，无不依据结论） | passed |
| AC-020 | TC-209（CompareView 5 例：表格+缺失占位+总结；403 空态；5xx 重试；未选满禁用） | passed |
| AC-021 | TC-207（pytest+ruff 全绿；配置扫描无 Product DB 连接串，仅经 java client） | passed |

## 4. 缺口备注

- 跨仓真实端到端（ai-service 经网关调起 mall-product 真实详情）属 C 类 Integration Gate：单测以 JavaMock 出证，联调环境按 §2.1 契约人工串一次。
- 前端开关 false 时入口隐藏已由 features store 既有模式保证（视图层显隐），直达路由场景由后端 403 fail-closed 收口。
