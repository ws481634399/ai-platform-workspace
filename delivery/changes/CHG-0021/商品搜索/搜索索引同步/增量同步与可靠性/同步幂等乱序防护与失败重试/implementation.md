# Implementation（跨仓实施汇总）— 同步幂等乱序防护与失败重试 STORY-005-02-02-02

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0021（商品搜索索引同步）
- Story：STORY-005-02-02-02 同步幂等乱序防护与失败重试
- 实施日期：2026-09-18

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-506 | repo-1 | mall-search：ExternalGte 版本化 upsert/delete（updatedAt epoch millis，409→STALE_VERSION，删文档 404→WRITTEN）；`SearchSyncFailure` 聚合有界退避 30s/1m/2m/5m/10m、5 次 FAILED_DEAD；`SearchSyncFailureService` 落表去重、@Scheduled 30s 扫描（LIMIT 100、单条隔离）、重放重拉投影（null→deletePlain）、人工重试 rearm 后立即 replay（B0504 404）；管理端失败记录分页/重试端点同批落地。Flow 测试 6 例 + 真实 ES 冲突 IT 2 例 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 82ccf6e | DU-BE-506 | repo-1 | feat(search,system): M5 商品搜索+索引同步+系统配置（CHG-0020/0021/0022 后端，M5 三 Change 合并提交） |

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0021/商品搜索/搜索索引同步/增量同步与可靠性/同步幂等乱序防护与失败重试/DU-BE-506/implementation.md`
  - `EsSearchIndexAdapter.upsertVersioned/deleteVersioned`：external_gte 外部版本=投影 updatedAt 毫秒，409 归 `STALE_VERSION`，版本化删除 404 归 `WRITTEN`；bulkUpsert 同样带版本。
  - `SearchSyncFailure`：BACKOFF={30s,1m,2m,5m,10m}、MAX_RETRIES=5、第 5 次失败 FAILED_DEAD；`rearm` 清零重置；错误截断 1000。
  - `SearchSyncFailureService`：recordFailure 按 (productId,eventType) 查 PENDING 复用刷新否则 register；`@Scheduled(fixedDelayString=${mall.search.sync-retry-delay-ms:30000})` findDue LIMIT 100；replay 重拉 product 投影当前态决定 upsert/delete，STALE_VERSION 按成功；manualRetry 不存在 B0504（SYNC_FAILURE_NOT_FOUND/404），非 PENDING 先 rearm 再立即 replay。
  - 枚举：`SyncFailureStatus=PENDING/SUCCESS/FAILED_DEAD`、`SyncEventType=UPSERT/DELETE`；表无 payload 列（重放以权威投影为准）；MallSearchApplication `@EnableScheduling`（注释声明单实例前提，多实例需 ShedLock）。

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | 同一 upsert 两投：ES 仅一份最新文档、失败表无脏记录 | passed（`staleUpsertSwallowed` 同 docId 两版本仅一份；`duplicateFailureReusesRow` 同故障两投仅 1 行 PENDING） |
| AC-002 | v200 后到 v100 upsert：保持 v200 内容、接口不报错 | passed（`staleUpsertSwallowed`，真实 ES external_gte 409→STALE_VERSION，INFO 消化、接口 200） |
| AC-003 | v200 后到旧版(100) delete：文档不删且有日志 | passed（`offSaleSyncDeletesAndStaleDeleteKeepsNew`：版本化删除 409 被保护文档保留；日志级别为 INFO「过期同步事件已消化」，AC 措辞 WARN，行为达成） |
| AC-004 | ES 停期间同步落 PENDING（含 productId/eventType/错误）；恢复后定时重试 SUCCESS | passed（受理与落表：`acceptedOnEsFailureAndRecorded` 200+1 行 PENDING+首退避 30s；恢复重放：`replaySuccessAndStaleAsSuccess` 直接调用扫描/重放方法验证，未做真实 ES 停启调度 E2E） |
| AC-005 | 退避序列递增，第 5 次 FAILED_DEAD 且不再被拾取 | passed（`backoffSequenceAndDead`：30/60/120/300/600 秒逐项断言、retryCount=5、FAILED_DEAD；findDue 仅取 PENDING） |
| AC-006 | 人工重试 FAILED_DEAD（ES 已恢复）→复活并尽快成功 | passed（`manualRetryRearmAndNotFound`：DEAD→rearm→同请求立即 replay SUCCESS；未知 id→B0504 404） |
| AC-007 | 重试时已下架→重拉投影后删除 SUCCESS；重新上架→upsert 成功 | passed（`replayDeleteWhenProjectionMissing` fetchOne null→verify deletePlain；`replaySuccessAndStaleAsSuccess` 当前态 upsert） |
| AC-008 | Testcontainers + 可控 ES 启停/wiremock 投影覆盖主路径；mvn test 全绿 | ⚠️ 部分：真实 ES Testcontainers 覆盖冲突主路径（IndexSyncIntegrationTest 9 例），H2+Mockito 覆盖失败/退避/重放 6 例（SyncFailureFlowTest）；可控 ES 停启场景由方法级调用替代真实停启，wiremock 投影被 Mockito 替代；`mvn test` 全绿需 CI/Integration Gate 执行（本机无 surefire 报告、未运行 mvn） |

> 测试说明：本 Story 直接相关 8 个 @Test（SyncFailureFlowTest 6 + IndexSyncIntegrationTest 冲突 2），全 Change 相关共 21 个（另含 ProductSearchSyncEventTest 2、ProductSearchProjectionApiTest 4、IndexSyncIntegrationTest 其余 7）。工作区无 `target/surefire-reports`，本表只引用真实方法名。Deviations（失败表不存 payload、应用层去重无唯一约束、人工重试立即执行、版本号取 updatedAt 毫秒）详见仓内 DU 文档。
