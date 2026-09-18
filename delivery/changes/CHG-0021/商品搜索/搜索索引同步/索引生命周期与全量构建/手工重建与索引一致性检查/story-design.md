---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-005-02-01-02"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §2.2/§2.5/§4
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0021
- Story ID: STORY-005-02-01-02
- 状态流转: specified → designed
- 相关仓库: repo-1（mall-search/mall-gateway/mall-identity）、repo-2（mall-admin）
- 需要 Migration: yes
- 数据变更概要: mall-identity Flyway V9（search:index:list/rebuild 两权限码+搜索索引菜单）

## 1. 模块改动（Module Changes）

### repo-1 mall-search（DU-BE-504）

- application.search.SearchIndexRebuildService：
  1. 以 DB 行锁/状态检查保证同一时刻至多一个 RUNNING：insert task(RUNNING) 前 select count(RUNNING)>0 → 409 语义；
  2. 建临时物理索引 mall_products_rebuild_{yyyyMMddHHmmss}（同 mapping/settings）；
  3. 分页（500）bulk 全量写入并更新 indexed_count；
  4. client.indices().updateAliases：remove mall_products→旧物理索引、add mall_products→新索引（原子 actions）；
  5. 删除旧物理索引；task SUCCEEDED；异常 → FAILED+error_message，临时索引保留（日志记录，供人工清理）。
- interfaces.rest.admin.SearchIndexAdminController（ADMIN）：
  - POST /api/admin/search/index/rebuild → 409（已有 RUNNING）或 {taskNo,status:RUNNING}；
  - GET /api/admin/search/index/rebuild-tasks（最近任务列表，简单分页）；
  - GET /api/admin/search/index/consistency-check：
    - productOnSaleCount=投影分页 total（或独立 count 投影接口复用 search-projection?page=0&size=1 取 total）；
    - indexCount=mall_products _count；
    - missingProductIds：以 productId 分批 scroll/terms 比对（每批 500）；extraProductIds：ES 侧扫 docId 集合作差；
    - 差异列表各截断 200，超出在响应 truncated=true 标记。
- mall-gateway：- Path=/api/admin/search/** → lb://mall-search（ADMIN 鉴权链）。

### repo-1 mall-identity（DU-BE-504）

- V9__search_index_permissions.sql：sys_permission 插入 search:index:list、search:index:rebuild；sys_menu 插入"搜索索引"管理菜单项（parent 系统工具/运维分组，按既有菜单 SQL 范式），角色-权限关联沿用种子范式授予超级管理员角色。

### repo-2 mall-admin（DU-FE-502）

- views/search/SearchIndexView.vue：索引状态卡片（别名/物理索引名/indexCount）、[重建索引]按钮（confirm 二次确认，RUNNING 时禁用并轮询当前任务进度 indexed/total）、一致性检查面板（两计数、缺失/多余 ID 表格、截断提示）、最近任务表格（状态/耗时/错误信息）。
- api/searchIndex.ts、路由与菜单按既有 admin 范式注册。

## 2. 接口契约细化

| 方法 | 路径 | 权限码 | 响应 |
| --- | --- | --- | --- |
| POST | /api/admin/search/index/rebuild | search:index:rebuild | 200 {taskNo,status} / 409 B0503（REBUILD_CONFLICT） |
| GET | /api/admin/search/index/rebuild-tasks | search:index:list | Page<Task> |
| GET | /api/admin/search/index/consistency-check | search:index:list | {productOnSaleCount,indexCount,missingProductIds[],extraProductIds[],truncated} |

错误码新增：B0503 REBUILD_CONFLICT(409,"已有重建任务执行中")。

## 3. 数据变更

mall-identity V9 权限/菜单（见 §1）。重建任务行写 search_index_rebuild_task（V1 已建）。

## 4. 错误处理

- 重建中途 ES 失败 → task FAILED；别名未切换，线上查询不受影响；
- 比对接口自身失败（ES/ product 不可用）→ B0501 503。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-504 | repo-1 | 重建(临时索引+原子切别名)/一致性检查/网关/identity V9 | AC-001, AC-002, AC-003, AC-004, AC-005 | 无 |
| DU-FE-502 | repo-2 | mall-admin 搜索索引运维页 | AC-006 | DU-BE-504 |

> 跨 Story 依赖（不入本表）：DU-BE-504 实际前置 DU-BE-503（STORY-005-02-01-01 索引生命周期/投影/全量）。

## 6. 测试策略

- IT：全量重建后别名指向新索引、旧索引被删除、重建期间第二次触发 409、重建失败旧别名不动；
- 一致性检查：人为 delete/insert 一条构造 missing/extra，断言差集与截断标记；
- V9 迁移测试；前端 Vitest：RUNNING 轮询、409 提示、差异表格渲染。
