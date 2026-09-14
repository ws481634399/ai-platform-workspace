---
story-id: "STORY-003-02-02-02"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S4, S6]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0017
- Story ID: STORY-003-02-02-02
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

商品详情页与详情接口：完整商品信息 + 规格维度/SKU 索引；用户选择规格组合定位唯一 SKU，价格/图片/可售状态随 SKU 联动；下架商品不可售视图，失效组合不可选；为加购（CHG-0018）提供确定的 skuId。

## 2. Scope（范围）

### 2.1 包含

- [S4] 详情聚合接口（Product + SKU 矩阵 + 品牌/分类名 + 图集）、规格选择交互、SKU 联动、下架/失效态、路由 404。
- [S6] 详情 Loading/Error/不存在视图。

### 2.2 不包含

- 可售三态后端聚合（STORY-003-02-03-01，本 Story 消费）；加购写操作（CHG-0018）。

## 3. 业务规则

- 严格区分 productId 与 skuId；未选齐规格前无确定 skuId，加购按钮禁用/提示。
- SKU 索引支持按规格值组合 O(1) 定位；禁用/失效组合禁用可选；切换 SKU 联动其专属图片/价格。
- 下架/不存在商品返回 404 语义；不展示可加入购物车的可操作态。
- SKU 价格整数分。

## 4. 接口与字段规格

- GET /api/mall/products/{id}（商城详情视图）：{ id(string), name, brandName, categoryPath[], mainImageUrl, images:[], detailHtml, skuSpecs:[{ specName, specValues:[] }], skus:[{ skuId(string), specCombo:{颜色:黑,容量:256GB}, priceFen, imageUrl, enabled }] }
- 可售状态批量取自 STORY-003-02-03-01 接口。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-011 | 详情 200 且含图集/品牌/分类路径/介绍/规格维度/SKU 索引 |
| AC-012 | 选规格定位唯一 skuId，切换联动价格/图片/可售状态 |
| AC-013 | 不存在/下架商品直访 → 404/不可售页，无可加购操作态 |
| AC-014 | 失效 SKU 组合不可选，缺货 SKU 有明确标识 |
| AC-018 | 详情加载/错误/不存在视图完整（详情部分） |
| AC-020 | SKU 价格整数分，前端无浮点金额 |
