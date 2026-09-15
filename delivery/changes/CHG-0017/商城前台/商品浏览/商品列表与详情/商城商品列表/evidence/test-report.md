# Test Report — STORY-003-02-02-01 商城商品列表

> 阶段：sdd-test 产物。

## 0. 元信息

- Change ID：CHG-0017
- Story ID：STORY-003-02-02-01
- 执行时间：2026-09-16
- 覆盖：AC-006~AC-009、AC-020
- 测试基线：repo-1 mall-product 90/90；repo-2 mall-web 71/71 + build 成功。

## 1. TC 执行结果

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| brandIdsMultiSelect | brandIds 多选交集命中两品牌 | MockMvc + JDBC | passed | MallProductListEnhancedTest |
| descendantCategory | 子孙分类展开（父分类命中子分类商品） | MockMvc + JDBC | passed | MallProductListEnhancedTest |
| sortByPrice | price_asc 升序 / price_desc 降序（派生表） | MockMvc + JDBC | passed | MallProductListEnhancedTest |
| invalidSortFallback | 非法 sort 回落 default | MockMvc | passed | MallProductListEnhancedTest |
| sizeCap50 | size>50 收敛 50 | MockMvc | passed | MallProductListEnhancedTest |
| priceRangeNonNull | minPrice/maxPrice long 非空 | MockMvc | passed | MallProductListEnhancedTest |
| catalog-api | getProducts brandIds 逗号序列化、serializeProductQuery 空值省略 | vitest | passed | catalog.spec.ts（5 例） |

合计：BE 6 / FE 5 passed。

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-product | `mvn -pl mall-services/mall-product test` | 90/90 |
| mall-web | `pnpm test` | 71/71 |
| mall-web | `pnpm build` | 成功 |

## 3. 红→绿记录

- RED：分类不存在时 collectDescendantCategoryIds 返回空列表，SQL `<if categoryIds.size()>0>` 跳过过滤导致返回全部商品。
- GREEN：service 层判断 categoryId 非空且 categoryIds 为空 → 直接返回空页（不查库）。

## 4. AC 覆盖

| AC | 覆盖 TC |
|----|---------|
| AC-006 | sizeCap50 + priceRangeNonNull |
| AC-007 | descendantCategory |
| AC-008 | brandIdsMultiSelect |
| AC-009 | sortByPrice + invalidSortFallback |
| AC-020 | ProductListView route.query 双向同步 + catalog.spec.ts |
