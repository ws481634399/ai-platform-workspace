# Review Report（Story 级）— STORY-005-02-02-01 商品变更增量同步

> 阶段：sdd-review 产物（独立只读评审；本报告不改动业务代码/测试/已有文档，不写 evidence.yaml）。

## 0. 元信息

- Change ID：CHG-0021（REQ-M5-002 商品搜索索引同步）
- Story ID：STORY-005-02-02-01 商品变更增量同步
- 关联 DU：DU-BE-505（repo-1，commit 82ccf6e，completed）
- Test Report 来源：`evidence/test-report.md`（2026-09-19；6 个直接测试方法全 passed，9 个验收项中 4 项为部分自动化/静态评审）
- Evidence 索引：`evidence/evidence.yaml`（EV-001 code-change 82ccf6e；EV-002 test-run 全 reactor 482/482；EV-003/EV-004 review-finding minor）
- 状态流转：testing（检查点，状态不变）
- 检查时间：2026-09-19
- 审查者：sdd-review 独立评审 Agent（trae-agent）

## 1. 检查结论

**通过（PASS，有 minor 遗留）。** AFTER_COMMIT 事件链路、重查当前态分流、best-effort 不阻断主事务、内部端点 SERVICE 鉴权均经源码与测试核实；无 blocker/major。2 项 minor 为已登记的触发点/回滚分支覆盖深度（合并登记为 1 项）与一处 AC 日志级别措辞差异。

### 1.1 需求一致性

| Story AC | 验收要点 | 证据（真实方法/源码） | 结论 |
| --- | --- | --- | --- |
| AC-001 | 上架提交后 5s 内 ES 可检出 | product 侧 ProductSearchSyncEventTest#createPublishUnpublishEventChain（提交后 sync ON_SALE 投影）；search 侧 IndexSyncIntegrationTest#syncUpsertAcceptedAndSearchable（受理即 refresh 可搜 total=1） | passed（两半实测；跨进程 5s E2E 留 Gate） |
| AC-002 | 改名/分类品牌/换图同步；SKU 改价刷新 min/max | #createPublishUnpublishEventChain（minPriceFen=8800）、ProductSearchProjectionApiTest#projectionPageOnSaleOnly 全字段、#syncUpsertAcceptedAndSearchable；投影重查装配统一 | passed（链路口径）；逐写方法触发点部分（EV-003） |
| AC-003 | 下架硬删除不可见；重复下架/删不存在成功 | #offSaleSyncDeletesAndStaleDeleteKeepsNew（total=0）、#deleteEndpointIdempotent（重复 200）、事件链 unpublish→delete | passed |
| AC-004 | SKU 增禁极值正确；无启用 SKU 不产生文档 | #projectionPageOnSaleOnly（INNER JOIN ENABLED SKU 1000/3000）、#singleProjectionAndNotFoundCases（无启用 SKU 404）、事件链草稿 CREATE→delete | passed；addSku/changeSkuStatus 触发部分（EV-003） |
| AC-005 | mall-search 停止时上架仍成功、有告警日志、不回滚 | #listenerFailureNeverBreaksWriteApi（client 抛异常，publish 仍 200）；ProductSearchSyncListener 全异常 catch 源码核实 | passed（日志级别措辞见 EV-004） |
| AC-006 | 事务回滚不产生任何同步调用 | 监听器 @TransactionalEventListener(phase=AFTER_COMMIT) 源码核实；提交侧时序已由事件链验证；无显式回滚用例 | 部分（EV-003，框架语义保证） |
| AC-007 | 内部同步端点 SERVICE；经网关 404 | IndexSyncIntegrationTest#authGuards（POST /sync 无凭证 401）；gateway /api/internal/** denyAll→404 配置 | passed（401 实测；网关 404 联调） |

### 1.2 设计一致性

- DU-BE-505 四项 Deviations 闭环：①事件仅携 productId+操作描述串、监听器 AFTER_COMMIT 重查当前投影决定 sync/delete（DEV-1）——源码核实 ProductSearchChangedEvent record、onProductChanged findById 非空 sync/空 delete，统一装配天然覆盖交叉状态，理由合理；②RestClient 替代 OpenFeign（DEV-2），SearchSyncClient 超时 connect 1s/read 3s 与设计一致；③8 个发布点（CREATE/UPDATE/CHANGE_STATUS/ADD_SKU/UPDATE_SKU/CHANGE_SKU_STATUS/PUBLISH/UNPUBLISH）替代设计的 7 个（DEV-3），已逐一定位 ProductApplicationService L191/205/218/235/244/257/267/275，重查+幂等使多发无副作用；④同步 HTTP+AFTER_COMMIT 为 requirement-design 备选决策表明示采纳（DEV-4 说明项），非偏离。
- 接收侧与设计一致：InternalSearchSyncController 恒 200 {accepted:true}；SyncReceiveService 按 ON_SALE 分流 upsertVersioned/deleteVersioned，STALE_VERSION INFO 消化，其他异常 WARN+recordFailure；DELETE 端点 deletePlain 幂等。
- 一处 AC 措辞与实现差异：story-spec §3/AC-005 要求异常"WARN"日志，实现为 log.error（EV-004），Story 实施文档已自行披露"语义达成"，不构成未记录偏差。

### 1.3 跨仓一致性

- product→search 调用契约闭环：SearchSyncClient POST /api/internal/search/products/sync、DELETE /api/internal/search/products/{productId}，X-Internal-Token 直连 8107，与 InternalSearchSyncController 路由逐字一致；请求体 SearchProjectionView 与 mall-search ProductProjectionView 13 字段同名同序，JSON 反序列化无漂移。
- 方向约束符合 requirement-design §4：product 不依赖 search 启动成功（监听器全兜底）、search 只经内部端点读 product 投影（ProductProjectionClient）、不直连 mall_product 库；权威方向 Product DB→ES 单向。
- 安全：两端内部端点均挂 /api/internal/** hasRole SERVICE，网关 denyAll 404；故障语义"search 侧落表、product 侧 ERROR 留痕"在两个服务的代码中分别核实，未出现跨域共表或反向依赖。
- 本 Story 为 repo-1 单仓跨两模块（mall-product/mall-search）变更；repo-2 无触点。

### 1.4 代码质量

- 事务/事件用法正确：事件在事务内发布、监听 AFTER_COMMIT，异常不外抛；traceId 经 MDC 透传，日志含 productId/operation，符合 service-standard 可观测要求。
- 投影 Mapper 为只读 @Select、稳定 ORDER BY p.id ASC 支撑分页；SearchSyncClient 快速失败超时与 UnifyResult 解包同仓内范式一致。
- 测试规范（testing-standard §2/§6）：主流程与故障不阻断有真实 SpringBoot 写链路 + Mockito 边界验证；异常/边界覆盖不足项（回滚、超时、逐触发点）已在报告登记，未见有明确规范依据的代码违规。

### 1.5 知识同步候选

- 事件驱动投影反腐败层模式：事务内只发"商品已变更"轻事件（不携载荷/op），AFTER_COMMIT 监听器重查权威源当前态决定 upsert/delete——避免事务中读旧态与交叉状态误判，天然幂等。
- 同步投影 best-effort 故障隔离范式：AFTER_COMMIT 监听器全异常吞咽+短超时（1s/3s），主交易零拖累，故障窗口交由消费端失败表+低频对账兜底（M5 明示接受边界，M7 Outbox 升级点）。

## 2. 发现清单

| EV id | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-003 | story-spec.md#AC-002、#AC-004、#AC-006；ProductApplicationService 8 个发布点；ProductSearchSyncListener | minor | 8 个写方法仅实证 create(草稿)→DELETE、publish→UPSERT、unpublish→DELETE 三类；update 改名、addSku/updateSku/changeSkuStatus 改价与启停的事件发布无显式用例，依赖重查装配与投影口径间接保证。事务回滚零同步调用亦无显式用例，仅靠 @TransactionalEventListener(AFTER_COMMIT) 框架语义与提交侧时序测试保证（已登记 G1/G2） | Integration Gate 联调改名/改价/启停端到端，或补逐方法事件发布断言用例；补一例校验失败回滚后 verify(call, never()) 的专项用例，或 Gate 联调确认 |
| EV-004 | story-spec.md §3、#AC-005；ProductSearchSyncListener.java L51 | minor | AC/业务规则措辞为异常仅 WARN，实现日志级别为 ERROR（实施文档已披露"有告警且不回滚"语义达成）；1s/3s 超时同样仅静态配置评审无运行时断言 | converge 统一口径：以实现为准将 spec 措辞改为"告警日志（ERROR/WARN）"，或将监听器日志降为 WARN；Gate 补短超时联调 |

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 无 blocker/major finding（2 项 minor 均为已登记覆盖深度/口径措辞项，允许开放）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（product 事件→search 内部端点路径/视图同构/SERVICE 边界/单向权威）
