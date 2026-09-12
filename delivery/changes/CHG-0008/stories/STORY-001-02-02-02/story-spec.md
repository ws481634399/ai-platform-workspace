---
story-id: "STORY-001-02-02-02"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S5]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0008
- Story ID: STORY-001-02-02-02
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

提供统一、稳定的按钮操作与 API 权限资源。

## 2. Scope（范围）

### 2.1 包含

- Permission CRUD、BUTTON/API 类型、编码校验、启停、资源描述。

### 2.2 不包含

- 具体商品/订单权限清单、前端按钮实现。

## 3. 业务规则

code 使用 resource:action 小写规则并唯一；code 创建后不可改变语义；禁用权限不参与授权；API Permission 可记录 method/path pattern 但授权仍按 code。

## 4. 接口与字段规格

GET/POST /permissions，GET/PUT /permissions/{id}，PUT /permissions/{id}/status；PermissionDto{id,code,name,type,httpMethod,pathPattern,status}。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 合法 BUTTON/API 权限可创建查询，非法或重复 code 返回 400/409。 | |
| AC-002 | 禁用权限后授权快照不再包含该 code。 | |
| AC-003 | 修改权限名称或资源描述不改变其稳定 code，尝试修改 code 被拒绝。 | |

