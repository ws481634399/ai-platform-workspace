---
story-id: "STORY-001-01-04-01"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S9]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0007
- Story ID: STORY-001-01-04-01
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

把 mall-admin 占位登录页升级为可用的管理员认证入口和基础会话状态。

## 2. Scope（范围）

### 2.1 包含

- 登录表单、authApi、auth store、Access/Refresh 状态、提交反馈、基础退出。

### 2.2 不包含

- 动态菜单、权限 store、按钮权限、完整 Refresh single-flight。

## 3. 业务规则

表单必填且提交期间防重复；成功后保存最小会话并跳转 redirect/工作台；失败不残留 Token；退出调用后端并始终清理本地状态。

## 4. 接口与字段规格

authApi.login({username,password})/refresh({refreshToken})/logout()；AuthState{accessToken,refreshToken,accessExpiresAt,status}；组件不直接操作 storage。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 输入正确凭证提交后，页面进入 loading、获得 TokenPair、auth store 变为 authenticated 并跳转目标页。 | |
| AC-002 | 输入错误凭证时显示稳定错误提示，auth store 和 sessionStorage 中不存在半成品 Token。 | |
| AC-003 | 点击退出后调用退出接口并清空本地认证状态，再进入登录页。 | |

