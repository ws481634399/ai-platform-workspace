# Test Report — STORY-005-02-01-02 手工重建与索引一致性检查

> 阶段：sdd-test 产物（Story 级）。

## 0. 元信息

- Change ID：CHG-0021
- Story ID：STORY-005-02-01-02
- 执行时间：2026-09-19
- 覆盖：AC-001~AC-006、TC-001~TC-008
- 实施来源：repo-1 DU-BE-504（commit 82ccf6e）；repo-2 DU-FE-502（commit a196082，枚举契约修复 5a5056f）
- 测试基线：mall-search 真实 ES Testcontainers 8.17.4 + H2 Flyway + 真实 JWT 安全链；mall-admin vitest/vue-tsc/eslint/vite build。

## 1. 测试范围

### 1.1 后端 DU-BE-504

| TC | 验证内容 | 执行方式 | 结果 | 证据（真实 类#方法） |
| --- | --- | --- | --- | --- |
| TC-001 | 重建中旧索引持续可查；完成后别名原子指向新物理索引、新数据可搜、旧索引 GET 404 | ES Testcontainers 集成 | passed（并发段未自动化） | IndexSyncIntegrationTest#fullRebuildSwitchesAliasAtomically：POST /api/admin/search/index/rebuild 返回 202、status=SUCCESS、totalCount/indexedCount=3；physicalIndex 前缀 mall_products_rebuild_；切换后别名仅指向新索引、mall_products_v1 indexExists=false、count=3、"重建商品"可搜 |
| TC-002 | 任务 RUNNING→SUCCESS、total/indexed 准确；中途失败 FAILED+error_message 且别名/旧索引不变 | ES Testcontainers 集成 | passed（成功路径）；失败路径未自动化 | 成功路径：#fullRebuildSwitchesAliasAtomically（totalCount=3/indexedCount=3，任务字段完整）。失败路径无对应用例（见 §4-G1） |
| TC-003 | 首触发返回任务态；RUNNING 期间第二次 POST → 409 B0503 且可定位当前 taskId | 服务层闸门集成 | passed（B0503）；HTTP 409 序列化未经 MockMvc | IndexSyncIntegrationTest#rebuildConflictWhenRunning：预置 RUNNING 行后 rebuildService.startRebuild() 抛 BusinessException，errorCode=B0503（任务行 RBL-RUNNING 可定位） |
| TC-004 | 一致性检查：计数准确；missing 报删除的 productId；extra 报孤儿 docId；>200 差异 truncated=true 且列表 200 | ES Testcontainers 集成 | passed（计数/extra）；missing 方向与截断未自动化 | IndexSyncIntegrationTest#consistencyCheckDiffs：product 2 条 / ES 3 条 → productOnSaleCount=2、indexCount=3、missingProductIds=[]、extraProductIds=[9003]、checkedAt 存在 |
| TC-005 | 无 rebuild 权限 JWT → 403；无 list 权限 → 403；网关未登录 /api/admin/search/** → 401 | MockMvc JWT | passed（401/403）；网关侧未自动化 | IndexSyncIntegrationTest#authGuards：无 JWT POST rebuild → 401；仅持 search:index:list JWT POST rebuild → 403（同例另证内部 sync 端点无凭证 401） |
| TC-006 | identity V9 权限/菜单种子存在并授予超管 | Flyway 迁移执行 + 静态评审 | passed（迁移可应用）；种子内容无断言用例 | mall-identity 模块 79/79 全绿，test profile 经 Flyway 执行 classpath:db/migration（含 V9__add_search_index_permissions.sql）无错；种子内容（search:index:list/rebuild、/search 与 /search/index 菜单、SUPER_ADMIN 授权）经 SQL 评审，按钮/菜单生效留 Integration Gate |

### 1.2 前端 DU-FE-502

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| TC-007 | SearchIndexView 任务列表渲染、重建 confirm、RUNNING 禁用+2s 轮询、409 提示、差异表格/truncated 提示 | Vitest | **无专属前端自动化测试** | 仓内 16 个 spec（47 例）无 search 相关用例：`src/api/search/index.ts` 无 spec，`src/views/search/SearchIndexView.vue` 无组件测试（见 §4-DEV-5） |
| TC-008 | mall-admin type-check/lint/test/build 全绿 | 构建门禁 | passed | vitest 16 files **47/47**；vue-tsc type-check **0 error**；eslint **0 error / 221 warnings**；vite build SUCCESS（✓ built in 1.01s）。日志 `delivery/changes/CHG-0022/evidence/logs/mall-admin-vitest.log`、`mall-admin-type-check.log`、`mall-admin-lint.log`、`mall-admin-build.log`（跨 Change 共享） |

## 2. 测试执行汇总
| 模块 | 命令 | 结果 |
| --- | --- | --- |
| mall-search | `mvn test -B -ntp`（全 reactor） | IndexSyncIntegrationTest **9/9**（本 Story 相关：fullRebuildSwitchesAliasAtomically、rebuildConflictWhenRunning、consistencyCheckDiffs、authGuards）；模块合计 32/32 |
| mall-identity | 同上 | **79/79**（V9 随 Flyway 链执行通过） |
| mall-admin | `pnpm vitest run` / `pnpm type-check` / `pnpm lint` / `pnpm build` | 47/47、0 error、0 error（221 warnings）、BUILD SUCCESS |
| 全 reactor | `mvn test -B -ntp`（2026-09-19） | 14 模块 **482/482**，BUILD SUCCESS |
| 日志 | `delivery/changes/CHG-0020/evidence/logs/backend-full-test.log`；`delivery/changes/CHG-0022/evidence/logs/mall-admin-*.log` | 完整输出 |

通过率：后端可执行 TC（TC-001~TC-006 中的自动化部分）全部 passed；TC-007 无自动化（DEV-5）；TC-008 门禁全绿。

## 3. AC 覆盖

| AC | 验收标准（摘要） | 覆盖 TC | 结论 |
| --- | --- | --- | --- |
| AC-001 | 重建中搜索不中断；完成后别名指新索引、新数据可搜、旧物理索引删除 | TC-001 | passed（原子切换/旧索引删除已证；"构建中并发持续可查"未做并发注入，由原子 actions 设计保证） |
| AC-002 | RUNNING→SUCCESS、total/indexed 准确；失败 FAILED 且旧索引仍可查 | TC-002 | passed（成功路径）；失败保留路径未自动化（G1） |
| AC-003 | RUNNING 中再触发 409 并回当前 taskId | TC-003 | passed（B0503 服务层断言；HTTP 409 响应体未经 MockMvc 核对） |
| AC-004 | 检查计数准确；missing/extra 差集可报 | TC-004 | passed（计数 + extra 方向）；missing 方向与 >200 truncated 标记未自动化（G2；截断实现见 ConsistencyCheckService.DIFF_LIMIT=200） |
| AC-005 | 无权限 403、菜单/按钮权限生效、网关未登录 401 | TC-005、TC-006 | passed（应用层 401/403 + V9 迁移）；网关 401 与按钮级体验留联调 |
| AC-006 | 页面可查看任务/重建确认/一致性检查；type-check/lint/build 通过 | TC-007、TC-008 | 构建门禁 passed；页面交互无专属自动化（DEV-5），由浏览器联调补证 |

## 4. 缺口 / 备注

- **DEV-5（TC-007）**：SearchIndexView.vue 无专属 vitest 组件测试，`src/api/search/index.ts` 亦无 api 层 spec。2s 轮询（POLL_INTERVAL_MS）、RUNNING 接续、B0503（409）提示、三卡片与 truncated 文案交互由 Integration Gate 浏览器联调补证；页面契约经 type-check 与 build 保证编译一致（含 5a5056f 枚举修复 SUCCESS/FAILED_DEAD）。
- **G1（TC-002 失败路径）**：构建中途 ES 失败 → FAILED+error_message、别名不动旧索引可查，无自动化用例。
- **G2（TC-004）**：missing 方向（人为 DELETE 文档）与构造 >200 差异的 truncated=true/列表 200 条无自动化；截断代码已实现（ConsistencyCheckService line 69-76：missingTruncated/extraTruncated + limit(200)，counts 不受截断影响，consistencyCheckDiffs 的 DisplayName 亦声明该不变量）。
- TC-001 未在构建进行中注入并发查询；不中断性依赖 ES 原子 updateAliases（remove 旧/add 新 单请求）与"切换前不触碰旧索引"的实现顺序。
- 重建端点真实响应为 202 且测试环境下同步执行完毕直接回 SUCCESS（RebuildTaskView 字段 totalCount/indexedCount/physicalIndex），与 story-design 早期"200 {taskNo,RUNNING}"表述的差异以实现+测试为准。
