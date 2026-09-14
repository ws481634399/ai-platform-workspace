---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-003-02-01-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0017
- Story ID: STORY-003-02-01-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed
- 需要 Migration: no
- 数据变更概要: 无

## 1. 模块改动（Module Changes）

### repo-1 mall-product

- `interfaces.rest.mall.MallHomeController`：GET /api/mall/home。
- `application.catalog.HomeApplicationService`：一次装配——分类树首层（复用分类查询，最多 12 个入口）、newArrivals（ON_SALE + EXISTS 启用 SKU，按上架时间/创建时间倒序 LIMIT 10）、recommends（同数据、source=FALLBACK_NEWEST 标注）、banners 返回空数组（前端静态占位）。
- DTO `HomeView{banners, categoryEntries, newArrivals, recommends{source,items}}`；商品卡复用 MallProductListItemView 结构（价区由 CHG-0015 聚合填充）。

### repo-2 mall-web

- `src/api/catalog.ts`：getHome/getCategoryTree/getBrands。
- `src/stores/catalog.ts`（pinia）：分类树/品牌缓存（会话级，失败可重试）。
- components：`ProductCard.vue`（图/名/价区 ¥ 分格式化/懒加载图/点击进详情）、`PriceText.vue`（整数分展示，域模型保持 number）、`StateView.vue`（loading/empty/error 插槽）、`BannerSlot.vue`（静态占位）。
- views `home/HomeView.vue` 替换 M0 占位：Banner 位 + 分类导航栅格 + 新品/推荐横向列表；空数据空态；接口错误 Error 态与重试。

## 2. 接口契约细化

| 方法 | 路径 | 鉴权 | 响应 |
| --- | --- | --- | --- |
| GET | /api/mall/home | 匿名（白名单） | {banners:[], categoryEntries:CategoryNode[], newArrivals:ListItem[], recommends:{source:"FALLBACK_NEWEST",items:ListItem[]}} |
- ListItem：{id:string,name,mainImageUrl,minPrice:number,maxPrice:number}；全部商品位保证价区非 null、仅 ON_SALE+启用 SKU。

## 3. 数据变更

- 无。

## 4. 错误处理

- 分类装配失败 vs 商品位失败分区处理：分类失败仍可渲染商品位（导航区 Error 内联）；商品位失败首页主体 Error 态；空商品位 Empty 态。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-701 | repo-1 | /home 聚合接口（分类入口+新品+推荐占位+banners 空） | AC-001,002 | — |
| DU-FE-701 | repo-2 | 首页三视图态、ProductCard/PriceText/StateView/BannerSlot | AC-001,002,018,019 | DU-BE-701 |

> 跨 Story/Change 依赖：DU-BE-702（分类树契约）由 STORY-003-02-01-02 交付；价区与有效 SKU 谓词由 CHG-0015 DU-BE-501 交付。

## 6. 测试策略

- 后端：home 装配集成测试（仅售/无启用 SKU 混合数据下商品位过滤、顺序、LIMIT、banners=[]）；分类失败不拖垮商品位的降级测试；SQL 调用次数断言（无 N+1）。
- 前端：HomeView 组件测试（loading/empty/error/成功四态、卡片点击路由）；PriceText 整数分快照；vue-tsc/eslint/build。
