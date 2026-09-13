---
story-id: "STORY-001-02-02-01"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S4]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0008
- Story ID: STORY-001-02-02-01
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

维护可校验、可排序、可投影为前端导航的后台菜单树。

## 2. Scope（范围）

### 2.1 包含

- DIRECTORY/PAGE/ACTION 菜单、父子关系、排序、可见/启停、route path、componentKey。

### 2.2 不包含

- 前端动态渲染、权限资源本身。

## 3. 业务规则

父节点必须存在且不能形成环；ACTION 不可作为父导航；PAGE 必须有 path/componentKey；componentKey 只为受控标识；禁用父节点使后代不可见。

## 4. 接口与字段规格

GET /menus/tree，POST /menus，PUT /menus/{id}，PUT /menus/{id}/status；MenuDto 字段遵循 change-design §5.1。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 创建合法目录和页面后，树接口按 sort/id 稳定返回正确层级。 | |
| AC-002 | 将节点父级设置为自身或后代时返回 409，原树保持无环。 | |
| AC-003 | PAGE 缺少 path/componentKey 或 ACTION 被作为导航父节点时返回 400。 | |

