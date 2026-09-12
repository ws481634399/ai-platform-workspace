---
story-id: "STORY-001-01-02-02"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S4]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0007
- Story ID: STORY-001-01-02-02
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

使用合法 Refresh Token 原子地获得新 TokenPair，并防止过期、撤销和重放。

## 2. Scope（范围）

### 2.1 包含

- Refresh 校验、行锁/并发控制、旧 Token used 标记、新 Session、family 重放撤销。

### 2.2 不包含

- 前端 single-flight、管理员状态管理。

## 3. 业务规则

一次 Refresh 只成功一次；旧 Token 轮换后不可复用；发现旧 Token 重放时撤销同一 family；过期、撤销、主体版本不匹配均返回 401。

## 4. 接口与字段规格

POST /api/admin/auth/refresh；请求 {refreshToken} 或安全 Cookie；成功返回新 TokenPair；401 表示必须重新登录；事务内锁定旧 session。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 给定有效 Refresh Token，当首次刷新时，旧会话被标记已轮换并返回全新 TokenPair。 | |
| AC-002 | 给定已轮换、撤销或过期 Refresh Token，当刷新时，返回 401 且不生成新会话。 | |
| AC-003 | 两个并发请求使用同一 Refresh Token 时，最多一个成功，另一个按重放策略失败并留下可审计结果。 | |

