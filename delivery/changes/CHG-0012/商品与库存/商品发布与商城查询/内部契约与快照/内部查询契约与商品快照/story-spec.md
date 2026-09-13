---
story-id: "STORY-002-03-03-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S5, S6]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 对应行 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0012
- Story ID: STORY-002-03-03-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

在 mall-product 提供面向内部服务（Cart/Order/Inventory/AI）的商品查询契约，通过 /api/internal/products/{id}/skus/{skuId} 返回稳定的 ProductSnapshot DTO（productId/skuId/productName/skuName/skuAttributes/price/image/currentStatus），不暴露 Product 领域实体，为订单商品快照提供标准契约，保证历史订单价格与商品名不随主数据变更漂移。

## 2. Scope（范围）

### 2.1 包含

- 内部 SKU 查询契约（S5）：/api/internal/products/{id}/skus/{skuId}，返回 ProductSnapshot。
- 商品快照契约（S6）：ProductSnapshot DTO 字段固定，可序列化，不含领域实体引用。

### 2.2 不包含

- 上下架动作（STORY-002-03-01-01）。
- 商城列表/详情查询（STORY-002-03-02-01）。
- 订单侧快照持久化（M4）。
- 批量 SKU 查询（本阶段单 SKU，批量留待 M4 按需扩展）。

## 3. 业务规则

- 内部接口返回 ProductSnapshot DTO，字段：productId、skuId、productName、skuName、skuAttributes（规格键值对）、price（分，long）、image（主图 URL）、currentStatus（商品状态）。
- 不返回 Product 领域实体或聚合内部结构。
- 商品不存在或 SKU 不属于该商品 → 404。
- 内部接口走网关服务间认证（不需用户登录，但需内部调用凭证）。
- ProductSnapshot 不可变，订单侧持久化后不受商品主数据变更影响。

## 4. 接口与字段规格

| 方法 | 路径 | 权限 | 请求 | 响应 |
| --- | --- | --- | --- | --- |
| GET | /api/internal/products/{id}/skus/{skuId} | 内部 | - | ProductSnapshotView |

ProductSnapshotView 字段：productId(long)、skuId(long)、productName(string)、skuName(string)、skuAttributes(Map<String,String>)、price(long, 分)、image(string)、currentStatus(string)。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | GET /api/internal/products/{id}/skus/{skuId} 返回 ProductSnapshot 全部字段 |
| AC-002 | ProductSnapshot 不含 Product 领域实体引用（仅 DTO 字段） |
| AC-003 | 商品不存在 → 404；SKU 不属于该商品 → 404 |
| AC-004 | price 字段为分（long），与 SKU salePriceInCents 一致 |
| AC-005 | skuAttributes 为规格键值对 |
