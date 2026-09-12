---
story-id: "STORY-001-03-02-02"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S5]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0009
- Story ID: STORY-001-03-02-02
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

通过编译期组件注册表把后端菜单安全、幂等地转换为可撤销动态路由。

## 2. Scope（范围）

### 2.1 包含

- componentRegistry、菜单转 RouteRecord、命名冲突、add/removeRoute、未知 key。

### 2.2 不包含

- 运行时下载组件、eval、服务端任意 import path。

## 3. 业务规则

只有 registry key 可加载；route name 命名空间且唯一；重复 sync 幂等；权限删除/退出调用 removeRoute；未知 key 跳过并告警。

## 4. 接口与字段规格

componentRegistry:Record<string,RouteComponent>；buildDynamicRoutes(menus)；dynamicRouteRegistry.sync()/clear()。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 已知 componentKey 生成并注册正确路由，页面可通过受控 path 访问。 | |
| AC-002 | 未知 componentKey 不产生路由、不触发动态 import，并记录受控告警。 | |
| AC-003 | 重复同步同一菜单不产生重复路由；clear 后所有动态路由被移除而静态路由保留。 | |

