---
story-id: "STORY-002-04-01-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S1, S2, S7, S8, S9]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 对应行 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-01-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

在 mall-inventory 建立 Inventory 聚合根与库存流水子实体，为 SKU 提供库存初始化与查询能力（单查/批查/后台分页），落 INIT 类型库存流水，并在 mall-admin 提供库存查询页面。这是库存上下文的基础 Story，为后续调整、锁定/释放、确认扣减提供数据底座。

## 2. Scope（范围）

### 2.1 包含

- 库存初始化（S1）：为已存在 SKU 建立库存记录（total/locked=0），校验 SKU 存在、初始 total>=0、不重复初始化。
- 库存查询（S2）：单 SKU 查询、批量 SKU 查询、后台分页查询，返回 total/locked/available（available = total - locked）。
- 库存流水 INIT（S7）：初始化时记录 INIT 流水。
- 后台查询页面（S8）：mall-admin 库存列表页（skuId/total/locked/available）。
- 基础幂等与并发（S9）：初始化幂等（skuId 唯一约束）。

### 2.2 不包含

- 库存调整（STORY-002-04-02-01）。
- 库存锁定/释放（STORY-002-04-03-01）。
- 库存确认扣减（STORY-002-04-04-01）。
- reservation 表与锁定状态机。

## 3. 业务规则

- 初始化：skuId 必须通过 mall-contracts SKU 契约校验存在；初始 total >= 0；同一 skuId 已有库存则拒绝（CONFLICT）。
- 查询：available = total - locked；不变量 total >= 0、locked >= 0。
- 流水：INIT 类型，记录 skuId、quantity（初始 total）、before=0、after=total、occurredAt。
- 权限：inventory:stock:list/detail、inventory:stock:init。

## 4. 接口与字段规格

Inventory 字段：

| 字段                | 类型    | 约束                               |
| ------------------- | ------- | ---------------------------------- |
| id                  | long    | 主键                               |
| skuId               | long    | 唯一，关联 SKU（不复制商品主数据） |
| totalQuantity       | long    | >= 0                               |
| lockedQuantity      | long    | >= 0                               |
| version             | long    | 乐观锁版本                         |
| createdAt/updatedAt | instant | 时间戳                             |

## 5. Story 验收标准

| ID     | 验收标准                                                                           |
| ------ | ---------------------------------------------------------------------------------- |
| AC-001 | 为已存在 SKU 初始化库存（total>=0）→ 成功，total=初始值、locked=0、available=total |
| AC-002 | 为不存在 SKU 初始化 → 拒绝，错误 INVALID_ARGUMENT                                  |
| AC-003 | 重复初始化同一 SKU → 拒绝，错误 CONFLICT                                           |
| AC-004 | 初始库存为负 → 拒绝，错误 INVALID_ARGUMENT                                         |
| AC-005 | 单 SKU 查询返回 total/locked/available；available = total - locked                 |
| AC-006 | 批量 SKU 查询返回各 SKU 库存                                                       |
| AC-007 | 后台分页查询库存列表                                                               |
| AC-018 | 初始化记录 INIT 流水，含 skuId/quantity/before/after                               |
| AC-021 | inventory_stock 表无 product 主数据字段（仅 skuId）                                |
| AC-020 | mall-admin 库存查询页受 inventory:stock:list 权限保护                              |
