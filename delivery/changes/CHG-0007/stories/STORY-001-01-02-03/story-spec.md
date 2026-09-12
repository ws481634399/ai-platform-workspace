---
story-id: "STORY-001-01-02-03"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S5]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0007
- Story ID: STORY-001-01-02-03
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

让管理员主动退出或账号状态变化后，相关登录会话按确定规则失效。

## 2. Scope（范围）

### 2.1 包含

- 单会话 logout、Refresh family 撤销、管理员 authVersion 变化、禁用后的刷新拒绝。

### 2.2 不包含

- 权限缓存失效、全功能会话管理台。

## 3. 业务规则

退出幂等；撤销后 Refresh 永久不可用；管理员禁用递增 authVersion 并撤销活跃 Refresh Session；Access Token 最迟在短 TTL 或在线版本校验时失效。

## 4. 接口与字段规格

POST /api/admin/auth/logout；可携带当前 Refresh Token/sessionId；成功 204/统一成功响应；重复退出仍成功；会话查询不返回 tokenHash。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 给定有效会话，当主动退出时，会话被撤销且同一 Refresh Token 再刷新返回 401。 | |
| AC-002 | 重复提交同一退出请求时，返回幂等成功且不创建额外会话。 | |
| AC-003 | 管理员被禁用后，新登录和 Refresh 均失败，旧会话版本不能继续换取凭证。 | |

