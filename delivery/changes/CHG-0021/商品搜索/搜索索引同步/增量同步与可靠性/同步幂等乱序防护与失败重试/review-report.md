# Review Report（Story 级）— STORY-005-02-02-02 同步幂等乱序防护与失败重试

> 阶段：sdd-review 产物（独立只读评审；本报告不改动业务代码/测试/已有文档，不写 evidence.yaml）。

## 0. 元信息

- Change ID：CHG-0021（REQ-M5-002 商品搜索索引同步）
- Story ID：STORY-005-02-02-02 同步幂等乱序防护与失败重试
- 关联 DU：DU-BE-506（repo-1，初验 commit 82ccf6e completed；review major 闭环 commit 1de0d9c）
- Test Report 来源：`evidence/test-report.md`（2026-09-19；SyncFailureFlowTest 6/6 + IndexSyncIntegrationTest 乱序/删除 2 例全 passed）；闭环定向回归 `evidence/logs/review-mall-search-retest.log`（26/26）
- Evidence 索引：`evidence/evidence.yaml`（EV-001 code-change 82ccf6e；EV-002 test-run 全 reactor 482/482；EV-003 review-finding major 已闭环；EV-004/EV-005 review-finding minor；EV-006 code-change 1de0d9c；EV-007 test-run 定向回归 26/26）
- 状态流转：testing（检查点，状态不变）
- 检查时间：2026-09-19（major 闭环复核 2026-09-19）
- 审查者：sdd-review 独立评审 Agent（trae-agent）

## 1. 检查结论

**通过（原 1 项 major 已闭环，另有 2 项 minor）。** external_gte 乱序仲裁、有界退避 30s/1m/2m/5m/10m、FAILED_DEAD、重拉权威投影重放、人工重试 B0504 等核心行为均经真实 ES/H2 测试与源码核实，枚举 PENDING/SUCCESS/FAILED_DEAD 与冻结契约一致。初评发现 story-spec §2.1/§4 与 requirement-design §2.4 声明的 SERVICE 内部只读端点 `GET /api/internal/search/sync-failures` 初版未实现且 Deviations 未记录，记 major（EV-003）；**该 major 已闭环**——commit 1de0d9c 补 InternalSearchFailureController（ROLE_SERVICE，只读分页复用 SearchSyncFailureService.page/count，{total,page,size,items} 与 admin 同构）+ InternalSearchFailureApiTest 2 例（令牌分页+FAILED_DEAD 筛选/无令牌 4xx），DU-BE-506 DEV-5 已补登，定向回归 26 例全绿（EV-006/EV-007）。

### 1.1 需求一致性

| Story AC | 验收要点 | 证据（真实方法/源码） | 结论 |
| --- | --- | --- | --- |
| AC-001 | 同 upsert 两投：ES 一份最新、失败表无脏行 | #staleUpsertSwallowed（同 docId 两版本仅一份）、SyncFailureFlowTest#duplicateFailureReusesRow（同 product+op 仅 1 行 PENDING） | passed（闭环回归 9+6 复绿，EV-007） |
| AC-002 | v200 后到 v100 upsert：保持 v200、接口不报错 | #staleUpsertSwallowed 真实 ES external_gte 409→STALE_VERSION，INFO 消化、两次 200；EsSearchIndexAdapter.upsertVersioned 源码核实 | passed |
| AC-003 | v200 后旧版 delete：不删除且有日志 | #offSaleSyncDeletesAndStaleDeleteKeepsNew（version=990 旧下架事件后 total 仍为 1，新版下架 total=0）；deleteVersioned 409→STALE_VERSION 源码核实 | passed（行为达成；AC 措辞 WARN 实际 INFO 消化日志，语义一致） |
| AC-004 | ES 停期间落 PENDING（字段齐/首退避 30s）；恢复重试 SUCCESS | #acceptedOnEsFailureAndRecorded（200+1 行 PENDING+nextRetryAt 25~30s）、#replaySuccessAndStaleAsSuccess（重放重拉投影 SUCCESS） | passed（故障为端口异常模拟，真实容器停启见 EV-004） |
| AC-005 | 退避序列；第 5 次 FAILED_DEAD 不再拾取 | #backoffSequenceAndDead（30/60/120/300/600 秒、retryCount=5、FAILED_DEAD）；SearchSyncFailure BACKOFF/MAX_RETRIES 源码核实；findDue 仅查 PENDING | passed |
| AC-006 | 人工重试 FAILED_DEAD 复活成功；未知 id 404 | #manualRetryRearmAndNotFound（DEAD→rearm→同请求 replay SUCCESS；999999→B0504/404）；SearchSyncFailureService.manualRetry 源码核实 | passed（服务层；HTTP 层见 EV-005） |
| AC-007 | 重试时已下架→删除 SUCCESS；再上架→upsert | #replayDeleteWhenProjectionMissing（fetchOne null→deletePlain）、#replaySuccessAndStaleAsSuccess | passed |
| AC-008 | Testcontainers/可控 ES 故障覆盖主路径；mvn 全绿 | 真实 ES 8.17.4 覆盖冲突主路径 9 例 + H2/Mock 覆盖失败链 6 例；全 reactor 482/482 BUILD SUCCESS（2026-09-19）；闭环定向回归 26/26（2026-09-19，EV-007） | passed（真实停启/网络分区边界见 EV-004） |

### 1.2 设计一致性

- DU-BE-506 Deviations 闭环且理由合理：①失败表不存 payload/op 名称、重放一律重拉投影当前态（DEV-1）——V1 SQL 抽查确认列集为 event_type/status/retry_count/max_retries/last_error/next_retry_at，与 requirement-design"重放不信旧 payload"决策一致，比 story-design §1 早期表结构更正确；②应用层 findPending 去重替代唯一约束（DEV-2），idx_sync_failure_product 普通索引+单实例前提（主类注释声明多实例需 ShedLock）；③人工重试 rearm 后同请求立即 replay（DEV-3），运维即时反馈，失败仍回落退避表；④版本号取 updatedAt epoch millis（DEV-4），同毫秒 external_gte 允许相等写入，配合重查当前态收敛；⑤sdd-review major 闭环补登（DEV-5，1de0d9c）——内部 SERVICE 只读端点按契约补实现。
- 冻结枚举核实：SyncFailureStatus=PENDING/SUCCESS/FAILED_DEAD、SyncEventType=UPSERT/DELETE，无 RETRYING；表注释同构。
- 原一处未记录的契约缺口（major，EV-003）已闭环：1de0d9c 补 InternalSearchFailureController（hasRole SERVICE、只读分页，{total,page,size,items} 与 admin 同构）+ InternalSearchFailureApiTest 2 例，并在 DU-BE-506 实施文档补登 DEV-5（EV-006/EV-007 为证据）。其余口径演进（失败管理端点实际挂载 /api/admin/search/index/sync-failures*）已在 Story 实施文档与 DU-BE-504 DEV-4 登记，前端调用一致。

### 1.3 跨仓一致性

- mall-product→mall-search 故障语义闭环：search 内部 sync/delete 端点 ES 异常时 recordFailure 且 202/200 受理，product 侧 SearchSyncClient 不因 5xx 重试（仅网络层异常上抛由监听器吞咽），两侧对"受理即成功、本地补偿重放"的契约理解一致。
- 重放反向依赖一致：SearchSyncFailureService 重放经 ProductProjectionClient.fetchOne 调 mall-product 单条投影（404→null→deletePlain），与 DU-BE-503 单条 404 口径闭环，不存在搜索侧回写 product 的路径。
- admin 失败记录管理：AdminSearchIndexController 的 GET /sync-failures（search:index:list，{total,page,size,items}）、POST /sync-failures/{id}/retry（search:index:rebuild）与 mall-admin api/search/index.ts 调用路径/权限码/分页结构逐字一致；内部只读侧 1de0d9c 新增 GET /api/internal/search/sync-failures（ROLE_SERVICE）分页体与 admin 同构，网关 denyAll 对外隐藏。
- 本 Story 为 repo-1 单仓变更；EV-003 所涉内部端点为 mall-search 自身 SERVICE 契约，已补齐，不影响 repo-2。

### 1.4 代码质量

- 领域模型质量良好：SearchSyncFailure 聚合内聚退避序列/截断/rearm 状态流转；服务层单条 try/catch 隔离、落库异常不外抛、@Lazy 解循环依赖；调度 fixedDelayString 可配置（测试以 3600000ms 关闭自动干扰）。
- ES 8.18.8 版本化写入正确：upsert/delete/bulk 均 ExternalGte，409→STALE_VERSION、版本化删除 404→WRITTEN、deletePlain 404 静默，分支与冻结设计一致。
- 测试质量：真实 ES 不 Mock 版本冲突语义、H2 真实持久化验证退避序列，符合 testing-standard 风险覆盖原则；故障注入以客户端异常模拟替代真实容器 kill（EV-004），人工重试 HTTP 层未驱动（EV-005），均为已登记边界。
- 闭环代码复核：InternalSearchFailureController 无写操作、分页参数夹取（page≥1、size 1..100）、复用 SearchSyncFailureService 不引入新查询路径；InternalSearchFailureApiTest 经真实安全链验证令牌分页+FAILED_DEAD 筛选与无令牌 4xx。

### 1.5 知识同步候选

- 失败死信 FAILED_DEAD 模式：有界退避（30s/1m/2m/5m/10m，5 次封顶）+ 不存旧载荷、重放重拉权威源当前态 + 人工 rearm 同请求立即重放 + 应用层 (productId,eventType) 去重复用行——可作为 CHG-0019 compensation_task 之后的第二个同构范式晋升。
- external_gte 乱序仲裁扩展到 delete：旧下架事件晚到不删新文档（409 STALE_VERSION 成功消化），解决"删除也需防乱序"的通用问题。
- @Scheduled 单实例补偿 Job 范式：fixedDelay 30s + status='PENDING' AND next_retry_at<=now LIMIT 100 + 单条隔离 + 可配置关闭键，可晋升 backend 调度规范（并注明多实例 ShedLock 升级点）。

## 2. 发现清单

| EV id | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-003 | story-spec.md §2.1/§4（GET /api/internal/search/sync-failures）；requirement-design.md §2.4；InternalSearchSyncController.java | major | 声明的 SERVICE 内部只读端点 `GET /api/internal/search/sync-failures?status=`（供服务侧排查）初版未实现——全仓搜索 sync-failures 仅命中 AdminSearchIndexController 两个端点；DU-BE-506 Deviations（DEV-1~4）未记录该取消。admin 端虽有等价分页（search:index:list），但 Story Scope 与接口契约条目缺失且未留痕 | 已闭环（1de0d9c，EV-006/EV-007 回归 26 全绿，DEV-5 补登） |
| EV-004 | story-spec.md#AC-004、#AC-008；SyncFailureFlowTest | minor | 未做真实 ES 容器 kill/网络分区注入；故障链以 SearchIndexPort 抛 RuntimeException 模拟，受理落表/退避/重放全分支已覆盖，缺真实停启后"调度自动拾取+文档恢复可搜"的端到端证据 | Integration Gate 场景五做真实 ES stop/start，验证 @Scheduled 自动拾取、SUCCESS 与文档恢复可搜 |
| EV-005 | story-spec.md#AC-006；AdminSearchIndexController.java L88-90；SearchSyncFailureService#scanAndRetry | minor | 人工重试端点权限码与 B0504/404 序列化未经 MockMvc（服务层已证）；@Scheduled 扫描"到期才拾取/FAILED_DEAD 不拾取"无调度级断言（测试关闭自动调度后直调方法） | 补 MockMvc 用例（无权限 403/未知 id 404 body/成功 200）或 Gate HTTP 联调；补一轮可控时钟下 scanAndRetry 拾取边界断言 |

## 3. 完成确认

- [x] 四项检查全部执行
- [x] blocker/major 已闭环：EV-003（major）已闭环（1de0d9c 补 InternalSearchFailureController + InternalSearchFailureApiTest 2 例，EV-006/EV-007 定向回归 26/26 全绿，DU-BE-506 DEV-5 补登）
- [x] minor finding 已记录（EV-004/EV-005 允许开放，联调补证）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（product↔search 故障受理语义、重放反向 404 口径、admin 失败记录契约、内部只读端点补齐）
