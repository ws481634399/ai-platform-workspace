---
story-id: "STORY-005-02-01-02"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S2]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.1 [S2]/§4/§5
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0021
- Story ID: STORY-005-02-01-02 手工重建与索引一致性检查
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`（S2）

## 1. Story 目标

提供后台可操作、可观测的索引重建与一致性核对：双索引+别名原子切换的可重复重建（构建中旧索引持续可查），任务状态/进度/失败可查询；上架数 vs 索引数与 productId 差集一致性检查；RBAC 权限码、网关 admin 路由与 mall-admin 运维页。

## 2. Scope（范围）

### 2.1 包含

- [S2] RebuildIndexService：创建 mall_products_rebuild_{taskId/ts} 临时索引（同代码 Mapping）→ 全量 bulk → refresh → 原子更新别名（remove v1/add 新索引，原子 actions）→ 清理旧物理索引；任务状态写入 search_index_rebuild_task（PENDING/RUNNING/SUCCESS/FAILED、total/indexed/failed、错误、起止时间）。
- [S2] 并发控制：同一时间仅一个 RUNNING；重复 POST 返回 409 + 当前任务 id。
- [S2] `POST /api/admin/search/index/rebuild`、`GET /api/admin/search/index/rebuild/{taskId}`、`GET /api/admin/search/index/rebuild`（最近任务列表）、`GET /api/admin/search/index/consistency-check`（实时执行并返回报告）。
- [S2] ConsistencyCheckService：product 投影总数 vs ES count；按分页拉全量 productId 与 ES 全量 docId 比对（M5 规模可接受），输出 missing/extra 列表（截断上限+计数）。
- [S2] mall-identity 新增权限码种子 search:index:list、search:index:rebuild + 后台菜单（搜索索引维护）；网关新增 /api/admin/search/** → 8107 ADMIN 路由；SearchSecurityConfiguration ADMIN+权限码。
- [S2] mall-admin 搜索索引页：展示最近构建状态/进度、"重建索引"按钮（二次确认）、一致性检查结果（数量/差异列表/刷新）。

### 2.2 不包含

- 自动定时重建/定时巡检（M5 仅手工）；差异自动修复（检查只报告，修复走重建）。

## 3. 业务规则

- [不中断] 重建完成切换前，查询别名始终指向可用旧索引；切换失败旧索引保留。
- [可重复] 任意时刻可发起新重建（无 RUNNING 时）；历史任务保留可查。
- [权限] 重建需 search:index:rebuild；查看任务/检查需 search:index:list；无权限 403。
- [检查口径] missing=product 在架但 ES 无文档；extra=ES 有文档但 product 非在架（含下架未删）。

## 4. 接口与字段规格

- POST /api/admin/search/index/rebuild → 202 {taskId,status:RUNNING}；已有 RUNNING → 409。
- GET .../rebuild/{taskId} → {taskId,status,total,indexed,failed,errorMessage,startedAt,finishedAt}。
- GET .../consistency-check → {productOnSaleCount,indexCount,missingProductIds[],extraProductIds[],checkedAt}。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 触发重建：构建中持续搜索旧索引不中断；完成后别名指向新索引，新数据可搜、旧物理索引被删除 |
| AC-002 | 任务状态经历 RUNNING→SUCCESS，total/indexed 准确；构建中失败为 FAILED 且保留错误信息、旧索引仍可查 |
| AC-003 | 存在 RUNNING 任务时再次触发返回 409 与当前 taskId |
| AC-004 | 一致性检查数量准确；人为删除若干文档后 missing 报出对应 productId；构造 extra 文档能报 extra |
| AC-005 | 无权限管理员 403；权限码经菜单/按钮体系生效；网关未登录访问 admin 路由 401 |
| AC-006 | mall-admin 页面可查看任务状态、发起重建（确认）、执行并展示一致性检查；type-check/lint/build 通过 |
