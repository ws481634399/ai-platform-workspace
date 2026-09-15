# Test Report — STORY-003-02-01-01 商城首页

> 阶段：sdd-test 产物（独立验证：按 test-design.md AC 逐条核对，证据取自 DU-BE-701）。

## 0. 元信息

- Change ID：CHG-0017（商城商品浏览体验）
- Story ID：STORY-003-02-01-01
- 执行时间：2026-09-15/16
- 覆盖：AC-001、AC-002、AC-018、AC-019
- 测试基线：repo-1 `mvn -pl mall-services/mall-product clean test`（84/84）；repo-2 `pnpm test`（68/68）、`pnpm build`（成功）。
- 测试环境：repo-1 JDK 21 + MockMvc + H2；repo-2 vitest 4 + happy-dom + @vue/test-utils。

## 1. TC 执行结果

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| homeAggregation | 分类入口仅启用根(3)、新品仅含启用SKU(2)、推荐 source=FALLBACK_NEWEST、banners=[]、价区填充 | MockMvc + JDBC fixture | passed | MallHomeApiTest::homeAggregation |
| homeEmpty | 无分类无商品时各数组返回 [] | MockMvc | passed | MallHomeApiTest::homeEmpty |
| categoryEntriesLimit8 | 分类入口>8 时只取前 8 | MockMvc + JDBC fixture | passed | MallHomeApiTest::categoryEntriesLimit8 |
| catalog-api | getHome 命中 GET /api/mall/home，解包 HomeView | vitest（mock http） | passed | catalog.spec.ts |
| price-text | 整数分→¥ 无浮点：9900→¥99.00、5→¥0.05、null→¥-- | @vue/test-utils | passed | PriceText.spec.ts（4 例） |
| home-four-states | loading/empty/error+重试/success 四态渲染；分类→/products?categoryId=1；卡片→/products/101 | @vue/test-utils + vue-router | passed | HomeView.spec.ts（4 例） |

合计：BE 3 passed / FE 14 passed / 0 failed / 0 skipped。

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-product | `mvn -pl mall-services/mall-product clean test` | 84/84（新增 3 + 既有 81 零回归） |
| mall-web | `pnpm test` | 68/68（新增 14 + 既有 54 零回归） |
| mall-web | `pnpm build` | 成功 |

## 3. 红→绿记录

- RED：product_sku INSERT 缺 `specification_data`/`specification_hash` NOT NULL 列；`specification_data='[]'` 被 `parseSpecifications` 当作 Map 解析抛 IllegalStateException。
- GREEN：INSERT 补 `specification_data='{}'` + `specification_hash` → 全绿。

## 4. AC 覆盖

| AC | 覆盖 TC |
|----|---------|
| AC-001 | homeAggregation（分类入口≤8 + 新品 ON_SALE+启用SKU + 价区 + 推荐 fallback + banners 空 + id 字符串） |
| AC-002 | homeEmpty（空态 []）、单路异常走全局 503 |
| AC-018 | home-four-states（四态渲染 + 路由） + price-text（整数分展示） |
| AC-019 | ProductCard/PriceText/StateView/BannerSlot 组件沉淀 + StateView 插槽复用设计 |
