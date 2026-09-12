---
affected-repositories: [repo-1]
---

# Change Design（架构总设计）

> 阶段：sdd-design 产物（多 Story Change 级）
> 输入：`change-spec.md`

## 0. 元信息

- Change ID: CHG-0008
- spec 来源: `CHG-0008/change-spec.md`
- 状态流转: specified → designed

## 1. 当前状态

- 当前架构模式: repo-1 的 mall-identity 已规划为身份数据拥有方，MyBatis-Plus/Flyway/MySQL 与 Redis 公共模块可复用；mall-common-security 是跨业务服务的技术安全边界。系统尚无 RBAC 表、权限加载器、管理 API 和审计模型。
- 相关仓库: repo-1
- 相关模块: `mall-services/mall-identity`、`mall-common/mall-common-security`、`mall-common/mall-common-redis`

## 2. 提议方案

- 方案概要: mall-identity 持有 AdminUser、Role、Menu、Permission 及关联表；应用服务以事务维护生命周期和关系。权限查询把有效角色、菜单和权限归并成 `AuthorizationSnapshot`。Redis 缓存键只保存管理员 id + permissionVersion 的快照，数据库为事实源。mall-common-security 提供 `PermissionEvaluator`/方法安全适配，具体权限由请求时的 Authentication authorities 提供。审计在同一事务后可靠记录变更摘要。
- 关键组件: Admin/Role/Menu/Permission 聚合与 Repository、AssignmentApplicationService、AuthorizationSnapshotQueryService、PermissionCache、PermissionVersionService、SecurityAuditRecorder、管理 Controller、`@EnableMethodSecurity` 与 authorities 转换器。
- 接口契约: `/api/admin/security/admins`、`/roles`、`/menus`、`/permissions` CRUD；`PUT /admins/{id}/roles`、`PUT /roles/{id}/permissions`；`GET /api/admin/session/bootstrap` 返回当前管理员与有效菜单/权限快照。

## 2.1 备选方案对比（Alternatives Considered）

| 方案 | 优点 | 缺点 | 结论 |
|---|---|---|---|
| 角色名硬编码 | 初期简单 | 无法配置、扩展和审计 | 拒绝 |
| 每次请求全量查库 | 一致性直接 | 高并发下重复查询成本高 | 作为缓存降级路径 |
| RBAC + 版本化 Redis 快照 | 可配置、可审计、读取快 | 需严谨失效策略 | 采用 |

### 2.2 数据与编码契约

- 角色编码使用 `^[A-Z][A-Z0-9_]{2,63}$`；权限编码使用 `^[a-z][a-z0-9-]{1,31}:[a-z][a-z0-9-]{1,31}$`。
- Menu 类型为 `DIRECTORY/PAGE/ACTION`；DIRECTORY/PAGE 可参与树，ACTION 不作为导航节点；API 权限以 Permission `type=API` 表达。
- 所有关联表使用唯一联合键；业务删除采用禁用/软删除，避免历史审计失去引用。
- 内置 `SUPER_ADMIN` 通过受保护 seed 创建；它仍通过模型求值，不在 Controller 散落角色名判断；最后一个有效超级管理员受领域规则保护。

### 2.3 授权与缓存契约

- 有效 authorities = 启用管理员的启用角色所拥有的启用 Permission Code 集合；菜单可见性由启用菜单及对应权限共同决定。
- API 授权使用 `@PreAuthorize("hasAuthority('resource:action')")` 或等价集中策略；未认证 401、已认证无权限 403。
- 每个管理员维护单调递增 `permission_version`；缓存键 `authz:{adminId}:{version}`，TTL 15 分钟。分配或状态变更事务提交后递增受影响管理员版本并删除旧键。
- 缓存不可用时回源数据库并保持正确性；不得因 Redis 失败默认放行。

## 3. 仓库影响（Repository Impact）

- 受影响仓库数: 1
- 主要修改点: 在 mall-identity 增加 RBAC 领域、迁移、管理 API、权限快照和审计；在 mall-common-security 增加方法安全与 authorities 适配；在 Redis 公共能力上使用明确 key/序列化策略。

### 3.1 repo-1

- `mall-identity`: Flyway V2 新增角色、菜单、权限、关联与审计表；新增 `rbac` 四层包和 bootstrap 查询 API。
- `mall-common-security`: 启用方法安全，提供基于 `GrantedAuthority` 的通用授权扩展和 401/403 统一 JSON handler。
- `mall-common-redis`: 不承载业务 key，只复用 String/JSON 操作能力；具体缓存 key 和失效策略留在 mall-identity。

## 4. 跨仓协作（Cross-Repository Contract）

- 接口契约: 本 Change 只修改 repo-1；对 repo-2 暴露的稳定契约是 `GET /api/admin/session/bootstrap`，返回 `user`、`menus`、`permissions`、`permissionVersion`。
- 仓库依赖: 无代码仓间依赖；CHG-0009 只依赖上述 HTTP DTO。
- 集成边界: RBAC 数据库由 mall-identity 独占写入；其他服务仅消费 JWT authorities/权限查询契约，不直连身份库。
- 跨仓时序: 先冻结 bootstrap DTO 和 Permission Code 规则，再允许 CHG-0009 联调；权限修改成功后版本递增，前端据版本刷新。

## 5. Story 设计分派（Story Design Assignments）

| Story ID | 技术要点摘要 | 涉及仓库 | 公共组件/契约归属 |
|---|---|---|---|
| STORY-001-02-01-01 | AdminUser CRUD、状态、防锁死 | repo-1 | AdminUser 归 mall-identity |
| STORY-001-02-01-02 | Role CRUD、编码唯一与状态 | repo-1 | Role 归 mall-identity |
| STORY-001-02-01-03 | 用户角色事务替换与版本失效 | repo-1 | 关系归 mall-identity |
| STORY-001-02-02-01 | Menu 树不变量、排序与 componentKey | repo-1 | Menu DTO 是跨仓契约 |
| STORY-001-02-02-02 | Permission CRUD、编码和资源类型 | repo-1 | Permission Code 是共享契约 |
| STORY-001-02-02-03 | 角色权限事务替换与影响面计算 | repo-1 | 关系归 mall-identity |
| STORY-001-02-03-01 | authorities 装载、方法安全和 403 | repo-1 | 技术适配归 mall-common-security |
| STORY-001-02-03-02 | versioned Redis snapshot 与提交后失效 | repo-1 | key 归 mall-identity |
| STORY-001-02-03-03 | 审计表、变更摘要与 traceId | repo-1 | 审计模型归 mall-identity |

### 5.1 公共组件与共享契约

- `AuthorizationSnapshotDto`：`user{id,username,displayName}`、`menus[]`、`permissions:string[]`、`permissionVersion:long`。
- `MenuDto`：`id/code/parentId/type/title/path/componentKey/icon/sort/visible/requiredPermission/children`；不返回任意文件系统路径。
- Permission Code 由后端校验并作为 authorities 原值传递，前后端不做角色名推断。

## 6. 数据变更

- 是否需 Migration: yes
- 变更摘要: 新增 `role`、`menu`、`permission`、`admin_user_role`、`role_permission`、`role_menu`、`security_audit_log`，并为 admin_user 增加 `permission_version`、审计字段和软删除字段；提供最小 SUPER_ADMIN、基础菜单与权限 seed，全部幂等。

## 7. 风险

- 风险等级: 高
- 主要风险: 权限缓存陈旧、最后管理员被锁死、菜单形成环、角色权限批量更新部分成功、超级管理员旁路失控。
- 缓解措施: 版本化缓存与提交后失效；领域层防锁死；菜单父链环检测与数据库约束；事务替换；超级管理员策略集中并纳入测试与审计。

## 8. 待澄清问题

- 无阻塞问题。M1 仅 seed `SUPER_ADMIN` 与验证用最小权限；商品、订单等业务权限由后续 Change 登记。
