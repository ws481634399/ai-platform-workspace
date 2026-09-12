---
affected-repositories: [repo-1]
story-id: "STORY-001-02-01-01"
change-design-ref: "change-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：`story-spec.md` + `change-design.md` §5
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0008
- Story ID: STORY-001-02-01-01
- Change Design 引用: `change-design.md#5-story-设计分派story-design-assignments`
- 状态流转: specified → designed

## 1. 模块改动（Module Changes）

- 涉及仓库: repo-1
- 模块改动摘要: mall-identity/rbac 新增 AdminApplicationService 与管理 Controller，复用认证 AdminUser 实体并实现防锁死。

### 1.1 repo-1

- mall-identity/rbac 新增 AdminApplicationService 与管理 Controller，复用认证 AdminUser 实体并实现防锁死。

## 2. 接口契约细化

/api/admin/security/admins 系列接口使用请求/响应 DTO、分页和明确 400/403/409。 跨 Story 共享类型与边界引用 `change-design.md` §2、§4、§5.1，不在本 Story 另造不兼容协议。

## 3. 数据变更

- 是否需 Migration: yes
- 变更摘要: Flyway V2 为 admin_user 补软删除/permission_version/审计字段与必要索引。

## 4. 错误处理

- 外部输入校验失败返回 400；未认证返回 401；已认证无权限返回 403；资源不存在返回 404；唯一性、状态或并发冲突返回 409。
- 事务失败必须整体回滚；日志只记录结构化标识与 traceId，不记录密码、Token、密钥或敏感摘要。
- 未知枚举、权限、组件 key 或状态默认拒绝，不采用宽松降级。

## 5. DU 划分（Delivery Units）

| DU | 仓库 | 职责（实现哪些 DES） | covers AC | depends on |
|---|---|---|---|---|
| DU-BE-201 | repo-1 | DES-001：实现本 Story 在 repo-1 的职责 | AC-001, AC-002, AC-003 | — |

## 6. 测试策略

- Unit：覆盖领域不变量、正常路径和每个拒绝分支。
- Integration/API：覆盖接口状态码、事务、序列化与持久化/路由协作。
- Security/Boundary：覆盖伪造、越权、重放、未知值或状态清理等本 Story 风险。
- 每个 AC 至少绑定一个 TC；开发按 TC 执行红灯→绿灯并保存证据。

