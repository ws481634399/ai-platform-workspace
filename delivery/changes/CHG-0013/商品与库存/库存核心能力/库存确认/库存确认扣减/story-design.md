---
affected-repositories: [repo-1]
story-id: "STORY-002-04-04-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-04-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed

## 1. 模块改动（Module Changes）

### repo-1 mall-inventory

- `domain.inventory.Inventory`：补充 confirmDeduction(reservation) 领域方法，total -= quantity、locked -= quantity。
- `application.inventory.InventoryApplicationService`：补充 confirmDeduction 方法，状态机校验 + 幂等 + DEDUCT 流水。
- `interfaces.rest.internal.InternalInventoryController`：补充 /api/internal/inventory/confirm。

## 2. 接口契约细化

| 方法 | 路径 | 权限 | 请求 | 响应 |
| --- | --- | --- | --- | --- |
| POST | /api/internal/inventory/confirm | 内部服务 | {reservationId} | {reservationId, skuId, quantity, status} |

## 3. 数据变更

- 复用 V2 inventory_reservation 表，无新增表。

## 4. 错误处理

- reservation 不存在：BusinessException(NOT_FOUND, "预留记录不存在")。
- reservation 非 LOCKED 状态：BusinessException(INVALID_STATE, "预留状态非法")。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-404 | repo-1 | 确认扣减 API、状态机、DEDUCT 流水、幂等 | AC-015,016,017,018 | — |

> 跨 Story 依赖：inventory_reservation 表与锁定能力由 STORY-002-04-03-01 的 DU-BE-403 落地（requirement-design §6 依赖图：DU-BE-404 depends on DU-BE-403）；本 Story 实现时该前置必须已合入，故本表内 depends on 列为 —。

## 6. 测试策略

- 后端：确认扣减成功测试、幂等扣减测试、非 LOCKED 状态拒绝测试。
