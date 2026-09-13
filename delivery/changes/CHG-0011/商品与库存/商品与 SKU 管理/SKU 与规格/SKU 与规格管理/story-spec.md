---
story-id: "STORY-002-02-02-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S5, S8, S9]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 对应行 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0011
- Story ID: STORY-002-02-02-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

在 Product 聚合内建立 SKU 实体，支持 SKU 编码、规格组合、销售价（精确金额，分）、SKU 图片与启停，提供管理端 SKU 增/改/启停接口与前端 SKU 表单，保证 SKU 编码全局唯一与同商品规格组合唯一，为订单/库存提供精确的 SKU 价格与规格契约。

## 2. Scope（范围）

### 2.1 包含

- SKU 管理（S5）：新增/编辑 SKU，含 SKU Code、规格组合、销售价（分）、主图、启停。
- SKU 表单（S8）：前端 SKU 规格/价格/图片/启停编辑区块。
- RBAC（S9）：product:sku:* 权限码。

### 2.2 不包含

- Product 基本信息/图片/属性（STORY-002-02-01-01）。
- 库存数量与锁定（CHG-0013）。
- SKU 物理删除（仅启停）。

## 3. 业务规则

- SKU Code 全局唯一（existsBySkuCode + uk）。
- 同 Product 内规格组合唯一（specification_hash + uk）。
- 价格：amountInCents（long）>= 0，禁止浮点。
- SKU 状态：ENABLED/DISABLED，独立启停。
- 领域事件：SkuAdded/Updated/PriceChanged/Enabled/Disabled。
- 权限：product:sku:create/update/disable。

## 4. 接口与字段规格

Sku 字段：

| 字段 | 类型 | 约束 |
| --- | --- | --- |
| id | long | 主键 |
| productId | long | 外键 product_spu |
| skuCode | string(64) | 全局唯一 |
| specificationJson | json | 规格键值对 |
| specificationHash | string(128) | 排序键值 SHA-256 |
| salePrice | long | 分，>= 0 |
| mainImageUrl | string(512) | 可空 |
| status | enum | ENABLED/DISABLED |

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-003 | 一个 Product 可创建一个或多个 SKU |
| AC-004 | SKU Code 全局唯一，重复拒绝且无落库 |
| AC-005 | 销售价为分（long）且 >= 0，无浮点金额字段 |
| AC-006 | 同 Product 内规格组合唯一，重复拒绝 |
| AC-008 | SKU 价格/图片/状态修改后查询一致 |
| AC-013 | 无 product:sku:* 权限 → 403；有权限 → 成功 |
| AC-014 | SKU 增/改/价格变更/启停注册领域事件 |
| AC-015 | SKU 可独立 ENABLED/DISABLED |
