---
story-id: "STORY-001-03-01-03"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S3]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0009
- Story ID: STORY-001-03-01-03
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

在浏览器刷新和权限版本变化后幂等恢复身份、权限与动态路由。

## 2. Scope（范围）

### 2.1 包含

- sessionStorage 恢复、bootstrap 编排、版本刷新、路由差异同步。

### 2.2 不包含

- 离线缓存权限、跨标签页强同步。

## 3. 业务规则

仅持久化最小认证状态；每次页面启动重新 bootstrap；相同版本重复刷新幂等；新版本整体替换并注销旧路由；失败按错误类型处理。

## 4. 接口与字段规格

restoreSession():Promise<void>；refreshPermissions(force?:boolean)；动态路由注册器提供 sync(menus)/clear()。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 刷新浏览器且 Token 有效时，应用重新 bootstrap 并恢复用户、菜单、权限和可访问动态路由。 | |
| AC-002 | 相同权限版本重复刷新不会重复注册路由或产生重复菜单。 | |
| AC-003 | 权限版本更新并移除一项权限后，对应菜单、按钮和动态路由从前端状态移除。 | |

