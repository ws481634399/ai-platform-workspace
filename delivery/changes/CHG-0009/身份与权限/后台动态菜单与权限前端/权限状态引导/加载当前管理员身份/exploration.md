# Exploration（需求探索报告）

> 阶段：sdd-explore 产物
> 输入：`requirement.md`、`references/需求M1.md`

## 1. 需求要点

- [P1] 登录后从后端加载当前管理员、菜单树和 Permission Codes，禁止按角色名硬编码权限。
- [P2] 在 Pinia 中维护可恢复、可刷新、可彻底清理的认证与权限状态。
- [P3] 根据后端菜单树渲染侧边栏，并通过静态组件注册表安全映射动态路由。
- [P4] 页面访问守卫区分未认证、无权限和不存在，提供 401/403/404 一致体验。
- [P5] 提供统一按钮/操作权限原语，后续业务页面不重复实现判断逻辑。
- [P6] 多个并发请求遇到 Access Token 失效时只触发一次 Refresh，并正确重放或统一失败退出。
- [P7] 权限变化能在合理时间内同步，前端篡改状态不能绕过后端 API 授权。

## 2. Story 归属判定

- Feature ID：`FEAT-001-03`
- Story 节点：新增 9 个正式 Story，覆盖权限状态引导、动态导航与页面访问、操作权限与认证异常。
- 是否新建 candidate：否
- Feature 路径：身份与权限 → 后台动态菜单与权限前端 → 各 L3 → 9 个 Story（详见后续 `change-spec.md` §3.3）。

## 3. 证据评估

- 证据类型与来源：`REQ-M1-003` 的正向/反向验收；`product/01-产品需求文档.md` 的 `ADMIN-SYS-MENU-002`、`ADMIN-SYS-PERM-001` 与 `ADMIN-AUTH-001`；现有 mall-admin Router/Pinia/Axios/Layout 基线。
- 结论：充分。后端契约依赖明确，可在契约冻结后并行实现前端。

## 4. 冲突点检测

- 与 product/specs/ 规则冲突：无。
- 与既有 Change 重叠或沿用：沿用 CHG-0004 的 Vue Router、Pinia、Axios 与布局骨架；现有静态占位菜单将被受控动态菜单替代，属于预期演进。
- 与已规划 Story 重复：无。
- 处理决策：组件路径仅允许映射前端编译期注册的组件；前端权限只控制可见性和导航，所有受保护 API 继续由后端授权。

## 5. 待澄清问题

- 无阻塞问题。设计阶段需冻结后端菜单 DTO、组件 key、路由 name/path 规则、权限版本刷新触发和 Refresh 重放约束。
