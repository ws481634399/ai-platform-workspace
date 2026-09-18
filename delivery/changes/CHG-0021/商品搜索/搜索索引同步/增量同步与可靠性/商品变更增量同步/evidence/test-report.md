# Test Report — STORY-005-02-02-01 商品变更增量同步

> 阶段：sdd-test 产物（Story 级）。

## 0. 元信息

- Change ID：CHG-0021
- Story ID：STORY-005-02-02-01
- 执行时间：2026-09-19
- 覆盖：AC-001~AC-007、TC-001~TC-009
- 实施来源：repo-1 DU-BE-505（commit 82ccf6e）
- 测试基线：mall-product 真实 SpringBoot 写链路（H2 + MockitoBean SearchSyncClient，验证 AFTER_COMMIT 事件）；mall-search 真实 ES Testcontainers 8.17.4 + MockMvc 内部端点。跨服务真实 HTTP 链路按 test-design §3 标注归 Integration Gate/E2E。

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据（真实 类#方法） |
| --- | --- | --- | --- | --- |
| TC-001 | 上架/新建上架事务提交后准实时检出（UPSERT） | 两段式集成（product 事件 + search 端点） | passed（两半）；跨服务 HTTP 端到端归 Gate | product 侧 ProductSearchSyncEventTest#createPublishUnpublishEventChain（publish 提交后 verify sync(ON_SALE 投影, minPriceFen=8800) 恰好 1 次）；search 侧 IndexSyncIntegrationTest#syncUpsertAcceptedAndSearchable（POST /api/internal/search/products/sync 200 accepted=true，商城搜索 keyword 命中 total=1、productId=7001） |
| TC-002 | 改名/改分类品牌/换主图后文档更新；SKU 改价后 min/max 刷新 | 集成 | passed（价格/字段投影链路）；7 写方法触发点未逐个覆盖 | #createPublishUnpublishEventChain（sync 视图携带重查后的当前投影，minPriceFen=8800 断言）；IndexSyncIntegrationTest#syncUpsertAcceptedAndSearchable（文档 brandName 等字段经搜索返回） |
| TC-003 | 下架后硬删除（搜索不可见）；重复下架/删除不存在 id 幂等 200 | ES Testcontainers 集成 + 事件链 | passed | IndexSyncIntegrationTest#offSaleSyncDeletesAndStaleDeleteKeepsNew（新版本 OFF_SALE 同步后 total=0）、#deleteEndpointIdempotent（DELETE 200 accepted、再删一次仍 200）；#createPublishUnpublishEventChain（unpublish 后 delete 调用累计 2 次：草稿清理 + 下架） |
| TC-004 | 增 ENABLED SKU 改变极值/禁用唯一低价 SKU 摘要正确；最后启用 SKU 禁用 → 文档删除/不可搜 | 投影口径集成 + 事件链 | passed（口径与草稿删除）；SKU 写方法触发未自动化 | ProductSearchProjectionApiTest#projectionPageOnSaleOnly（仅 DISABLED SKU 的 5002 被排除、5001 极值 1000/3000）、#singleProjectionAndNotFoundCases（5002 → 404）；#createPublishUnpublishEventChain（创建草稿投影查无 → DELETE，不产生可搜文档） |
| TC-005 | 停 mall-search：上架接口仍 200、商品落库、product WARN、不回滚 | MockitoBean 故障注入 | passed | ProductSearchSyncEventTest#listenerFailureNeverBreaksWriteApi（SearchSyncClient#sync 抛 RuntimeException，publish 接口仍 200，sync 仍被调用 1 次，异常不外抛）；search 侧"故障仍 200 受理并落表"由 SyncFailureFlowTest#acceptedOnEsFailureAndRecorded（DU-BE-506）支撑 |
| TC-006 | AFTER_COMMIT：回滚不推送、提交后推送；7 写方法 op 映射正确 | Spring 事件测试 | passed（提交后 + 三类 op）；回滚分支与全量 7 方法未逐个覆盖 | #createPublishUnpublishEventChain：create(草稿)→DELETE、publish→UPSERT(sync)、unpublish→DELETE，均在事务提交后经 Mockito after(2000) 验证；监听器源码 @TransactionalEventListener(phase=AFTER_COMMIT)（ProductSearchSyncListener L35） |
| TC-007 | 内部 sync 端点需 SERVICE；无凭据 401/403；经网关 404 | MockMvc | passed（401）；网关 404 归 Gate | IndexSyncIntegrationTest#authGuards（POST /api/internal/search/products/sync 无凭证 → 401）。网关配置 /api/internal/** 不经网关（gateway application.yml 注释明示），404 表现留联调 |
| TC-008 | sync upsert 200 {accepted:true}；DELETE 不存在 id 200 幂等 | ES Testcontainers 集成 | passed | IndexSyncIntegrationTest#syncUpsertAcceptedAndSearchable（$.data.accepted=true）、#deleteEndpointIdempotent（首次删 200、重复删 200） |
| TC-009 | SearchSyncClient 超时 connect 1s/read 3s | 静态配置评审 | passed（无运行时用例） | `mall-product/.../infrastructure/client/SearchSyncClient.java` L26-27：requestFactory.setConnectTimeout(Duration.ofSeconds(1))、setReadTimeout(Duration.ofSeconds(3))；无短超时候选地址自动化用例（见 §4-G3） |

## 2. 测试执行汇总
| 模块 | 命令 | 结果 |
| --- | --- | --- |
| mall-product | `mvn test -B -ntp`（全 reactor） | ProductSearchSyncEventTest **2/2**（18.57s）、ProductSearchProjectionApiTest **4/4**；模块合计 **101/101**，0 失败 |
| mall-search | 同上 | IndexSyncIntegrationTest **9/9**（本 Story 相关：syncUpsertAcceptedAndSearchable、offSaleSyncDeletesAndStaleDeleteKeepsNew、deleteEndpointIdempotent、authGuards）；模块合计 32/32 |
| 全 reactor | 同上（2026-09-19） | 14 模块 **482/482**，BUILD SUCCESS |
| 日志 | `delivery/changes/CHG-0020/evidence/logs/backend-full-test.log`（跨 Change 共享） | ProductSearchSyncEventTest 行 3885（2,0,0）；ProductSearchProjectionApiTest 行 11909（4,0,0）；IndexSyncIntegrationTest 行 20469（9,0,0）；mall-product 汇总行 17942（101） |

通过率：本 Story 直接相关 6 个真实测试方法全部 passed；TC 覆盖中 TC-002/TC-004/TC-006/TC-009 为部分自动化（评审/口径/同类触发覆盖），无失败项。

## 3. AC 覆盖

| AC | 验收标准（摘要） | 覆盖 TC | 结论 |
| --- | --- | --- | --- |
| AC-001 | 上架提交后 5s 内 ES 出现文档并可被搜索接口检出 | TC-001 | passed（product 事件 + search 写入/检出两段均证；双服务真实 HTTP 5s 端到端归 Integration Gate 场景一/二） |
| AC-002 | 改名/换分类品牌/换主图同步；SKU 改价 min/max 刷新 | TC-002 | passed（投影重查+文档写入链路）；update/改价触发点无独立事件用例（G1） |
| AC-003 | 下架硬删除、搜索不可见；重复下架/删除不存在成功 | TC-003、TC-008 | passed |
| AC-004 | SKU 增禁改价极值正确；无启用 SKU 不产生可搜文档 | TC-004 | passed（口径与草稿 DELETE）；addSku/changeSkuStatus 触发点留补测（G1） |
| AC-005 | mall-search 停止时上架仍成功、WARN、不回滚 | TC-005、TC-009 | passed（故障兜底实测；超时值经代码评审） |
| AC-006 | 事务回滚不产生任何同步调用 | TC-006 | 部分（AFTER_COMMIT 提交侧实测；回滚不推送无显式用例，G2） |
| AC-007 | 内部端点 SERVICE 身份；网关访问 404 | TC-007 | passed（401 实测；网关 404 归 Gate） |

## 4. 缺口 / 备注

- **G1（TC-002/TC-004 触发点）**：7 个写方法（create/update/publish/unpublish/addSku/updateSku/changeSkuStatus）中，自动化仅实证 create 草稿→DELETE、publish→UPSERT、unpublish→DELETE；改名 update、SKU 改价/启停的事件发布未逐方法编码，依赖监听器"重查当前投影"的统一装配与投影口径测试间接保证。
- **G2（TC-006 回滚分支）**：未构造校验失败回滚场景显式断言"零同步调用"；AFTER_COMMIT 语义由注解 + 提交侧时序验证支撑。
- **G3（TC-009）**：1s/3s 超时仅静态配置评审，无短超时候选地址的运行时断言。
- test-design §3 已标注：跨服务真实 HTTP（product→search）在单仓 dev 以双模块集成 + Mockito 边界替代，M5 Integration Gate 以双服务联调为准；本 Story 两半证据均可在同 reactor 内独立复跑。
- 故障窗口的"落表/退避恢复"属 DU-BE-506（SyncFailureFlowTest 6 例），本 Story 只保证主事务不阻断（listenerFailureNeverBreaksWriteApi）。
