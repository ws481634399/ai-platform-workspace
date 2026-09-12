# Exploration（需求探索报告）

> 阶段：sdd-explore 产物
> 输入：`requirement.md`、`references/需求M1.md`

## 1. 需求要点

- [P1] 管理管理员与角色的生命周期、启停状态及多对多分配关系。
- [P2] 建模目录、页面、按钮/操作和 API 权限，统一权限编码并支持菜单树排序。
- [P3] 管理角色与菜单、操作、API 权限的关系，不以角色名称硬编码授权逻辑。
- [P4] 在后端业务服务执行权限判定，绕过前端直接调用仍返回 403。
- [P5] 使用 Redis 加速权限读取，同时对管理员禁用、用户角色、角色权限和菜单权限变化实施失效。
- [P6] 对管理员、角色和授权关系的敏感变更形成可追溯审计基础。

## 2. Story 归属判定

- Feature ID：`FEAT-001-02`
- Story 节点：新增 9 个正式 Story，覆盖权限主体、权限资源、授权执行与治理。
- 是否新建 candidate：否
- Feature 路径：身份与权限 → 后台 RBAC 权限体系 → 各 L3 → 9 个 Story（详见后续 `change-spec.md` §3.3）。

## 3. 证据评估

- 证据类型与来源：`REQ-M1-002` 明确功能与反向安全验收；`product/01-产品需求文档.md` 的 `ADMIN-SYS-USER-001`、`ADMIN-SYS-ROLE-001`、`ADMIN-SYS-MENU-001`、`ADMIN-SYS-PERM-002`；M0 已提供 MySQL/Redis 与 Java 服务骨架。
- 结论：充分。RBAC 模型、管理面、执行面、缓存与审计边界清晰。

## 4. 冲突点检测

- 与 product/specs/ 规则冲突：无。
- 与既有 Change 重叠或沿用：复用 CHG-0003 的持久化/Web/Security 模块边界和 CHG-0006 的 MySQL/Redis 基础设施；无重复交付。
- 与已规划 Story 重复：无。
- 处理决策：RBAC 数据与管理 API 归 mall-identity；通用授权上下文与注解支持归 `mall-common-security`；具体业务资源归属判断留给后续业务 Change。

## 5. 待澄清问题

- 无阻塞问题。设计阶段需冻结权限编码格式、超级管理员策略、软删除/禁用语义、缓存版本策略与审计保留字段。
