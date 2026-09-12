---
affected-repositories: [repo-1, repo-2]
---

# Change Design（架构总设计）

> 阶段：sdd-design 产物（多 Story Change 级）
> 输入：`change-spec.md`

## 0. 元信息

- Change ID: CHG-0009
- spec 来源: `CHG-0009/change-spec.md`
- 状态流转: specified → designed

## 1. 当前状态

- 当前架构模式: repo-2 mall-admin 已有静态 Vue Router、Pinia app store、Axios client、AdminLayout 和静态 MenuItems；登录页只是 M0 占位。repo-1 将由 CHG-0007/0008 提供认证和 RBAC，但需补齐面向前端的聚合 bootstrap 契约。
- 相关仓库: repo-1、repo-2
- 相关模块: `mall-identity` session bootstrap；`mall-admin/src/api|stores|router|layouts|views|directives|composables`

## 2. 提议方案

- 方案概要: repo-1 暴露一次性 session bootstrap DTO；repo-2 将 auth 与 permission 分成两个 Pinia store，路由层保留静态公共路由并用 `componentRegistry` 把后端 componentKey 转为已知懒加载组件。`permissionBootstrap` 负责加载状态和幂等注册/注销路由，HTTP client 通过单例 Refresh Coordinator 合并并发刷新，路由守卫用返回值式 API 区分 login/403/404。
- 关键组件: `sessionApi`、`useAuthStore`、`usePermissionStore`、`componentRegistry`、`buildDynamicRoutes`、`dynamicRouteRegistry`、`permissionGuard`、`v-permission`、`usePermission`、`RefreshCoordinator`、403/404 页面与动态 Sidebar。
- 接口契约: `GET /api/admin/session/bootstrap` 返回 `user`、树形 `menus`、排序且去重的 `permissions` 和 `permissionVersion`；认证接口沿用 CHG-0007；403 使用 HTTP status 403，不伪装成业务 200。

## 2.1 备选方案对比（Alternatives Considered）

| 方案 | 优点 | 缺点 | 结论 |
|---|---|---|---|
| 按角色名硬编码静态路由 | 实现快 | 与后端权限漂移，无法细粒度控制 | 拒绝 |
| 服务端返回任意组件路径 | 配置灵活 | 可加载未知组件，安全与构建不可控 | 拒绝 |
| 后端菜单 + 前端组件注册表 | 权限数据驱动且加载集合受控 | 需维护稳定 componentKey | 采用 |

### 2.2 前端状态与恢复契约

- auth store 持有 Access Token、过期时间和当前 session 状态；permission store 持有 user、menus、permissions Set、permissionVersion、bootstrap 状态。
- sessionStorage 只保存恢复认证所需最小信息，不持久化菜单和权限事实；页面刷新后重新调用 bootstrap。
- bootstrap 使用共享 Promise 防止重复请求；成功后先验证 DTO，再替换权限状态并幂等同步动态路由；失败时按 401/403/网络错误分别处理。
- 权限版本变化或显式 `refreshPermissions()` 会整体替换菜单和权限，并注销不再存在的动态路由。

### 2.3 路由与组件安全契约

- 静态路由：`/login`、`/403`、`/:pathMatch(.*)*`；受保护业务路由均挂在 AdminLayout 下动态注册。
- `componentRegistry: Record<ComponentKey, RouteComponent>` 在编译期声明；后端 key 未命中时跳过节点并记录不含敏感数据的告警。
- 动态路由 name 由后端稳定 menu code 映射并加命名空间，注册前检查冲突；每次同步保存 removeRoute 回调用于权限撤销和退出。
- 守卫顺序：公开路由 → 无 Token 去 login（保留 redirect）→ 确保 bootstrap → 检查 route permission → 403；未知路径最终 404。

### 2.4 HTTP 与 Refresh 契约

- 请求拦截器注入 Access Token 与 traceId；认证登录/刷新请求可通过显式配置跳过注入/重试。
- 只对“Access Token 可刷新过期”401 进入 Coordinator；同一时间复用一个 Promise，成功后原请求最多重放一次。
- Refresh 失败统一 reject 等待请求，调用 `clearSession()` 并跳登录；403 只抛出权限错误，不刷新、不清会话。
- 为避免循环，重放请求加 `_retry=true`，Refresh 请求禁止进入响应拦截器刷新分支。

## 3. 仓库影响（Repository Impact）

- 受影响仓库数: 2
- 主要修改点: repo-1 完善 session bootstrap 聚合接口；repo-2 重构 auth/permission 状态、Axios 拦截器、动态路由、Sidebar、权限原语和异常页面。

### 3.1 repo-1

- 在 mall-identity 提供只读 bootstrap Application Service 与 Controller，复用 CHG-0008 AuthorizationSnapshot，不新增另一套权限计算。
- 对 DTO 进行契约测试，保证 componentKey 只是枚举式 key，menus 为无环树，permissions 去重且 permissionVersion 单调。

### 3.2 repo-2

- 新增领域化 stores/api/router services/directives/composables，替换静态 MenuItems 和占位守卫。
- 更新 AdminLayout 以从 permission store 渲染菜单；新增 ForbiddenView；保留 NotFoundView；登录页与 auth store 沿用 CHG-0007。
- 增加 Vitest 与 Vue Test Utils（版本由 lockfile 固定）用于 store、路由、Refresh Coordinator 和权限原语测试。

## 4. 跨仓协作（Cross-Repository Contract）

- 接口契约: repo-2 → repo-1 `GET /api/admin/session/bootstrap`；字段为 `user:{id,username,displayName}`、`menus:MenuNode[]`、`permissions:string[]`、`permissionVersion:number`，MenuNode 字段与 CHG-0008 §5.1 一致。
- 仓库依赖: repo-2 只依赖 HTTP JSON 契约，不引入 Java DTO 或服务数据库；repo-1 不依赖前端实现。
- 集成边界: 所有请求经 Gateway；组件 key 双方共享文档枚举但前端注册表为最终可加载集合；Vite 环境只提供 base URL，不包含 Secret。
- 跨仓时序: repo-1 契约测试先冻结 → repo-2 用 fixture 并行开发 → Gateway 联调 → 权限变更与后端 403 反向验证。

## 5. Story 设计分派（Story Design Assignments）

| Story ID | 技术要点摘要 | 涉及仓库 | 公共组件/契约归属 |
|---|---|---|---|
| STORY-001-03-01-01 | bootstrap 用户 DTO 与 auth/permission store 身份部分 | repo-1, repo-2 | Bootstrap DTO 属跨仓契约 |
| STORY-001-03-01-02 | menus/permissions/version 加载与校验 | repo-1, repo-2 | Permission store 归 repo-2 |
| STORY-001-03-01-03 | 恢复、共享 bootstrap Promise 与版本刷新 | repo-2 | 引导编排归 repo-2 |
| STORY-001-03-02-01 | 树形 Sidebar 渲染与可见节点过滤 | repo-2 | MenuNode 类型复用契约 |
| STORY-001-03-02-02 | componentRegistry、路由转换与可撤销注册 | repo-2 | registry 是前端安全边界 |
| STORY-001-03-02-03 | 返回值式权限守卫、403/404 | repo-2 | 守卫遵循现有 router standard |
| STORY-001-03-03-01 | `usePermission` 与 `v-permission` | repo-2 | 权限判断只读 permission store |
| STORY-001-03-03-02 | Axios Refresh Coordinator、单飞与一次重放 | repo-2 | 认证 API 沿用 CHG-0007 |
| STORY-001-03-03-03 | 401/403 分类、会话和动态路由清理 | repo-2 | `clearSession` 为唯一清理入口 |

### 5.1 公共组件与共享契约

- `MenuNode`、`SessionBootstrap`、`PermissionCode` TypeScript 类型集中在 `src/types/security.ts`，API、store、router 和 layout 复用。
- `clearSession()` 统一清理 auth、permission、动态路由和待处理 Refresh，不允许各组件自行删部分状态。
- `hasPermission()` 是唯一权限判断原语，Directive/Composable/守卫都复用，后端仍为最终授权边界。

## 6. 数据变更

- 是否需 Migration: no
- 变更摘要: 复用 CHG-0007/0008 的管理员、会话和 RBAC 表；本 Change 只增加聚合查询和前端运行时状态，不增加持久化业务表。

## 7. 风险

- 风险等级: 高
- 主要风险: 任意组件加载、重复动态路由、Refresh 风暴/循环、权限删除后残留入口、401/403 混淆、跨 store 清理不完整。
- 缓解措施: 编译期白名单 registry；removeRoute 句柄与幂等同步；single-flight + `_retry`；整体替换状态；显式错误分类；集中 clearSession 并用单元/路由集成测试覆盖。

## 8. 待澄清问题

- 无阻塞问题。M1 用现有占位页面作为 componentRegistry 的验证载体，后续业务 Change 注册真实页面时不得改变本契约。
