---
affected-repositories: [repo-1]
story-id: "STORY-002-04-02-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-02-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed

## 1. 模块改动（Module Changes）

### repo-1 mall-inventory

- `domain.inventory.Inventory`：补充 adjust(delta, reason) 领域方法，校验 total + delta >= 0。
- `application.inventory.InventoryApplicationService`：补充 adjust 方法，落 ADJUST 流水。
- `interfaces.rest.admin.InventoryAdminController`：补充调整接口。

### repo-2 mall-admin

- `src/views/inventory/InventoryListView.vue`：补充调整弹窗。
- `src/views/inventory/InventoryLogView.vue`：流水列表页。

## 2. 接口契约细化

| 方法 | 路径 | 权限 | 请求 | 响应 |
| --- | --- | --- | --- | --- |
| POST | /api/admin/inventory/stocks/{skuId}/adjust | inventory:stock:adjust | {delta, reason, businessId?} | InventoryView |
| GET | /api/admin/inventory/logs | inventory:log:list | ?skuId&page&size | PageView<InventoryLogView> |

InventoryLogView: { id, skuId, operationType, quantity, beforeQuantity, afterQuantity, businessId, operator, occurredAt }

## 3. 数据变更

- 复用 V1 inventory_log 表，无新增表。

## 4. 错误处理

- 库存不存在：BusinessException(NOT_FOUND, "库存不存在")。
- 调整后 total < 0：BusinessException(INVALID_ARGUMENT, "库存不足")。
- delta 为 0：BusinessException(INVALID_ARGUMENT, "调整数量不能为 0")。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-402 | repo-1 | 库存调整领域方法、ADJUST 流水、调整 API | AC-008,009,018 | — |

> 跨 Story 依赖：Inventory 聚合与 inventory_stock/inventory_log 表由 STORY-002-04-01-01 的 DU-BE-401 落地（requirement-design §6 依赖图：DU-BE-402 depends on DU-BE-401）；前端库存页面（含调整弹窗与流水页）统一由 STORY-002-04-01-01 的 DU-FE-401 交付，故本表不含前端 DU。

## 6. 测试策略

- 后端：adjust 正负 delta 测试、调整后负库存拒绝测试、ADJUST 流水记录测试。
- 前端：调整弹窗表单校验 + 流水页渲染。
