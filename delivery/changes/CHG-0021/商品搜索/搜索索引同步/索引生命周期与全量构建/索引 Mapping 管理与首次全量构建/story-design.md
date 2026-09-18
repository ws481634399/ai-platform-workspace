---
affected-repositories: [repo-1]
story-id: "STORY-005-02-01-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §2.0/§2.1/§2.4
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0021
- Story ID: STORY-005-02-01-01
- 状态流转: specified → designed
- 相关仓库: repo-1（mall-search、mall-product）
- 需要 Migration: yes
- 数据变更概要: mall_search 库 Flyway V1（search_index_rebuild_task/search_sync_failure_record 两表）；ES 物理索引 mall_products_v1+查询别名 mall_products（幂等创建）

## 1. 模块改动（Module Changes）

### repo-1 mall-search（DU-BE-503）

- infrastructure.elasticsearch.SearchIndexLifecycleManager（ApplicationRunner, Ordered 于 client 就绪后）：
  - ensureIndex()：indices().exists(mall_products_v1) → 否则 create（mapping/settings 按 §3 冻结）；alias mall_products 缺失则 putAlias；全部幂等，启动不因 ES 故障中断（catch→ERROR 日志，健康指标 DOWN，供全量/一致性检查暴露）。
- resources/db/migration/V1__create_search_sync_tables.sql（mall_search 库）：
  - search_index_rebuild_task：id bigint PK auto、task_no varchar(40) UK、physical_index varchar(120)、status varchar(20)（RUNNING/SUCCEEDED/FAILED）、total_count bigint、indexed_count bigint、started_at/finished_at datetime、error_message varchar(1000)；
  - search_sync_failure_record：id bigint PK、product_id bigint、op varchar(16)（UPSERT/DELETE）、payload mediumtext、reason varchar(500)、retry_count int default 0、next_retry_at datetime、status varchar(20)（PENDING/SUCCEEDED/FAILED_DEAD）、created_at/updated_at；索引 idx_status_next_retry(status,next_retry_at)。
- domain/search + infrastructure/persistence：对应实体/Mapper（MyBatis-Plus 既有规范）。
- application.search.SearchIndexBuildService：分页游标拉取 product 投影（见下），BulkRequest（每批 500）写物理索引；首轮全量在启动任务/管理触发均可（首次全量以 admin 手动触发+启动 ensureIndex 只建空索引；运维入口在下一 Story）。
- infrastructure.client.ProductProjectionClient（OpenFeign，name=mall-product，contextId）：GET /api/internal/products/search-projection?page&size=500。

### repo-1 mall-product（DU-BE-503）

- interfaces.rest.internal.InternalProductController 增 GET /search-projection（SERVICE，hasAuthority 与既有 internal 端点一致）：
  - ProductSearchProjectionMapper：仅 ON_SALE 且存在至少一个 ENABLED SKU 的商品；SQL `EXISTS(... sku status='ENABLED')` 保证 total 口径；
  - 字段 productId/productName/keywords(取 product.keywords 或既有搜索词字段)/categoryId/categoryName/brandId/brandName/mainImage/status/minPrice/maxPrice/publishedAt/updatedAt；
  - 单条 GET /api/internal/products/{id}/search-projection 同结构（供增量使用）。
  - 价格 min/max：ENABLED SKU priceFen 的 min/max；无启用 SKU 不返回。

## 2. 接口契约细化

| 方法 | 路径 | 调用方 | 响应 |
| --- | --- | --- | --- |
| GET | /api/internal/products/search-projection?page=0&size=500 | mall-search SERVICE | UnifyResult<Page<ProductSearchProjection>> |
| GET | /api/internal/products/{id}/search-projection | mall-search SERVICE | UnifyResult<ProductSearchProjection>；商品不存在或不可售 → success=true,data=null |

## 3. 数据变更

- MySQL mall_search V1 两表（字段见 §1）。
- ES settings：number_of_shards=1、number_of_replicas=0；mapping 字段冻结见 CHG-0020 设计 §2.2（mainImage index:false）。
- 别名：mall_products（查询/写入别名）→ mall_products_v1。

## 4. 错误处理

- 分页投影某 product 数据异常不中断整批（跳过+WARN，记录 productId）。
- ES 启动故障：ensureIndex 捕获并日志，不阻止应用启动。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-503 | repo-1 | product 投影端点(分页/单条)+mall_search V1+索引生命周期+首轮全量构建 | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007 | 无 |

> 跨 Story 依赖（不入本表）：DU-BE-503 实际前置 DU-WS-501（CHG-0020/STORY-005-01-01-01 compose ES）与 DU-BE-501（mall-search ES Client 基线）。

## 6. 测试策略

- Flyway 迁移测试（testcontainers mysql 既有基线）校验两表结构。
- Product 侧 Mapper 测试：ON_SALE 无启用 SKU 被排除、total 口径、价格 min/max。
- IT（ES+MySQL）：ensureIndex 幂等（跑两次）、首次全量后 _count 等于投影 total；ES 宕机时应用仍启动。
