---
affected-repositories: [repo-1]
story-id: "STORY-003-02-03-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0017
- Story ID: STORY-003-02-03-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed
- 需要 Migration: no
- 数据变更概要: 无（只读 inventory_stock）

## 1. 模块改动（Module Changes）

### repo-1 mall-inventory

- `application.inventory.InventoryApplicationService`：新增 `batchAvailability(List<Long> skuIds)`，返回 skuId→available(total-locked)；无记录行按 0 返回（不报错）；单次 ≤100 校验。
- `infrastructure.persistence`：InventoryMapper 新增 `selectAvailableBySkuIds`（SELECT sku_id, total_quantity - locked_quantity ... WHERE sku_id IN）；一次查询。
- `interfaces.rest.internal.InternalInventoryController`：新增 POST /api/internal/inventory/availability（InternalIdentityFilter 凭证保护）；DTO AvailabilityRequest{List<Long> skuIds}、AvailabilityItem{skuId,availableQuantity}。

### repo-1 mall-product

- `domain.catalog.AvailabilityStatus` 枚举：IN_STOCK/LOW_STOCK/OUT_OF_STOCK/UNKNOWN；`AvailabilityThresholds` 常量 `LOW_STOCK_UPPER_BOUND = 9`（available 1..9 LOW_STOCK，≥10 IN_STOCK）。
- `infrastructure.client.InventoryAvailabilityClient`：RestClient 直连 8106 + X-Internal-Token；单次 POST 批量；异常上抛可识别的 AvailabilityDependencyException。
- `application.catalog.SkuAvailabilityApplicationService`：校验 ≤100；调 client；映射三态；依赖异常时整体降级为逐 SKU UNKNOWN（成功部分仍返回真实态——partial 降级）。
- `interfaces.rest.mall.MallSkuAvailabilityController`：POST /api/mall/skus/availability（匿名只读语义），入参 {skuIds:string[]}，出参 {items:{skuId:string,stockStatus}[]}；为购物车预留同一应用服务（CHG-0018 内部复用，不另建聚合）。

### repo-1 mall-gateway

- 白名单 /api/mall/skus/** 已随分类品牌 Story 写入；本 Story 验证生效。

## 2. 接口契约细化

| 方法 | 路径 | 鉴权 | 请求 | 响应/错误 |
| --- | --- | --- | --- | --- |
| POST | /api/internal/inventory/availability | X-Internal-Token | {skuIds:long[](1..100)} | {items:{skuId:long,availableQuantity:int}[]}；401 凭证错；400 超量 |
| POST | /api/mall/skus/availability | 匿名 | {skuIds:string[](1..100)} | {items:{skuId:string,stockStatus}[]}，stockStatus ∈ IN_STOCK/LOW_STOCK/OUT_OF_STOCK/UNKNOWN；400 空/超量 |
- 公开响应不含任何精确库存数字。

## 3. 数据变更

- 无。

## 4. 错误处理

- 空数组 / >100 / 含非法 ID → 400 AVAILABILITY_BATCH_INVALID。
- inventory 超时/5xx/连接拒绝：catch → UNKNOWN（整体）；部分成功时已得数据保留真实态，缺失 SKU 标 UNKNOWN；记录 WARN（含 traceId、skuId 数量）。
- inventory 对不存在 skuId 返 available=0（由 product 侧后续经商品契约区分 NOT_FOUND，本 Story 三态即 OUT_OF_STOCK，语义满足展示）。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-705 | repo-1 | inventory internal availability（一次批量 SQL）+ product 三态聚合公开端点、阈值常量与 UNKNOWN 降级 | AC-015,016,017 | — |

> 跨 Change 依赖：X-Internal-Token 与 internal denyAll 由 CHG-0015 DU-BE-501 提供。

## 6. 测试策略

- inventory：批量 SQL 单测/集成（含无记录 SKU、total-locked 边界 0/9/10）；凭证缺失 401；≤100 边界。
- product：阈值映射参数化（0→OUT、1/9→LOW、10→IN）；mock inventory 抛异常→UNKNOWN 且 HTTP 200；partial 降级；一次批量调用断言（RestClient 调用次数=1）；响应不含数字断言（JSON 字段白名单）。
