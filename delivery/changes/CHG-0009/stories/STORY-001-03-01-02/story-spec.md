---
story-id: "STORY-001-03-01-02"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S2]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0009
- Story ID: STORY-001-03-01-02
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

把后端菜单树、Permission Codes 和权限版本加载成唯一前端权限事实投影。

## 2. Scope（范围）

### 2.1 包含

- DTO 校验、菜单树、permissions Set、版本、共享加载 Promise。

### 2.2 不包含

- 具体菜单渲染、路由注册、按钮 DOM 行为。

## 3. 业务规则

权限去重；未知菜单类型/非法节点拒绝或隔离；不按角色名补权限；同一 bootstrap 并发调用共享 Promise；成功后原子替换。

## 4. 接口与字段规格

SessionBootstrap{user,menus:MenuNode[],permissions:string[],permissionVersion:number}；usePermissionStore.bootstrap()/hasPermission().

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 合法 bootstrap 响应被原子写入 store，Permission Codes 去重且 hasPermission 结果正确。 | |
| AC-002 | 两个并发 bootstrap 调用只产生一个 HTTP 请求并共享同一结果。 | |
| AC-003 | 响应包含非法菜单节点时不注册未知能力并进入受控错误/告警路径。 | |

