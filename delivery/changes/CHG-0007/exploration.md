# Exploration（需求探索报告）

> 阶段：sdd-explore 产物
> 输入：`requirement.md`、`references/需求M1.md`

## 1. 需求要点

- [P1] 为后台管理员提供账号密码认证，密码只以强哈希形式保存且不出现在响应或普通日志中。
- [P2] 使用短时 Access Token 与可撤销、可轮换的 Refresh Token，覆盖签发、过期、刷新、退出和状态失效。
- [P3] 在认证载荷和运行时上下文中显式区分 GUEST、MEMBER、ADMIN、SERVICE，拒绝跨主体误用。
- [P4] Gateway 负责入口 Token 初验与身份传播，业务服务仍承担授权和资源归属判断。
- [P5] Java 服务建立统一 SecurityContext，后续 RBAC 与 `@PreAuthorize` 可直接复用。
- [P6] mall-admin 完成登录页、认证请求、基础 Token 状态与退出入口，不提前实现动态菜单和按钮权限。
- [P7] 认证链路必须具备自动化测试、可观测 traceId 和安全失败语义。

## 2. Story 归属判定

- Feature ID：`FEAT-001-01`
- Story 节点：新增 9 个正式 Story，覆盖凭证认证、Token 生命周期、身份接入传播和管理端认证入口。
- 是否新建 candidate：否
- Feature 路径：身份与权限 → 统一身份认证体系 → 各 L3 → 9 个 Story（详见后续 `change-spec.md` §3.3）。

## 3. 证据评估

- 证据类型与来源：`docs/需求/M1/需求M1.md` 的验收标准与边界；`product/01-产品需求文档.md` 的 `ADMIN-AUTH-001`；既有 M0 后端微服务、Gateway、公共安全模块和 mall-admin 基线代码。
- 结论：充分。需求目标、范围、前置基础和阶段验收均已明确，可进入产品规格阶段。

## 4. 冲突点检测

- 与 product/specs/ 规则冲突：未发现已批准规格冲突；当前 `product/specs/` 无覆盖 M1 认证的更高优先级规则。
- 与既有 Change 重叠或沿用：与 CHG-0003/CHG-0004 的工程基线存在复用关系，无功能范围重叠；沿用其 Spring Boot/Vue/HTTP 基础。
- 与已规划 Story 重复：无；本次新增 Story 均位于新建的身份与权限能力域。
- 处理决策：复用工程基线，不回改 M0 已归档 Change；认证与授权保持分层，RBAC 与动态权限前端分别交由 CHG-0008/CHG-0009。

## 5. 待澄清问题

- 无阻塞问题。设计阶段需确定 Token 算法与密钥装载、Refresh Token 持久化形式、Gateway 到下游的防伪传播机制以及本地初始管理员引导策略。
