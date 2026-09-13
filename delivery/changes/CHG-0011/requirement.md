---
id: "REQ-M2-002"
name: "商品与 SKU 管理"
content: "按 docs/需求/M2/M2.md 中 REQ-M2-002 建立商品 SPU 与 SKU 核心模型，实现后台商品完整维护能力。"
source: requirement-doc
created-at: "2026-09-13T02:40:00.000Z"
---

# Requirement

> 原始需求全文归档于 `references/M2.md`，本文件记录本 Change 的输入边界。

## 需求描述

按 `docs/需求/M2/M2.md` 中 `REQ-M2-002 商品与 SKU 管理` 执行完整 SDD。在 mall-product 建立 Product（SPU）与 SKU 核心模型，覆盖商品名称、分类、品牌、描述、图片、商品属性、SKU、SKU 属性、SKU 编码、SKU 图片与 SKU 价格；mall-admin 提供商品列表、创建、编辑、分类/品牌选择、图片、SKU 编辑/属性/价格与商品查看的完整后台维护页面。

核心约束：Product 绑定合法分类与品牌；Product 可包含一个或多个 SKU；SKU Code 唯一；价格使用精确金额类型（禁止浮点计算金额）、SKU 售价合法且不为负；商品与 SKU 的图片只保存文件标识/URL/Object Key（实际文件存 MinIO/对象存储）；Product 需表达 DRAFT/ON_SALE/OFF_SALE 状态生命周期（具体状态名 Design 确定），创建≠商城可见，上架动作由 REQ-M2-003 完成；商品销售价格由 Product Context 管理；Product Context 不包含真实库存权威字段（stock=100 式的库存字段禁止作为真实库存来源）；订单创建后使用订单商品快照保存成交价格，后续修改商品价格不能影响历史订单。

## 补充信息

- 优先级：P0
- 前置依赖：REQ-M2-001（分类与品牌管理）
- 主要服务：mall-product
- 主要前端：mall-admin
- 主要仓库：repo-1、repo-2
- 领域边界：Product Context（Product、SKU、Attribute、Image、Price；不负责库存数量）
- 非本需求范围：商品正式发布、商城商品列表/详情、库存数量与锁定、ES、购物车、订单