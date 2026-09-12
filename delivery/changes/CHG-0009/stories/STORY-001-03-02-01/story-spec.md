---
story-id: "STORY-001-03-02-01"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S4]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0009
- Story ID: STORY-001-03-02-01
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

根据权限 store 的有效菜单树渲染稳定、角色差异化的后台侧边栏。

## 2. Scope（范围）

### 2.1 包含

- 目录/页面递归渲染、排序、图标白名单、折叠、当前路由高亮。

### 2.2 不包含

- 菜单管理页面、任意 HTML/icon 执行。

## 3. 业务规则

只渲染 visible+enabled 投影；目录无可见后代则隐藏；按 sort/id 稳定排序；标题文本转义；图标使用本地注册表。

## 4. 接口与字段规格

DynamicMenu.vue 接收 MenuNode[]；导航目标使用已注册 route name/path，不拼接组件路径。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 两个不同菜单集合登录时，侧边栏分别只显示各自可见目录和页面。 | |
| AC-002 | 同级节点按 sort 后 id 稳定排序，空目录不显示。 | |
| AC-003 | 后端返回未知图标或含 HTML 的标题时，不执行任意内容并安全回退。 | |

