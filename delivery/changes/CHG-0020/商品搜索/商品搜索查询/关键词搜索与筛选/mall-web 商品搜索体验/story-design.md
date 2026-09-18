---
affected-repositories: [repo-2]
story-id: "STORY-005-01-02-03"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §4
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0020
- Story ID: STORY-005-01-02-03
- 状态流转: specified → designed
- 相关仓库: repo-2（mall-web）
- 需要 Migration: no
- 数据变更概要: 无

## 1. 模块改动（Module Changes）

### repo-2 mall-web（DU-FE-501）

- 新增 stores/search.ts（Pinia）：state keyword/filters(categoryId,brandId,minPriceFen,maxPriceFen,sort)/page/size/items/total/loading/error；action fetchProducts(query) 调 GET /api/mall/search/products（沿用既有 request 封装与 baseURL）。
- 新增 views/search/SearchView.vue：
  - 顶部搜索框（回车/按钮触发，keyword 同步 URL ?keyword=）；
  - 左侧/顶部筛选：类目（一级下拉或复用 HomeView 类目数据）、品牌、价格区间（元输入，提交时 ×100 转分）、排序 Tabs（综合/价格升/价格降/最新 → default/price_asc/price_desc/newest）；
  - 结果卡片网格复用商品卡片样式（productId→/product/:id，imageUrl 对应 mainImage，priceFen 对应 minPrice；字段以 story-spec §契约表为准）；
  - 分页器（默认 20）；全部查询条件双向同步 URL query，刷新可还原；
  - 三态：loading 骨架/空结果插画式空态+清除筛选/错误态（B0501 提示"搜索服务暂不可用"+重试按钮）。
- router 增 /search 路由；HomeView 与 Header（若有全局头部）搜索框提交跳 /search?keyword=。
- 价格展示统一走既有分→元格式化工具，禁止新造。

## 2. 接口契约细化

消费 GET /api/mall/search/products（后端契约见 STORY-005-01-02-01/02 story-design）：
- 请求 query：keyword/page/size/categoryId/brandId/minPriceFen/maxPriceFen/sort；
- 响应使用 UnifyResult.data.{items,total,page,size}；item 字段 productId/productName/mainImage/minPrice/maxPrice；
- 400/503 错误码 B0502/B0501 走既有拦截器 message 展示。

## 3. 数据变更

无。

## 4. 错误处理

- 网络/5xx → 错误态卡片+重试，不清空已有 URL 条件；400 → 表单内提示；空结果 → 空态。
- 竞态：连续翻页/筛选以请求序号（或 AbortController）保证仅最后一次响应落屏。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-FE-501 | repo-2 | mall-web 搜索页/搜索框/筛选排序分页/URL 同步/三态 | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006 | 无 |

> 跨 Story 依赖（不入本表）：DU-FE-501 实际前置 DU-BE-502（STORY-005-01-02-01/02 查询后端）。

## 6. 测试策略

- Vitest 组件/ store 单测：query 拼装、URL 同步、竞态丢弃、三态渲染、分页边界。
- 手工/浏览器（Integration Gate）：完整搜索→筛选→排序→跳详情→返回还原。
