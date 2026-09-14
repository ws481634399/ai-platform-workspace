---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-003-02-02-02"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0017
- Story ID: STORY-003-02-02-02
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed
- 需要 Migration: no
- 数据变更概要: 无

## 1. 模块改动（Module Changes）

### repo-1 mall-product

- `MallProductDetailView` 扩展：`brandName`、`categoryPath:[{id,name}]`、`specDimensions:[{name,values:[]}]`、`skuIndex:[{skuId,specs:{name:value},priceFen,imageUrl,status}]`（保留既有 skus 平铺列表兼容期可共存或由新结构替代）。
- assembler：从 SKU 集合归并规格维度（按 specification 首次出现序去重排序）；skuIndex 每组合一条；价格整数分；status 透传 SKU 状态（ENABLED 才可选）。
- 详情仍仅 ON_SALE 可访问（getMallById 既有约束），不存在/下架 404 业务码 PRODUCT_NOT_AVAILABLE。

### repo-2 mall-web

- `src/components/product/SkuSelector.vue`：规格维度按钮组；不存在的组合与 DISABLED SKU 禁用；已选组合映射唯一 skuId；发出 change 事件。
- `src/components/product/StockBadge.vue`：IN_STOCK 灰/绿、LOW_STOCK 橙色"仅剩少量"、OUT_OF_STOCK 红色"缺货"、UNKNOWN"状态获取失败重试"。
- views `product/ProductDetailView.vue`：图集轮播、面包屑（categoryPath）、富文本（v-html 仅渲染后端可信字段，M3 无 UGC 保留注释）、价格/图片/三态随 SKU 切换（挂载后一次 POST availability，StateView 兜底）；加购按钮渲染但行为占位（点击提示登录/敬请期待，真实写操作接 CHG-0018）；下架/不存在由 Error 态渲染为路由级 404 商品页。
- router：/products/:id 懒加载。

## 2. 接口契约细化

| 方法 | 路径 | 响应要点 |
| --- | --- | --- |
| GET | /api/mall/products/{id} | 增 specDimensions/skuIndex/brandName/categoryPath；404 PRODUCT_NOT_AVAILABLE |
| POST | /api/mall/skus/availability | 详情页挂载一次批量（DU-BE-705 契约） |
- skuIndex.specs 的 key 集合与 specDimensions.name 完全对应；每个 ENABLED SKU 的规格组合在矩阵中唯一。

## 3. 数据变更

- 无。

## 4. 错误处理

- 下架/不存在：404 + 不渲染加购入口；前端商品 404 页提供返回列表。
- availability UNKNOWN：三态区域可重试；不阻塞图文浏览；加购按钮在非 IN_STOCK/LOW_STOCK 或 UNKNOWN 时禁用。
- 矩阵数据异常（同组合两个 skuId）：后端 assembler 防御性记录 ERROR 并按最小 id 取一（数据质量问题，不应到达前端）。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-704 | repo-1 | 详情 specDimensions/skuIndex/品牌名/分类路径装配与 404 口径 | AC-011,013 | — |
| DU-FE-704 | repo-2 | 详情页、SkuSelector/StockBadge、规格联动三态、商品 404 页 | AC-011,012,013,014,018,019,020 | DU-BE-704 |

> 跨 Story 依赖：三态聚合 DU-BE-705（STORY-003-02-03-01）为前置；ProductCard/StateView 由首页 Story 的 FE 产物复用。

## 6. 测试策略

- 后端：多规格 SKU 矩阵装配（维度归并序、组合唯一、禁用 SKU 标记 status）；下架 404；富文本/图集字段完整；JSON 金额为整数分。
- 前端：SkuSelector 组合定位（全组合表驱动测试）、禁用组合不可选、切换联动价格图状态；UNKNOWN 重试；加购在缺货时禁用；路由 404；vue-tsc/eslint/build。
