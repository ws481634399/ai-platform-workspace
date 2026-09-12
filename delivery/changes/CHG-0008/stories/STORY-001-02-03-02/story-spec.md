---
story-id: "STORY-001-02-03-02"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S8]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0008
- Story ID: STORY-001-02-03-02
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

通过版本化 Redis 快照提高授权读取效率，同时保持数据库事实源和失败安全。

## 2. Scope（范围）

### 2.1 包含

- AuthorizationSnapshot 缓存、permissionVersion key、TTL、回源、提交后失效。

### 2.2 不包含

- 跨地域缓存、消息总线失效。

## 3. 业务规则

键为 authz:{adminId}:{version}；TTL 默认 15 分钟；miss 回源数据库；Redis 不可用回源且不得放行空权限；关系事务提交后递增版本并删除旧键。

## 4. 接口与字段规格

PermissionCache.get/put/evict(adminId,version)；snapshot={permissions,menuIds,generatedAt}，不含密码或 Refresh 数据。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 首次查询回源并写缓存，后续同版本查询命中且权限集合一致。 | |
| AC-002 | 管理员或授权关系变更后版本递增，下一次查询不会使用旧版本快照。 | |
| AC-003 | Redis 不可用时系统从数据库计算正确权限；数据库也失败时请求失败而不是默认放行。 | |

