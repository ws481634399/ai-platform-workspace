---
affected-repositories: [repo-1, repo-2]
---

# Requirement Design（需求级方案设计）

> 层级：Requirement 级产物——本次 Change 的技术方案骨架
> 业界锚点：ADR（Context → Decision → Alternatives → Consequences）+ 跨仓影响面
> 输入：requirement-spec.md + CHG-0011 Product 聚合产出
> 产出状态：specified
> 分层关系：本文是 Requirement 级；Story 内部的详细设计见各 Story 目录 story-design.md。

## 0. 元信息

- Change ID: CHG-0012
- spec 来源: requirement-spec.md（REQ-M2-003 商品发布与商城查询）
- 相关仓库: repo-1（ai-platform-backend）、repo-2（ai-platform-frontend）
- 受影响仓库数: 2

## 1. 当前状态

- 当前架构模式: Spring Boot 3.5 / Spring Cloud 微服务 + 独立前端仓；后端 DDD 四层，鉴权经网关 + JWT 资源服务器。
- 相关模块:
  - `mall-services/mall-product`：CHG-0011 已落地 Product 聚合根（含 Sku 集合、ProductStatus 四态 DRAFT/ON_SALE/OFF_SALE/DISABLED）、ProductApplicationService（create/update/changeStatus/page/getById/addSku/updateSku/changeSkuStatus）、ProductAdminController（/api/admin/products/**）、Flyway V2/V3（product_spu/product_image/product_attribute/product_sku）、权限 product:product:* / product:sku:*。
  - `mall-identity`：V4 已注册 product:product/sku:* 权限与商品菜单。
  - 前端 `mall-admin`：CHG-0011 已交付商品列表/编辑页（ProductListView/ProductEditView）。
  - 复用基础：UnifyResult、GlobalExceptionHandler+BusinessException、PageView、ApiTestSecurityConfig。

## 2. 提议方案

- 方案概要: 在 Product 聚合根增加 publish()/unpublish() 行为与上架校验（ProductPublishability）；ProductApplicationService 增加 publish/unpublish 方法；ProductAdminController 增加 /{id}/publish、/{id}/unpublish 端点（权限 product:product:publish）；新增 MallProductController（/api/mall/products，公开）提供商城列表与详情（硬过滤 status=ON_SALE）；新增 InternalProductController（/api/internal/products/{id}/skus/{skuId}）返回 ProductSnapshot DTO。mall-identity V5 追加 product:product:publish 权限码。mall-admin 商品列表/详情页增加上架/下架按钮。
- 关键组件:
  - 后端 mall-product：Product 聚合 publish/unpublish + 校验；MallProductController（商城查询）；InternalProductController（内部契约）；ProductSnapshot DTO；领域事件 ProductPublishedDomainEvent/ProductUnpublishedDomainEvent。
  - 数据：product_spu 表已有 status 字段，无需新表；published_at/unpublished_at 字段已在 ProductPo 预留（V2 建表时已加）。
  - 权限资产：mall-identity V5 追加 product:product:publish 权限码。
  - 前端：ProductListView 增加上架/下架操作列；product.ts 增加 publish/unpublish API。
- 关键不变量实现:
  - 上架校验：Product.publish() 内校验——名称非空、分类/品牌有效（由应用服务 ensureCategoryEnabled/ensureBrandEnabled）、至少一个 ENABLED SKU、所有 ENABLED SKU 价格 >= 0、mainImageUrl 非空、当前状态非 DISABLED。
  - 商城可见性：MallProductController 查询层硬过滤 status='ON_SALE'。
  - 内部契约隔离：ProductSnapshot 为独立 record，字段固定，不引用 Product 聚合。
  - 领域事件：publish() 注册 ProductPublishedDomainEvent，unpublish() 注册 ProductUnpublishedDomainEvent（聚合内事件列表）。

## 2.1 备选方案对比（Alternatives Considered）

| 方案 | 描述 | 优点 | 缺点 | 是否采纳 |
| ---- | ---- | ---- | ---- | -------- |
| A（选中） | Product 聚合内 publish/unpublish + 校验；商城/内部查询独立 Controller；ProductSnapshot DTO | 聚合内保证不变量；查询职责分离；DTO 防领域污染 | 需新增两个 Controller | 是 |
| B（备选） | 上下架走通用 changeStatus 接口（传 ON_SALE/OFF_SALE） | 复用现有接口 | 无法集中校验上架条件；状态语义不清晰 | 否 |

## 3. 仓库影响（Repository Impact）

- 受影响仓库数: 2
- 主要修改点: repo-1 承担后端（Product 聚合发布行为 + 商城/内部查询 Controller + 权限码）；repo-2 承担 mall-admin 上下架按钮。

### 3.1 repo-1（ai-platform-backend）

- `mall-product`：Product 聚合 publish/unpublish + 上架校验；ProductApplicationService.publish/unpublish；ProductAdminController 增加 publish/unpublish 端点；新增 MallProductController（/api/mall/products）；新增 InternalProductController（/api/internal/products/{id}/skus/{skuId}）；新增 ProductSnapshot DTO；领域事件类。
- `mall-identity`：新增 V5__add_product_publish_permission.sql，插入 product:product:publish 权限码。
- `mall-gateway`：路由已由 CHG-0010/0011 建立（/api/admin/products/**、/api/mall/**、/api/internal/** 转发到 mall-product），无需改动。

### 3.2 repo-2（ai-platform-frontend）

- `mall-admin`：ProductListView 增加上架/下架操作列与按钮；product.ts 增加 publish/unpublish API 方法。

## 4. 跨仓协作（Cross-Repository Contract）

- 接口契约: 前端 → 网关 → mall-product 的 REST 契约；统一 UnifyResult；分页 PageView。
- 仓库依赖: repo-2 运行期依赖 repo-1 HTTP；源码与部署独立。
- 集成边界: 权限事实源 mall-identity；mall-product 消费 JWT claim；商城查询公开。
- Migration Impact: mall_identity V5 纯插入权限码；product_spu 表无结构变更（status/published_at 已存在）。
- 跨仓时序: 后端 DU 先于前端 DU 联调。

## 5. Story 设计分派（Story Design Assignments）

| Story ID | 技术要点摘要 | 涉及仓库 | 公共组件/契约归属 |
| -------- | ------------ | -------- | ----------------- |
| STORY-002-03-01-01 | Product 聚合 publish/unpublish + 上架校验、管理端上下架 API、领域事件 ProductPublished/Unpublished、权限 product:product:publish、mall-admin 上下架按钮 | repo-1、repo-2 | Product 聚合发布行为、ProductPublished/Unpublished 领域事件、product:product:publish 权限码 |
| STORY-002-03-02-01 | MallProductController 商城列表（ON_SALE 过滤）与详情 API | repo-1 | 商城查询路径 /api/mall/products、MallProductListItemView/DetailView |
| STORY-002-03-03-01 | InternalProductController 内部 SKU 查询、ProductSnapshot DTO | repo-1 | ProductSnapshot 契约（productId/skuId/productName/skuName/skuAttributes/price/image/currentStatus） |

### 5.1 公共组件与共享契约

- ProductStatus：DRAFT/ON_SALE/OFF_SALE/DISABLED（沿用 CHG-0011）。
- 权限码：product:product:publish（本 Change 新增）。
- ProductSnapshot：固定字段 DTO，订单侧快照契约 SSOT。
- 路由路径：/api/admin/products/{id}/publish、/api/mall/products、/api/internal/products/{id}/skus/{skuId}。

## 6. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-306 | repo-1 | Product 聚合发布/上下架 + 上架校验 + 领域事件 + 管理端 publish/unpublish API + product:product:publish 权限码 | AC-001~009（Story 1） | CHG-0011 |
| DU-BE-307 | repo-1 | MallProductController 商城列表/详情（ON_SALE 过滤） | AC-001~006（Story 2） | DU-BE-306 |
| DU-BE-308 | repo-1 | InternalProductController 内部 SKU 查询 + ProductSnapshot DTO | AC-001~005（Story 3） | DU-BE-306 |
| DU-FE-304 | repo-2 | mall-admin 商品列表/详情页上架/下架按钮 | AC-008,009（Story 1） | DU-BE-306 |

## 7. 风险

- 上架校验依赖 SKU 状态与价格：需确保聚合内 SKU 集合完整加载后再校验。
- 商城查询性能：列表硬过滤 ON_SALE + 分页，M2 数据量下 DB 查询可接受；M5 再迁 ES。
- 内部契约字段稳定性：ProductSnapshot 字段一旦被订单侧依赖，变更需走兼容策略（新增字段而非修改）。

## 8. 待澄清问题

- 内部接口认证方式：本阶段走网关内部认证（X-Internal-Token 或服务间 JWT），具体由网关配置决定，Controller 层不做用户级权限校验。
