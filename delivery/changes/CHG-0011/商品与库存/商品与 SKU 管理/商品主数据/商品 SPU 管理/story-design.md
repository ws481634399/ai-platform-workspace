---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-002-02-01-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0011
- Story ID: STORY-002-02-01-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed

## 1. 模块改动（Module Changes）

### repo-1 mall-product

- `domain.product.Product`：聚合根，字段 id/productCode/productName/subtitle/description/categoryId/brandId/status/images/attributes/skus；领域行为 create/updateBasicInfo/changeCategory/changeBrand/changeStatus/setMainImage。
- `domain.product.ProductImage`：值对象/实体（imageId/objectKey/imageUrl/imageType/sortOrder/mainFlag）。
- `domain.product.ProductAttribute`：值对象（attributeName/attributeValue/sortOrder）。
- `domain.product.ProductStatus`：枚举 DRAFT/ON_SALE/OFF_SALE/DISABLED。
- `domain.product.ProductRepository`：端口 findById/findByCode/save。
- `infrastructure.persistence.product`：ProductPO/ProductImagePO/ProductAttributePO + Mapper + Repository 实现。
- `application.ProductAdminAppService`：create/update/changeStatus/get/page。
- `interfaces.rest.admin.ProductAdminController`：/api/admin/products，权限 product:product:*。

### repo-1 mall-identity

- V3__add_product_permissions.sql：product:product:* 权限码 + 商品菜单。

### repo-2 mall-admin

- `src/views/product/ProductListView.vue`：商品列表。
- `src/views/product/ProductEditView.vue`：创建/编辑页（基本信息+图片+属性区块）。
- `src/api/product/product.ts`：API 封装。

## 2. 接口契约细化

| 方法 | 路径 | 权限 | 请求 | 响应 |
| --- | --- | --- | --- | --- |
| GET | /api/admin/products | product:product:list | ?keyword&categoryId&brandId&status&page&size | PageView<ProductListItemView> |
| GET | /api/admin/products/{id} | product:product:detail | - | ProductDetailView（含 images/attributes/skus） |
| POST | /api/admin/products | product:product:create | ProductCreateRequest | ProductDetailView |
| PUT | /api/admin/products/{id} | product:product:update | ProductUpdateRequest | ProductDetailView |
| PUT | /api/admin/products/{id}/status | product:product:disable | {status} | void |

## 3. 数据变更

- Flyway V2：product_spu、product_image、product_attribute 三表（对齐 requirement-design §3）。
- product_spu.category_id → product_category.id；brand_id → product_brand.id。
- product_image.main_flag 唯一约束：应用层保证一商品一主图。

## 4. 错误处理

- 分类/品牌不存在或非启用：BusinessException(INVALID_ARGUMENT, "分类或品牌无效")。
- product_code 重复：BusinessException(CONFLICT, "商品编码已存在")。
- 无权限：403（Spring Security）。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-304 | repo-1 | 商品权限码（identity V3）+ Product 聚合、SPU REST、图片/属性、状态、领域事件 | AC-001,002,007,008,009,010,012,013,014,015 | CHG-0010 |
| DU-FE-303 | repo-2 | 商品列表/创建/编辑/查看页（SPU 区块） | AC-011,013 | DU-BE-304 |

## 6. 测试策略

- 后端：Product 聚合不变量单元测试（主图唯一、状态流转、引用合法）；ProductAdminAppService 集成测试（H2，ApiTestSecurityConfig 复用）；权限 403 测试。
- 前端：vitest 组件测试 + vue-tsc + eslint + build。
