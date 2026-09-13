---
story-id: "STORY-002-02-01-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S1, S2, S3, S4, S6, S7, S8, S9]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 对应行 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0011
- Story ID: STORY-002-02-01-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

在 mall-product 建立 Product（SPU）聚合根，提供商品创建、编辑、分页查询、详情、禁用/启用能力，覆盖商品基本信息、分类/品牌合法绑定、商品图片（主图唯一+图集）、商品属性与状态生命周期（创建即 DRAFT），并在 mall-admin 提供商品列表/创建/编辑/查看页面骨架，为 SKU 管理与商品发布提供可信商品主数据。

## 2. Scope（范围）

### 2.1 包含

- 创建 Product（S1）：名称、副标题、描述、分类、品牌、主图、图集、商品属性；创建后状态 DRAFT。
- 编辑 Product（S2）：基本信息、图片、属性修改；分类/品牌变更需引用合法。
- 查询 Product（S3）：分页列表（keyword/categoryId/brandId/status）与详情。
- 商品状态（S4）：DRAFT/ON_SALE/OFF_SALE/DISABLED 字段；本阶段仅创建 DRAFT 与禁用/启用。
- 商品图片（S6）：主图唯一、图集多图，存 object_key+image_url。
- 商品属性（S7）：非规格键值对可维护。
- 后台页面骨架（S8）：商品列表/详情/创建编辑页基本信息区块。
- RBAC（S9）：product:product:* 权限码。

### 2.2 不包含

- SKU 实体与规格/价格/启停（STORY-002-02-02-01）。
- 正式发布/上下架动作（REQ-M2-003）。
- 库存（CHG-0013）。
- 商品物理删除（仅禁用）。

## 3. 业务规则

- 引用合法：category_id/brand_id 必须存在且启用，否则拒绝。
- 主图唯一：一个 Product 仅一张 main_flag=1 图片。
- product_code 全局唯一。
- 状态：创建即 DRAFT；DISABLED 商品不可被发布（发布归 REQ-M2-003）。
- 领域事件：Product 创建/更新注册 ProductCreated/Updated 事件。
- 权限：product:product:list/detail/create/update/disable。

## 4. 接口与字段规格

Product 字段：

| 字段 | 类型 | 约束 |
| --- | --- | --- |
| id | long | 主键 |
| productCode | string(64) | 全局唯一 |
| productName | string(255) | 必填 |
| subtitle | string(255) | 可空 |
| description | text | 可空 |
| categoryId | long | 必填，存在且启用 |
| brandId | long | 必填，存在且启用 |
| status | enum | DRAFT/ON_SALE/OFF_SALE/DISABLED |
| mainImageUrl | string(512) | 可空 |
| images | list | 图集，含 objectKey/imageUrl/mainFlag/sortOrder |
| attributes | list | 商品属性键值对 |

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 提交合法 Product → 创建成功，状态 DRAFT |
| AC-002 | 分类/品牌不存在或非启用 → 拒绝 |
| AC-007 | 一个 Product 仅一张主图；图集可多张 |
| AC-008 | 修改基本信息/属性/图片后查询返回最新值 |
| AC-009 | product_spu 无 stock 字段 |
| AC-010 | 创建商品状态 DRAFT，状态字段支持四态 |
| AC-012 | 商品属性键值对可增删改并保存 |
| AC-013 | 无 product:product:* 权限直调 → 403；有权限 → 成功 |
| AC-014 | Product 创建/更新注册领域事件 |
| AC-011 | mall-admin 商品页可完成列表、创建、编辑、查看（含 SKU 区块由 SKU Story 补充） |
| AC-015 | DISABLED 商品不可被发布 |
