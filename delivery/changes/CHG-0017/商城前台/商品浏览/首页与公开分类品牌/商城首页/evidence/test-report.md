# Test Report — STORY-003-02-01-01 商城首页

> 阶段：sdd-test 产物（独立验证：按 test-design.md AC 逐条核对，证据取自 DU-BE-701）。

## 0. 元信息

- Change ID：CHG-0017（商城商品浏览体验）
- Story ID：STORY-003-02-01-01
- 执行时间：2026-09-15
- 覆盖：AC-001、AC-002
- 测试基线：repo-1 `mvn -pl mall-services/mall-product clean test`（84/84）。
- 测试环境：JDK 21、Spring Boot Test + MockMvc、H2 内存库（MODE=MySQL）、@ActiveProfiles("test")。

## 1. TC 执行结果

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| homeAggregation | 分类入口仅启用根(3)、新品仅含启用SKU(2)、推荐 source=FALLBACK_NEWEST、banners=[]、价区填充 | MockMvc + JDBC fixture | passed | MallHomeApiTest::homeAggregation |
| homeEmpty | 无分类无商品时各数组返回 [] | MockMvc | passed | MallHomeApiTest::homeEmpty |
| categoryEntriesLimit8 | 分类入口>8 时只取前 8 | MockMvc + JDBC fixture | passed | MallHomeApiTest::categoryEntriesLimit8 |

合计：3 passed / 0 failed / 0 skipped。

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-product | `mvn -pl mall-services/mall-product clean test` | 84/84（新增 3 + 既有 81 零回归） |

## 3. 红→绿记录

- RED：product_sku INSERT 缺 `specification_data`/`specification_hash` NOT NULL 列；`specification_data='[]'` 被 `parseSpecifications` 当作 Map 解析抛 IllegalStateException。
- GREEN：INSERT 补 `specification_data='{}'` + `specification_hash` → 全绿。

## 4. AC 覆盖

| AC | 覆盖 TC |
|----|---------|
| AC-001 | homeAggregation（分类入口≤8 + 新品 ON_SALE+启用SKU + 价区 + 推荐 fallback + banners 空 + id 字符串） |
| AC-002 | homeEmpty（空态 []）、单路异常走全局 503 |
