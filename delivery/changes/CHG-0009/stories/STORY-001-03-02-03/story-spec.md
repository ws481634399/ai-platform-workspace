---
story-id: "STORY-001-03-02-03"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S6]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0009
- Story ID: STORY-001-03-02-03
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

用返回值式路由守卫稳定区分未认证、无权限和未知页面。

## 2. Scope（范围）

### 2.1 包含

- 公开路由、redirect 保留、bootstrap、permission meta、403/404。

### 2.2 不包含

- 后端 API 授权、页面内容级数据权限。

## 3. 业务规则

公开路由无需 Token；无 Token 访问受保护页跳 login?redirect；有 Token 先 bootstrap；缺权限去 403；未匹配路由去 404；禁止 next() 回调签名。

## 4. 接口与字段规格

route meta {requiresAuth:boolean,permission?:string,title:string}；guard 返回 true/RouteLocationRaw/false。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 未登录访问受保护路由时跳转登录页并保留原目标 redirect。 | |
| AC-002 | 已登录但缺少 route permission 时进入 403，认证状态不被清除。 | |
| AC-003 | 访问未知路径时进入 404；守卫使用返回值式签名且浏览器刷新行为一致。 | |

