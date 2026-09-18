# Convergence — CHG-0021 M5 搜索索引同步

> 阶段：sdd-converge 产物
> 业界锚点：Postmortem + Lessons Learned（What → Why → Action → Knowledge）
> 本文档记录知识收敛过程；真正的 standards/product 写回由 sdd-knowledge 主流程与人工评审执行，本文件只记录"该不该更新、更新什么、为什么"。

## 0. 元信息

- Change ID：CHG-0021（REQ-M5-002 商品搜索索引同步）
- 完成时间：2026-09-19
- 产出 Artifact 数：37（Change 级 8：exploration / requirement-spec / requirement-design / test-design / implementation / evidence/test-report / review-report / convergence；Story 级 24：4 Story ×（story-spec / story-design / test-design / implementation / review-report / evidence/test-report）；证据索引 5：Change 级 1 + 4 Story evidence.yaml。requirement.md 与 references/M5.md 为输入归档、story-metadata.yaml 为流转元数据，不计入产出）
- standards-need-update：yes（新建后端搜索引擎标准 1 篇；前端枚举契约教训并入既有前端规范评估）
- product-need-update：yes（Spec 晋升候选 1 篇 `product/specs/搜索索引同步.md`，待人工评审）
- featuretree-need-update：yes（4 个 Story planned → delivered）
- glossary-need-update：no

## 1. 知识变化总结

本 Change 交付 4 个 Story、5 个 DU（repo-1：DU-BE-503/504/505/506；repo-2：DU-FE-502），把 Product DB 权威态到 ES Search Projection 的"建、灌、追、补、重建、核对"六大能力全部落地，形成 7 项可跨 Change 复用的知识增量：

1. **事件驱动投影反腐败层（BE）**：Spring 应用事件只携带 productId 不携载荷，`@TransactionalEventListener(AFTER_COMMIT)` 在事务提交后由消费端重查权威投影、按当前态决定 upsert/delete，写入侧以 updatedAt 毫秒走 ES external version（`external_gte`）做版本仲裁——旧事件被 ES 拒绝即"已被新版本覆盖"正常消化，VersionConflict 不落失败表；事务回滚天然零推送。——适用于 M7 升级 MQ 后的所有权威态→只读投影链路（库存投影、营销投影）。

2. **FAILED_DEAD 有界退避死信模式（BE）**：失败记录按 (productId,eventType) 应用层去重复用行，固定退避 30s/1m/2m/5m/10m、5 次封顶置 FAILED_DEAD，重放一律重拉权威投影（不信旧 payload，已下架则删、在架则 upsert），人工 rearm 同请求立即 replay。与 CHG-0019 compensation_task 互为同构范式（独立建表、不跨域共表）。——适用于所有跨服务最终一致链路的应用层死信。

3. **ES 别名原子切换重建（BE）**：临时索引以 UTC 时间戳命名（mall_products_rebuild_UTC），全量 bulk + refresh 后在**单请求** updateAliases 内 remove 旧/add 新，再删旧物理索引；切换前不触碰旧索引故查询不中断，任何异常保留临时索引现场并置任务 FAILED 可再触发。——适用于所有 Mapping 升级与索引重建场景。

4. **ES8 全量 dump 稳定分页（BE）**：全量比对/灌数使用 PIT + `_shard_doc` 的 search_after，禁止按 `_id` 排序（8.x 不再支持）；业务侧分页统一稳定 id 升序（500/批），保证分页 total 与在架全集口径天然可比。

5. **代码化双映射 IK 缺失自动回退（BE）**：Mapping/Settings 全部位于代码资源（resources/es 两份 JSON），IK 版优先、运行环境无 IK 插件时自动回退 standard 版；两份字段类型冻结一致、仅分析器不同。冻结口径：**productId 映射为 long，docId 使用字符串 _id**；minPrice/maxPrice=long、日期 epoch_millis/date、mainImage keyword 且 index=false。

6. **内部端点双层安全（BE/网关）**：网关对 `/api/internal/**` denyAll，匿名与认证请求统一 404 隐藏存在性；服务端 SecurityConfiguration 再以 hasRole SERVICE（X-Internal-Token）校验，测试 profile 外双层缺一不可。admin 路由独立 `/api/admin/search/**` + hasRole ADMIN + @PreAuthorize 权限码。

7. **跨端枚举字面量漂移教训（FE/契约）**：TS 侧手写枚举字面量（SUCCEEDED/RETRYING/DEAD）与后端 Java enum（SUCCESS/FAILED_DEAD）漂移时，type-check 无法发现（本 Change 由 5a5056f 修复）。对策：枚举/分页体等契约应共享生成类型，或至少在 api 层补 HTTP 契约逻辑切片组件测试兜底；该教训已在 review EV-010 固化。

## 2. 更新判断

### Standards

- 是否需更新：yes
- 更新内容：
  - 新建 `standards/engineering/backend/search-engine-standard.md`（由 sdd-knowledge 主流程统一写入；本报告仅记录判断/概要/理由）。要点：①事件驱动投影反腐败层三段式（轻事件 + AFTER_COMMIT 重查权威态 + external_gte 仲裁，冲突消化为成功）；②有界退避死信（30s/1m/2m/5m/10m、5 次 FAILED_DEAD、重放重拉、人工 rearm），与既有订单状态机标准中 compensation_task 范式互参；③ES 别名单请求原子切换重建与失败保留现场；④ES8 PIT + `_shard_doc` search_after、稳定 id 升序分页、禁 `_id` 排序；⑤代码化双映射与 IK 缺失自动回退 standard，字段类型冻结仅分析器不同（productId=long、字符串 _id docId）；⑥内部端点网关 denyAll 404 + 服务端 hasRole SERVICE 双层；⑦best-effort 投影故障绝不回滚/阻断权威态主事务，丢失窗口由失败记录与一致性检查/重建兜底。
  - 第 7 点知识增量（跨端枚举契约）属前端范畴，建议由 sdd-knowledge 评估并入既有 `standards/engineering/frontend/coding-standard.md` §15（api 契约层切片测试/契约共享类型），本 Change 不新建前端标准文件。
- 理由：ES 投影/重建/退避模式将在 M7（MQ+Outbox）及后续更多投影链路复用，且多处属 ES8 强约束（_shard_doc、external_gte）与安全红线（内部端点不可达），需要跨 Change 统一依据。

### Product

- 是否需更新：yes
- 更新内容：Spec 晋升候选 `product/specs/搜索索引同步.md`（人工评审通过后创建；草稿要点汇总自 4 份 story-spec AC 与冻结契约）：
  - 索引生命周期：启动幂等 ensureIndex（物理索引 mall_products_v1 + 查询别名 mall_products）；Mapping/Settings 代码化，IK 缺失自动回退 standard，productId=long、docId 为字符串 _id。
  - 手工重建：`POST /api/admin/search/index/rebuild` 返回 202；RUNNING 互斥，重复触发 409 B0503；RebuildStatus 四态 PENDING/RUNNING/SUCCESS/FAILED，带 total/indexed/failed 计数与错误信息；双索引 + 单请求原子切别名 + refresh + 删旧，失败保留临时索引。
  - 一致性检查：七字段报告 productOnSaleCount、indexCount、missingProductIds、extraProductIds、missingTruncated、extraTruncated、checkedAt；500/批全量比对，差集列表上限 200 双向截断、计数不受截断影响。
  - 失败记录：sync-failures 分页体 {total,page,size,items}，状态 PENDING/SUCCESS/FAILED_DEAD；30s/1m/2m/5m/10m 有界退避、5 次封顶；重放重拉权威投影；人工 rearm 立即 replay，未知 id B0504/404。
  - 增量同步：ProductApplicationService 8 个商品变更发布点全部 AFTER_COMMIT 轻事件（productId），监听器重查投影后 upsert（ON_SALE）/硬删（其余态）；best-effort 故障不阻断主事务；仅 ON_SALE 且有 ENABLED SKU 入索引，minPrice/maxPrice 为启用 SKU 售价极值；搜索价仅列表摘要，订单实时取价。
  - 乱序与幂等：docId=productId 覆盖写幂等；updatedAt 毫秒 external version（external_gte），旧 upsert/旧 delete 均不覆盖新文档并正常消化。
  - 内部端点两套（X-Internal-Token + ROLE_SERVICE，网关 denyAll）：`POST /api/internal/search/products/sync`（upsert 受理）与 `DELETE /api/internal/search/products/{productId}`（幂等硬删）；`GET /api/internal/search/sync-failures?status=`（只读分页排查）。
  - 权限：search:index:list / search:index:rebuild + ADMIN；mall-admin 运维页三卡片（重建与 2s 轮询、一致性检查、失败记录与人工重试）。
  - **本草稿为晋升候选，须经人工评审后才落入 product/specs/，本次不直接写共享目录。**
- 理由：索引同步是商城搜索域长期能力（M7 将替换触发机制但产品契约不变），需要稳定产品依据承接 M7 与运维排障。

### feature-tree.yaml

- 是否需更新：yes
- 更新内容：4 个 Story 节点 planned → delivered
  - STORY-005-02-01-01 索引 Mapping 管理与首次全量构建
  - STORY-005-02-01-02 手工重建与索引一致性检查
  - STORY-005-02-02-01 商品变更增量同步
  - STORY-005-02-02-02 同步幂等乱序防护与失败重试
- 方式：`openspec feature update <STORY-ID> --status delivered`（由知识更新主流程执行）
- 理由：4 Story 全部 completed，DU-BE-503/504/505/506 与 DU-FE-502 均已交付，review gate 已过。

### Glossary

- 是否需更新：no
- 更新内容：无。
- 理由：external_gte、FAILED_DEAD、PIT、别名切换等为 Elasticsearch 通用术语；RebuildStatus/SyncFailureStatus 由接口契约与 Feature Tree 承载，无需新增术语表条目。

### No Update

- 各端点具体 JSON 字段名、超时配置值（connect 1s/read 3s）、调度 fixedDelay 30s、批大小 500/差集上限 200：实现/配置细节，不入 standards/product。
- Flyway V1 两表 DDL、identity V9 权限种子、gateway 路由配置：实现细节，由代码与标准中的安全/建表原则覆盖。
- CHG-0019 已确立的补偿退避范式：本 Change 仅同构复用验证，不重复立标，新标准以互参方式引用。

## 3. 知识沉淀过程

- 通读 4 Story 全部 Artifact：Change 级 requirement/spec/design、test-design、implementation、evidence（evidence.yaml EV-001~EV-018、test-report）、review-report，及 4 套 story-spec/story-design/test-design/implementation/review-report 与各自 evidence（共 37 个产出 Artifact，计数口径见 §0）。
- 从 review-report §1.5 提取知识候选 7 项（6 项后端工程模式 + 1 项跨端契约教训），按可复用性判定：6 项归新建后端 search-engine-standard，1 项归既有前端 coding-standard §15 增补评估。
- 检索既有 standards：CHG-0019 已立订单集中状态机/CAS 与 compensation_task 有界退避范式（standards/engineering/backend/order-state-machine-and-cas.md），本次失败死信与其同构，新标准只互参不重复；CHG-0020 已立 ES 接入与查询，本次补索引生命周期/投影写入侧。
- Spec 候选仅在本文件 §2 起草要点，未直接写 product/specs/，等待人工评审；feature-tree 状态更新登记操作命令，由知识更新主流程执行；Glossary 判定无需更新。
- review 唯一 major（EV-006：声明的 `GET /api/internal/search/sync-failures` 内部只读端点初版缺失且未登记偏差）**已闭环**：commit 1de0d9c 补 InternalSearchFailureController（hasRole SERVICE、复用 SearchSyncFailureService.page/count、{total,page,size,items} 与 admin 同构）+ InternalSearchFailureApiTest 2 例，EV-017/EV-018 落账，定向回归 26/26 全绿，DU-BE-506 DEV-5 已补登。
- review minor EV-007（证据勘误）已在本次 converge 执行：STORY-005-02-01-01 `evidence/test-report.md` §1 测试范围表中"Mapping 代码化可评审"一行的两处失真描述"productId=keyword"（验证内容列与证据列）已改为事实口径"productId 映射为 long，docId 使用字符串 _id"；测试结论（passed）、AC 覆盖表与证据编号均未改动。
- 其余 minor（EV-008~EV-016）全部为覆盖深度项，已登记延后 M5 Integration Gate 联调，逐条列入 §5 登记项；其中两项以本报告补记口径收口：EV-010 结构偏离（设计声明的 stores/searchIndex.ts 未落地，2s 轮询/409 接续/分页分支留在 SearchIndexView.vue SFC，converge 据实补记，Gate 评估抽 store/composable 并补 api 层切片测试）；EV-015 日志口径统一（监听器实际 log.error，语义为"告警且不回滚"，以实现为准）。EV-012（重建任务详情 404 复用 B0504 文案错配）登记为 Gate 前修复项。
- 无未解决 Conflict，无开放 blocker/major。

## 4. 全局验收标准对照

| # | 验收点（摘自 requirement-spec §5） | 覆盖 Story | 证据引用 | 结论 |
| --- | --- | --- | --- | --- |
| AC-001 | mall-search 首次启动自动幂等创建物理索引与别名；重复启动不报错、不覆盖已有 Mapping | STORY-005-02-01-01 | IndexSyncIntegrationTest#ensureIndexIdempotentWithStandardFallback（清索引后 ensureIndex 创建 mall_products_v1+别名 mall_products，连调两次仍唯一指向 v1）；SearchIndexLifecycleManager 异常 catch 仅 log.error 不阻断启动（源码静态评审）；EV-004（全 reactor 482/482） | 通过（ES 停机启动不阻断/health DOWN 自动化缺口延后 M5 Integration Gate 联调，minor EV-008） |
| AC-002 | Mapping/Settings 存在于代码资源（无手工 Console）；字段类型符合设计（价格 long、分词器等） | STORY-005-02-01-01 | resources/es/product-index.json（IK 版）与 product-index-standard.json（回退版）静态评审：字段类型完全一致仅分析器不同，minPrice/maxPrice=long、productId 映射为 long（docId 使用字符串 _id）、mainImage keyword 且 index=false、日期 date；以该映射真实建索引成功见 #ensureIndexIdempotentWithStandardFallback；EV-004；证据文字勘误 EV-007 已于本次 converge 修正 | 通过 |
| AC-003 | mall-product GET /api/internal/products/search-projection 分页返回上架商品投影（价格摘要/分类品牌名/主图/updatedAt），需 SERVICE 身份，网关不可达 | STORY-005-02-01-01 | ProductSearchProjectionApiTest#projectionWithoutTokenUnauthorized（无令牌 401）、#projectionPageOnSaleOnly（持 X-Internal-Token 分页，total/page/size 回显、投影 13 字段齐）、#singleProjectionAndNotFoundCases（不可售/不存在 404）；mall-gateway /api/internal/** denyAll 配置静态评审；EV-004 | 通过（网关运行时匿名/认证均 404 延后 M5 Integration Gate 联调，minor EV-008） |
| AC-004 | 触发全量构建后 ES 文档数=ON_SALE 有效商品数；无有效 SKU/非上架商品不入索引；分批 Bulk 成功 | STORY-005-02-01-01 | IndexSyncIntegrationTest#fullRebuildSwitchesAliasAtomically（投影 3 条 → totalCount/indexedCount=3、别名 count=3）；ProductSearchProjectionApiTest#projectionPageOnSaleOnly（仅 DISABLED SKU 与 DRAFT 商品排除、极值 1000/3000）、#paginationOrderAndSize（id 升序稳定翻页）；FullIndexBuildService PAGE_SIZE=500 源码；EV-004 | 通过（1001 条造数分批与批次失败 FAILED 注入延后 M5 Integration Gate 联调，minor EV-008） |
| AC-005 | POST /api/admin/search/index/rebuild 双索引重建：重建中旧搜索可用，完成后别名指向新索引，新数据可搜、旧物理索引被清理 | STORY-005-02-01-02 | IndexSyncIntegrationTest#fullRebuildSwitchesAliasAtomically（POST rebuild 202、physicalIndex 前缀 mall_products_rebuild_、切换后别名仅指向新索引、mall_products_v1 indexExists=false、count=3、"重建商品"可搜）；RebuildService 单请求 updateAliases remove/add + refresh + 删旧源码；EV-004 | 通过（构建中并发查询注入未做，由原子 actions 与"切换前不触碰旧索引"实现顺序保证；失败保留现场路径延后联调，minor EV-009） |
| AC-006 | 重建任务有状态记录（RUNNING/SUCCESS/FAILED + 进度/错误）；并发重复触发返回 409/明确提示 | STORY-005-02-01-02 | IndexSyncIntegrationTest#rebuildConflictWhenRunning（预置 RUNNING 行再触发抛 BusinessException，errorCode=B0503，可定位当前任务）、#fullRebuildSwitchesAliasAtomically（SUCCESS + totalCount/indexedCount/physicalIndex/起止时间）；search_index_rebuild_task 经 Flyway V1 真实读写（IndexSyncIntegrationTest/SyncFailureFlowTest 均实证）；EV-004 | 通过（FAILED 失败路径与 HTTP 409 响应体序列化延后 M5 Integration Gate 联调，minor EV-009；详情 404 错误码文案错配 EV-012 登记 Gate 前修复） |
| AC-007 | 一致性检查返回上架总数、索引总数、missing/extra productId 列表；人为删文档后能报出差异 | STORY-005-02-01-02 | IndexSyncIntegrationTest#consistencyCheckDiffs（productOnSaleCount=2、indexCount=3、missingProductIds=[]、extraProductIds=[9003]、checkedAt 存在，含 missingTruncated/extraTruncated 七字段）；ConsistencyCheckService 源码（BATCH_SIZE=500、DIFF_LIMIT=200 双向截断、计数不受截断影响）；EV-004 | 通过（missing 方向人为删文档与 >200 双截断构造延后 M5 Integration Gate 联调，minor EV-009） |
| AC-008 | 重建/检查端点受 RBAC 权限码控制；mall-admin 页面可触发重建、查看状态与检查结果 | STORY-005-02-01-02 | IndexSyncIntegrationTest#authGuards（无 JWT POST rebuild 401、仅持 search:index:list JWT 403）；V9__add_search_index_permissions.sql（search:index:list/rebuild + 菜单 + SUPER_ADMIN 幂等授权）经 mall-identity Flyway 链 79/79；SearchIndexView.vue 三卡片 + v-permission + api/search/index.ts 六方法契约逐字一致，type-check/lint/build 全绿、mall-admin vitest 47/47；EV-002/EV-003/EV-005 | 通过（网关 401/404/403 E2E 与 V9 种子行断言延后 M5 Integration Gate 联调，minor EV-013；前端无 api 层切片/组件测试 EV-010、重建无二次确认 EV-011 一并 Gate 补证） |
| AC-009 | 商品上架 → ES 出现文档可被搜到；新建商品（上架时）→ 出现 | STORY-005-02-02-01 | ProductSearchSyncEventTest#createPublishUnpublishEventChain（publish AFTER_COMMIT 后 verify sync 携带 ON_SALE 投影恰好 1 次，minPriceFen=8800）；IndexSyncIntegrationTest#syncUpsertAcceptedAndSearchable（POST internal sync 200 accepted=true，经商城搜索 keyword 检出 total=1、productId=7001）；EV-004 | 通过（双服务真实 HTTP 5s 端到端延后 M5 Integration Gate 场景一联调，minor EV-015） |
| AC-010 | 商品改名/改分类品牌/换主图后文档字段更新；SKU 改价 → minPrice/maxPrice 摘要刷新 | STORY-005-02-02-01 | ProductSearchSyncEventTest#createPublishUnpublishEventChain（sync 视图为重查后的当前投影）；IndexSyncIntegrationTest#syncUpsertAcceptedAndSearchable（brandName 等字段经搜索返回）；ProductSearchProjectionApiTest#projectionPageOnSaleOnly（启用 SKU 极值 1000/3000）；EV-004 | 通过（8 发布点中 update 改名/addSku/updateSku/changeSkuStatus 改价与启停仅静态定位、未逐方法实证，全矩阵延后 M5 Integration Gate 场景二/四联调，minor EV-014） |
| AC-011 | 商品下架 → 文档从正常搜索消失（硬删除），下架后搜不到；订单/详情链路不读取搜索价格 | STORY-005-02-02-01 | IndexSyncIntegrationTest#offSaleSyncDeletesAndStaleDeleteKeepsNew（OFF_SALE 同步后 total=0）、#deleteEndpointIdempotent（硬删 200、重复删除幂等 200）；ProductSearchSyncEventTest#createPublishUnpublishEventChain（unpublish AFTER_COMMIT → delete）；订单实时取价由 Product API 保证（CHG-0019 OrderApiTest 随全 reactor 回归守住），搜索 min/max 仅列表摘要；EV-004 | 通过 |
| AC-012 | 同步调用失败不影响商品上架/下架事务成功（投影故障不拖垮主流程） | STORY-005-02-02-01 | ProductSearchSyncEventTest#listenerFailureNeverBreaksWriteApi（SearchSyncClient#sync 抛 RuntimeException，publish 接口仍 200、商品落库、sync 仍被调用 1 次、异常不外抛）；监听器 try-catch 全兜底 + @TransactionalEventListener(AFTER_COMMIT) 源码；SearchSyncClient connect 1s/read 3s 配置静态评审；EV-004 | 通过（短超时运行时断言延后 M5 Integration Gate 联调，minor EV-015；日志级别口径以实现为准——告警 log.error 语义达成，EV-015 已在 §3 统一） |
| AC-013 | 同一事件重复投递两次：最终仅一份正确文档，无重复/错误数据 | STORY-005-02-02-02 | docId=productId 字符串 _id 覆盖写模型；IndexSyncIntegrationTest#staleUpsertSwallowed（真实 ES 版本化覆盖写语义佐证）；SyncFailureFlowTest#duplicateFailureReusesRow（同 (productId,eventType) 连续失败仅 1 行 PENDING、retryCount=0，不脏表）；EV-004、EV-018（闭环回归 26/26） | 通过（ES 双投 _count=1 无专属断言，由覆盖写模型 + 真实版本化用例佐证，列入 M5 Integration Gate 联调观察项，minor EV-016） |
| AC-014 | 构造 updatedAt 更小的旧事件晚到：不覆盖新文档（external version 拒绝并被正常消化） | STORY-005-02-02-02 | IndexSyncIntegrationTest#staleUpsertSwallowed（v2000 后投 v1000，total=1 且 productName="新版本手机"，两次请求均 200，VersionConflict 消化）、#offSaleSyncDeletesAndStaleDeleteKeepsNew（version=999 旧 delete 不删新文档 total 仍为 1，v2000 新下架事件后 total=0）；ES 8.18.8 external_gte 真实语义（Testcontainers 8.17.4，不 Mock）；EV-004、EV-018 | 通过 |
| AC-015 | ES 不可用时触发同步 → search_sync_failure_record 产生 PENDING 记录；恢复后定时重试成功 → SUCCESS | STORY-005-02-02-02 | SyncFailureFlowTest#acceptedOnEsFailureAndRecorded（ES 异常端点仍 200 受理，记录 productId/eventType/reason/status=PENDING、首退避 30s）、#replaySuccessAndStaleAsSuccess（恢复后重拉权威投影 upsert WRITTEN → SUCCESS，STALE_VERSION 同消化）、#replayDeleteWhenProjectionMissing（重放时投影缺失/已下架 → 硬删 SUCCESS）；EV-004、EV-018 | 通过（真实 ES kill/网络分区与 @Scheduled 自动拾取端到端延后 M5 Integration Gate 场景五联调，minor EV-016） |
| AC-016 | 连续失败 5 次 → FAILED_DEAD 不再自动重试；人工重试端点可重新激活并最终成功 | STORY-005-02-02-02 | SyncFailureFlowTest#backoffSequenceAndDead（退避间隔 [30,60,120,300,600] 秒、第 5 次 status=FAILED_DEAD/retryCount=5）、#manualRetryRearmAndNotFound（人工 rearm 立即 replay SUCCESS；未知 id B0504/httpStatus=404）；InternalSearchFailureApiTest 2 例（GET /api/internal/search/sync-failures 令牌分页 + FAILED_DEAD 筛选、无令牌 4xx；major EV-006 闭环 commit 1de0d9c）；EV-004、EV-017、EV-018 | 通过（admin 人工重试 HTTP 层 MockMvc 与调度拾取边界断言延后 M5 Integration Gate 联调，minor EV-016） |
| AC-017 | Integration Gate 场景二/三/四/五（改名、下架、改价、ES 故障恢复）E2E 通过；后端测试全绿 | ALL（4 Story 跨 Story 集成） | Change 级 evidence/test-report.md §4：场景三下架两半实测（#offSaleSyncDeletesAndStaleDeleteKeepsNew + #createPublishUnpublishEventChain）；场景二改名/场景四改价两半实测（ProductSearchSyncEventTest + ProductSearchProjectionApiTest + #syncUpsertAcceptedAndSearchable）；场景五 SyncFailureFlowTest 6 例 + #listenerFailureNeverBreaksWriteApi；全 reactor 482/482（mall-search 32/32、mall-product 101/101）、mall-admin 47/47（EV-004/EV-005）；major 闭环定向回归 26/26（EV-018） | 通过（自动化两半与全量回归全绿；跨服务/网关运行时/真实 ES 故障端到端矩阵延后 M5 Integration Gate 联调：8 发布点全矩阵 EV-014、真实 ES kill EV-016、网关 404/401/403 EV-008/EV-013，已在 §5 登记） |

## 5. 完成确认

- [x] 全部 4 Story Artifact 已读取（Change 级 + 4 套 Story Artifact，共 37 个产出 Artifact）
- [x] 知识分类完成（新建后端 standards 候选 1 篇 search-engine-standard、前端规范增补评估 1 项、Spec 晋升候选 1 篇、Feature Tree 4 节点、Glossary 无）
- [x] 5 个 DU 均 completed（repo-1 DU-BE-503/504/505/506，repo-2 DU-FE-502；初验 82ccf6e/a196082，枚举契约修复 5a5056f，major 闭环 1de0d9c）
- [x] 代码变更已完成，测试已完成，证据已收集（后端全 reactor 482/482、mall-admin 47/47、闭环定向回归 26/26）
- [x] 全局验收标准 AC-001~AC-017 已逐条对照（§4，含跨 Story 集成验收点 AC-017，分层两半证据 + 联调登记，不以"各 Story 验收已通过"替代）
- [x] 知识更新已评估（standards/product/feature-tree/glossary 判断见 §2；实际写回由 sdd-knowledge 主流程与人工评审执行）
- [x] review 唯一 major（EV-006）已闭环（1de0d9c，EV-017/EV-018 回归 26/26，DEV-5 补登）；minor EV-007 证据勘误已于本次 converge 执行
- [x] 无未解决 Conflict、无开放 blocker/major
- [x] **M5 Integration Gate 延后联测登记项**（均为 review minor，自动化已覆盖主路径、缺口在联调补证，不阻断 converge）：
  - EV-008：1001 条造数分批 + 批次失败 FAILED 注入、ES 停机启动不阻断/health DOWN、内部路径经网关 404
  - EV-009：重建 FAILED 保留临时索引、构建中并发可查、一致性 missing 方向与 >200 双向截断构造
  - EV-010：前端 api/search 契约层切片测试、轮询状态机抽 store/composable（结构偏离已在 §3 补记）
  - EV-011：SearchIndexView 重建操作 ElMessageBox 二次确认（B0503 互斥下误触无害，Gate 补弹窗或修订口径）
  - EV-012：重建任务详情 404 错误码/文案语义错配（复用 B0504），登记 Gate 前修复
  - EV-013：网关 401/404/403 E2E 与 V9 权限/菜单/超管种子行断言
  - EV-014：8 发布点全矩阵联调（改名/改价/启停）+ 事务回滚零同步调用 verify(never) 专项用例
  - EV-015：跨服务 5s 新鲜度与 1s/3s 短超时联调（日志级别口径已在 §3 统一为告警 ERROR/WARN）
  - EV-016：场景五真实 ES stop/start 后 @Scheduled 自动拾取 SUCCESS 与文档恢复可搜、人工重试 MockMvc 403/404/200、可控时钟调度拾取边界
