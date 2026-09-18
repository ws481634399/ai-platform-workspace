# Review Report（Story 级）— STORY-005-02-01-02 手工重建与索引一致性检查

> 阶段：sdd-review 产物（独立只读评审；本报告不改动业务代码/测试/既有文档，不写 evidence.yaml）。

## 0. 元信息

- Change ID：CHG-0021（REQ-M5-002 商品搜索索引同步）
- Story ID：STORY-005-02-01-02 手工重建与索引一致性检查
- 关联 DU：DU-BE-504（repo-1，commit 82ccf6e，completed）、DU-FE-502（repo-2，commit a196082 + 5a5056f，completed）
- Test Report 来源：`evidence/test-report.md`（2026-09-19；后端可执行项 passed，前端四门禁全绿，页面交互无专属自动化）
- Evidence 索引：`evidence/evidence.yaml`（EV-001 82ccf6e；EV-002 a196082；EV-003 5a5056f；EV-004 后端 482/482；EV-005 mall-admin 47/47；EV-006~EV-010 review-finding minor）
- 状态流转：testing（检查点，状态不变）
- 检查时间：2026-09-19
- 审查者：sdd-review 独立评审 Agent（trae-agent）

## 1. 检查结论

**通过（PASS，有 minor 遗留）。** 冻结契约（POST rebuild→202、RUNNING 互斥 B0503/409、一致性报告七字段、search:index:list/rebuild 权限码）经源码抽查全部落地；前端枚举漂移已由 5a5056f 修复并复核。无 blocker/major；5 项 minor（含已登记 DEV-2/DEV-5 与本次抽查新发现的错误码复用、store 缺失）。

### 1.1 需求一致性

| Story AC | 验收要点 | 证据（真实方法/源码） | 结论 |
| --- | --- | --- | --- |
| AC-001 | 重建中旧索引不中断；完成后别名指新、新数据可搜、旧物理索引删除 | IndexSyncIntegrationTest#fullRebuildSwitchesAliasAtomically（202/SUCCESS、count=3、旧 v1 indexExists=false、"重建商品"可搜）；RebuildService.switchAlias 单请求 remove/add 顺序抽查 | passed（构建中并发查询未注入，由原子 actions 设计保证） |
| AC-002 | RUNNING→SUCCESS、total/indexed；失败 FAILED 保留错误且旧索引可查 | 成功路径同上实测；markFailed（rootMessage 截断 1000、临时索引保留、别名不动）仅静态评审 | passed 成功路径；失败路径部分（EV-006） |
| AC-003 | RUNNING 中再触发 409 B0503 带当前任务 | #rebuildConflictWhenRunning（预置 RUNNING 行→BusinessException B0503/409，任务号可定位）；RebuildService.findRunning 闸门源码核实 | passed |
| AC-004 | 计数准确；missing/extra 差集；超 200 截断 | #consistencyCheckDiffs（2 vs 3、extraProductIds=[9003]、checkedAt）；ConsistencyCheckService 抽查七字段 key 与 DIFF_LIMIT=200、missingTruncated/extraTruncated 双标记 | passed（extra 方向）；missing 方向与截断构造部分（EV-006） |
| AC-005 | 无权限 403、菜单/按钮生效、网关未登录 401 | #authGuards（无 JWT 401、仅 list 权限 POST rebuild 403）；V9 SQL 权限/菜单/超管授权抽查；gateway mall-search-admin 路由与 /api/admin/** ADMIN 链抽查 | passed（应用层+SQL/配置）；网关 E2E/种子断言部分（EV-010） |
| AC-006 | 页面查任务/发起重建/一致性检查；type-check/lint/build 通过 | SearchIndexView.vue 三卡 + api/search/index.ts 抽查；type-check 0 error、lint 0 error、vitest 47/47、build SUCCESS | 部分：二次确认缺失（EV-008）、无页面/api 专属测试（EV-007） |

### 1.2 设计一致性

- DU-BE-504 四项 Deviations 均闭环：①任务列表收敛为 GET /rebuild?limit=（DEV-1）；②同步执行返 202、前端兼容终态与轮询（DEV-2，M5 单实例千级数据秒级，已核 RebuildService 请求线程内跑完）；③单 truncated 拆为 missingTruncated/extraTruncated（DEV-3，与冻结契约一致，已核源码）；④失败记录两端点随控制器同批落地、挂载 /index/sync-failures 子资源（DEV-4，前后端实际调用一致）。
- 口径演进合理并已登记：story-design 早期"200 {taskNo,RUNNING}"→实际 202 且同步回 SUCCESS；路径 /rebuild-tasks→/rebuild；枚举行文 SUCCEEDED→冻结 SUCCESS——实现、测试、前端三者一致，以实现为准。
- DU-FE-502：DEV-4 枚举漂移（SUCCEEDED/DEAD/RETRYING）已由 commit 5a5056f 修复，本次复核 api/search/index.ts 为 PENDING/RUNNING/SUCCESS/FAILED 与 PENDING/SUCCESS/FAILED_DEAD（无 RETRYING），SearchIndexView.vue 无残留旧字面量，canManualRetry=PENDING||FAILED_DEAD 正确。DEV-2（无 confirm）、DEV-5（无 spec）仍开放，见 EV-007/EV-008。
- 新发现两处未在 Deviations 登记的实现细节：重建详情 404 复用 B0504（EV-009）；requirement-design §3.2 声明的 stores/searchIndex.ts 未落地（EV-007）。均为 minor。

### 1.3 跨仓一致性

- admin 页 → admin API：前端六方法路径与 AdminSearchIndexController 五端点完全一致（/api/admin/search/index/rebuild、/rebuild/{id}、/rebuild?limit、/consistency-check、/sync-failures、/sync-failures/{id}/retry）；分页消费 {total,page,size,items}（ItemPage）与控制器 Map 结构一致；2s 轮询（POLL_INTERVAL_MS=2000）、onMounted 接续 RUNNING、409 extractMessage 后刷新接续均已接线。
- identity 权限 → 服务端鉴权：V9 种子 search:index:list/search:index:rebuild 与 @PreAuthorize 字面量逐字一致；权限幂等 ON DUPLICATE KEY UPDATE、超管 INSERT IGNORE；菜单 component_key=SearchIndex 与前端 component-registry 注册键一致（注册随 CHG-0022 404eb77 合入主干，已登记跨 Change 依赖）。
- 网关：mall-search-admin 路由 Path=/api/admin/search/**→8107，安全链 /api/admin/** hasRole ADMIN；内部 /api/internal/** denyAll 返 404，与服务端双重保证一致。
- Flyway 版本协调：V9 归本 Change、V10 归 CHG-0022，与 requirement-design §8 冻结分配一致，无版本争用。

### 1.4 代码质量

- 后端：原子别名切换（单请求 updateAliases remove/add + 显式 refresh + 清旧）、失败保留现场、B0503 闸门、200 截断与 size 夹取（1..100）等实现严谨；分层与异常转换（SearchSecurityExceptionAdvice 403、503 复用 B0501）符合 backend 规范。
- 前端：api 层按域目录组织、类型对齐后端、UnifyResult 解包与仓内范式一致；type-check/lint/build 门禁达标。
- 规范偏差一处：standards/engineering/frontend/coding-standard §15 要求可测逻辑下沉 api/utils/stores 三层并以 node 逻辑切片测试、"SFC 不承载可单测业务分支"；本页轮询状态机/409 接续/分页分支全部位于 SFC，且设计声明的 store 未落地，api 契约层也无 spec——详见 EV-007。

### 1.5 知识同步候选

- ES 别名原子切换重建模式（临时索引 mall_products_rebuild_UTC 时间戳 → 全量 bulk → 单请求 remove/add aliases → refresh → 删旧；失败保留临时索引与 FAILED 任务），可晋升 backend 架构知识。
- "重建 RUNNING 互斥 + 202 受理 + 单实例同步执行、前端轮询兼容返回即终态"的轻量任务模式。
- 一致性检查"双全集求差 + 双侧独立截断 200 + counts 不受截断影响"的对账报告模式。

## 2. 发现清单

| EV id | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-006 | story-spec.md#AC-002、#AC-004；RebuildService/ConsistencyCheckService | minor | 重建失败 FAILED+旧索引保留、构建中并发可查、一致性 missing 方向与 >200 双截断构造无自动化；成功/extra/计数路径已实测，缺口路径代码具备 | Integration Gate 注入构建失败、人为 DELETE 文档、构造 >200 差集，补全失败与截断断言 |
| EV-007 | DU-FE-502 Deviations（DEV-5）；requirement-design.md §3.2；standards/engineering/frontend/coding-standard.md §15 | minor | SearchIndexView 无 vitest（DEV-5 已登记），且设计声明的 stores/searchIndex.ts 未落地——2s 轮询/409 接续/失败重试可用性等可测分支留在 SFC，api/search/index.ts 亦无 §15 要求的 HTTP 契约逻辑切片 spec；枚举漂移正是缺乏该层测试才漏出 | Gate 补 api 层 node 切片 spec（URL/方法/分页解包/枚举），将轮询状态机抽 store 或 composable 并测试；若不抽取，在 converge 补记结构偏离 |
| EV-008 | story-spec.md#AC-006；DU-FE-502 DEV-2；SearchIndexView.vue#triggerRebuild | minor | "发起重建（确认）"要求的二次确认弹窗未实现，点击直接触发；DEV-2 已登记（后端 B0503 互斥+操作幂等使误触后果无害），但 AC 字面未满足 | Gate 补 ElMessageBox 二次确认，或以实现为准在 converge 更新 AC/设计口径 |
| EV-009 | RebuildService.java#getTask；IndexErrorCode.java | minor | GET /rebuild/{taskId} 查询不存在的重建任务时复用 B0504"同步失败记录不存在"（HTTP 404 状态正确，但错误码/文案语义错位，会误导前端提示） | 新增重建任务专用 NOT_FOUND 错误码（如 B0505 REBUILD_TASK_NOT_FOUND）或复用通用 404 码；Gate 前修复 |
| EV-010 | story-spec.md#AC-005；V9__add_search_index_permissions.sql；mall-gateway application.yml | minor | 网关层未登录 401、内部路径经网关 404、admin 重试端点 HTTP 鉴权未做 E2E；V9 种子内容（权限行/菜单/超管授予）无专门断言，依赖 SQL 静态评审与 Flyway 链 79/79 可应用 | Integration Gate 网关联调 401/404/403，并补 V9 种子内容断言（查询权限/菜单/角色关联行） |

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 无 blocker/major finding（5 项 minor 已记录：2 项已登记 Deviations、1 项规范覆盖深度、2 项本次抽查新发现，均给出处置建议）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（admin 页↔admin API、identity V9↔@PreAuthorize↔网关、Flyway V9/V10）
