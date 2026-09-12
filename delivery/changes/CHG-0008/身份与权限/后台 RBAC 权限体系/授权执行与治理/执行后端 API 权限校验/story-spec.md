---
story-id: "STORY-001-02-03-01"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S7]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0008
- Story ID: STORY-001-02-03-01
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

在业务服务实施默认拒绝的真实 API 权限边界。

## 2. Scope（范围）

### 2.1 包含

- authorities 装载、方法安全、hasAuthority、统一 401/403、绕过前端验证。

### 2.2 不包含

- 资源所有权和数据范围规则。

## 3. 业务规则

受保护方法必须声明 Permission Code；Authentication authorities 只来自有效授权快照/可信 Token；无 authority 返回 403；未知 code 默认拒绝；公开接口显式白名单。

## 4. 接口与字段规格

`@PreAuthorize("hasAuthority('resource:action')")`；Authentication principal 沿用 CHG-0007；错误响应遵循 UnifyResult。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 具备指定 authority 的 ADMIN 调用受保护 API 时请求通过。 | |
| AC-002 | 已认证但缺少 authority 的 ADMIN 直接调用同一 API 时返回 403，业务方法未执行。 | |
| AC-003 | 未认证请求返回 401，未知 Permission Code 或禁用权限不会获得默认放行。 | |

