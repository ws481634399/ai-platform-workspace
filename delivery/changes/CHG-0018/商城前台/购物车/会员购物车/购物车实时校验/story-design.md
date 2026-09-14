---
affected-repositories: [repo-1]
story-id: "STORY-003-03-01-02"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0018
- Story ID: STORY-003-03-01-02
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed
- 需要 Migration: no
- 数据变更概要: 无

## 1. 模块改动（Module Changes）

### repo-1 mall-cart

- `infrastructure.client.InventoryAvailabilityClient`：复用 CHG-0017 契约 POST /api/internal/inventory/availability（X-Internal-Token，≤100/批；车 >100 时按 100 分片并发/顺序多批——上限 100 条目下仅一批）。
- `application.cart.CartViewAssembler`：
  1. HGETALL 取全部条目（空车直接空响应）；
  2. 一次 product sku/batch；一次 inventory availability（并行无依赖，CompletableFuture/顺序均可，M3 顺序即可）；
  3. 状态映射：快照缺失→NOT_FOUND；productStatus≠ON_SALE→PRODUCT_OFF_SHELF；skuStatus≠ENABLED→SKU_INVALID；priceFenAtAdded≠priceFen→PRICE_CHANGED（叠加在 VALID 上，itemStatus 以失效优先、价格次之）；
  4. stockStatus 阈值映射复用 1..9/≥10/=0 口径（cart 侧持同一常量值，来源于 product 三态内部语义——inventory 给数字，cart 本地常量映射并注释与 CHG-0017 SSOT 对齐）；
  5. 依赖故障：对应条目 UNKNOWN（product 整体失败则所有条目 UNKNOWN；inventory 失败仅库存态 UNKNOWN、商品态照常）；
  6. selectedTotalFen = Σ(priceFen × quantity)，仅 itemStatus=VALID 且 selected 且 stockStatus≠OUT_OF_STOCK；selectedCount。
- GET /api/mall/cart 替换为读模型 CartLine 视图；不改写 Redis。
- CartLine dto（@StringId skuId/productId；金额 number 整数分）。

## 2. 接口契约细化

| 方法 | 路径 | 响应 |
| --- | --- | --- |
| GET | /api/mall/cart | {items:CartLine[], selectedTotalFen:number, selectedCount:number}（恒 200，含降级条目） |

CartLine：{skuId,quantity,selected,productId,productName,skuName,specs:{},imageUrl,priceFen,priceFenAtAdded,itemStatus,stockStatus,createdAt,updatedAt}

## 3. 数据变更

- 无。

## 4. 错误处理

- 空车：{items:[],selectedTotalFen:0,selectedCount:0}。
- product 故障：整车条目 itemStatus=UNKNOWN，HTTP 200；inventory 故障：stockStatus=UNKNOWN，金额按"未知库存不参与合计"口径（等同缺货排除）。
- 拼装失败边界：快照字段缺失防御（imageUrl null 由前端占位），绝不抛 5xx。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-802 | repo-1 | 读车聚合（一次商品+一次库存）、双状态/调价/降级/金额 | AC-008,009,010,011,012,013,021 | — |

> 跨 Story 依赖：DU-BE-801（Redis 车写模型/ProductSkuClient/安全配置）；跨 Change：CHG-0017 DU-BE-705（inventory availability 内部端点与阈值）、CHG-0015 DU-BE-501（内部凭证）。

## 6. 测试策略

- assembler 表驱动测试：双状态优先级矩阵（下架/禁用/删除/调价/库存三态/UNKNOWN×依赖故障组合）；金额合计排除规则（失效、缺货、未选中）；空车。
- 调用次数断言：一次读车 product 一次、inventory 一次（mock 客户端计数）。
- 边界：priceFenAtAdded 缺失（老数据/游客合并条目无快照——合并条目写入时补快照，测试补此路径）按 PRICE_CHANGED 不当作失效。
- 边界审计：grep 断言 cart 仓无 product/inventory Mapper/JDBC 依赖，仅 RestClient。
