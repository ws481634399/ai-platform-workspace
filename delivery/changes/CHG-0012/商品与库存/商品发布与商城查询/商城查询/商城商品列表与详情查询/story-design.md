---
affected-repositories: [repo-1]
story-id: "STORY-002-03-02-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0012
- Story ID: STORY-002-03-02-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed

## 1. 模块改动（Module Changes）

### repo-1 mall-product

- `interfaces.rest.mall.MallProductController`：新增，路径 /api/mall/products，公开（不需认证）。
  - GET /：商城列表，硬过滤 status=ON_SALE，支持 keyword/categoryId/brandId/page/size，按 createdAt 倒序。
  - GET /{id}：商城详情，仅 ON_SALE 商品可查（否则 404），返回 Product+SKU 信息，不含库存。
- `domain.product.ProductRepository`：增加 mallPage(MallProductPageQuery) 方法（或复用 page 但强制 status=ON_SALE）。
- `infrastructure.persistence.product.ProductRepositoryImpl`：实现 mallPage，硬过滤 status='ON_SALE'。

## 2. 接口契约细化

| 方法 | 路径 | 权限 | 请求 | 响应 |
| --- | --- | --- | --- | --- |
| GET | /api/mall/products | 公开 | ?keyword&categoryId&brandId&page&size | PageView<MallProductListItemView> |
| GET | /api/mall/products/{id} | 公开 | - | MallProductDetailView |

MallProductListItemView：id、productCode、productName、subtitle、categoryId、brandId、mainImageUrl、minPrice、maxPrice、status。
MallProductDetailView：id、productCode、productName、subtitle、description、categoryId、brandId、mainImageUrl、images、attributes、skus（skuId/skuCode/specifications/salePriceInCents/status/mainImageUrl）、status。

## 3. 数据变更

- 无新表；复用 product_spu/product_image/product_attribute/product_sku 表。
- 列表查询需 category_id/brand_id/status 索引（已由 V2 建表时的索引覆盖）。

## 4. 错误处理

- 非 ON_SALE 商品详情 → 404（ProductException.notFound 或直接返回 404）。
- 参数非法 → 400。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-307 | repo-1 | MallProductController 商城列表/详情（ON_SALE 过滤） | AC-001~006 | — |

> 跨 Story 依赖：Product 聚合发布行为由发布 Story 的 DU-BE-306 落地（requirement-design §6 依赖图：DU-BE-307 depends on DU-BE-306）；本 Story 实现时该前置必须已合入 repo-1，故本表内 depends on 列为 —。

## 6. 测试策略

- 后端：MallProductApiTest 集成测试（列表只返回 ON_SALE、筛选/分页、详情非 ON_SALE 返回 404、详情不含库存字段）。
