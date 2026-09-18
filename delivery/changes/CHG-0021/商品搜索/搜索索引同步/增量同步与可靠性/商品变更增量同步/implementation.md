# Implementation（跨仓实施汇总）— 商品变更增量同步 STORY-005-02-02-01

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0021（商品搜索索引同步）
- Story：STORY-005-02-02-01 商品变更增量同步
- 实施日期：2026-09-18

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-505 | repo-1 | mall-product：`ProductSearchChangedEvent(productId, operation)` + 8 个写方法发布点、`@TransactionalEventListener(AFTER_COMMIT)` 监听器（提交后重查投影决定 sync/delete，全异常吞咽不外抛）、`SearchSyncClient`（RestClient 1s/3s）；mall-search：`InternalSearchSyncController`（sync/delete 恒 200 受理）、`SyncReceiveService`（按在架状态分流版本化写入，STALE_VERSION 消化，异常落失败表）。双端方法级测试就位 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 82ccf6e | DU-BE-505 | repo-1 | feat(search,system): M5 商品搜索+索引同步+系统配置（CHG-0020/0021/0022 后端，M5 三 Change 合并提交） |

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0021/商品搜索/搜索索引同步/增量同步与可靠性/商品变更增量同步/DU-BE-505/implementation.md`
  - mall-product：8 发布点（CREATE/UPDATE/CHANGE_STATUS/ADD_SKU/UPDATE_SKU/CHANGE_SKU_STATUS/PUBLISH/UNPUBLISH）；事件不携载荷，监听器 AFTER_COMMIT 调 `ProductSearchProjectionService.findById` 重查当前态——非空 `sync(view)`、为空 `delete(productId)`；异常仅 log.error（productId/operation/traceId）；`SearchSyncClient` RestClient 直连 8107（connect 1s/read 3s、X-Internal-Token）。
  - mall-search：`POST /api/internal/search/products/sync`、`DELETE /api/internal/search/products/{id}` 恒 200 `{accepted:true}`；`SyncReceiveService.receive` 对 ON_SALE 走 `upsertVersioned`、其余走 `deleteVersioned`（external_gte=updatedAt），409 STALE_VERSION 记 INFO 按成功，其他异常 WARN 并 `recordFailure`；DELETE 端点走 `deletePlain` 幂等硬删。
  - 传输方式：AFTER_COMMIT 应用事件 + 同步 HTTP 为 requirement-design 决策表明示采纳（MQ 推迟 M7），非实现偏离。

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | 上架提交后 5s 内 ES 出现文档并可被 CHG-0020 搜索接口检出 | passed（product 侧 `createPublishUnpublishEventChain` 提交后 sync ON_SALE 投影；search 侧 `syncUpsertAcceptedAndSearchable` 受理即 refresh 可搜；双进程 5s 时延 E2E 留 Integration Gate） |
| AC-002 | 改名/换分类品牌/换主图后字段更新；SKU 改价后 minPrice/maxPrice 刷新 | passed（投影 `projectionPageOnSaleOnly` 全字段与价区断言、事件链 minPrice 8800、`syncUpsertAcceptedAndSearchable` 文档可搜；逐字段变更场景未做跨服务 E2E） |
| AC-003 | 下架硬删除不可见；重复下架/删除不存在文档成功 | passed（`offSaleSyncDeletesAndStaleDeleteKeepsNew`、`deleteEndpointIdempotent`、事件链 unpublish→delete） |
| AC-004 | 新增/禁用 SKU 极值正确；无启用 SKU 的在架商品不产生可搜文档 | passed（投影 SQL INNER JOIN ENABLED SKU 取 MIN/MAX + `projectionPageOnSaleOnly`；无启用 SKU 查无投影→监听器 delete：`singleProjectionAndNotFoundCases` + 草稿 CREATE→delete 事件链） |
| AC-005 | mall-search 停止时上架仍成功不回滚，product 有日志 | passed（`listenerFailureNeverBreaksWriteApi`：client.sync 抛异常，publish 仍 200；product 侧实际日志级别为 ERROR，AC 措辞 WARN——"有告警日志且不回滚"语义达成） |
| AC-006 | 事务回滚不产生任何同步调用 | ⚠️ 部分：监听器为 `@TransactionalEventListener(AFTER_COMMIT)`，回滚不触发由框架语义保证；提交路径已由事件链测试覆盖，未编写显式回滚用例 |
| AC-007 | 内部同步端点需 SERVICE 身份，经网关 404 | passed（`authGuards` 内部端点无凭证 401；gateway `/api/internal/**` denyAll→404 为配置保证，未 E2E） |

> 测试说明：本 Story 相关 @Test 共 8 个直接用例——product 侧 `ProductSearchSyncEventTest` 2 例、`ProductSearchProjectionApiTest` 4 例，search 侧 `IndexSyncIntegrationTest` 中 `syncUpsertAcceptedAndSearchable`/`deleteEndpointIdempotent`/`offSaleSyncDeletesAndStaleDeleteKeepsNew`/`authGuards`（跨 Story 复用）。工作区无 surefire 报告，引用方法名、不杜撰执行数字。Deviations（事件不携载荷改为重查当前态、RestClient 替代 Feign、8 发布点而非 7、同步 HTTP 决策说明）详见仓内 DU 文档。
