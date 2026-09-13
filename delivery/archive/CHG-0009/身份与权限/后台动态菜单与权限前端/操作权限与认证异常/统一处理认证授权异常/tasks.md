# Tasks（Repository Delivery Decomposition Plan）

> Story：STORY-001-03-03-03 — 统一处理认证授权异常
> 输入：story-spec.md + story-design.md；状态流转：designed → tasked

## 0. 元信息

- Change ID: CHG-0009
- Story ID: STORY-001-03-03-03
- Design 来源: story-design.md §5
- DU 总数: 1

## 任务清单

### DU-FE-309: 统一处理认证授权异常

- Repository: repo-2
- Goal: DES-001：实现本 Story 在 repo-2 的职责
- Scope: [S1] 仅实现 STORY-001-03-03-03 的 AC-001, AC-002, AC-003，不扩展相邻 Story。
- Design References: story-design.md §1–§6；change-design.md §2、§4、§5
- Dependencies: 无
- Acceptance Criteria: AC-001, AC-002, AC-003
- Execution Order: 1
- Parallelization: 可与无依赖 DU 并行
- verifies: TC-001, TC-002, TC-003
- Implementation Sketch: 依次固化领域/状态模型、持久化或前端状态边界、应用编排和入口适配；未知状态与越权默认拒绝，敏感信息不进入响应和日志。
- Pseudocode: VALIDATE input and subject; LOAD current state/version; REJECT invalid status, permission or replay; EXECUTE 统一处理认证授权异常; PERSIST atomically; RETURN sanitized result.
- Verification: 逐项执行下表 TC 红灯→最小实现→绿灯；随后运行模块测试、静态检查和契约回归。

#### 可执行任务

| Task | 文件/模块 | 具体改动 | verifies | depends on |
|---|---|---|---|---|
| TASK-001 | mall-admin/src/auth/clear-session.ts | 集中清理 Token、stores 和动态路由 | TC-001, TC-002, TC-003 | — |
| TASK-002 | mall-admin/src/api/http.ts | 分流 401/403/业务错误且不泄露 Token | TC-001, TC-002, TC-003 | TASK-001 |
| TASK-003 | mall-admin/src/auth/clear-session.spec.ts | 覆盖幂等清理、403 保持会话和退出 | TC-001, TC-002, TC-003 | TASK-002 |
