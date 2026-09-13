---
affected-repositories: [repo-1]
story-id: "STORY-002-04-03-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-03-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed

## 1. 模块改动（Module Changes）

### repo-1 mall-inventory

- `domain.inventory.InventoryReservation`：预留实体，字段 id/reservationId/skuId/quantity/status。
- `domain.inventory.ReservationStatus`：枚举 LOCKED/RELEASED/DEDUCTED。
- `domain.inventory.InventoryRepository`：补充 lockStock（SQL 条件更新）、findReservationByReservationId、saveReservation。
- `application.inventory.InventoryApplicationService`：补充 lock/release 方法。
- `interfaces.rest.internal.InternalInventoryController`：/api/internal/inventory/lock、/api/internal/inventory/release。

## 2. 接口契约细化

| 方法 | 路径 | 权限 | 请求 | 响应 |
| --- | --- | --- | --- | --- |
| POST | /api/internal/inventory/lock | 内部服务 | {reservationId, skuId, quantity} | {reservationId, skuId, quantity, status} |
| POST | /api/internal/inventory/release | 内部服务 | {reservationId} | {reservationId, status} |

## 3. 数据变更

- Flyway V2：inventory_reservation 表，reservation_id 唯一（uk）。

## 4. 错误处理

- 库存不存在：BusinessException(NOT_FOUND, "库存不存在")。
- 可用库存不足：BusinessException(STOCK_INSUFFICIENT, "库存不足")。
- reservation 不存在（释放时）：BusinessException(NOT_FOUND, "预留记录不存在")。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-403 | repo-1 | inventory_reservation 表、锁定/释放 API、SQL 条件更新、幂等、LOCK/RELEASE 流水 | AC-010,011,012,013,014,018,019 | — |

> 跨 Story 依赖：Inventory 聚合与 inventory_stock 表由 STORY-002-04-01-01 的 DU-BE-401 落地（requirement-design §6 依赖图：DU-BE-403 depends on DU-BE-401）；本 Story 实现时该前置必须已合入，故本表内 depends on 列为 —。

## 6. 测试策略

- 后端：锁定成功/失败测试、幂等锁定测试、释放成功/幂等测试、并发锁定测试（多线程）。
