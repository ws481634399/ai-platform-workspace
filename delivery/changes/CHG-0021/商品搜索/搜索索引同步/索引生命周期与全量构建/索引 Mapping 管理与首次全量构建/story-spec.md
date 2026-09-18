---
story-id: "STORY-005-02-01-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S1]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.1 [S1]/§4/§5
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0021
- Story ID: STORY-005-02-01-01 索引 Mapping 管理与首次全量构建
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`（S1）

## 1. Story 目标

建立索引代码化生命周期与首次全量数据链路：mall-search 代码内管理 Mapping/Settings（启动幂等 ensureIndex：物理索引 mall_products_v1 + 查询别名 mall_products）；mall-product 新增 SERVICE 身份的分页投影端点；mall-search 拉取上架商品组装 SearchDocument（价格摘要 minPrice/maxPrice），分批 Bulk 完成首次全量构建并记录构建结果。

## 2. Scope（范围）

### 2.1 包含

- [S1] mall-search：IndexMappingDefiner（代码/资源文件定义 settings+mapping：productId keyword/long、productName text、keywords/text、categoryName/brandName text+keyword 子字段、categoryId/brandId long、mainImage keyword、status keyword、minPrice/maxPrice long、publishedAt/updatedAt date）。
- [S1] IndexLifecycleService.ensureIndex()：应用启动 ApplicationRunner 幂等执行（存在则跳过，不修改在线 Mapping）。
- [S1] mall-product InternalProductController 新增 `GET /api/internal/products/search-projection?page=&size=`：分页返回 ON_SALE 且有 ENABLED SKU 商品的投影（productId/name/categoryId+name/brandId+name/mainImage/keywords（可空）/minPriceFen/maxPriceFen/publishedAt(createdAt)/updatedAt），total/page/size。
- [S1] mall-search：ProductProjectionClient（RestClient + X-Internal-Token，UnifyResult 解包/503 归一）；SearchDocumentAssembler；Bulk 分批（500/批，稳定 productId 排序分页，防深分页）。
- [S1] FullIndexBuildService：内部/admin 可触发（本 Story 提供内部触发端点供手工/初始化调用；admin 页面在 STORY-005-02-01-02）；构建写入 search_index_rebuild_task 记录（本 Story 建该表 Flyway V1，同时含 search_sync_failure_record 表定义占位供 STORY-005-02-02-02 使用）。

### 2.2 不包含

- 双索引重建与别名切换（STORY-005-02-01-02；本 Story 全量构建目标为 v1+alias 初始场景，原地 bulk 到别名指向索引）。
- 增量事件同步与失败重试（STORY-005-02-02-01/02）。

## 3. 业务规则

- [幂等建索引] 物理索引已存在则不重建不改 Mapping；别名已存在不重复创建；启动过程失败不阻断应用启动（记录 ERROR，健康检查可反映）。
- [投影口径] 仅 ON_SALE + 存在 ENABLED SKU；价格取启用 SKU salePriceInCents 极值；updatedAt 取商品更新时间毫秒（乱序版本基准）。
- [Bulk] 每批 500；某批失败 → 任务 FAILED 并记录失败批次/错误；部分成功允许续跑（重新触发全量构建以 upsert 覆盖，幂等）。
- [鉴权] 投影端点仅 SERVICE（X-Internal-Token）；经网关访问 404。

## 4. 接口与字段规格

- `GET /api/internal/products/search-projection?page=1&size=500`（SERVICE）→ UnifyResult<Page<ProductProjectionView>>。
- `POST /api/internal/search/index/full-build`（SERVICE，本 Story 内部触发用）→ {taskId,status}。
- SearchDocument 字段：productId,productName,categoryId,categoryName,brandId,brandName,mainImage,keywords,status,minPrice,maxPrice,publishedAt,updatedAt。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 全新 ES 启动 mall-search 后 mall_products_v1 与别名 mall_products 自动创建；再次启动不报错不改 Mapping |
| AC-002 | Mapping 定义在代码/资源中可评审；价格字段 long、productId 可作 docId/term、文本字段可检索 |
| AC-003 | 投影端点无内部令牌调用被拒绝（401/403），经网关 404；持令牌分页返回正确投影与 total |
| AC-004 | 投影不包含下架/无启用 SKU 商品；minPriceFen/maxPriceFen 与启用 SKU 价格极值一致 |
| AC-005 | 全量构建后 ES count=投影 ON_SALE 总数；抽样文档字段正确（名/分类品牌/图/价格/时间） |
| AC-006 | 数据量 >500 时分批构建成功（Testcontainers 造 1001 条验证）；中途某批失败任务置 FAILED 且错误可定位 |
| AC-007 | Flyway V1 在 mall_search 库建 search_index_rebuild_task、search_sync_failure_record 两表 |
