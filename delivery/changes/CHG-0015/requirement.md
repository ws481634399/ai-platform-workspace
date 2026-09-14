---
id: "REQ-M3-READY"
name: "M3 前置就绪修复"
content: "在进入 REQ-M3-001/002/003 开发前，修复 M2 遗留、会直接阻塞商城侧联调的接口契约与运行环境缺口：网关公开路由 401、库存服务内部调用凭证、库存分页 total 错误、Snowflake ID 字符串序列化、商品列表真实价格区间与有效 SKU 过滤。"
source: requirement-doc
created-at: "2026-09-14T07:00:00.000Z"
---

# Requirement

> 原始需求全文归档于 `references/M3.md`（重点为文末“注意点：必须先调整”第 1、4、5 项与“M3 前置就绪检查”三个现实阻塞），本文件记录本 Change 的输入边界。

## 需求描述

M3（商城基础）要求把 mall-web 与真实商品/库存/会员体系串起来。在 M3 功能开发开始前，M2 已交付能力存在若干已确认的契约与运行缺口，若不先行修复，商城页面与购物车联调会被反复阻塞。本 Change 作为 M3 的“前置就绪检查”，只修复**既有接口/既有服务**的缺陷与跨切面契约，不实现 M3 新功能（公开分类树/品牌新接口、批量库存聚合等新能力归 CHG-0017）。

修复清单（来源：M3.md 文末注意点与三个现实阻塞）：

1. **业务 ID 统一字符串序列化**：当前 Snowflake ID（如 2099488396675276801）超过 JavaScript 安全整数范围，浏览器被解析为 2099488396675276800，M3 购物车可能传错 skuId/productId。所有对外业务 ID（商品、SKU、分类、品牌、库存记录、会员、地址、购物车条目等）在 JSON 中必须输出为字符串；后端在 mall-common 提供统一的 Long → String JSON 序列化策略，改造 product/inventory 现有对外 DTO；mall-admin/mall-web 前端 ID 类型统一为 string。新增服务（member/cart）自始遵循该约定。
2. **网关商城公开路由 401**：当前经网关访问 `GET /api/mall/products` 返回 401，直连商品服务正常。网关必须正确放行商城公开只读接口（products 等 GET），会员私有路由保持认证。
3. **库存服务内部调用缺服务凭证**：库存服务调用商品内部接口（SKU 校验）时未携带服务凭证，API 初始化库存误报“SKU 不存在”。需补齐服务间认证（SERVICE 主体凭证传播），内部接口拒绝浏览器直访。
4. **库存分页 total=0**：库存分页能返回 33 条数据但 total 返回 0，需修复分页统计。
5. **商品列表价格区间**：当前列表 minPrice/maxPrice 固定返回 null。必须返回启用 SKU 的最低价/最高价（整数分，禁止浮点数）；无有效（启用）SKU 的商品不得出现在商城列表；金额单位统一为分。

## 补充信息

- 优先级：P0（M3 一切联调的前置）
- 需求来源：M3.md 文末“注意点：必须先调整”与“当前进入 M3 前还有三个现实阻塞”
- 主要仓库：repo-1（backend：mall-gateway / mall-common / mall-product / mall-inventory / mall-contracts）、repo-2（frontend：mall-admin 既有页面 ID 类型回归）
- 非本需求范围：
  - `GET /api/mall/categories/tree`、`GET /api/mall/brands` 等**新增**公开接口（CHG-0017）；
  - 批量 SKU 可售状态聚合新接口（CHG-0017）；
  - 会员注册登录、资料、地址（CHG-0016）；购物车（CHG-0018）；
  - Elasticsearch、RocketMQ、分布式锁。
- 验收口径：三个现实阻塞全部消除并留证；既有 mall-admin 页面在 ID 字符串化后功能不回归；mall-web 经网关可匿名访问商城公开商品接口。
