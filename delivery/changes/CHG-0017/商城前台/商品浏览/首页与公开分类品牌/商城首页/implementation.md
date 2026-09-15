# Implementation（跨仓实施汇总）— 商城首页 STORY-003-02-01-01

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文位于各实现仓 DU 目录。

## 0. 元信息

- Change ID：CHG-0017（商城商品浏览体验）
- Story：STORY-003-02-01-01 商城首页
- 实施日期：2026-09-15
- 范围边界：商城首页聚合（分类入口≤8启用根 + 新品 ON_SALE+启用SKU LIMIT 10 + 推荐 fallback + banners 空），复用分类树与商品列表已有能力。

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-701 | repo-1（ai-platform-backend） | 完成并验证：mall-product 84/84（新增 3 + 既有 81） |
| DU-FE-701 | repo-2（ai-platform-frontend） | 完成并验证：mall-web 68/68（新增 14 + 既有 54），build 成功 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 868ee02 | DU-BE-701 | repo-1 | feat(mall-home): 商城首页聚合接口（分类入口+新品+推荐fallback+banners空） |
| 2c85e52 | DU-FE-701 | repo-2 | feat(mall-home): 商城首页 + 公共组件（ProductCard/PriceText/StateView/BannerSlot） |

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0017/商城前台/商品浏览/首页与公开分类品牌/商城首页/DU-BE-701/implementation.md`
  - `MallHomeController` GET /api/mall/home（匿名，网关白名单已在 DU-BE-702 加好）
  - `HomeApplicationService` 三路聚合：categoryEntries（启用根≤8）+ newArrivals（复用 mallPage）+ recommends（fallback）+ banners([])
  - `MallHomeDtos` @StringId，空数据各数组返回 [] 非 null
- repo-2：`implementation/ai-platform-frontend/delivery/CHG-0017/商城前台/商品浏览/首页与公开分类品牌/商城首页/DU-FE-701/implementation.md`
  - `api/catalog.ts` getHome + HomeView 类型；`PriceText` 整数分→¥ 无浮点；`StateView` 四态；`ProductCard` 懒加载+跳转；`BannerSlot` 占位
  - HomeView 四态加载、分类→/products?categoryId=、卡片→/products/:id

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | /api/mall/home 匿名 200，返回 categoryEntries(≤8启用根) + newArrivals(ON_SALE+启用SKU,价区) + recommends(source=FALLBACK_NEWEST) + banners([]) | passed（MallHomeApiTest::homeAggregation / homeEmpty / categoryEntriesLimit8） |
| AC-002 | 空数据各数组返回 []；分类与商品查询部分降级 | passed（homeEmpty 空数组；单路异常走全局 503） |
| AC-018 | 首页四态（loading/empty/error+重试/success）、分类入口与卡片路由、价区整数分展示、图片懒加载 | passed（HomeView.spec.ts 4 例 + PriceText.spec.ts 4 例） |
| AC-019 | ProductCard/PriceText/StateView 公共组件沉淀，供列表/详情复用 | passed（components/ 下 4 组件 + StateView 插槽设计） |

## 5. 前置 Story 代码提交（repos-coverage 累计）

| Commit | Story | 说明 |
| --- | --- | --- |
| b4b5a1f | STORY-003-02-01-02 公开分类与品牌查询 | 公开分类树/品牌接口 + 网关白名单（含 /api/mall/home） |
| b982bf5 | STORY-003-02-03-01 SKU 可售状态聚合 | inventory availability + product sku stockStatus |
