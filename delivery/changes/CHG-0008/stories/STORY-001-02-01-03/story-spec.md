---
story-id: "STORY-001-02-01-03"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S3]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0008
- Story ID: STORY-001-02-01-03
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

以原子替换语义维护管理员与角色的多对多关系。

## 2. Scope（范围）

### 2.1 包含

- 读取管理员角色、完整替换角色集合、有效性校验、权限版本失效。

### 2.2 不包含

- 角色权限分配、批量导入。

## 3. 业务规则

请求角色 id 去重；不存在或禁用角色使整个请求失败；事务成功后只保留请求集合；影响管理员 permissionVersion 递增；最后超级管理员保护继续生效。

## 4. 接口与字段规格

GET /admins/{id}/roles；PUT /admins/{id}/roles {roleIds:long[]}；成功返回当前角色摘要；无权限 403，非法关系 400/404/409。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 给定有效管理员和启用角色集合，替换分配后数据库关系与请求集合完全一致且无重复。 | |
| AC-002 | 集合中包含不存在或禁用角色时，整个事务失败且原角色关系保持不变。 | |
| AC-003 | 角色集合变化成功后管理员 permissionVersion 递增并触发权限缓存失效。 | |

