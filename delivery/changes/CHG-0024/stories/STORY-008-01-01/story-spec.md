---
story-id: "STORY-008-01-01"
change-spec-ref: "requirement-spec.md#3-功能范围"
scope-refs: [S1]
---

# Story Spec（Story 产品规格）— AI 智能导购

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3 [S1]/§4/§5（AC-001~013）
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0024
- Story ID: STORY-008-01-01 AI 智能导购（REQ-M6-001，P1）
- Change spec 引用: requirement-spec.md#3-功能范围（S1）
- 仓库分工: repo-3 ai-service（主）、repo-1 mall-search/mall-product/mall-inventory（数据源）、repo-2 mall-web（入口）

## 1. Story 目标

用户用一句自然语言（如"预算 5000 左右，想买一台适合程序开发的笔记本"）即可获得来自真实在售商品的推荐与理由：

1. AI 完成"理解需求→提取约束→判断是否澄清→调用商品搜索/详情 Tool→分析真实候选→返回结构化推荐"，推荐商品、价格全部来自 Tool 返回的真实业务数据，可逐条回溯；
2. 信息不足时有界澄清（单轮 ≤2 问），信息充分时优先执行搜索；支持会话内多轮上下文（"第二台再详细说说"）；
3. 能力可被 `ai.shopping.enabled` 整体启停（前端隐藏入口 + ai-service 拒绝，双端生效），ES 不可用时按设计降级到 mall-product 合法查询。

## 2. Scope（范围）

### 2.1 包含

- [S1] 自然语言需求理解与结构化约束提取（类别/使用场景/预算/品牌偏好/价格范围/关键属性/排除条件/推荐数量）。
- [S1] 有界澄清：关键约束（预算/类别/使用场景）缺失时追问，单轮 ≤2 问、一次打包；信息充分直接执行。
- [S1] `search_products` Tool：keyword/category/brand/minPrice/maxPrice/sort/pageSize(≤20)，调 mall-search 公开查询；mall-search 不可用时降级 mall-product 合法商品查询；两路皆败返回明确失败不编造。
- [S1] `get_product_detail` Tool：名称/品牌/SKU/属性/当前价格/图片/介绍/可售展示状态（库存合入本 Tool，不设独立库存 Tool；展示库存 ≠ 交易保证）。
- [S1] Agent/Workflow 编排：意图识别→参数提取→澄清判断→搜索→详情 enrich（候选 ≤3）→候选分析→生成推荐。
- [S1] 结构化推荐：`message + recommendations[]`（productId/productName/image/price/reason 必含），推荐理由引用真实属性，缺失字段写"暂无该项数据"。
- [S1] 多轮会话上下文（会话 ID 贯穿，最近 N 轮窗口；不做长期用户记忆）。
- [S1] `ai.shopping.enabled` FeatureGate 双端生效（fail-closed）；mall-web AI 导购入口（输入/澄清态/推荐卡片/Loading/Error）。
- [S1] AI 基础横切落地：TraceId 链路传播、LLM/Java API 失败明确错误处理（不崩溃/不编造）、Secret 不进 Prompt。

### 2.2 不包含

- 用户画像推荐、协同过滤、深度学习排序、广告投放、自动购买/自动下单（属 REQ-M6-004 写域且首期仅 cancel_order）。
- 复杂长期用户记忆系统（仅会话内上下文）；交易库存保证（下单由 M4 重新校验）。
- 真实 LLM Provider 运行态联调（openai 兼容 provider 就绪，真实外呼留 Integration Gate；CI 用 mock provider 闭环）。
- AI 商品对比/知识库/订单助手（分别归属 STORY-008-02-01/03-01/04-01）。

## 3. 业务规则

- [真实商品] 推荐 productId 100% 来自本次 Tool 返回结果（代码回溯断言）；禁止生成不存在 SKU/编造价格；候选外商品一律不出现。
- [真实价格] 展示价=Tool 返回当前价；前端附"价格以结算页为准"类文案；库存为展示态。
- [推荐解释] reason 必须引用该商品 Tool 返回的真实属性；Tool 未提供的能力不得虚构。
- [澄清有界] 预算与类别/使用场景等关键约束缺失才澄清；单轮 ≤2 问；已有足够信息优先搜索，不无意义追问。
- [降级链] mall-search 失败 → mall-product 合法查询兜底 → 均败 502"商品服务暂时不可用"；任何失败路径不返回编造数据。
- [开关 fail-closed] ai.shopping.enabled=false 或开关读取失败 → ai-service 403 拒绝 + mall-web 隐藏入口；AI 为增强能力，不影响交易主链路。
- [身份] 导购端点 GUEST 可用；如携带 MEMBER Token 则按已登录处理；memberId 永不接受为可信请求参数。
- [会话] conversationId 由 ai-service 签发；上下文仅会话内有效（TTL 24h）；不跨会话记忆。

## 4. 接口与字段规格

- `POST /api/ai/shopping/recommendations`：入 `{conversationId?, message}`；出 `{conversationId, message, recommendations:[{productId,productName,image,price,reason}], clarifyingQuestion?}`；澄清与推荐互斥。
- 错误：400 参数无效（空/超长 message）；403 功能开关关闭；502 LLM 或 Java 上游失败（响应含 X-Trace-Id）；503 Redis 不可用（降级单轮并 warn）。
- Tool 出参白名单：search_products/get_product_detail 仅返回既有 mall 公开端点字段，ai-service 不新增业务字段语义。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
| --- | --- | --- |
| AC-001 | 输入"预算 5000 左右，想买一台适合程序开发的笔记本" → 返回 message + recommendations[]（productId/productName/image/price/reason） | |
| AC-002 | 输入含类别/预算/品牌/价格范围 → 约束提取并作为 Tool 入参（参数映射可断言） | |
| AC-003 | 缺预算与场景 → ≤2 个澄清问题而非直接搜索；信息充分 → 不追问直接执行 | |
| AC-004 | 每个推荐 productId 均来自本次 Tool 返回（回溯断言），无法回溯即失败 | 真实商品约束 |
| AC-005 | 诱导"推荐不存在的 iPhone 99 Pro" → 不返回 Tool 结果之外的商品/SKU/价格 | |
| AC-006 | 展示价格 == Tool 返回当前价（逐条断言） | |
| AC-007 | 推荐理由引用真实属性；Tool 未提供能力不出现虚构描述 | |
| AC-008 | mall-web 入口可输入并渲染推荐卡片，Loading/Error 态可用 | |
| AC-009 | 会话内"第二台再详细说说" → 返回上轮第二名商品详情级信息 | |
| AC-010 | mall-search 不可用 → 降级 mall-product 返回真实商品；均败 → 明确失败文案 | |
| AC-011 | ai-service 无业务库直连（配置/代码断言），商品数据仅经 Tool→Java API | |
| AC-012 | ai.shopping.enabled=false → 入口隐藏 + ai-service 拒绝；恢复后功能恢复 | |
| AC-013 | 导购核心 pytest 通过（约束提取/Tool/真实约束/推荐生成） | |

## 6. 待设计确认（已移至 design 定稿）

- Workflow 选型/Tool 调用通道/会话存储/DTO 扩展字段/Provider 选型已在 requirement-design.md §2.0 定稿，本节不遗留问题。
