# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（mock 范式参照 CHG-0019）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0021
- Story ID: STORY-005-02-01-01
- Feature Path: 商品搜索 > 搜索索引同步 > 索引生命周期与全量构建 > 索引 Mapping 管理与首次全量构建
- 状态流转: designed → tasked
- TC 总数: 9

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 集成（ES Testcontainers）：空 ES 跑 ApplicationRunner→mall_products_v1 与查询别名 mall_products 存在；再跑一次 ensureIndex 不抛错；GET mapping 与首次一致（未被覆盖） | AC-001 | DU-BE-503 | [S1] |
| TC-002 | 静态/集成：resources 下 mapping 定义文件/Java DSL 可评审；GET mapping 断言 price 字段 long、productId keyword、mainImage index=false、日期类型 date | AC-002 | DU-BE-503 | [S1] |
| TC-003 | API（MockMvc）：投影端点无内部令牌 → 401/403；持 SERVICE 凭据分页（page/size）返回投影与 total；网关可达性在 Integration Gate 验 404 | AC-003 | DU-BE-503 | [S1] |
| TC-004 | 持久层：SQL EXISTS 过滤数据集（ON_SALE 无启用 SKU、OFF_SALE、正常）断言投影仅含有效商品；minPrice/maxPrice=启用 SKU priceFen 极值 | AC-004 | DU-BE-503 | [S1] |
| TC-005 | 集成（ES+投影）：执行全量构建后 ES _count=投影 total；抽样文档字段（名/分类品牌名/图/价格/publishedAt/updatedAt）正确 | AC-005 | DU-BE-503 | [S1] |
| TC-006 | 集成：Testcontainers MySQL 造 1001 条有效商品→构建成功且批次数≥3；mock ES 在第 2 批失败 → 任务 FAILED、error_message 含批次/productId 线索 | AC-006 | DU-BE-503 | [S1] |
| TC-007 | 迁移：Flyway V1 在 mall_search 库建 search_index_rebuild_task/search_sync_failure_record，断言列/索引齐全 | AC-007 | DU-BE-503 | [S1] |
| TC-008 | 韧性：ES 停机时启动 mall-search，ensureIndex 捕获不阻止启动，日志 ERROR，health DOWN | AC-001 | DU-BE-503 | [S1] |
| TC-009 | API：GET /api/internal/products/{id}/search-projection 下架商品 → data=null；正常商品字段完整 | AC-003, AC-004 | DU-BE-503 | [S1] |

## 2. 测试策略

- 后端分层：Mapper SQL 测试（H2/MySQL testcontainers 沿用工程基线）+ ES IT（static 容器，每测试用临时/显式管理索引）+ MockMvc 安全断言。
- 1001 条分批：参数化投影仓储模拟分页，避免真实写入 1001 条 MySQL 数据过重（或用 testcontainers MySQL 批量 insert）。
- 证据：mapping 输出、_count 截图日志入 evidence/logs。

## 3. 不可测项标注

- 无。

## 4. 依赖与前置条件

- CHG-0020 DU-WS-501/DU-BE-501（ES 环境与 Client）；mall_search 库已预建。
