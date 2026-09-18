# Implementation（跨仓实施汇总）— 索引 Mapping 管理与首次全量构建 STORY-005-02-01-01

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0021（商品搜索索引同步）
- Story：STORY-005-02-01-01 索引 Mapping 管理与首次全量构建
- 实施日期：2026-09-18

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-503 | repo-1 | mall-search：V1 Flyway 两表、IK/standard 双 Mapping 资源、启动幂等建索引+别名、500/批全量构建服务、RestClient 投影客户端、安全链/健康检查；mall-product：在架投影 Mapper（启用 SKU INNER JOIN 取价区）+ 分页/单条内部端点（SERVICE，单条 404）。真实 ES Testcontainers IT + 投影 API 测试就位 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 82ccf6e | DU-BE-503 | repo-1 | feat(search,system): M5 商品搜索+索引同步+系统配置（CHG-0020/0021/0022 后端，M5 三 Change 合并提交） |

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0021/商品搜索/搜索索引同步/索引生命周期与全量构建/索引 Mapping 管理与首次全量构建/DU-BE-503/implementation.md`
  - `mall-search`：`V1__create_search_sync_tables.sql` 建 `search_index_rebuild_task`/`search_sync_failure_record`；`resources/es/product-index.json`（IK 冻结版）+ `product-index-standard.json`（无插件回退，字段类型一致）；`SearchIndexLifecycleManager`（ApplicationRunner 最高优先级，ensureIndex 幂等，ES 宕机仅 log.error 不阻启动）；`EsSearchIndexAdapter`（IK 检测回退、ExternalGte bulk、PIT `_shard_doc` search_after 游标）；`FullIndexBuildService`（500/页、页号从 1、进度回调）；`ProductProjectionClient`（RestClient 2s/5s、X-Internal-Token、404→null）；`SearchSecurityConfiguration`（internal SERVICE / admin ADMIN，test profile 不装配）；`SearchHealthIndicator`。
  - `mall-product`：`ProductSearchProjectionMapper`（ON_SALE + deleted=0，启用 SKU 派生表 INNER JOIN 取 MIN/MAX sale_price，LEFT JOIN 分类/品牌名，id 升序分页，`keywords` 固定空串）；`InternalProductController` 两端点（分页 500、单条；无令牌 401，不存在/非在架/无启用 SKU 404）。
  - 说明：未提供独立内部 `full-build` 端点，首次全量复用管理端重建链路（见 Story STORY-005-02-01-02）。

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | 全新 ES 启动自动建 `mall_products_v1`+别名 `mall_products`，重复执行幂等不改 Mapping | passed（`ensureIndexIdempotentWithStandardFallback`） |
| AC-002 | Mapping 资源可评审：价格 long、productId long 作 docId/term、mainImage keyword index:false、时间 date epoch_millis、文本可检索（IK，回退 standard） | passed（`product-index.json`/`product-index-standard.json` 资源评审 + 建索引 IT） |
| AC-003 | 投影端点无令牌 401；持令牌分页正确含 total；网关对 `/api/internal/**` denyAll 返 404 | passed（`projectionWithoutTokenUnauthorized`、`projectionPageOnSaleOnly`；网关 404 配置保证，未 E2E） |
| AC-004 | 投影排除下架/无启用 SKU；价区与启用 SKU 极值一致（1000/3000） | passed（`projectionPageOnSaleOnly`、`singleProjectionAndNotFoundCases`） |
| AC-005 | 全量后 ES count=投影总数；抽样文档字段（名/分类品牌/图/价格/时间）正确 | passed（`fullRebuildSwitchesAliasAtomically` 断言 count=3/别名指向；`syncUpsertAcceptedAndSearchable` 抽样可搜） |
| AC-006 | 数据量 >500 分批（Testcontainers 造 1001 条）；中途失败 FAILED 且错误可定位 | ⚠️ 部分：`FullIndexBuildService` 500/批与 `RebuildService.markFailed`（rootMessage 截断 1000）代码路径具备；未造 1001 条数据、未注入批次失败，建议 Integration Gate 补测 |
| AC-007 | Flyway V1 在 mall_search 建两表（列/索引） | passed（`V1__create_search_sync_tables.sql`；H2+Flyway 被全部 `@SpringBootTest` 间接验证，无独立列断言） |

> 测试说明：本 Story 相关自动化为 `IndexSyncIntegrationTest`（真实 ES Testcontainers 8.17.4）与 `ProductSearchProjectionApiTest`（4 例）；当前工作区无 `target/surefire-reports`，本表引用真实测试方法名，未杜撰执行数字。详细自检与 5 条 Deviations（RestClient 替代 Feign、无独立 full-build 端点、IK 回退、404 单条语义、名称字段无 keyword 子字段）见仓内 DU 文档。
