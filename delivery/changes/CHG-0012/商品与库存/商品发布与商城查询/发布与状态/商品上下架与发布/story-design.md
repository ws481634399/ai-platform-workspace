---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-002-03-01-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0012
- Story ID: STORY-002-03-01-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed

## 1. 模块改动（Module Changes）

### repo-1 mall-product

- `domain.product.Product`：增加 publish()/unpublish() 行为；publish 内执行上架校验（主图存在、至少一 ENABLED SKU、ENABLED SKU 价格合法、非 DISABLED）；publish 注册 ProductPublishedDomainEvent，unpublish 注册 ProductUnpublishedDomainEvent。
- `domain.product.ProductPublishability`：上架校验策略（可内聚在 Product.publish 内）。
- `domain.product.event.ProductPublishedDomainEvent` / `ProductUnpublishedDomainEvent`：领域事件（record，含 productId）。
- `application.product.ProductApplicationService`：增加 publish(id)/unpublish(id)，复用 ensureCategoryEnabled/ensureBrandEnabled。
- `interfaces.rest.admin.ProductAdminController`：增加 POST /{id}/publish、POST /{id}/unpublish，权限 product:product:publish。

### repo-1 mall-identity

- V5__add_product_publish_permission.sql：插入 product:product:publish 权限码。

### repo-2 mall-admin

- `src/api/product/product.ts`：增加 publishProduct(id)/unpublishProduct(id)。
- `src/views/product/ProductListView.vue`：增加上架/下架操作列与按钮。

## 2. 接口契约细化

| 方法 | 路径 | 权限 | 请求 | 响应 |
| --- | --- | --- | --- | --- |
| POST | /api/admin/products/{id}/publish | product:product:publish | - | void |
| POST | /api/admin/products/{id}/unpublish | product:product:publish | - | void |

上架失败：BusinessException(INVALID_ARGUMENT, "商品不满足上架条件：{原因}")。

## 3. 数据变更

- 无新表；product_spu.status、published_at、unpublished_at 字段已存在（CHG-0011 V2）。
- publish 时写入 published_at=now；unpublish 时写入 unpublished_at=now。

## 4. 错误处理

- 商品不存在：ProductException.notFound。
- 上架校验失败：BusinessException(INVALID_ARGUMENT)，message 含具体原因（如"缺少主图"、"无有效 SKU"、"商品已禁用"）。
- 无权限：403。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-306 | repo-1 | Product 聚合 publish/unpublish + 上架校验 + 领域事件 + 管理端 API + 权限码 | AC-001~009 | CHG-0011 |
| DU-FE-304 | repo-2 | mall-admin 上架/下架按钮 | AC-008,009 | DU-BE-306 |

## 6. 测试策略

- 后端：Product 聚合 publish/unpublish 单元测试（校验逻辑、状态流转、领域事件注册）；ProductAdminApiTest 集成测试（publish/unpublish 端点、权限 403、校验失败）。
- 前端：ProductListView 上架/下架按钮交互测试。
