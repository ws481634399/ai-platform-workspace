---
story-id: "STORY-005-01-02-03"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S5]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.1 [S5]/§5
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0020
- Story ID: STORY-005-01-02-03 mall-web 商品搜索体验
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`（S5）

## 1. Story 目标

mall-web 交付完整搜索体验：全局搜索框、/search 结果页（关键词回显、分类/品牌/价格筛选、排序、分页、商品卡片）、无结果/Loading/Error 三态，点击商品进入既有商品详情页；查询状态写入 URL query 可分享可刷新。

## 2. Scope（范围）

### 2.1 包含

- [S5] api/search.ts：searchProducts(query) 类型与 DTO 逐字段对齐后端（priceFen 等）；stores/search.ts（结果/分页/加载/错误状态机）。
- [S5] 顶部布局新增搜索框（输入回车/点击跳转 /search?keyword=）。
- [S5] views/search/SearchView.vue：关键词回显；分类（下拉/列表，M5 用既有分类树数据）、品牌（文本/已知品牌列表，M5 提供品牌 ID 输入或从首页品牌进入，design 定交互）、价格区间（元）筛选；排序控件（综合/价格升/价格降/新品）；分页；复用既有商品卡片样式；URL query ↔ 页面状态双向同步。
- [S5] 三态：无结果（空插画+推荐去分类浏览）、Loading（骨架/加载指示）、Error（搜索暂时不可用 + 重试 + 返回首页/分类入口）。
- [S5] 卡片点击 → 既有 /product/:id 详情页。
- [S5] vitest 覆盖 store 与视图关键行为。

### 2.2 不包含

- 搜索联想/热词/历史；facet 多选；搜索结果库存标签。
- search.enabled 公开开关的获取与隐藏逻辑（CHG-0022 STORY-006-02-01-02 接线；本 Story 搜索入口默认展示）。

## 3. 业务规则

- 价格区间 UI 以元输入，提交时转为整数分；空值不传。
- 所有查询状态（keyword/categoryId/brandId/min/max/sort/page）体现在 URL query；刷新结果一致。
- 请求失败（503/网络）进入 Error 态而非白屏；空结果与错误严格区分。
- 复用现有 http 客户端与统一错误解包，不新建请求栈。

## 4. 接口与字段规格

- 消费 `GET /api/mall/search/products`（经网关 8080）；响应字段与 STORY-005-01-02-01/02 DTO 一致。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 顶部搜索框输入关键词回车 → 跳转 /search?keyword=...，结果页回显关键词并展示结果卡片（图/名/价/品牌） |
| AC-002 | 分类/品牌/价格筛选与四种排序可操作并正确刷新结果；分页可翻页；URL query 完整反映状态，刷新后页面与结果一致 |
| AC-003 | 无结果显示空状态与分类浏览引导；加载中有 Loading 指示；接口 503/断网显示 Error 态与重试按钮 |
| AC-004 | 点击商品卡片进入既有商品详情页且正常渲染 |
| AC-005 | 价格输入元 → 查询参数正确换算为分；非法区间前端即时提示不发请求 |
| AC-006 | vitest：store 请求成功/空结果/失败三态、query 同步逻辑通过；type-check/lint/build 通过 |
