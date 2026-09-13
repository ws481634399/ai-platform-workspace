---
affected-repositories: [repo-1]
story-id: "STORY-002-02-02-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0011
- Story ID: STORY-002-02-02-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed

## 1. 模块改动（Module Changes）

### repo-1 mall-product

- `domain.product.Sku`：聚合内实体，字段 id/skuCode/specifications/salePrice(Money)/status/mainImageUrl/specificationHash。
- `domain.product.Money`：值对象 amountInCents（long），构造校验 >= 0。
- `domain.product.Specification`：值对象 name/value。
- `domain.product.SpecificationHash`：值对象，由 specifications 排序键值 SHA-256 生成。
- `domain.product.SkuStatus`：枚举 ENABLED/DISABLED。
- Product 聚合行为：addSku/updateSku/changeSkuPrice/enableSku/disableSku。
- `infrastructure.persistence.product.SkuPO` + SkuMapper + 持久化。
- `application.ProductAdminAppService`：addSku/updateSku/changeSkuStatus。
- `interfaces.rest.admin.ProductAdminController`：/api/admin/products/{id}/skus 子资源，权限 product:sku:*。

### repo-2 mall-admin

- ProductEditView 内 SKU 表单区块：规格键值、价格（元→分转换）、图片、启停。

## 2. 接口契约细化

| 方法 | 路径 | 权限 | 请求 | 响应 |
| --- | --- | --- | --- | --- |
| POST | /api/admin/products/{id}/skus | product:sku:create | SkuCreateRequest | SkuView |
| PUT | /api/admin/products/{id}/skus/{skuId} | product:sku:update | SkuUpdateRequest | SkuView |
| PUT | /api/admin/products/{id}/skus/{skuId}/status | product:sku:disable | {status} | void |

## 3. 数据变更

- Flyway V3：product_sku 表（对齐 requirement-design §3）。
- uk(sku_code, deleted)；uk(product_id, specification_hash, deleted)。

## 4. 错误处理

- sku_code 重复：BusinessException(CONFLICT, "SKU 编码已存在")。
- 规格组合重复：BusinessException(CONFLICT, "SKU 规格组合已存在")。
- 价格 < 0：BusinessException(INVALID_ARGUMENT, "价格不能为负")。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-305 | repo-1 | SKU 实体、规格组合唯一、Money 价格、SKU REST、领域事件 | AC-003,004,005,006,008,013,014,015 | — |

> 跨 Story 依赖：Product 聚合与表由 SPU Story 的 DU-BE-304 落地（requirement-design §6 依赖图：DU-BE-305 depends on DU-BE-304）；本 Story 实现时该前置必须已合入 repo-1，故本表内 depends on 列为 —。

## 6. 测试策略

- 后端：Sku 聚合行为单元测试（hash 唯一、价格非负、启停）；并发创建同 SKU 编码测试（DB uk 兜底）；specification_hash 稳定性测试。
- 前端：SKU 表单组件测试（价格元分转换、规格键值）。
