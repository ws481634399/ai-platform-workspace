---
story-id: "STORY-001-02-02-03"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S6]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0008
- Story ID: STORY-001-02-02-03
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

原子维护角色与菜单、按钮、API 权限关系并计算受影响管理员。

## 2. Scope（范围）

### 2.1 包含

- 读取角色授权、完整替换 menuIds/permissionIds、关系校验、版本失效。

### 2.2 不包含

- 前端权限编辑 UI、数据权限。

## 3. 业务规则

请求 id 去重；不存在或禁用资源导致整体失败；事务成功后关系完全匹配请求；所有拥有该角色的管理员 permissionVersion 递增；变更审计包含差异摘要。

## 4. 接口与字段规格

GET /roles/{id}/grants；PUT /roles/{id}/grants {menuIds:long[],permissionIds:long[]}；成功返回当前 grant 摘要。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 有效授权集合替换成功后，角色菜单与权限关系和请求完全一致。 | |
| AC-002 | 请求包含不存在或禁用资源时事务回滚，原授权不变。 | |
| AC-003 | 角色授权变化后所有关联管理员 permissionVersion 递增并失效缓存。 | |

