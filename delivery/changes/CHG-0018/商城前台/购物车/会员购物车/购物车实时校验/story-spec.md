---
story-id: "STORY-003-03-01-02"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S2]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0018
- Story ID: STORY-003-03-01-02
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

购物车读模型实时聚合：读车时批量拉取商品/SKU 最新状态、最新价格（整数分）与库存三态，输出条目级状态标记与选中金额合计；依赖降级；保证购物车价格仅展示、库存仅展示。

## 2. Scope（范围）

### 2.1 包含

- [S2] GET /api/mall/cart 读模型：批量商品/SKU 契约调用、批量可售状态（复用 CHG-0017 内部聚合）、状态标记、调价提示、降级 UNKNOWN、选中金额；mall-cart 跨服务边界审计。

### 2.2 不包含

- 写操作（STORY-003-03-01-01）；游客车合并（STORY-003-03-02-01）。

## 3. 业务规则

- 一次读车对 product/inventory 各最多一次批量调用，禁 N+1；不访问对方数据库。
- 状态枚举 VALID/PRODUCT_OFF_SHELF/SKU_INVALID/NOT_FOUND/PRICE_CHANGED/STOCK_LOW/OUT_OF_STOCK/UNKNOWN；校验不改写 Redis。
- 金额只来自 product，整数分；浏览器传价忽略；合计仅统计 VALID+选中。
- 库存三态阈值与 CHG-0017 完全一致（常量 10）。

## 4. 接口与字段规格

- GET /api/mall/cart → { items: [{ skuId, quantity, selected, productId, name, imageUrl, specText, priceFen, status, stockStatus, createdAt }], selectedTotalFen, selectedCount }
- 依赖：product 内部批量商品/SKU 契约；availability 内部聚合。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-008 | 读车返回图/名/SKU 属性/最新价（整数分）/数量/选择/状态 |
| AC-009 | 下架→PRODUCT_OFF_SHELF；SKU 禁用→SKU_INVALID；删除→NOT_FOUND |
| AC-010 | 改价后 PRICE_CHANGED+latestPriceFen；请求传 price 被忽略 |
| AC-011 | 库存三态阈值与 CHG-0017 同口径（0/1–9/≥10） |
| AC-012 | 依赖故障条目级 UNKNOWN，整车 200 不白屏 |
| AC-013 | 选中金额仅计 VALID+选中条目，整数分 |
| AC-021 | mall-cart 无 product/inventory 库表直查，仅经契约 API |
