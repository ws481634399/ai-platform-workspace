---
affected-repositories: [repo-1]
story-id: "STORY-002-03-03-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0012
- Story ID: STORY-002-03-03-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed

## 1. 模块改动（Module Changes）

### repo-1 mall-product

- `interfaces.rest.internal.InternalProductController`：新增，路径 /api/internal/products/{id}/skus/{skuId}，内部服务调用。
  - GET /{id}/skus/{skuId}：返回 ProductSnapshot DTO。
- `interfaces.rest.internal.dto.ProductSnapshotView`：record，字段 productId/skuId/productName/skuName/skuAttributes(Map)/price(long,分)/image/currentStatus。
- `application.product.ProductQueryService`（或复用 ProductApplicationService）：getSkuSnapshot(productId, skuId)，查找 Product 与对应 SKU，组装 ProductSnapshot。

## 2. 接口契约细化

| 方法 | 路径 | 权限 | 请求 | 响应 |
| --- | --- | --- | --- | --- |
| GET | /api/internal/products/{id}/skus/{skuId} | 内部 | - | ProductSnapshotView |

ProductSnapshotView 字段：
- productId: long
- skuId: long
- productName: string
- skuName: string（由规格拼接，如 "颜色:黑 容量:128G"）
- skuAttributes: Map<String,String>
- price: long（分）
- image: string（SKU 主图，为空则取商品主图）
- currentStatus: string（商品状态）

## 3. 数据变更

- 无新表；复用 product_spu/product_sku。

## 4. 错误处理

- 商品不存在 → 404。
- SKU 不存在或不属于该商品 → 404。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-308 | repo-1 | InternalProductController + ProductSnapshot DTO | AC-001~005 | — |

> 跨 Story 依赖：Product/SKU 聚合由发布 Story 的 DU-BE-306 落地（requirement-design §6 依赖图：DU-BE-308 depends on DU-BE-306）；本 Story 实现时该前置必须已合入 repo-1，故本表内 depends on 列为 —。

## 6. 测试策略

- 后端：InternalProductApiTest 集成测试（返回完整 ProductSnapshot、不含领域实体、404 场景、price 为分、skuAttributes 正确）。
