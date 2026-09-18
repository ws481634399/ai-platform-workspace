# Test Report — CHG-0021 M5 搜索索引同步

> 阶段：sdd-test 产物（Change 级集成验收）。

## 0. 元信息

- Change ID：CHG-0021（商品搜索 > 搜索索引同步，STORY-005-02-01-01/02、STORY-005-02-02-01/02）
- 执行时间：2026-09-19
- 覆盖：M5 Integration Gate 场景一~场景五（`docs/需求/M5/M5.md`，索引同步相关部分；场景六功能开关不属本 Change）
- 实施来源：
  - repo-1（ai-platform-backend）：commit **82ccf6e**（DU-BE-503/504/505/506，含 mall-identity V9 权限种子与 mall-gateway `/api/admin/search/**` 路由）
  - repo-2（ai-platform-frontend/mall-admin）：commit **a196082**（DU-FE-502 搜索索引运维页）+ **5a5056f**（RebuildStatus/SyncFailureStatus 枚举契约对齐 SUCCESS/FAILED_DEAD）
- Evidence 索引：`evidence/evidence.yaml`（EV-001 repo-1 82ccf6e、EV-002 repo-2 a196082、EV-003 repo-2 5a5056f）
- Story 级报告：
  - `商品搜索/搜索索引同步/索引生命周期与全量构建/索引 Mapping 管理与首次全量构建/evidence/test-report.md`（9 TC / 7 AC）
  - `商品搜索/搜索索引同步/索引生命周期与全量构建/手工重建与索引一致性检查/evidence/test-report.md`（8 TC / 6 AC）
  - `商品搜索/搜索索引同步/增量同步与可靠性/商品变更增量同步/evidence/test-report.md`（9 TC / 7 AC）
  - `商品搜索/搜索索引同步/增量同步与可靠性/同步幂等乱序防护与失败重试/evidence/test-report.md`（8 TC / 8 AC）

## 1. 测试范围（分仓分 DU）

| 仓库 | DU | 范围 | 真实测试载体 |
| --- | --- | --- | --- |
| repo-1 | DU-BE-503 | Mapping 代码化（es/product-index*.json）、ensureIndex 幂等启动保障、V1 两表、product 分页/单条投影端点、全量 bulk 管线 | IndexSyncIntegrationTest（部分）、ProductSearchProjectionApiTest（4） |
| repo-1 | DU-BE-504 | 双索引重建+原子别名切换、409 B0503 互斥、一致性差集检查、admin 端点鉴权、identity V9 权限/菜单、gateway admin 路由 | IndexSyncIntegrationTest（部分）、mall-identity 79 例 Flyway 链 |
| repo-1 | DU-BE-505 | 7 写方法 AFTER_COMMIT 事件、SearchSyncClient（1s/3s 超时）、search 内部 sync/delete 端点、故障不阻断主事务 | ProductSearchSyncEventTest（2）、IndexSyncIntegrationTest（部分） |
| repo-1 | DU-BE-506 | external_gte 乱序消化、旧删除防护、failure_record 落表/去重、30s/1m/2m/5m/10m 退避、FAILED_DEAD、重放重拉投影、人工重试 B0504 | SyncFailureFlowTest（6）、IndexSyncIntegrationTest（乱序/删除 3 例） |
| repo-2 | DU-FE-502 | SearchIndexView 三卡片（重建+2s 轮询/一致性检查/失败记录与人工重试）、api/search 契约 | 无专属前端用例；以 mall-admin 全量门禁（type-check/lint/vitest/build）兜底 |

本 Change 直接相关后端用例 **21 个**（IndexSyncIntegrationTest 9 + SyncFailureFlowTest 6 + ProductSearchSyncEventTest 2 + ProductSearchProjectionApiTest 4），全部为真实 @Test 方法（方法名见 §4 与各 Story 报告），无编造用例。

## 2. 测试执行汇总

| 范围 | 命令 | 结果 |
| --- | --- | --- |
| 后端全 reactor | `mvn test -B -ntp`（TESTCONTAINERS_RYUK_DISABLED=true，ES Testcontainers 8.17.4） | **BUILD SUCCESS**，14 个有测试模块合计 **482/482**，0 失败 0 错误（Total 02:47） |
| 本 Change 直接相关 | 同上 | **21/21 passed**：mall-search IndexSyncIntegrationTest 9 + SyncFailureFlowTest 6；mall-product ProductSearchSyncEventTest 2 + ProductSearchProjectionApiTest 4 |
| 模块回归 | 同上 | mall-search 32/32（含 CHG-0020 ProductSearchApiTest 等回归）；mall-product **101/101** 全绿；mall-identity 79/79（V9 随 Flyway 链执行） |
| 前端 mall-admin | `pnpm vitest run` | 16 files **47/47 passed**（无 search 专属 spec，均为既有回归） |
| 前端门禁 | `pnpm type-check` / `pnpm lint` / `pnpm build` | type-check **0 error**；lint **0 error / 221 warnings**；build SUCCESS（✓ built in 1.01s） |

**通过率：本 Change 直接相关 21/21 = 100%；全 reactor 回归 482/482 = 100%；前端回归 47/47 = 100%。** SearchIndexView.vue 无专属组件用例（见 §5-①）。

## 3. 证据清单（日志）

| 证据 | 路径（相对 CHG-0021 目录） | 关键行 |
| --- | --- | --- |
| 后端全 reactor 测试日志（跨 Change 共享，CHG-0020 实跑产物） | `../CHG-0020/evidence/logs/backend-full-test.log` | ProductSearchProjectionApiTest 4,0,0（L11909）；mall-product 101（L17942）；ProductSearchSyncEventTest 2,0,0（L3885）；IndexSyncIntegrationTest 9,0,0（L20469）；SyncFailureFlowTest 6,0,0（L21293）；BUILD SUCCESS（L22991） |
| mall-admin vitest | `../CHG-0022/evidence/logs/mall-admin-vitest.log` | Test Files 16 passed (16)、Tests 47 passed (47)（L79-80） |
| mall-admin type-check | `../CHG-0022/evidence/logs/mall-admin-type-check.log` | 0 error |
| mall-admin lint | `../CHG-0022/evidence/logs/mall-admin-lint.log` | 221 problems（0 errors, 221 warnings）（L247） |
| mall-admin build | `../CHG-0022/evidence/logs/mall-admin-build.log` | ✓ built in 1.01s |

工作区根相对路径：`delivery/changes/CHG-0020/evidence/logs/backend-full-test.log`、`delivery/changes/CHG-0022/evidence/logs/mall-admin-*.log`。

## 4. M5 Integration Gate 场景映射

| 场景 | M5 要求 | 真实方法（类#方法） | 结果 |
| --- | --- | --- | --- |
| 场景一 商品搜索（索引中有数据才能搜到） | 上架商品进入 ES，关键词返回真实商品 | **联动 CHG-0020**：ProductSearchApiTest#keyword_relevance_andOnSaleOnly（关键词命中名称/品牌、下架不返回）、#seedIndex（CHG-0020 交付，本 reactor 32/32 回归绿）；本 Change 补写入侧：IndexSyncIntegrationTest#syncUpsertAcceptedAndSearchable（内部 sync 写入后经 `/api/mall/search/products` 检出 total=1） | passed |
| 场景二 商品修改（改名后可搜新名） | 改名 → 同步索引 → 搜新名称得最新结果 | IndexSyncIntegrationTest#syncUpsertAcceptedAndSearchable（投影写入即可搜，brandName 等字段回传）、#staleUpsertSwallowed（新 updatedAt 内容覆盖可搜，旧版本不改写）；ProductSearchSyncEventTest#createPublishUnpublishEventChain（事务提交 AFTER_COMMIT 后 sync 携带重查的当前投影）。注：update 改名触发点未逐方法编码（G：Story3 §4-G1），端到端"改名→搜新名"由联调补证 | passed（链路两半实测） |
| 场景三 商品下架（下架后不作为正常可售商品出现） | 下架 → 同步删除 → 再搜不可见 | IndexSyncIntegrationTest#offSaleSyncDeletesAndStaleDeleteKeepsNew（新版 OFF_SALE 同步后 total=0，旧版下架事件不删新文档）、#deleteEndpointIdempotent（硬删 200、重复删除幂等 200）；ProductSearchSyncEventTest#createPublishUnpublishEventChain（unpublish 提交后 delete）；ProductSearchProjectionApiTest#projectionPageOnSaleOnly（下架/无启用 SKU 不入投影，双保险） | passed |
| 场景四 价格变化（SKU 100→120，索引价格摘要最终一致） | 改价后列表价格摘要最终更新；订单仍走 Product API | ProductSearchProjectionApiTest#projectionPageOnSaleOnly（启用 SKU 极值 minPriceFen=1000/maxPriceFen=3000 投影口径）、#singleProjectionAndNotFoundCases；ProductSearchSyncEventTest#createPublishUnpublishEventChain（sync 视图 minPriceFen=8800 断言）；IndexSyncIntegrationTest#syncUpsertAcceptedAndSearchable（投影经 sync 写入索引价格摘要）。注：SKU 改价触发点无独立事件用例（Story3 §4-G1），最终一致端到端由联调补证 | passed（投影/写入口径实测） |
| 场景五 Elasticsearch 故障（无不可理解 500、错误可定位、失败可恢复） | 故障期受理、落表可查、退避重试/人工重试恢复 | SyncFailureFlowTest 全部 6 例：#acceptedOnEsFailureAndRecorded（故障仍 200 受理 + PENDING，productId/eventType/reason 齐、首退避 30s）、#duplicateFailureReusesRow（同 product+op 复用一行，可定位不脏表）、#backoffSequenceAndDead（30s/1m/2m/5m/10m 退避，第 5 次 FAILED_DEAD）、#replaySuccessAndStaleAsSuccess（恢复后重拉投影 upsert→SUCCESS，STALE_VERSION 同样消化）、#replayDeleteWhenProjectionMissing（重试时已下架→硬删 SUCCESS）、#manualRetryRearmAndNotFound（人工重试复活；未知 id B0504/404）；主事务侧 ProductSearchSyncEventTest#listenerFailureNeverBreaksWriteApi（search 不可达时上架仍 200、异常不外抛） | passed（6+1 全过） |

## 5. 缺口与说明

1. **SearchIndexView.vue 无专属 vitest 组件测试（DEV-5）**：仓内 16 个 spec/47 例不含任何 search 用例，`src/api/search/index.ts` 亦无 api 层 spec。任务列表渲染、重建二次确认、RUNNING 禁用与 **2s 轮询**、**409 B0503 提示与接续轮询**、差异表格/truncated 文案、失败记录三卡片交互，由 Integration Gate 浏览器联调补证；编译期契约由 type-check 0 error + build SUCCESS 保证（含 5a5056f 枚举对齐）。
2. **未做真实 ES 容器 kill / 网络分区级故障注入**：单机自动化未停启 Testcontainers ES。场景五的失败登记/退避/恢复由 SyncFailureFlowTest 以 **Testcontainers/H2 持久化 + SearchIndexPort 客户端异常模拟**覆盖全分支（受理不落 500、PENDING 字段、退避序列、FAILED_DEAD、重放 SUCCESS/删除、人工重试 B0504）；真实 ES 停启恢复后"文档可搜"的端到端证据在联调阶段取得。
3. **重建 2s 轮询 / 409 接续的端到端浏览器验证在联调阶段执行**；后端互斥闸门已由 IndexSyncIntegrationTest#rebuildConflictWhenRunning（B0503）、原子换别名由 #fullRebuildSwitchesAliasAtomically 实测保证，仅缺 HTTP 409 响应体与前端联动这一段。
4. 其他次级自动化缺口（详见各 Story 报告 §4）：
   - 1001 条分批与"某批失败 FAILED+error_message"无专属用例（STORY-01 S1 用例006）；ES 停机启动不阻断/health DOWN 无用例（S1 用例008，代码 catch 评审）。
- 一致性检查 missing 方向（人为删文档）与 >200 差异 truncated 标记无用例（STORY-02 S2 用例004；DIFF_LIMIT=200 已实现）；重建失败保留旧索引路径无用例（S2 用例002）。
- product 侧 7 写方法仅实证 create/publish/unpublish 三类 op，update/SKU 改价与启停触发点、回滚不推送分支无显式用例（STORY-03 S3 用例002/S3 用例004/S3 用例006）；SearchSyncClient 1s/3s 超时为静态配置评审（S3 用例009）。
   - 网关层 401（/api/admin/search/**）与内部路径经网关 404、admin 人工重试端点 HTTP 层鉴权未在单机自动化驱动，归 Integration Gate。
   - identity V9 种子经 mall-identity Flyway 链 79/79 验证可应用，权限/菜单行内容与超管授予无专门断言，以 SQL 评审 + 联调菜单/按钮为准。
5. 契约演进备注（以最终实现为准）：单条投影不可售/不存在返回 **404**（非 story-design 早期 data=null）；重建端点返回 **202** 且测试环境同步回 SUCCESS；失败管理 admin 路径为 `/api/admin/search/index/sync-failures*`；ES 镜像无 IK 插件时自动回退 standard 映射（字段类型与冻结映射一致）。
