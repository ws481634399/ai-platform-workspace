---
story-id: "STORY-001-01-01-02"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S2]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0007
- Story ID: STORY-001-01-01-02
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

提供统一管理员登录用例，正确凭证建立认证结果，错误凭证以不可枚举的方式失败。

## 2. Scope（范围）

### 2.1 包含

- 用户名密码登录、参数校验、密码匹配、启用状态校验、登录成功/失败审计事件。

### 2.2 不包含

- Token 具体签发、前端页面、RBAC 权限加载。

## 3. 业务规则

账号不存在与密码错误对外返回相同认证失败语义；禁用账号拒绝登录；成功结果只传递 subjectId/username/authVersion 给 Token 用例；失败不得记录明文凭证。

## 4. 接口与字段规格

POST /api/admin/auth/login；请求 {username:string,password:string}；成功 200 并进入 Token 签发链；参数错误 400，认证失败或禁用 401，触发限流 429。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 给定启用管理员和正确密码，当调用登录接口时，返回成功认证结果并进入双 Token 签发。 | |
| AC-002 | 给定不存在账号或错误密码，当调用登录接口时，均返回相同 401 业务语义且不泄露账号是否存在。 | |
| AC-003 | 给定禁用管理员，当调用登录接口时，返回 401 且不创建 Refresh Session。 | |

