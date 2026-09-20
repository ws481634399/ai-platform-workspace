---
story-id: "STORY-008-02-01"
change-id: "CHG-0024"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
feature-path: "FEAT-008/FEAT-008-02/FEAT-008-02-01/STORY-008-02-01"
---

# Story Design（Story 技术设计）— AI 商品对比

## 0. 元信息

- Change ID：CHG-0024；Story ID：STORY-008-02-01（REQ-M6-002，P1）
- 两仓两 DU：DU-AI-002（repo-3 对比全链路）、DU-FE-002（repo-2 mall-web 对比页）
- 实施顺序：DU-AI-002 → DU-FE-002（契约在 requirement-design §2.1 冻结，FE 可 mock 起步）

### 现状事实（已逐文件核实，含 DU-AI-001 交付物）

- ai-service 已具备（DU-AI-001 交付）：`app/agents/workflow.py` 节点链引擎（ShoppingIntent/RecommendOut schema、structured_chat 约定）、`app/agents/tools/registry.py` Tool 注册表（tier=READ/WRITE）、`app/agents/tools/product_tools.py`（search_products/get_product_detail，ProductCandidate 归一，price_display 元两位小数）、`app/core/security.py`（parse_bearer）、`app/services/conversation.py`、`app/services/feature_gate.py`（fail-closed）、`app/api/v1/shopping.py`（直出契约模式 + `# ruff: noqa: N815` camelCase 先例）、`app/infrastructure/java/client.py`（get 透传封装）、tests/helpers.py（JavaMock/StubLLM/shopping_test_env 测试基建）。
- mall-gateway `/api/ai/**` 路由与角色矩阵已交付（DU-BE-001）：`/api/ai/compare/**` 已在 permitAll。
- mall-product `GET /api/mall/products/{id}` 公开详情（名称/品牌/SKU/规格/价格/图片/介绍/状态）为本 Story 唯一数据源，零改动。
- mall-web 已有 `src/api/ai.ts`（aiApi.recommendations）、`views/ai/AssistantView.vue`、features store `hasFeature` 模式、`stores/products`（商品选择数据源）与 ProductDetail 页（对比入口挂载点候选）。

## 1. 模块改动（Module Changes）

### repo-3 ai-service（DU-AI-002）

- `app/agents/tools/product_tools.py` 扩展：`get_products_detail(productIds[2..6])` 批量详情——并发（asyncio.gather）逐个调 `get_product_detail`，单个失败/404 降级为"该商品详情缺失"占位不阻断整体；返回 `dict[productId, ProductDetail | None]`。
- `app/agents/compare_agent.py` 新增对比节点链：`normalize`（按商品类型归一属性键：分类目属性→维度候选集；价格/库存状态为必含维度）→ `select_dimensions`（LLM structured_chat：入 question+属性并集，出维度列表 3~8 个；无 question 时取通用维度集）→ `build_table`（comparisonDimensions 构建缺失占位"暂无该项数据"，价格/库存状态取 Tool 原值）→ `summarize`（有 question 时 LLM 总结，硬条款：结论必须引用 dimensions 中真实属性值，缺失属性不得作为依据）。
- `app/api/v1/compare.py` 新增：`POST /api/ai/compare`（契约见 requirement-design §2.1）；入参校验 productIds 数量 2~6、去重、逐个存在性（Tool 查询 404 → 400 无效 id）；gate.ensure_enabled("ai.compare.enabled")；成功直出契约结构（复用 shopping.py 模式，文件头 `# ruff: noqa: N815`）。
- `app/main.py` 注册 compare 路由；异常映射复用既有 handler（400/403/502）。
- pytest：批量 Tool 并发与单点降级、维度选择（有/无 question）、缺失属性占位、价格/状态一致性、grounding（summary 引用真实属性）、开关 fail-closed、入参边界（<2/>6/重复/无效 id → 400）。

### repo-2 mall-web（DU-FE-002）

- `src/api/ai.ts` 扩展：`aiApi.compare({productIds, question?})` 封装（类型对齐 §2.1 契约）。
- `src/views/ai/CompareView.vue` 新增：商品选择器（从商品列表/搜索结果选择 2~6 个，本地 selected 列表）+ 可选场景问题输入 + 维度对比表格（行=维度，列=商品，缺失单元格"暂无该项数据"）+ AI 总结区 + Loading/Error 态 + "价格以结算页为准"文案。
- 路由 `/ai/compare` 注册；导航入口 `v-if="features.hasFeature('ai.compare.enabled', true)"`（data-testid="mall-compare-link"）；开关 false 时直达路由空态。
- vitest：compare api 封装、视图交互（选择商品→表格渲染→缺失占位→总结渲染→错误态→开关隐藏）。

## 2. 接口契约细化

- SSOT：requirement-design.md §2.1 compare 契约。Story 侧补充：
  - `comparisonDimensions[].values` 键为 productId（字符串），值为展示值或"暂无该项数据"；价格维度值=Tool 返回价（元，两位小数）。
  - `products[]` = 本次入参 productIds 顺序的摘要（productId/productName/image/price）；详情缺失商品照常列出（price 等字段"暂无该项数据"）。
  - `summary` 恒返回（无 question 时为通用对比要点，引用真实属性）。

## 3. 数据变更

- 无 SQL 迁移、无新中间件；纯读链路（Tool → 网关 → mall-product）。

## 4. 错误处理

- 400：productIds 数量 <2 或 >6、重复、含无效/查无 id（错误体逐个列出无效 id）。
- 403：ai.compare.enabled=false 或读取失败（fail-closed，body 说明"AI 对比暂未开启"）。
- 502：LLM 或 Java 上游失败（全部商品详情均失败时）；部分失败不 502（缺失占位降级）。
- 前端：Error 态可重试；403 → 空态提示。

## 5. DU 划分（Delivery Units）

| DU | 仓库 | 范围 | 覆盖 AC | depends on |
| --- | --- | --- | --- | --- |
| DU-AI-002 | repo-3 | get_products_detail 批量 Tool、compare_agent 节点链、compare 端点、pytest 全套 | AC-014~019, AC-021 | — |
| DU-FE-002 | repo-2 | aiApi.compare + CompareView + 路由/开关联动 + vitest | AC-020 | DU-AI-002 |

> 跨 Story 前置：DU-AI-002 实施前提为 DU-AI-001（STORY-008-01-01）已交付的 workflow 引擎/Tool 注册表/product_tools/feature_gate（见 §0 现状事实），属 Story 间依赖不进本表。

## 6. 测试策略

| TC | AC | 位置/类型 | 关键断言 |
| --- | --- | --- | --- |
| TC-201 | AC-015 | pytest compare_agent_test | 每个 productId 均触发 get_products_detail 调用（JavaMock 断言调用面）；无 Tool 路径不存在 |
| TC-202 | AC-014 | pytest compare_api_test | 2 商品 → comparisonDimensions/products/summary 结构完整；values 键=productId |
| TC-203 | AC-016 | pytest dimensions_test | 同类（两台电脑）维度含 CPU/RAM/存储/GPU/屏幕/重量/价格；不同类型不强求统一 Schema |
| TC-204 | AC-017 | pytest missing_field_test | Tool 未返回属性 → 表格值"暂无该项数据"；无推测值 |
| TC-205 | AC-018 | pytest price_state_test | 价格/库存状态 == Tool 返回原值（逐格断言） |
| TC-206 | AC-019 | pytest summary_grounding_test | "哪个更适合玩游戏" → summary 引用 GPU/内存等真实属性；mock LLM 强约束输出可断言 |
| TC-207 | AC-021 | pytest 合集 + 架构断言 | 对比核心 pytest 全绿 + ruff；无 Product DB 连接串（仅经 java client） |
| TC-208 | AC-014 | pytest compare_api_test 边界 | <2/重复/含无效 id → 400；6 上限 |
| TC-209 | AC-020 | vitest compare_view.spec | 选择 2 商品→表格渲染+缺失占位+总结；错误态重试；开关 false 入口隐藏/空态 |

## 7. 待办与跨 Story 复用

- get_products_detail 为 DU-AI-004 订单助手无关、但属性归一化模式可被后续 Story 参考本 Story 沉淀。
- 无参数类定值遗留。
