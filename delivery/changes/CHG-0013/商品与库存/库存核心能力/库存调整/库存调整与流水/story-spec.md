---
story-id: "STORY-002-04-02-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S3, S7, S8]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 对应行 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-02-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

在库存初始化与查询基础上，提供库存调整能力（盘点/人工修正），强制落 ADJUST 流水（before/after/delta/reason/operator/traceId/businessId），不允许裸 UPDATE；并在 mall-admin 提供库存调整入口与流水查看页面。

## 2. Scope（范围）

### 2.1 包含

- 库存调整（S3）：按 delta 调整 total，正 delta 增加、负 delta 减少；调整后 total >= 0。
- ADJUST 流水（S7）：记录 before/after/delta/reason/operator/traceId/businessId。
- 后台调整与流水页（S8）：mall-admin 库存调整表单 + 流水列表页。

### 2.2 不包含

- 库存初始化/查询（STORY-002-04-01-01，已提供底座）。
- 锁定/释放/确认扣减（STORY-002-04-03/04）。

## 3. 业务规则

- 调整：必须基于已存在库存记录；delta 可正可负；调整后 total >= 0，否则拒绝。
- 流水：ADJUST 类型，记录 before（调整前 total）、after（调整后 total）、delta、reason、operator（当前管理员）、traceId、businessId（调整单号，可选）。
- 不允许裸 UPDATE：调整必须经过领域方法并落流水。
- 权限：inventory:stock:adjust、inventory:log:list。

## 4. 接口与字段规格

调整请求：

| 字段 | 类型 | 约束 |
| --- | --- | --- |
| skuId | long | 必填，库存已存在 |
| delta | long | 非零，可正可负 |
| reason | string | 必填，调整原因 |
| businessId | string | 可选，调整单号 |

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-008 | 调整库存（正/负 delta）→ total 更新正确，流水记录 before/after/delta/reason/operator |
| AC-009 | 调整导致 total < 0 → 拒绝，错误 INVALID_ARGUMENT |
| AC-018 | 调整记录 ADJUST 流水，含 skuId/quantity/before/after/reason |
| AC-020 | mall-admin 库存调整与流水查看受 inventory:stock:adjust / inventory:log:list 权限保护 |
