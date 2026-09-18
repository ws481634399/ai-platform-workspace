# Test Report — STORY-005-02-02-02 同步幂等乱序防护与失败重试

> 阶段：sdd-test 产物（Story 级）。

## 0. 元信息

- Change ID：CHG-0021
- Story ID：STORY-005-02-02-02
- 执行时间：2026-09-19
- 覆盖：AC-001~AC-008、TC-001~TC-008
- 实施来源：repo-1 DU-BE-506（commit 82ccf6e）
- 测试基线：
  - 乱序/幂等/删除语义——IndexSyncIntegrationTest（真实 ES Testcontainers 8.17.4，external_gte 真实版本冲突语义，不 Mock）；
  - 失败登记/退避/重放/人工重试——SyncFailureFlowTest（H2 Flyway 真实持久化 + SearchIndexPort/ProductProjectionClient 全 Mock，故障以客户端异常模拟；类属性 `mall.search.sync-retry-delay-ms=3600000` 关闭调度自动干扰，重放直接方法调用）。

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据（真实 类#方法） |
| --- | --- | --- | --- | --- |
| TC-001 | 相同 upsert 连投两次 → ES 仅 1 文档且最新；failure_record 无脏行 | H2 + Mock 端口 | passed（去重落表）；ES 双投计数无专属用例 | SyncFailureFlowTest#duplicateFailureReusesRow：同 (6007,UPSERT) 连续两次 receive 失败 → repository.page 仅 1 行 PENDING、retryCount=0。ES 侧 docId=productId 覆盖写幂等由真实 ES 版本化写入用例间接佐证（见 §4-G1） |
| TC-002 | v200 upsert 后投 v100 upsert → 文档保持 v200，接口 200（VersionConflict 消化） | 真实 ES Testcontainers | passed | IndexSyncIntegrationTest#staleUpsertSwallowed：先投 version=2000"新版本手机"再投 1000"旧版本手机"，搜索 total=1 且 productName="新版本手机"，两次请求均 200 |
| TC-003 | v200 upsert 后到 v100 delete → 文档仍在；旧事件忽略有 WARN/INFO | 真实 ES Testcontainers | passed（保留语义）；日志级别未捕获断言 | IndexSyncIntegrationTest#offSaleSyncDeletesAndStaleDeleteKeepsNew：version=999 的 OFF_SALE 旧事件后 total 仍为 1；version=2000 的新下架事件后 total=0 |
| TC-004 | 停 ES 触发 sync → 200 受理 + failure_record 一行 PENDING（字段齐、首次退避 30s）；恢复后调度拾取 → SUCCESS 且文档可搜 | Mock 端口故障 + H2 + 直接重放 | passed（受理/落表/重放成功）；真实容器 kill 与 @Scheduled 拾取未执行 | SyncFailureFlowTest#acceptedOnEsFailureAndRecorded（upsertVersioned 抛异常，端点仍 200 accepted；记录 productId=6001/eventType=UPSERT/status=PENDING/retryCount=0，nextRetryAt 距今 25~30s）；#replaySuccessAndStaleAsSuccess（重放重拉投影 upsert WRITTEN → SUCCESS；STALE_VERSION 同样 SUCCESS） |
| TC-005 | 退避 30s/1m/2m/5m/10m；第 5 次失败后 FAILED_DEAD，调度不再拾取 | 可控时钟（Instant.now 注入） | passed（序列与终态） | SyncFailureFlowTest#backoffSequenceAndDead：5 轮 replay 依次断言 nextRetryAt 间隔 [30,60,120,300,600] 秒（容差 5s），第 5 次 status=FAILED_DEAD、retryCount=5。"调度不再拾取"由 PENDING+next_retry_at 扫描条件与终态保证（见 §4-G2） |
| TC-006 | POST 人工重试 FAILED_DEAD（ES 恢复）→ 重置并尽快成功；不存在 id → 404 B0504 | 服务层 + H2 | passed（服务层）；admin HTTP 端点未经 MockMvc | SyncFailureFlowTest#manualRetryRearmAndNotFound：手工 5 次失败构造 FAILED_DEAD，manualRetry → 直接重放 SUCCESS；manualRetry(999999) 抛 BusinessException，code=B0504、httpStatus=404 |
| TC-007 | 重试时投影已下架 → DELETE 并 SUCCESS；重新上架 → upsert 成功 | Mock 投影 + H2 | passed | SyncFailureFlowTest#replayDeleteWhenProjectionMissing（fetchOne 返回 null → verify deletePlain(6005)，status=SUCCESS）；#replaySuccessAndStaleAsSuccess（fetchOne 返回 ON_SALE 视图 → upsertVersioned WRITTEN，SUCCESS） |
| TC-008 | 构建门禁：mall-search（-am）mvn test 全绿含上述 IT | 全 reactor 回归 | passed | mall-search 模块 **32/32**：IndexSyncIntegrationTest 行 20469（9,0,0,5.991s）、SyncFailureFlowTest 行 21293（6,0,0,1.060s）；全 reactor 14 模块 482/482 BUILD SUCCESS |

## 2. 测试执行汇总
| 模块 | 命令 | 结果 |
| --- | --- | --- |
| mall-search | `mvn test -B -ntp`（TESTCONTAINERS_RYUK_DISABLED=true，ES Testcontainers 8.17.4） | IndexSyncIntegrationTest **9/9**、SyncFailureFlowTest **6/6**；模块合计 32/32，0 失败 |
| mall-product（回归联动） | 同上 | **101/101**（事件/投影端点支撑增量链路） |
| 全 reactor | 同上（2026-09-19 01:42 完成） | 14 模块 **482/482**，BUILD SUCCESS，Total time 02:47 |
| 日志 | `delivery/changes/CHG-0020/evidence/logs/backend-full-test.log`（跨 Change 共享） | SyncFailureFlowTest 行 21293（6,0,0）；IndexSyncIntegrationTest 行 20469（9,0,0）；BUILD SUCCESS 行 22991 |

通过率：本 Story 直接相关 15 个真实测试方法（9+6）全部 passed，通过率 100%。

## 3. AC 覆盖

| AC | 验收标准（摘要） | 覆盖 TC | 结论 |
| --- | --- | --- | --- |
| AC-001 | 同 upsert 连投两次：ES 一份文档、字段最新；失败表无脏记录 | TC-001 | passed（失败行复用去重实测）；ES 双投 _count=1 无独立用例（G1） |
| AC-002 | 先 200 后 100 的 upsert：文档保持 200，接口不报错 | TC-002 | passed（真实 external_gte） |
| AC-003 | 200 upsert 后旧版 delete：不删除且有 WARN | TC-003 | passed（文档保留实测；WARN 日志未做断言） |
| AC-004 | ES 停止期落 PENDING（productId/eventType/错误齐）；恢复后重试成功置 SUCCESS | TC-004 | passed（受理/落表/退避/重放 SUCCESS）；故障为端口异常模拟，真实停容器归联调（G3） |
| AC-005 | 退避序列递增，第 5 次 FAILED_DEAD 且不再被拾取 | TC-005 | passed（30/60/120/300/600、retryCount=5、终态）；扫描 SQL 拾取排除无独立断言（G2） |
| AC-006 | 人工重试 FAILED_DEAD → PENDING 并尽快成功 | TC-006 | passed（服务层；B0504/404 同例）；admin HTTP 端点 MockMvc 未驱动（G4） |
| AC-007 | 重试重拉投影：下架→删除 SUCCESS；重新上架→upsert 成功 | TC-007 | passed |
| AC-008 | Testcontainers + 可控 ES 故障覆盖主路径；mvn test 全绿 | TC-008 | passed（真实 ES 覆盖乱序/删除；故障链以 Mock 端口+H2 覆盖，G3 记录边界） |

## 4. 缺口 / 备注

- **G1（TC-001 ES 半）**：未编码"相同 upsert 连投两次后 ES _count=1"的专门用例；幂等性由 docId=productId 覆盖写模型保证，失败表去重已由 duplicateFailureReusesRow 实测，版本化写入语义由 staleUpsertSwallowed 真实 ES 佐证。
- **G2（TC-005 调度拾取）**：退避/终态在服务层逐轮断言，`@Scheduled(fixedDelay=30s)` 的扫描（status=PENDING AND next_retry_at<=now LIMIT 100）未做"到期才拾取/FAILED_DEAD 不拾取"的调度级断言；测试通过 sync-retry-delay-ms=3600000 关闭自动调度干扰。
- **G3（TC-004/AC-008 故障注入边界）**：单机自动化未做真实 ES 容器 kill/网络分区；SyncFailureFlowTest 以 SearchIndexPort 抛 RuntimeException 模拟 ES 不可用，覆盖"受理 200→落 PENDING→退避→重放 SUCCESS/删除/STALE 消化"全分支。真实停启恢复与"文档可搜"的端到端验证放 Integration Gate 场景五联调。
- **G4（TC-006 HTTP 层）**：人工重试点 `/api/admin/search/index/sync-failures/{id}/retry` 的权限码（search:index:rebuild）与 404 序列化未经 MockMvc；服务层 B0504/404 与 @PreAuthorize 配置（AdminSearchIndexController L88-90）分别由用例与评审保证。
- 实现说明：失败管理 admin 端点实际挂载在 `/api/admin/search/index/sync-failures*`（story-design 早期写作 `/api/admin/search/sync-failures*`），以实现与前端 `src/api/search/index.ts` 调用一致为准。
