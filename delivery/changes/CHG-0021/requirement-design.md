---
affected-repositories: [repo-1, repo-2]
---

# Requirement Design（需求级方案设计）

> 层级：Requirement 级产物——本次 Change 的技术方案骨架
> 业界锚点：ADR（Context → Decision → Alternatives → Consequences）+ 跨仓影响面
> 输入：requirement-spec.md + exploration.md + CHG-0011/0012/CHG-0019/CHG-0020 设计
> 产出状态：designed
> 分层关系：本文是 Requirement 级；各 Story 详细设计见 Story 目录 story-design.md。

## 0. 元信息

- Change ID: CHG-0021
- spec 来源: CHG-0021/requirement-spec.md（REQ-M5-002 商品搜索索引同步）
- 相关仓库: repo-1（ai-platform-backend：mall-search、mall-product、mall-gateway、mall-identity）、repo-2（ai-platform-frontend：mall-admin）
- 受影响仓库数: 2
- 需要 Migration: yes（mall_search 库 Flyway V1：search_index_rebuild_task、search_sync_failure_record；mall-identity V9 权限菜单种子——V9 归属 CHG-0022 同一版本号需协调，见 §8）

## 1. 当前状态

- mall-search（8107）：CHG-0020 交付 ES Client 接入、查询能力、别名 `mall_products` 的读路径与 Mapping 常量（测试用）；**无索引生命周期服务、无 internal/admin 端点、无 Flyway 表、无调度**。
- mall-product（8103）：InternalProductController 仅 3 个端点（单 SKU 快照、existsSku、skus/batch），**无分页枚举投影端点**；ProductApplicationService 的 create/update/changeStatus/addSku/updateSku/changeSkuStatus/publish/unpublish 为事务方法；domain 已有 ProductPublishedDomainEvent/ProductUnpublishedDomainEvent 类，但当前**无 Spring 事件发布与监听**；ProductRepository 有分页与 findById 装配聚合（含 SKU 极值计算所需数据）。
- CHG-0019 compensation_task 提供成熟范式：退避序列 30s/1m/2m/5m/10m、最多 5 次、@Scheduled 固定速率 + 条件更新拾取、人工重试端点；本 Change 在 mall_search 库独立同构实现，不共表。
- mall-identity：权限/菜单 Flyway 种子当前到 V8（订单）；下一可用版本 V9（CHG-0022 同样需要 V9——协调：本 Change 的 search:index:* 与 CHG-0022 的 system:* 分两个迁移文件或合并发布；决策见 §8：CHG-0021 使用 V9，CHG-0022 使用 V10，避免版本争用）。
- mall-admin：动态菜单/权限页面体系齐备，补偿台页面可参照。

## 2. 提议方案

### 2.0 总体链路

```
mall-product 事务提交(AFTER_COMMIT 应用事件)
  → ProductSearchSyncListener → SearchSyncClient(RestClient+X-Internal-Token, 直连 8107)
      POST /api/internal/search/products/sync | DELETE /api/internal/search/products/{id}
mall-search 内部端点：组装/删除 ES 文档（external_gte 版本）；ES 故障 → search_sync_failure_record 落表 → 200 受理
定时 SyncFailureRetryJob：退避重试（重拉 product 投影当前态后执行）
全量/重建：mall-search 分页拉 GET mall-product /api/internal/products/search-projection → Bulk 到 v1/rebuild 索引
ADMIN：/api/admin/search/index/** 触发重建/查状态/一致性检查（mall-admin 运维页）
```

### 2.1 索引生命周期（mall-search）

- `IndexMappingDefiner`：与 CHG-0020 同源 Mapping（复用其常量/资源），settings：number_of_shards=1、number_of_replicas=0。
- `IndexLifecycleService.ensureIndex()`（ApplicationRunner，STARTUP 期幂等）：物理索引 mall_products_v1 不存在则创建并放别名 mall_products；均存在则跳过；异常只 ERROR 不阻断启动。
- 重建：`mall_products_rebuild_{yyyyMMddHHmmss}` → 全量 bulk（refresh）→ aliases 原子 actions（remove 旧物理索引别名 + add 新索引别名）→ 删除旧物理索引；全程查询别名不中断。
- `search_index_rebuild_task`：id、task_no、status(PENDING/RUNNING/SUCCESS/FAILED)、total_count、indexed_count、failed_count、physical_index、error_message、started_at、finished_at、created_at、updated_at。
- 并发：触发前 SELECT ... WHERE status='RUNNING' 判存在 → 409 SEARCH_REBUILD_RUNNING；状态推进用条件更新。

### 2.2 mall-product 投影端点

- `GET /api/internal/products/search-projection?page=1&size=500`（SERVICE）：
  - 复用 ProductMapper 分页查询 ON_SALE 商品（join 分类名/品牌名）+ 内存装配启用 SKU 价格极值；仅返回含 ≥1 ENABLED SKU 商品（分页口径：SQL 过滤 EXISTS enabled sku 或内存过滤——design story 细化，优先 SQL EXISTS 保证 total 口径）。
  - ProductProjectionView：productId(String)、productName、categoryId、categoryName、brandId、brandName、mainImage、keywords（M5 空串，列预留）、status、minPriceFen、maxPriceFen、publishedAt(epoch milli)、updatedAt(epoch milli)。
- 单商品投影内部方法供增量复用：search 侧重试时也可调 `GET /api/internal/products/{id}/search-projection`（单条，404 语义=已删除/不可见→应删文档）。

### 2.3 增量同步（mall-product 侧）

- 新增应用事件 `ProductSearchChangedEvent(productId, kind)`（CREATED/UPDATED/PUBLISHED/UNPRICED/PRICE_CHANGED 归一为 CHANGED；下架单独 UNPUBLISHED）。
- 在 ProductApplicationService 各写方法事务成功后发布事件（ApplicationEventPublisher，publish 在事务内、监听 AFTER_COMMIT，天然拿到提交结果）；事件载荷仅 productId。
- `ProductSearchSyncListener`：单商品投影查询（新增内部应用服务方法，复用聚合装配），按当前状态调用 search：ON_SALE 有效→sync(upsert)；其余→delete；监听内 try-catch 全兜底，异常仅 WARN（search 不可达时 search 侧无法落表的窗口由 WARN + 低频对账兜底；M5 可接受，reason：product 不被投影故障拖垮是硬约束）。
  - 增强（同 Story 实现）：search 不可达时 product 侧不具备落表条件；为缩小丢失窗口，search 侧 sync 端点在收到但 ES 写入失败时落表；调用完全不通的极端窗口依赖一致性检查/重建发现（M5 接受，文档明示）。
- SearchSyncClient 超时：connect 1s/read 3s。

### 2.4 mall-search 同步写入与可靠性

- InternalSearchSyncController：
  - `POST /api/internal/search/products/sync`：body=ProductProjectionView；ON_SALE→index(docId=productId, external version=updatedAt, external_gte)；非 ON_SALE→delete（带版本保护）；ES 异常 → failure_record upsert + 返回 200 accepted=true。
  - `DELETE /api/internal/search/products/{productId}`：幂等删除（version 冲突 → 不删 + WARN，正常受理）。
- VersionConflictEngineException 一律消化为成功（更新的版本已在）。
- `search_sync_failure_record`：id、product_id、event_type（UPSERT/DELETE）、status（PENDING/SUCCESS/FAILED_DEAD）、retry_count、max_retries 默认 5、last_error、next_retry_at、created_at、updated_at；uk(product_id,event_type,status) 采用应用层"存在 PENDING 则更新否则插入"（避免唯一键把不同历史失败合并）。
- SyncFailureRetryJob（@Scheduled fixedDelay 30000）：查 PENDING AND next_retry_at<=now LIMIT 100；逐条重拉投影单条（404/非在架→delete）执行；成功 SUCCESS；失败 retry_count+1、退避序列、≥5→FAILED_DEAD；拾取/状态迁移条件更新。
- `POST /api/admin/search/sync-failures/{id}/retry`（search:index:rebuild）：重置计数立即重试。
- `GET /api/internal/search/sync-failures?status=`（SERVICE）：供排查。

### 2.5 一致性检查与 admin 端点

- `POST /api/admin/search/index/rebuild` → 202 {taskId}；`GET /api/admin/search/index/rebuild/{taskId}`；`GET /api/admin/search/index/rebuild?limit=` 最近任务。
- `GET /api/admin/search/index/consistency-check`：分页拉全部在架 productId 集（投影端点）+ ES 全量 _id 集（scroll/分页，M5 数据量小用 search_after），输出 {productOnSaleCount,indexCount,missingProductIds[],extraProductIds[],checkedAt}（差异列表上限 200，超限截断并提示）。
- 权限：search:index:list（查任务/检查）、search:index:rebuild（重建/重试）；mall-gateway 增 /api/admin/search/** → 8107 ADMIN 路由；SearchSecurityConfiguration ADMIN + @PreAuthorize 权限码（沿用既有 @PreAuthorize 模式）。
- mall-admin：views/search/SearchIndexView.vue（任务状态表、重建按钮+确认弹窗、一致性检查面板、失败记录与人工重试入口）。

### 2.6 分层结构（新增包）

```
mall-search
├── domain/index/   IndexRebuildTask(状态机)/SearchSyncFailure(退避计算)/IndexErrorCode(B051x)
│                   IndexLifecyclePort/SearchIndexPort/SyncFailureRepository/RebuildTaskRepository
├── application/index/  FullIndexBuildService/RebuildService/ConsistencyCheckService/SyncReceiveService/SyncFailureRetryJob
├── infrastructure/
│   ├── elasticsearch/  EsIndexLifecycleAdapter/EsSearchIndexAdapter(复用 CHG-0020 client)
│   ├── persistence/index/  Po/Mapper/RepositoryImpl（两表）
│   └── client/ProductProjectionClient（RestClient 内部调用）
└── interfaces/rest/internal/InternalSearchSyncController
    └── rest/admin/AdminSearchIndexController + dto
mall-product
├── application/product/event/ProductSearchChangedEvent + ProductSearchSyncListener
├── infrastructure/client/SearchSyncClient
└── interfaces/rest/internal/InternalProductController(+search-projection) + dto
```

## 2.1 备选方案对比（Alternatives Considered）

| 决策 | 采纳 | 备选与理由 |
| --- | --- | --- |
| 触发机制 | AFTER_COMMIT 应用事件 + 同步 HTTP + 调度补偿 | 直接 MQ：M7 才引入，需求明确不提前；轮询 binlog：过重 |
| 下架处理 | 硬删除 | status 标记：查询已有 ON_SALE 双保险，但索引累积垃圾且数量核对口径复杂；硬删除与"仅在架入索引"一致 |
| 重建方案 | 临时索引 + 别名原子切换 | 原地 delete+bulk：构建中结果残缺；reindex API：无法灌代码组装文档（投影在应用层） |
| 乱序防护 | updatedAt 毫秒 external_gte | 应用层先查后比：多读一次且仍有竞态；ES 原生版本号最省 |
| 重试数据源 | 重拉投影当前态，不信旧 payload | 旧 payload 重放会把已下架商品重新 upsert |
| 失败表位置 | mall_search 库独立表 | 放 mall_product：跨库写入；复用 order compensation_task：跨域共表违规 |
| product 调不通 search 的极端窗口 | WARN + 一致性检查/重建兜底 | product 本地 outbox 表：等于提前做 M7 |

## 3. 仓库影响（Repository Impact）

### 3.1 repo-1（ai-platform-backend）

- mall-search：新增 domain/index、application/index、infrastructure（es adapter/persistence/client）、interfaces internal+admin；Flyway V1 两表；application.yml 开 flyway、调度、product 内部 URI；@EnableScheduling。
- mall-product：新增投影端点（+Service/Mapper SQL）、应用事件、监听器、SearchSyncClient；写路径接线 7 个方法；无 DDL。
- mall-gateway：/api/admin/search/** → 8107 ADMIN 路由（internal 不开）。
- mall-identity：新增 search:index:list/rebuild 权限码与菜单种子（迁移版本 V9，CHG-0022 用 V10）。

### 3.2 repo-2（ai-platform-frontend）

- mall-admin：api/searchIndex.ts、stores/searchIndex.ts、views/search/SearchIndexView.vue + 动态路由/菜单（菜单数据来自后端种子）。

## 4. 跨仓协作

- API Contract：
  - product→search：`POST /api/internal/search/products/sync`（ProductProjectionView）→ {accepted}；`DELETE /api/internal/search/products/{id}` → {deleted}；SERVICE；故障语义见 §2.4。
  - search→product：`GET /api/internal/products/search-projection?page&size` → UnifyResult<Page<ProductProjectionView>>；`GET /api/internal/products/{id}/search-projection` → 404/视图；SERVICE。
  - admin→search：/api/admin/search/index/rebuild（POST/GET）、/consistency-check、/sync-failures/{id}/retry；ADMIN+权限码；409 重建并发。
- Data Contract：ProductProjectionView 字段以 CHG-0020 requirement-design §2.2 字段表为准（SearchDocument 同构）；updatedAt 为版本基准（epoch milli）。
- Repository Dependencies：mall-product 不依赖 mall-search 启动成功（best-effort）；search 依赖 product 投影契约；前端依赖 admin 契约。
- Integration Boundary：内部端点全部 X-Internal-Token、网关 denyAll；admin 走网关。
- Cross-Repository Sequence：CHG-0020 查询能力 → 本 Change 建索引（此时搜索端到端首次打通）→ Integration Gate 场景一~五联调。

## 5. Story 设计分派（Story Design Assignments）

| Story ID | domain（L3） | 技术要点 | 仓库 |
| -------- | ------------ | -------- | ---- |
| STORY-005-02-01-01 索引 Mapping 管理与首次全量构建 | FEAT-005-02-01 索引生命周期与全量构建 | ensureIndex 幂等/别名、投影端点+Mapper、ProjectionClient、Bulk 全量、V1 两表（BE-503） | repo-1 |
| STORY-005-02-01-02 手工重建与一致性检查 | FEAT-005-02-01 索引生命周期与全量构建 | 双索引切换/任务状态机/并发 409/差集检查/权限种子 V9/网关 admin/运维页（BE-504、FE-502） | repo-1、repo-2 |
| STORY-005-02-02-01 商品变更增量同步 | FEAT-005-02-02 增量同步与可靠性 | product 事件+AFTER_COMMIT 监听+SearchSyncClient、search 内部 sync/delete、7 写路径接线（BE-505） | repo-1 |
| STORY-005-02-02-02 同步幂等乱序防护与失败重试 | FEAT-005-02-02 增量同步与可靠性 | external_gte/冲突消化/failure_record/退避 Job/人工重试（BE-506） | repo-1 |

## 6. DU 划分总览（跨 Story 依赖）

| DU id | repository | goal | 关联 Story | depends on |
| ----- | ---------- | ---- | ---------- | ---------- |
| DU-BE-503 | repo-1 | 索引生命周期 ensureIndex/别名 + product 投影端点 + Bulk 全量构建 + Flyway V1 | STORY-005-02-01-01 | CHG-0020 DU-BE-501 |
| DU-BE-504 | repo-1 | 重建任务/别名切换/一致性检查/权限种子 V9/网关 admin 路由 | STORY-005-02-01-02 | DU-BE-503 |
| DU-FE-502 | repo-2 | mall-admin 搜索索引运维页 | STORY-005-02-01-02 | DU-BE-504 |
| DU-BE-505 | repo-1 | product 应用事件/监听/SyncClient + search 内部 sync/delete + 写路径接线 | STORY-005-02-02-01 | DU-BE-503 |
| DU-BE-506 | repo-1 | external 版本/乱序消化/failure_record/退避重试/人工重试 | STORY-005-02-02-02 | DU-BE-505、DU-BE-503 |

## 7. 数据变更

```sql
-- mall_search V1__search_index_init.sql（MySQL，H2 测试用 MySQL 兼容模式或 mysql 模式 profile）
CREATE TABLE search_index_rebuild_task (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  task_no VARCHAR(48) NOT NULL UNIQUE,
  status VARCHAR(16) NOT NULL,           -- PENDING/RUNNING/SUCCESS/FAILED
  total_count INT NOT NULL DEFAULT 0,
  indexed_count INT NOT NULL DEFAULT 0,
  failed_count INT NOT NULL DEFAULT 0,
  physical_index VARCHAR(96) NOT NULL,
  error_message VARCHAR(1000) NULL,
  started_at DATETIME(6) NULL, finished_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  KEY idx_status_created (status, created_at)
);
CREATE TABLE search_sync_failure_record (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  product_id BIGINT NOT NULL,
  event_type VARCHAR(16) NOT NULL,       -- UPSERT/DELETE
  status VARCHAR(16) NOT NULL,           -- PENDING/SUCCESS/FAILED_DEAD
  retry_count INT NOT NULL DEFAULT 0,
  max_retries INT NOT NULL DEFAULT 5,
  last_error VARCHAR(1000) NULL,
  next_retry_at DATETIME(6) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  KEY idx_status_next_retry (status, next_retry_at),
  KEY idx_product (product_id)
);
-- mall-identity V9：权限码 search:index:list / search:index:rebuild + “系统管理-搜索索引”菜单（INSERT，沿用 V8 种子风格与角色关联）
```

## 8. 风险

| 风险项 | 级别 | 缓解措施 |
| --- | --- | --- |
| Flyway 版本号 V9 与 CHG-0022 冲突 | 中 | 本 Change 用 V9（search 权限），CHG-0022 用 V10（system 权限）；开发顺序锁定，评审检查 |
| 投影分页与在架过滤 total 口径 | 中 | SQL EXISTS(enabled sku) 过滤保证 total=索引全集；集成测试 1001 条验证 |
| product 调不通 search 的丢失窗口 | 中 | M5 接受：sync 端点落表覆盖"收到但 ES 挂"；"完全不通"由一致性检查发现；converge 文档明示边界 |
| 重建期别名切换失败 | 中 | 原子 aliases actions；任何异常保留旧索引与 FAILED 任务；可再次触发 |
| 调度重复拾取（未来多实例） | 低 | 条件更新 + M5 单实例；M7 引入 MQ/分片时替换 Job |
| 全量比对数据量 | 低 | M5 商品量级千级；search_after + 差异截断 200；报告 total 不受限 |

## 9. 待澄清问题

- 无阻断项；迁移版本 V9/V10 分配在本文冻结，CHG-0022 设计遵守。
