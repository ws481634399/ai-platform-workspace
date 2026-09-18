# Implementation（跨仓实施汇总）— 手工重建与索引一致性检查 STORY-005-02-01-02

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0021（商品搜索索引同步）
- Story：STORY-005-02-01-02 手工重建与索引一致性检查
- 实施日期：2026-09-18

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-504 | repo-1 | mall-search：`RebuildService`（RUNNING 互斥 B0503/409、临时索引 `mall_products_rebuild_*`、原子切别名、删旧、FAILED 保留）、`ConsistencyCheckService`（双计数+missing/extra+200 截断双标记）、`AdminSearchIndexController` 五端点（202/权限码）；mall-identity V9 权限码/菜单种子；mall-gateway admin 路由。IT 覆盖重建/差集/冲突/鉴权 |
| DU-FE-502 | repo-2 | mall-admin 搜索索引运维页：`api/search/index.ts` + `SearchIndexView.vue` 三卡（重建/一致性/失败记录），2s 轮询、409 接续、v-permission；type-check/lint/vitest/build 四门禁本地实测通过；存在状态枚举跨端字面量不一致遗留 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 82ccf6e | DU-BE-504 | repo-1 | feat(search,system): M5 商品搜索+索引同步+系统配置（CHG-0020/0021/0022 后端，M5 三 Change 合并提交） |
| a196082 | DU-FE-502 | repo-2 | feat(search): 管理端搜索索引运维页（CHG-0021 FE-502），仅 api/search/index.ts 与 SearchIndexView.vue 两文件（824 行） |

> 前端动态组件注册 `SearchIndex → SearchIndexView`（`component-registry.ts`）随 404eb77（CHG-0022 FE-503）合入，主干 HEAD 已包含，非本 Story 提交内容。

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0021/商品搜索/搜索索引同步/索引生命周期与全量构建/手工重建与索引一致性检查/DU-BE-504/implementation.md`
  - 重建：findRunning 闸门（B0503「已有重建任务执行中，请稍后再试」/409）；临时索引+taskNo 时间戳（UTC）；`switchAlias` 单请求 updateAliases remove/add 后显式 refresh；成功删旧、异常 markFailed 保留现场；M5 单实例同步执行，POST 返回 202 时通常已 SUCCESS。
  - 一致性：500/批分页拉投影全集 + PIT 游标拉 ES docId 全集；报告 `productOnSaleCount/indexCount/missingProductIds/extraProductIds/missingTruncated/extraTruncated/checkedAt`，差集各截断 200。
  - 端点（`/api/admin/search/index`）：POST `/rebuild`（202，search:index:rebuild）、GET `/rebuild/{id}`、GET `/rebuild?limit=20`、GET `/consistency-check`、GET `/sync-failures?status&page&size`（size 夹 1..100）、POST `/sync-failures/{id}/retry`。
  - identity V9：`search:index:list`/`search:index:rebuild` 权限（ON DUPLICATE KEY UPDATE 幂等）、「搜索索引/索引管理」菜单（component_key=SearchIndex）、SUPER_ADMIN 补齐（INSERT IGNORE）；gateway `mall-search-admin` 路由 `/api/admin/search/**`→8107。
- repo-2：`implementation/ai-platform-frontend/delivery/CHG-0021/商品搜索/搜索索引同步/索引生命周期与全量构建/手工重建与索引一致性检查/DU-FE-502/implementation.md`
  - 三张 el-card（重建+最近任务表、一致性检查、同步失败记录+分页+人工重试）；v-permission（rebuild/list）；2s 轮询、onMounted 接续 RUNNING、409 extractMessage 提示。
  - 门禁实测：type-check ✅、lint 0 error（221 存量 warning）、vitest 47/47（16 文件，本页无专属 spec）、build ✅。

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | 构建中旧索引持续可查（别名最后一步单请求切换的代码顺序保证）；完成后别名指新索引、新数据可搜、旧物理索引删除 | passed（`fullRebuildSwitchesAliasAtomically`：旧 v1 不存在、别名指向新索引、count=3 可搜；构建中并发查询未做 IT） |
| AC-002 | RUNNING→SUCCESS 且 total/indexed 准确；失败 FAILED 保留错误信息、旧索引可查 | passed（成功路径：`fullRebuildSwitchesAliasAtomically` total/indexed=3）；⚠️ FAILED 分支（markFailed、临时索引保留、别名不动）仅代码保证，无故障注入用例 |
| AC-003 | RUNNING 中再触发 409 且带当前 taskId | passed（`rebuildConflictWhenRunning`，`IndexErrorCode.B0503`/HttpStatus.CONFLICT） |
| AC-004 | 计数准确；删文档报 missing、孤儿 docId 报 extra；超 200 truncated | passed（extra/计数：`consistencyCheckDiffs`，productOnSaleCount=2/indexCount=3/extraProductIds=[9003]/checkedAt）；⚠️ missing 构造与超 200 截断（missingTruncated/extraTruncated）未自动化 |
| AC-005 | 无权限 403；权限码经菜单/按钮生效；网关未登录 admin 路由 401 | passed（`authGuards`：无 JWT 401、缺权限码 403；V9 权限/菜单种子与网关路由为 SQL/配置保证，未做 E2E）；前端按钮 v-permission 已接线（展示受枚举遗留影响） |
| AC-006 | 页面可查看任务状态、发起重建（确认）、执行并展示一致性检查；type-check/lint/build 通过 | ⚠️ 部分：页面三卡交付、四门禁实测通过；但①重建未做二次确认弹窗（DU-FE-502 DEV-2）；②前端状态枚举（SUCCEEDED/DEAD/RETRYING）与后端（SUCCESS/FAILED_DEAD、无 RETRYING）字面量不匹配，重建成功终态误报、死信筛选/标签/人工重试入口不可用（DU-FE-502 DEV-4，须 Integration Gate 前修复）；本页无 vitest 专属用例（DEV-5） |

> 测试说明：后端引用真实测试方法名（`IndexSyncIntegrationTest` 9 例中的 4 例与本 Story 直接相关）；前端四门禁结果为 2026-09-18 本地实测；工作区无 surefire 报告，未杜撰 mvn 执行数字。各 DU Deviations（列表路径 `/rebuild`、同步执行、双截断标记、端点同批落地；前端路径/confirm/轮询 2s/枚举缺陷/缺单测）详见仓内 DU 文档。
