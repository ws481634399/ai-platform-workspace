---
id: "REQ-M5-001"
name: "Elasticsearch 商品搜索"
content: "建立独立 mall-search 商品搜索能力：Elasticsearch 基础设施、关键词搜索、分类/品牌/价格筛选、基础排序、标准分页、Search DTO 结果模型、搜索异常响应（降级由 Design 决定）与 mall-web 搜索页；Product DB 为 Source of Truth，ES 仅为 Search Projection，mall-search 不修改商品主数据、不承担商品详情与交易库存。"
source: requirement-doc
created-at: "2026-09-18T10:36:41.088Z"
---

# Requirement

> 原始需求全文归档于 `references/M5.md`（M5 三 REQ + Integration Gate 七场景 + DoD），本文件记录本 Change（REQ-M5-001）的输入边界。

## 需求描述

**阶段：** M5 搜索与系统配置
**类型：** 搜索能力需求
**优先级：** P1
**前置依赖：** REQ-M2-003
**主要服务：** mall-search
**主要前端：** mall-web
**基础设施：** Elasticsearch

### 一、需求目标

建立独立商品搜索能力，使商城用户可以通过关键词快速搜索真实上架商品。

完成后至少支持：

- 关键词搜索；
- 分页；
- 分类筛选；
- 品牌筛选；
- 价格区间；
- 基础排序；
- 搜索结果商品展示。

商城商品检索从普通数据库筛选升级为 Elasticsearch 搜索。

### 二、搜索数据来源

搜索索引必须来源于 Product Context：

```text
mall-product
↓
Search Projection
↓
Elasticsearch
↓
mall-search
```

禁止 mall-search 成为商品主数据维护方。搜索服务不得拥有修改 Product、SKU、Brand、Category 业务状态的能力。

必须明确：**Product DB = Source of Truth；Elasticsearch = Search Projection。** Elasticsearch 不是商品主数据库；商品名称、SKU、价格、上下架状态的最终权威数据仍属于 Product Context。

### 三、搜索文档

Elasticsearch 商品文档至少包含：

```text
productId
productName
categoryId
categoryName
brandId
brandName
mainImage
keywords
status
minPrice
maxPrice
updatedAt
```

可按最终搜索需求加入 SKU 摘要、属性、搜索标签、销量、发布时间等字段。具体 Mapping 在 Design 阶段确定（Mapping 代码化管理由 REQ-M5-002 交付）。

### 四、关键词搜索

至少支持根据商品名称、关键词、品牌、分类等字段搜索（如用户搜索"机械键盘"返回真实商城商品）。搜索结果必须只包含当前允许展示的商品，下架商品不得作为正常搜索结果出现。

### 五、筛选能力

至少支持 `categoryId`、`brandId`、`priceRange` 基础筛选条件，并能够组合查询（如：关键词手机 + 品牌 Apple + 价格 5000-10000）。

### 六、排序

至少支持：默认排序、价格升序、价格降序、新品排序。销量、综合热度可后续增强；M5 不要求建设复杂推荐排序模型。

### 七、分页

搜索必须支持标准分页，避免一次性查询大量商品；分页模型与项目统一 API 响应规范保持一致。

### 八、搜索结果

搜索返回 Search DTO 而不是 Product Aggregate，只包含商城结果页真正需要的数据：

```text
productId
name
image
price
brand
category
```

避免直接复制整个 Product Domain Model。

### 九、商品详情边界

搜索负责"找到商品"；商品详情仍由 mall-product 提供：

```text
搜索 → mall-search → 返回 productId + Search Summary → 点击商品 → mall-product Product Detail
```

不要让 Elasticsearch 逐渐成为完整商品详情的第二数据库。

### 十、库存边界

搜索索引原则上不维护强实时库存作为交易依据，可展示有货/缺货等弱实时信息；最终可售库存属于 mall-inventory，订单创建仍必须重新校验库存。

### 十一、mall-web 搜索体验

商城前端至少支持：搜索框、搜索结果页、搜索关键词、分类筛选、品牌筛选、价格筛选、排序、分页、无结果状态、Loading、Error。用户点击商品后进入已有商品详情页面。

### 十二、搜索异常

需要处理：Elasticsearch 不可用、查询超时、索引不存在、搜索结果为空。M5 至少建立明确异常响应。是否采用数据库降级搜索由 Design 决定；如果实现降级，降级路径不能产生与正式商品状态明显冲突的数据。

### 十三、验收标准

- Elasticsearch 可以正常运行；
- mall-search 可以连接 Elasticsearch；
- 可以根据商品名称搜索；
- 分类筛选正常；
- 品牌筛选正常；
- 价格筛选正常；
- 排序正常；
- 分页正常；
- 下架商品不会正常出现在结果中；
- 搜索结果不直接返回 Product Aggregate；
- 搜索服务不修改 Product 主数据；
- mall-web 搜索页面正常；
- 搜索核心测试通过。

### 十四、非本需求范围

- 索引同步机制；
- Product Event；
- 推荐系统；
- AI 智能导购；
- 用户行为画像；
- 搜索推荐模型。

索引同步由 REQ-M5-002（CHG-0021）完成。

## 补充信息

- 优先级：P1；与 REQ-M5-003 可并行，REQ-M5-002 在本 REQ 索引结构稳定后启动。
- 前置依赖：REQ-M2-003（商品发布与商城查询：上下架状态、商城列表查询已交付）。
- 主要仓库：repo-4（infrastructure：docker-compose 新增 Elasticsearch）、repo-1（backend：mall-search 从空骨架交付，8107，mall_search 库已预建）、repo-2（frontend：mall-web 新增搜索页）。
- 端口/路由（product/08-系统与微服务架构.md 已规划）：mall-search 8107；网关 `/api/mall/search/**`（游客可访问，参照商品公开查询放行策略）。
- 技术约束：Java 21 + Spring Boot 3.5.x + 官方 Elasticsearch Java Client（版本经 mall-bom 管理）；DDD 分层；金额（价格区间/展示价）沿用整数分 Long；跨服务交互仅 Internal API（RestClient + X-Internal-Token），禁止跨服务直库；中文注释。
- 测试基线：ES 相关集成测试采用 Testcontainers（与既有 Redis/MySQL 集成测试基线同构）。
