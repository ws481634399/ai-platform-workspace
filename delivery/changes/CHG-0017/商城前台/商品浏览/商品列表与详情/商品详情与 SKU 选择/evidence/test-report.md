# Test Report — STORY-003-02-02-02 商品详情与 SKU 选择

> 阶段：sdd-test 产物。

## 0. 元信息

- Change ID：CHG-0017
- Story ID：STORY-003-02-02-02
- 执行时间：2026-09-16
- 覆盖：AC-011~AC-014、AC-018、AC-020
- 测试基线：repo-1 mall-product 93/93；repo-2 mall-web 85/85 + tsc/build 成功。

## 1. TC 执行结果

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| detailWithMatrix | brandName/categoryPath/dimensionsOrder/specDimensions 去重保序/skuIndex 组合键 | MockMvc + JDBC | passed | MallProductDetailEnhancedTest |
| detailNotFound | 不存在商品 → 404 | MockMvc | passed | MallProductDetailEnhancedTest |
| detailNoEnabledSku | 无启用 SKU 商品 → 404（不泄露存在性） | MockMvc + JDBC | passed | MallProductDetailEnhancedTest |
| sku-select-unique | 选齐维度命中唯一 SKU；未选齐 change=null | vitest | passed | SkuSelector.spec.ts |
| sku-select-disabled | 蓝\|XL DISABLED 组合置灰 disabled | vitest | passed | SkuSelector.spec.ts |
| stock-badge | 三态文案/样式 + UNKNOWN 重试 emit | vitest | passed | StockBadge.spec.ts |
| catalog-detail-api | getProductDetail / getSkuAvailability / 空数组不发请求 | vitest | passed | catalog.spec.ts |
| detail-render | 名称/品牌/面包屑渲染 + 批量可售状态查询 | vitest | passed | ProductDetailView.spec.ts |
| detail-sanitize | 富文本 DOMPurify 净化（script 剥离，jsdom 环境） | vitest | passed | ProductDetailView.spec.ts |
| detail-404 | 404 不存在态无加购入口 | vitest | passed | ProductDetailView.spec.ts |
| detail-add-disabled | 未选齐 SKU 加购按钮禁用 | vitest | passed | ProductDetailView.spec.ts |
| sku-three-dim | 三维度初始无选择不误禁用 | vitest | passed | SkuSelector.spec.ts |

合计：BE 3 / FE 14（SkuSelector 4 + StockBadge 3 + catalog 3 + ProductDetailView 4）passed。

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-product | `mvn -pl mall-services/mall-product test` | 93/93 |
| mall-web | `npx vitest run` | 85/85 |
| mall-web | `npx vue-tsc --noEmit` | 零错误 |
| mall-web | `npx vite build` | 成功 |

## 3. 红→绿记录

- RED-1（FE）：SkuSelector `isValueDisabled` 初版仅枚举第一个未选维度，三维度以上且无选择时组合键残留通配符，导致所有值被误判禁用。GREEN：改为遍历 skuIndex 全部组合做兼容性匹配（已选维度约束、未选维度通配），补三维度守护测试。
- RED-2（FE）：ProductDetailView 误用 StateView 的 `state` prop（实际 API 为 loading/error/is-empty）。GREEN：对齐三 prop，404 → is-empty；availability 批量失败 try/catch 降级 UNKNOWN 不阻塞图文。
- BE 两个防御点（组合键冲突取 skuId 较小并 warn；brand/category 缺失降级不 500）按 task-design 一次实现，单测覆盖正常路径，防御路径代码审查确认。

## 4. AC 覆盖

| AC | 覆盖 TC |
|----|---------|
| AC-011 | detailWithMatrix |
| AC-012 | sku-select-unique + ProductDetailView onSkuChange 联动 |
| AC-013 | detailNotFound + detailNoEnabledSku + 前端 empty 态 |
| AC-014 | sku-select-disabled + stock-badge OUT_OF_STOCK |
| AC-018 | ProductDetailView StateView 四态 |
| AC-020 | catalog.spec.ts 类型断言（priceFen number）+ PriceText 整数拆分（既有 4 例） |
