---
story-id: "STORY-008-02-01"
change-spec-ref: "requirement-spec.md#3-功能范围"
scope-refs: [S2]
---

# Story Spec（Story 产品规格）— AI 商品对比

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3 [S2]/§4/§5（AC-014~021）
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0024
- Story ID: STORY-008-02-01 AI 商品对比（REQ-M6-002，P1）
- Change spec 引用: requirement-spec.md#3-功能范围（S2）
- 仓库分工: repo-3 ai-service（主）、repo-1 mall-product（商品详情数据源，零改动）、repo-2 mall-web（对比页）

## 1. Story 目标

用户选中 2~N 个真实商品（可附加一个场景化问题，如"哪个更适合玩游戏"）后，AI 基于每个商品经 Tool 获取的实时详情进行结构化对比：

1. 对比表中每个商品的每个维度取值全部来自 `get_products_detail` Tool 实时返回，缺失属性明确显示"暂无该项数据"，无任何推测值；
2. AI 总结可给"如果主要关注 X，A 更符合"类结论，但必须引用真实属性数据；
3. 能力可被 `ai.compare.enabled` 整体启停（前端隐藏入口 + ai-service 拒绝，双端生效）。

## 2. Scope（范围）

### 2.1 包含

- [S2] `get_products_detail` 批量详情 Tool：一次请求批量获取 2~6 个商品的实时详情（复用 `get_product_detail` 单品 Tool 的字段白名单与通道），失败单个降级为缺失不阻断整体。
- [S2] 属性归一化：按商品类型整理可比较结构，同类商品（如两台电脑）输出 CPU/RAM/存储/GPU/屏幕/重量/价格等合理维度；不同类型商品不强求统一 Schema。
- [S2] 维度选择：优先按商品类型与用户问题（question）选择对比维度；无 question 时给通用维度集。
- [S2] 对比 Workflow：批量详情 → 属性归一 → 维度选择 → 对比表构建 → 场景化总结（有 question 时）。
- [S2] 结构化输出：`comparisonDimensions[]`（dimension + values 按 productId 映射，缺失占位"暂无该项数据"）+ `products[]`（id/name/image/price）+ `summary`。
- [S2] `POST /api/ai/compare` 端点：入 `{productIds:[2..6], question?}`，GUEST 可用（开关 fail-closed 在 ai-service 内）。
- [S2] mall-web 对比页 CompareView：商品选择器 + 维度对比表格 + AI 总结 + Loading/Error 态；`ai.compare.enabled` 开关联动显隐。

### 2.2 不包含

- 推荐购买/加购/下单引导（属导购/交易链路）；跨商品价格历史、监控降价。
- 商品数据写入（对比只读，mall-product 零改动）。
- 真实 LLM Provider 运行态联调（mock provider 闭环，真实外呼留 Integration Gate）。
- 知识库/客服/订单助手能力（归属 STORY-008-03-01/04-01）。

## 3. 业务规则

- [真实详情] 参与对比的每个 productId 必须经 get_products_detail Tool 获取实时详情；仅凭名称/会话记忆对比即判失败（AC-015）。
- [缺失即声明] Tool 未返回的属性在对比表中显示"暂无该项数据"，不得推测补齐（规则 5/AC-017）。
- [真实价格] 对比表中价格 == Tool 实时返回值；前端附"价格以结算页为准"类文案（AC-018）。
- [结论有据] 场景化结论必须引用具体属性数据（GPU/刷新率/内存等），不得输出无依据的"A 最好"（规则 22/AC-019）。
- [开关 fail-closed] ai.compare.enabled=false 或读取失败 → ai-service 403 + mall-web 隐藏入口（规则 14）。
- [身份] 对比端点 GUEST 可用；不涉及会员私有数据。
- [入参约束] productIds 数量 2~6；含无效/不可售商品 id → 400（不静默剔除后对比）。

## 4. 接口与字段规格

- `POST /api/ai/compare`：入 `{productIds: string[2..6], question?}`；出 `{comparisonDimensions:[{dimension, values:{productId: value|"暂无该项数据"}}], products:[{productId,productName,image,price}], summary}`；错误 400（<2 个或含无效 id）/ 403 开关关闭 / 502 LLM 或 Java 上游失败（响应含 X-Trace-Id）。
- Tool 出参白名单：get_products_detail 仅返回 mall-product 公开详情既有字段，ai-service 不新增业务字段语义。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
| --- | --- | --- |
| AC-014 | 选择 2~N 个真实商品发起对比 → 返回 comparisonDimensions + products + summary 结构 | P1 |
| AC-015 | 参与对比的每个 productId 均经 get_product_detail(s) Tool 获取实时详情；不传 Tool 仅凭名称对比即判失败 | |
| AC-016 | 同类商品（如两台电脑）对比维度含 CPU/RAM/存储/GPU/屏幕/重量/价格等合理维度；不同类型商品不强求统一 Schema | |
| AC-017 | Tool 未返回的属性在对比表中显示"暂无该项数据"，不出现推测值 | |
| AC-018 | 对比表中价格/库存状态 == Tool 实时返回值 | |
| AC-019 | 场景化问题（"哪个更适合玩游戏"）→ 结论引用具体属性（GPU/刷新率/内存），无不依据的"A 最好" | |
| AC-020 | mall-web 对比页渲染维度对比表格 + AI 总结 | |
| AC-021 | ai-service 不直连 Product DB（同导购 Story 口径：无业务库连接串，数据仅经 Tool→Java API）；对比核心 pytest 通过 | |

## 6. 待设计确认（已移至 design 定稿）

- 批量 Tool 通道/上限（2~6）、对比商品传参（前端显式 productIds）、维度选择机制已在 requirement-design.md §2.0/§2.1/§4.F-23 定稿，本节不遗留问题。
