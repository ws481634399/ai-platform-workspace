# Test Report — STORY-003-02-01-02 公开分类与品牌查询

> 阶段：sdd-test 产物（独立验证：按 test-design.md TC 逐条核对，证据取自 DU-BE-702 evidence）。

## 0. 元信息

- Change ID：CHG-0017（商城商品浏览体验）
- Story ID：STORY-003-02-01-02
- 执行时间：2026-09-15
- 覆盖：AC-003、AC-004、AC-005
- 测试基线：repo-1 `mvn -pl mall-services/mall-product clean test`（75/75）、`mvn -pl mall-gateway test`（19/19）。
- 测试环境：JDK 21、Spring Boot Test + MockMvc、H2 内存库（MODE=MySQL）、@ActiveProfiles("test")。

## 1. TC 执行结果

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| TC-001 | 分类树仅启用、禁用父整枝剪除（含启用子）、按 sort | MockMvc + JDBC fixture | passed | MallCatalogApiTest::categoryTreeEnabledOnlyAndPrune |
| TC-002 | 品牌仅启用、keyword 模糊、size>200 收敛 200、id 字符串 | MockMvc + JDBC fixture | passed | MallCatalogApiTest::brandsEnabledKeywordAndSizeCap |
| TC-004 | 空分类树/空品牌返回 [] | MockMvc | passed | MallCatalogApiTest::emptyCategoryTree + emptyBrands |
| — | keyword 通配符 % 转义不当作 LIKE 通配 | MockMvc + JDBC fixture | passed | MallCatalogApiTest::brandKeywordWildcardEscaped |

合计：5 passed / 0 failed / 0 skipped。

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-product | `mvn -pl mall-services/mall-product clean test` | 75/75（新增 5 + 既有 70 零回归） |
| mall-gateway | `mvn -pl mall-gateway test` | 19/19（白名单变更零回归） |

## 3. 红→绿记录

- RED：BrandRepositoryImpl 编译失败 `[42,43] 需要 ')' 或 ','`——ECJ 对链式 `.eq(boolean condition, SFunction, Object)` 重载推断失败，导致后续方法引用解析异常。
- GREEN：page() 拆为 if 块分别调用 `.eq()` / `.apply()`；keyword 改用 `LOWER(name) LIKE CONCAT('%', LOWER({0}), '%') ESCAPE '!'` + `escapeLike()` 转义 `%`/`_`/`!` → 全绿。

## 4. AC 覆盖

| AC | 覆盖 TC |
|----|---------|
| AC-003 | TC-001 |
| AC-004 | TC-002 |
| AC-005 | GatewaySecurityConfiguration /api/internal/** denyAll（CHG-0015 既有，白名单变更零回归） |
