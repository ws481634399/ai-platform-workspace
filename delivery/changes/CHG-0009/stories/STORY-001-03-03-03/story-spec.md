---
story-id: "STORY-001-03-03-03"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S9]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0009
- Story ID: STORY-001-03-03-03
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

统一 401/403 用户体验，并在会话结束时完整清理跨模块状态。

## 2. Scope（范围）

### 2.1 包含

- 错误分类、clearSession、动态路由清理、等待队列清理、登录跳转、403 提示。

### 2.2 不包含

- 通用业务错误提示平台、审计查询。

## 3. 业务规则

401 可刷新则交给 Coordinator，否则清理并登录；403 不刷新、不清合法会话；clearSession 幂等且清 Token/user/menus/permissions/routes；日志脱敏。

## 4. 接口与字段规格

handleHttpError(error)；clearSession(reason)；ForbiddenView 提供返回工作台/上一页；登录跳转携带安全 redirect。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 不可刷新 401 触发一次 clearSession，清除全部认证权限和动态路由后进入登录页。 | |
| AC-002 | 403 显示无权限页/提示且保留当前合法登录态，不发起 Refresh。 | |
| AC-003 | 重复调用 clearSession 保持幂等，不残留 Token、用户、菜单、权限、动态路由或等待请求。 | |

