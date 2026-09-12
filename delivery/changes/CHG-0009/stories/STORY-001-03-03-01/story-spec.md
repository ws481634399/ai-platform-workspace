---
story-id: "STORY-001-03-03-01"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S7]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0009
- Story ID: STORY-001-03-03-01
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

提供可复用、行为一致的按钮/操作权限原语。

## 2. Scope（范围）

### 2.1 包含

- hasPermission、usePermission、v-permission、隐藏/禁用策略、动态权限更新。

### 2.2 不包含

- 后端授权、每页自定义角色判断。

## 3. 业务规则

判断仅使用 Permission Code；默认无权限隐藏；可显式选择 disabled；权限变化立即响应；指令卸载无残留；不能把前端结果当安全结论。

## 4. 接口与字段规格

usePermission().has(code|string[])；v-permission="'product:create'"；可选 modifier disabled。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 具有指定 Permission Code 时按钮保持可用，缺少时按默认策略隐藏。 | |
| AC-002 | disabled 模式下缺权限按钮保留但不可交互且具有可访问性状态。 | |
| AC-003 | store 权限集合变化后 Directive/Composable 结果同步更新，不需刷新页面。 | |

