---
story-id: "STORY-001-02-01-01"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S1]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0008
- Story ID: STORY-001-02-01-01
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

让授权管理员安全查询、创建、修改、启用和禁用后台管理员。

## 2. Scope（范围）

### 2.1 包含

- 分页查询、创建、基本资料修改、启停、防最后超级管理员锁死。

### 2.2 不包含

- 角色 CRUD、角色分配、前端管理页面。

## 3. 业务规则

用户名唯一且创建后不可改；密码强哈希；禁用立即递增 authVersion/permissionVersion；不得禁用或删除最后一个有效超级管理员；所有变更审计。

## 4. 接口与字段规格

GET/POST /api/admin/security/admins，GET/PUT /admins/{id}，PUT /admins/{id}/status；AdminDto 不含密码；冲突 409，防锁死 409。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 有权限调用者可创建并分页查询管理员，响应不含密码或摘要。 | |
| AC-002 | 禁用普通管理员后其 authVersion 与 permissionVersion 递增且后续认证失效。 | |
| AC-003 | 尝试禁用最后一个有效超级管理员时返回 409，数据库状态不变并记录失败审计。 | |

