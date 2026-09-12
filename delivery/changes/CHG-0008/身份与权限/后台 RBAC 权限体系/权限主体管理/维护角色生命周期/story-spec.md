---
story-id: "STORY-001-02-01-02"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S2]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0008
- Story ID: STORY-001-02-01-02
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

维护编码稳定、可启停的后台角色。

## 2. Scope（范围）

### 2.1 包含

- 角色分页查询、创建、名称描述修改、启停、唯一编码。

### 2.2 不包含

- 管理员角色分配、权限分配、角色管理 UI。

## 3. 业务规则

角色 code 匹配大写规则且全局唯一；code 创建后不可改；禁用角色不再产生有效授权；内置 SUPER_ADMIN 不可删除。

## 4. 接口与字段规格

GET/POST /api/admin/security/roles，GET/PUT /roles/{id}，PUT /roles/{id}/status；RoleDto{id,code,name,description,status,builtin}。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 合法角色可创建、查询和修改名称描述，重复或非法 code 返回 400/409。 | |
| AC-002 | 禁用角色后，该角色不再出现在有效授权计算中。 | |
| AC-003 | 尝试删除或修改内置 SUPER_ADMIN 的稳定 code 时被拒绝且状态不变。 | |

