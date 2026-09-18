# Review Report（Change 级）— CHG-0021 M5 搜索索引同步

> 阶段：sdd-review 产物（独立只读评审；本报告不改动业务代码/测试/既有文档，不写 evidence.yaml）。

## 0. 元信息

- Change ID：CHG-0021（REQ-M5-002 商品搜索索引同步；父需求 PRD-005 商品搜索与筛选）
- 覆盖 Story：
  - STORY-005-02-01-01 索引 Mapping 管理与首次全量构建（DU-BE-503）
  - STORY-005-02-01-02 手工重建与索引一致性检查（DU-BE-504 + DU-FE-502）
  - STORY-005-02-02-01 商品变更增量同步（DU-BE-505）
  - STORY-005-02-02-02 同步幂等乱序防护与失败重试（DU-BE-506）
- 交付仓库：repo-1 ai-platform-backend（初验 commit 82ccf6e，review major 闭环 commit 1de0d9c，5 个 DU 均 completed）；repo-2 ai-platform-frontend（commit a196082 + 5a5056f）
- Test Report 来源：Change 级 `evidence/test-report.md`（2026-09-19；全 reactor 482/482、mall-admin 47/47）；各 Story `evidence/test-report.md`；review 闭环定向回归 `evidence/logs/review-mall-search-retest.log`（26/26）
- Evidence 索引：Change 级 `evidence/evidence.yaml`（EV-001~EV-018；EV-006 为 major 且已闭环，EV-017/EV-018 为闭环提交与回归证据）；各 Story `evidence/evidence.yaml`
- 状态流转：testing（sdd-review 检查点，状态不变；5 个 DU 已 completed）
- 检查时间：2026-09-19
- 审查者：sdd-review 独立评审 Agent（trae-agent）

## 1. 检查结论

**通过（无 blocker；原 1 项 major 已闭环；其余为已登记的 minor 覆盖深度项）。**

冻结契约（错误码 B0501~B0504、枚举 RebuildStatus/SyncFailureStatus、分页体、权限码、internal/admin 路径、external_gte 仲裁、退避序列）经四仓源码抽查全部一致，无枚举/路径/分页结构漂移。原唯一 major（EV-006）：requirement-design §2.4 与 Story4 story-spec §4 声明的 SERVICE 内部只读端点 `GET /api/internal/search/sync-failures` 初版未实现且 Deviations 未记录；**已闭环**——commit 1de0d9c 补 InternalSearchFailureController（ROLE_SERVICE，复用 SearchSyncFailureService.page/count，{total,page,size,items} 与 admin 端点同构）+ InternalSearchFailureApiTest 2 例（令牌分页+FAILED_DEAD 筛选/无令牌 4xx），EV-017/EV-018 为修复与回归证据，定向回归 26/26 全绿，DU-BE-506 DEV-5 已补登。

### 1.1 需求一致性（全局 AC-001~AC-017）

| 全局 AC | 验收要点 | 主要证据（真实方法/源码） | 结论 |
| --- | --- | --- | --- |
| AC-001 | 全新 ES 自动建 mall_products_v1+别名；重启幂等不改 Mapping；ES 停机启动不阻断 | IndexSyncIntegrationTest#ensureIndexIdempotentWithStandardFallback；SearchIndexLifecycleManager 源码（停机仅 log.error、health DOWN） | passed（停机启动仅静态评审，留 Gate） |
| AC-002 | Mapping 代码化（IK 优先、缺失回退 standard）；价格 long、日期 epoch_millis、mainImage index:false | resources/es 两份 JSON 抽查字段类型完全一致、仅分析器不同；以该映射真实建索引成功 | passed（证据文字一处勘误，EV-007） |
| AC-003 | 投影端点 SERVICE 鉴权（无令牌 401、经网关 404）、分页含 total、默认 20 | ProductSearchProjectionApiTest#projectionWithoutTokenUnauthorized/#projectionPageOnSaleOnly；gateway denyAll 配置 | passed（404 网关侧留联调） |
| AC-004 | 投影排除下架/软删/无启用 SKU；价区为启用 SKU 极值；稳定 id 排序 | #projectionPageOnSaleOnly、#singleProjectionAndNotFoundCases；ProductSearchProjectionMapper INNER JOIN ENABLED SKU 派生表 + ORDER BY p.id ASC | passed |
| AC-005 | 首次全量经管理重建链路；>500 分批 id 升序；count=在架总数 | #fullRebuildSwitchesAliasAtomically（count=3）；FullIndexBuildService PAGE_SIZE=500 | passed（1001 条与批次失败注入留 Gate，EV-008） |
| AC-006 | Flyway V1 建重建任务表/同步失败表（无 payload 列） | V1__create_search_sync_tables.sql 静态评审；全部 @SpringBootTest 经 H2 Flyway 真实读写 | passed |
| AC-007 | 发起重建 202；RUNNING 互斥 409 B0503；查询任务/列表 | #rebuildConflictWhenRunning；AdminSearchIndexController 五端点源码；请求线程同步执行兼容同步 SUCCESS | passed |
| AC-008 | 重建中旧索引不中断；成功原子别名+refresh+删旧；失败 FAILED 保留临时索引与错误 | #fullRebuildSwitchesAliasAtomically；RebuildService.switchAlias/markFailed 源码 | passed 成功路径（失败路径留 Gate，EV-009） |
| AC-009 | 一致性检查七字段、500 批、差集截断 200 双侧标记 | #consistencyCheckDiffs；ConsistencyCheckService 源码核实七 key、BATCH_SIZE=500、DIFF_LIMIT=200 | passed（missing 方向/截断构造留 Gate） |
| AC-010 | 管理端权限 search:index:list/rebuild；无权限 403；菜单与按钮 | IndexSyncIntegrationTest#authGuards；V9__add_search_index_permissions.sql 权限/菜单/超管幂等；SearchIndexView v-permission | passed（网关 E2E/种子断言留 Gate，EV-013） |
| AC-011 | 运营页查任务/发起重建/查一致性/失败记录与人工重试；四门禁通过 | SearchIndexView.vue + api/search/index.ts 源码抽查（枚举无漂移）；type-check/lint/build 全绿、47/47 | 部分（无二次确认 EV-011、无前端逻辑切片测试 EV-010） |
| AC-012 | 8 类商品写操作 AFTER_COMMIT 重查投影 sync/delete，主交易不阻断 | ProductSearchSyncEventTest#createPublishUnpublishEventChain、#listenerFailureNeverBreaksWriteApi；ProductApplicationService 8 发布点逐一定位 | passed（逐触发点仅 3 类实证，EV-014） |
| AC-013 | 事务回滚零推送 | @TransactionalEventListener(AFTER_COMMIT) 源码核实 | 部分（无显式回滚用例，EV-014，框架语义保证） |
| AC-014 | 提交后 5s 内可检出（best-effort，超时 1s/3s） | 两半实测（事件链 + 真实 ES 受理即 refresh）；SearchSyncClient 超时配置 | passed（跨服务 5s E2E 留 Gate；超时仅配置评审，EV-015） |
| AC-015 | external_gte 防乱序：旧 upsert 不覆盖、旧 delete 不删新；重复投递幂等 | #staleUpsertSwallowed、#offSaleSyncDeletesAndStaleDeleteKeepsNew、#duplicateFailureReusesRow；ES 8.18.8 ExternalGte 源码核实 | passed |
| AC-016 | ES 失败落 PENDING；退避 30s/1m/2m/5m/10m、5 次 FAILED_DEAD；重放重拉权威投影；删除型重放幂等 | SyncFailureFlowTest 全 6 例（#acceptedOnEsFailureAndRecorded、#backoffSequenceAndDead、#replaySuccessAndStaleAsSuccess、#replayDeleteWhenProjectionMissing、#duplicateFailureReusesRow、#manualRetryRearmAndNotFound） | passed（真实 ES kill 留 Gate，EV-016；1de0d9c 定向回归 6/6 复绿，EV-018） |
| AC-017 | 人工重试 rearm 立即 replay；未知 id B0504/404；失败记录分页 | #manualRetryRearmAndNotFound；AdminSearchIndexController /sync-failures 与前端调用路径/分页体一致；内部只读端点 1de0d9c 由 InternalSearchFailureApiTest 2 例覆盖（令牌分页+FAILED_DEAD 筛选/无令牌 4xx） | passed（HTTP 层未 MockMvc，EV-016；内部 SERVICE 端点已补并回归，EV-017/EV-018） |

### 1.2 设计一致性

- 五份仓内 implementation.md Deviations 共 17 项全部可闭环：口径演进（200→202+同步终态、路径 /rebuild-tasks→/rebuild、双截断标记、事件不携载荷、失败表无 payload、重放重拉、RestClient、8 发布点）均在设计/Story 实施文档双向登记，实现、测试、前端三者一致。
- requirement-design 备选决策（HTTP+AFTER_COMMIT 作为 M5 方案、M7 Outbox 升级点）与实现一致；表结构/权限/Flyway V9/V10 分配与设计冻结一致。
- 未登记偏差初评仅一项且为 major：SERVICE 内部只读同步失败端点裁剪（EV-006），已由 commit 1de0d9c 补实现闭环并补登 DU-BE-506 DEV-5（EV-017/EV-018 为修复与 26/26 回归证据）。另有两处实现细节属轻微文档不一致（重建详情 404 复用 B0504、设计声明的前端 store 未落地），均记 minor 并给处置。

### 1.3 跨仓一致性（重点三链）

1. **product 事件 → mall-search 投影链路**：8 发布点 AFTER_COMMIT 轻事件（productId+操作描述）→ SearchSyncClient（X-Internal-Token、1s/3s、直连 8107）→ mall-search internal sync/delete 恒受理 → 接收侧重查 ProductProjectionClient 单条/分页投影（双端 13 字段 record 同名同序、productId String、404→null 二分重放）→ external_gte 仲裁写 ES；回滚不推送、故障全吞咽主交易零阻断。链路逐跳抽查契约一致，无反向依赖/跨库访问。
2. **admin 页 → admin API**：api/search/index.ts 六方法与 AdminSearchIndexController 五端点路径/方法/权限注解（search:index:list/rebuild）/分页体 {total,page,size,items} 逐字一致；枚举 RebuildStatus=PENDING/RUNNING/SUCCESS/FAILED、SyncFailureStatus=PENDING/SUCCESS/FAILED_DEAD 跨端一致（5a5056f 修复后无 SUCCEEDED/RETRYING/DEAD 残留，本次复核确认）；2s 轮询、onMounted 接续、409 刷新接续、canManualRetry=PENDING||FAILED_DEAD 接线正确。
3. **identity 权限 → 网关**：V9 权限/菜单（component_key=SearchIndex）/SUPER_ADMIN 幂等授权与 @PreAuthorize 字面量、前端 v-permission、component-registry（随 CHG-0022 404eb77 合入，跨 Change 依赖已登记）一致；gateway mall-search-admin `/api/admin/search/**`→8107 + hasRole ADMIN，`/api/internal/**` denyAll 匿名/认证均 404，与 SearchSecurityConfiguration（@Profile("!test")）双层一致；Flyway V9（本 Change）/V10（CHG-0022）无版本争用。

### 1.4 代码质量

- 后端：分层（domain/application/infrastructure）、端口适配器、配置化（超时/退避/调度间隔）符合 backend architecture-standard；ES 8.18.8（BOM 托管）用法合规（PIT+_shard_doc 全量、ExternalGte 版本化、别名原子切换）；真实 ES Testcontainers 8.17.4 + H2 Flyway + 真实安全链测试，符合 testing-standard 风险覆盖原则；全 reactor 482/482、mall-admin 47/47，无回归。
- 前端：type-check/lint/build 全绿、api 域目录与 UnifyResult 解包范式一致；偏差为可测逻辑留在 SFC、设计声明的 store 未落地（EV-010），及破坏性操作无二次确认（EV-011）。
- 错误码质量：B0503 互斥、B0504 不存在语义使用正确，唯重建详情 404 复用"同步失败记录不存在"文案错配（EV-012，minor）。
- review major 闭环复核：1de0d9c 新增 InternalSearchFailureController 挂 `/api/internal/search/sync-failures`（ROLE_SERVICE，只读分页复用 SearchSyncFailureService，{total,page,size,items} 与 admin 同构），InternalSearchFailureApiTest 2 例通过；定向回归 ProductSearchApiTest 9、InternalSearchFailureApiTest 2、IndexSyncIntegrationTest 9、SyncFailureFlowTest 6 共 26/26 全绿（EV-018，日志 evidence/logs/review-mall-search-retest.log）。

### 1.5 知识同步候选

1. 事件驱动投影反腐败层：事件不携载荷 + AFTER_COMMIT 重查权威态决定 upsert/delete + 消费端 external_gte 仲裁。
2. FAILED_DEAD 有界退避死信模式：30s/1m/2m/5m/10m、5 次封顶、重放重拉不信旧 payload、人工 rearm 同请求立即 replay、应用层去重复用行（与 CHG-0019 compensation_task 互为同构范式）。
3. ES 别名原子切换重建：临时索引（UTC 时间戳）+ 单请求 updateAliases remove/add + refresh + 删旧；失败保留临时索引与 FAILED 任务。
4. ES8 全量 dump：PIT + `_shard_doc` search_after（禁 `_id` 排序）+ 稳定 id 升序分页保证分页 total 保真。
5. 代码化双映射自动回退：IK 缺失回退 standard，字段类型冻结一致仅分析器不同。
6. 内部端点安全：网关 denyAll 对匿名/认证统一 404 隐藏存在性 + 服务端 hasRole SERVICE 双层。
7. 跨端枚举契约教训：TS 字面量/常量漂移不被 type-check 发现，需契约共享（生成类型）或 api 层组件测试兜底（本 Change 枚举漂移即由此漏出后修复）。

## 2. 发现清单

| EV id | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-006（Story4 EV-003） | requirement-design.md §2.4；Story4 story-spec §2.1/§4；InternalSearchSyncController | major | 声明的 SERVICE 内部只读端点 GET /api/internal/search/sync-failures?status= 初版未实现（全仓仅 admin 版 /api/admin/search/index/sync-failures），DU-BE-506 Deviations 未记录裁剪；无 AC 直接要求、无 SERVICE 消费方、admin 端点已覆盖排查用途，故非功能阻断 | 已闭环（1de0d9c，EV-017/EV-018 回归 26 全绿，DEV-5 补登） |
| EV-007（Story1 EV-003） | Story1 evidence/test-report.md；resources/es/product-index.json | minor | 证据文字称回退映射 productId=keyword，抽查两份 JSON 实为 long（docId 用字符串 _id）；AC 满足但证据描述失真 | converge 勘误证据，固化"productId=long、_id 字符串 docId"冻结口径 |
| EV-008（Story1 EV-004/005） | Story1 AC-006/AC-001；FullIndexBuildService、SearchIndexLifecycleManager | minor | 1001 条分批/批次失败 FAILED、ES 停机启动不阻断、网关内部 404 无自动化（已登记 G1/G2，静态评审+间接覆盖） | Integration Gate 造数批失败注入、ES 停启、网关 404 联调 |
| EV-009（Story2 EV-006） | Story2 AC-002/AC-004；RebuildService、ConsistencyCheckService | minor | 重建 FAILED 保留路径、构建中并发可查、missing 方向与 >200 双截断构造无专属自动化（已登记 G1/G2） | Gate 注入构建失败/DELETE 文档/>200 差集补断言 |
| EV-010（Story2 EV-007） | requirement-design §3.2；standards/engineering/frontend/coding-standard.md §15；SearchIndexView.vue、api/search/index.ts | minor | 设计声明的 stores/searchIndex.ts 未落地，轮询/409 接续/分页分支留在 SFC，api 契约层无 node 逻辑切片 spec（与 FE DEV-5 关联） | Gate 补 api 层 spec、轮询状态机抽 store/composable 并测试；或 converge 补记结构偏离 |
| EV-011（Story2 EV-008） | Story2 AC-006；SearchIndexView.vue#triggerRebuild；FE DEV-2 | minor | AC 要求"发起重建（确认）"，无 ElMessageBox 二次确认（已登记，B0503 互斥使误触无害） | Gate 补确认弹窗，或以实现为准修订 AC/设计 |
| EV-012（Story2 EV-009） | RebuildService.java#getTask；IndexErrorCode.java | minor | 重建任务详情 404 复用 B0504"同步失败记录不存在"，错误码语义错配（HTTP 状态正确） | 新增重建任务 NOT_FOUND 码或用通用 404；Gate 前修复 |
| EV-013（Story2 EV-010） | Story2 AC-005；V9 SQL；mall-gateway 配置 | minor | 网关 401/404/403 未 E2E、V9 种子内容无专门断言（SQL/配置静态评审+Flyway 79/79 可应用） | Gate 网关联调 + V9 权限/菜单/角色行断言 |
| EV-014（Story3 EV-003） | Story3 AC-002/004/006；ProductApplicationService、ProductSearchSyncListener | minor | 8 发布点仅 create/publish/unpublish 3 类实证，update/SKU 改价/启停无显式用例；回滚零推送仅靠 AFTER_COMMIT 框架语义无显式用例（已登记 G1/G2） | Gate 联调改名/改价/启停；补回滚 verify(never) 用例 |
| EV-015（Story3 EV-004） | Story3 §3/AC-005；ProductSearchSyncListener L51 | minor | AC 措辞 WARN 实际 log.error（实施文档已披露语义达成）；1s/3s 超时仅配置评审 | converge 统一日志级别口径；Gate 短超时联调 |
| EV-016（Story4 EV-004/005） | Story4 AC-004/006/008；SearchSyncFailureService、AdminSearchIndexController | minor | 无真实 ES kill/网络分区（端口异常模拟覆盖故障链分支）；人工重试 HTTP 层未 MockMvc；调度拾取边界无调度级断言（已登记 G3/G4） | Gate 场景五真实 ES stop/start + MockMvc 403/404/200 + 可控时钟拾取断言 |

## 3. 完成确认

- [x] 四项检查全部执行（需求/设计/跨仓/代码质量），结论为"通过：无 blocker；原 1 项 major（EV-006，未记录的端点裁剪）已闭环（1de0d9c，EV-017/EV-018 回归 26 全绿，DEV-5 补登）；另有 10 项 minor（多为已登记覆盖深度项）"
- [x] major 已闭环：1de0d9c 补 SERVICE 只读端点（hasRole SERVICE、{total,page,size,items} 同构）+ InternalSearchFailureApiTest 2 例，EV-017/EV-018 落账，定向回归 26/26 全绿；DU-BE-506 DEV-5 已补登
- [x] 知识同步候选 7 项已写入 §1.5
- [x] 跨仓一致性已核对（repo-1 两模块 + repo-2 + identity V9 + gateway；commit 82ccf6e/a196082/5a5056f + 闭环 1de0d9c；全 reactor 482/482、mall-admin 47/47、闭环定向回归 26/26）
- [x] 4 份 Story 级 review-report.md 已产出并与本报告结论一致
