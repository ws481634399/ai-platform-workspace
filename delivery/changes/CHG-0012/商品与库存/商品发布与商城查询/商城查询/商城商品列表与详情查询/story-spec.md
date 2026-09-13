---
story-id: "STORY-002-03-02-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S3, S4]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 对应行 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0012
- Story ID: STORY-002-03-02-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

在 mall-product 提供面向 mall-web 的商城商品列表与详情查询接口，列表只返回 ON_SALE 商品（支持分类/品牌筛选、分页、排序），详情返回 Product 基本信息、分类、品牌、图片、SKU（规格/价格/状态）、商品状态，不伪造库存，使商城消费者可浏览真实可售商品。

## 2. Scope（范围）

### 2.1 包含

- 商城商品列表查询（S3）：/api/mall/products，支持 keyword/categoryId/brandId 筛选、分页、按创建时间倒序，只返回 status=ON_SALE。
- 商城商品详情查询（S4）：/api/mall/products/{id}，返回 Product 信息、分类、品牌、图片、SKU 列表（规格/价格/状态）、商品状态；非 ON_SALE 商品返回 404。

### 2.2 不包含

- 上下架动作（STORY-002-03-01-01）。
- 内部查询契约与商品快照（STORY-002-03-03-01）。
- ES 搜索（M5）。
- 库存实时查询（通过 Inventory Context，本接口不返回库存）。

## 3. 业务规则

- 商城列表硬过滤 status='ON_SALE'，DRAFT/OFF_SALE/DISABLED 不返回。
- 商城详情仅 ON_SALE 商品可查，否则 404。
- 列表排序默认按创建时间倒序。
- 详情不含库存字段；库存由 mall-inventory 提供。
- 商城查询接口公开（不需认证）。

## 4. 接口与字段规格

| 方法 | 路径 | 权限 | 请求 | 响应 |
| --- | --- | --- | --- | --- |
| GET | /api/mall/products | 公开 | ?keyword&categoryId&brandId&page&size | PageView<MallProductListItemView> |
| GET | /api/mall/products/{id} | 公开 | - | MallProductDetailView |

MallProductListItemView 字段：id、productCode、productName、subtitle、categoryId、brandId、mainImageUrl、minPrice、maxPrice、status。
MallProductDetailView 字段：id、productCode、productName、subtitle、description、categoryId、brandId、mainImageUrl、images、attributes、skus（skuId/skuCode/specifications/salePriceInCents/status/mainImageUrl）、status。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 商城列表只返回 ON_SALE 商品（DRAFT/OFF_SALE 不出现） |
| AC-002 | 商城列表支持 categoryId/brandId 筛选与分页 |
| AC-003 | 商城列表按创建时间倒序 |
| AC-004 | ON_SALE 商品详情返回完整 Product+SKU 信息 |
| AC-005 | 非 ON_SALE 商品详情 → 404 |
| AC-006 | 详情响应不含库存字段 |
