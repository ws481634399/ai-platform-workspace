# Tasks（Repository Delivery Decomposition Plan）

> Story：STORY-001-03-02-03 — 守卫页面并区分 403 与 404
> 输入：story-spec.md + story-design.md；状态流转：designed → tasked

## 0. 元信息

- Change ID: CHG-0009
- Story ID: STORY-001-03-02-03
- Design 来源: story-design.md §5
- DU 总数: 1

## 任务清单

### DU-FE-306: 守卫页面并区分 403 与 404

- Repository: repo-2
- Goal: DES-001：实现本 Story 在 repo-2 的职责
- Scope: [S1] 仅实现 STORY-001-03-02-03 的 AC-001, AC-002, AC-003，不扩展相邻 Story。
- Design References: story-design.md §1–§6；change-design.md §2、§4、§5
- Dependencies: 无
- Acceptance Criteria: AC-001, AC-002, AC-003
- Execution Order: 1
- Parallelization: 可与无依赖 DU 并行
- verifies: TC-001, TC-002, TC-003
- Implementation Sketch: 依次固化领域/状态模型、持久化或前端状态边界、应用编排和入口适配；未知状态与越权默认拒绝，敏感信息不进入响应和日志。
- Pseudocode: VALIDATE input and subject; LOAD current state/version; REJECT invalid status, permission or replay; EXECUTE 守卫页面并区分 403 与 404; PERSIST atomically; RETURN sanitized result.
- Verification: 逐项执行下表 TC 红灯→最小实现→绿灯；随后运行模块测试、静态检查和契约回归。

#### 可执行任务

| Task | 文件/模块 | 具体改动 | verifies | depends on |
|---|---|---|---|---|
| TASK-001 | mall-admin/src/router/guards.ts | 区分未认证、无权限与不存在 | TC-001, TC-002, TC-003 | — |
| TASK-002 | mall-admin/src/views/ForbiddenView.vue | 实现 403 页面 | TC-001, TC-002, TC-003 | TASK-001 |
| TASK-003 | mall-admin/src/router/guards.spec.ts | 覆盖登录跳转、403、404 和回跳地址 | TC-001, TC-002, TC-003 | TASK-002 |
