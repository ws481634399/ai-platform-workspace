---
id: "REQ-M2-003"
name: "商品发布与商城查询"
content: "按 docs/需求/M2/M2.md 中 REQ-M2-003 建立商品发布、上下架和标准商品查询能力。"
source: requirement-doc
created-at: "2026-09-13T02:40:00.000Z"
---

# Requirement

> 原始需求全文归档于 `references/M2.md`，本文件记录本 Change 的输入边界。

## 需求描述

按 `docs/需求/M2/M2.md` 中 `REQ-M2-003 商品发布与商城查询` 执行完整 SDD。使后台维护的商品真正成为商城可售商品，并向其他上下文提供稳定商品查询契约。

能力范围：
- 商品上架：提供明确上架动作，上架前完整业务校验（商品基本信息完整、分类有效、品牌有效、至少存在一个有效 SKU、SKU 价格合法、必要商品图片存在），不满足条件不得上架。
- 商品下架：支持主动下架；下架后商城正常商品列表不再显示、新交易不能将其作为正常可售商品、历史订单商品快照不受影响；下架 ≠ 删除商品历史。
- 商城商品列表查询：面向 mall-web，支持商品列表、分类筛选、品牌筛选、基础分页、基础排序，只返回有效可售商品；M2 可用数据库查询（完整 ES 搜索由 M5 实现）。
- 商品详情：返回 Product 信息、分类、品牌、图片、SKU、SKU 属性、SKU 价格、商品状态等；库存信息不伪造，如需要实时库存通过 Inventory Context 获取。
- 内部商品查询契约：为 Cart/Order/Inventory/AI 提供稳定契约（productId、skuId、productName、skuName、skuAttributes、price、image、currentStatus），用于构建 Product Snapshot；不将 Product Domain Entity 直接共享给其他服务。
- 商品快照契约：订单后续保存历史成交信息的标准契约，保证"今天买 A 价格 100，明天改 B 价格 120，历史订单仍显示 A/100"。
- 商品领域事件基础：上架/下架具备领域事件语义（ProductPublished/ProductUnpublished/ProductChanged），本阶段不要求 MQ 发布，M7 再做可靠消息与最终一致性。

## 补充信息

- 优先级：P0
- 前置依赖：REQ-M2-002（商品与 SKU 管理）
- 主要服务：mall-product
- 主要前端：mall-admin（上架/下架动作）
- 下游使用方：mall-web、mall-cart、mall-order、ai-service
- 主要仓库：repo-1、repo-2
- 非本需求范围：ES 搜索与索引同步、购物车、下单、AI 导购、RocketMQ 可靠事件发布