---
affected-repositories: [repo-1, repo-2]
---

# Requirement Design（需求级方案设计）

> 层级：Requirement 级产物——本次 Change 的技术方案骨架
> 业界锚点：ADR（Context → Decision → Alternatives → Consequences）+ 跨仓影响面
> 输入：requirement-spec.md + M2 商品/库存既有实现
> 产出状态：designed
> 分层关系：本文是 Requirement 级；Story 内部的详细设计见各 Story 目录 story-design.md。

## 0. 元信息

- Change ID: CHG-0017
- spec 来源: requirement-spec.md（REQ-M3-002 商城商品浏览体验）
- 相关仓库: repo-1（ai-platform-backend）、repo-2（ai-platform-frontend）
- 受影响仓库数: 2
- 需要 Migration: no（复用 M2 商品/分类/品牌/库存表）

## 1. 当前状态

- mall-product 商城侧已有 `MallProductController`（`GET /api/mall/products` 分页、`GET /{id}` 详情，含图集/属性/SKU 规格）；网关已放行 `/api/mall/products/**`。价区填充、有效 SKU 过滤由 CHG-0015 修复。
- 分类/品牌只有 admin 端 Controller（`/api/admin/categories/**`、`/api/admin/brands/**`，RBAC 鉴权），无商城公开接口；应用层与仓储层已具备树查询/状态字段。
- 列表无 sort/brandIds 多选/子孙分类展开；`ProductPageQuery` 现有 keyword/categoryId/brandId/status/page/size。
- 详情 `SkuView` 含 specifications(name/value) 平铺数组，无规格维度矩阵索引。
- mall-inventory：内部仅有 lock/release/confirm；**批量查询能力只存在于 admin 端** `POST /api/admin/inventory/stocks/batch`（需 inventory:stock:list 权限），商城三态语义不存在；库存表有 total/locked（available=total-locked）。
- mall-web：仅 M0 骨架（http.ts、MallLayout、空 router、app store、HomeView/NotFoundView 由 CHG-0015 前的基线提供）。
- 内部调用模式：RestClient 直连 + UnifyResult 解包（SkuClient 先例）；CHG-0015 补齐 X-Internal-Token 凭证。

## 2. 提议方案

- 方案概要:
  1. **公开只读接口群（mall-product 新增 mall 包 Controller，不与 admin 共用 DTO）**：
     - `GET /api/mall/categories/tree`：从分类应用层取启用分类，组装为树（禁用节点的整棵子树剪除），按 sortOrder。
     - `GET /api/mall/brands?keyword=&page=&size=`：仅启用品牌；首期默认返回全量（上限 200 条保护）。
     - `GET /api/mall/home`：聚合 `{ banners: [], categoryEntries: 树首层(或前 N), newArrivals: 上架时间倒序前 10（且有启用 SKU）, recommends: 同数据并标注 source=FALLBACK_NEWEST }`；一次请求填充首页，各商品位复用同一"可售商品"查询。
     - 列表增强：sort=default|newest|price_asc|price_desc（非法回落 default）、brandIds 多选、categoryId 子孙展开（内存展开启用分类后代）；分页 size 上限 50。
     - 详情增强：响应增加 `specDimensions[{name, values[]}]` 与 `skuIndex[{skuId, specs:{name:value}, priceFen, imageUrl, status}]`；前端凭此定位唯一 SKU。
  2. **库存三态聚合（SSOT 在 inventory，product 是商城唯一出口）**：
     - inventory 新增内部接口 `POST /api/internal/inventory/availability`，入参 ≤100 skuId，返 `{skuId, availableQuantity}`（内部精确值，凭证保护）；无库存记录视为 available=0。
     - product 新增商城公开接口 `POST /api/mall/skus/availability`，入参 ≤100，经 RestClient 一次批量调 inventory，映射三态（阈值常量 `AvailabilityThresholds.LOW_STOCK_MAX = 9`，即 available 1–9 LOW_STOCK、≥10 IN_STOCK、=0 OUT_OF_STOCK）；inventory 异常逐条/整体降级 UNKNOWN，不抛 5xx 给浏览器。
     - 详情页由前端加载后调用一次 availability（SKU ≤100 的商品直接全量；>100 的极端商品按规格交互时再按批请求，M3 商品 SKU 数实际远小于 100）。
  3. **网关**：白名单追加 `/api/mall/categories/**`、`/api/mall/brands/**`、`/api/mall/home`、`/api/mall/skus/**`（均 GET/POST 只读；POST availability 是幂等查询语义，白名单显式枚举完整路径）。
  4. **mall-web 浏览链路**：首页（布局/分类导航/新品推荐/Banner 占位）、商品列表（筛选侧栏/排序条/分页卡片）、详情（图集/面包屑/SKU 选择器/三态徽标/加购按钮占位）；统一 Loading/Empty/Error 组件与路由 404；金额整数分工具（formatPriceFen 仅展示除 100，域模型保持 number）；图片懒加载。
- 关键组件:
  - mall-product：`interfaces.rest.mall.{MallCategoryController,MallBrandController,MallHomeController,MallSkuAvailabilityController}` + dto；`application` 增加 home/sort/子孙分类/skuIndex 装配；`infrastructure.client.InventoryAvailabilityClient`；`infrastructure.persistence` 复用 Mapper + 新增价区/排序 SQL（价区已在 CHG-0015 落地，排序复用其分组结果或以 min_price 列排序）。
  - mall-inventory：`interfaces.rest.internal.InternalInventoryController` 增加 availability；application `batchAvailability(skuIds)`；mapper `selectAvailableBySkuIds`（total-locked 计算或字段映射）。
  - mall-gateway：白名单与路由（product 路由 predicate 扩展）。
  - mall-web：api/{category,brand,product,catalog}.ts、stores/catalog（筛选项缓存）、views/{Home,ProductList,ProductDetail}、components/{ProductCard,PriceText,StockBadge,StateView,SkuSelector}、router。
- 关键不变量:
  - 浏览器只接触 product 域：从不直连 inventory，不知道精确库存。
  - 三态阈值唯一常量定义在 mall-product（购物车 CHG-0018 经同一公开/内部语义复用；为避免跨服务依赖拷贝，常量同时在 inventory 内部契约文档声明，inventory 只报数字）。
  - 所有商品位查询都过"ON_SALE + EXISTS(启用 SKU)"同一谓词。
  - 公开接口零内部路径泄漏（CHG-0015 denyAll 延续）。

## 2.1 备选方案对比（Alternatives Considered）

| 方案 | 描述 | 优点 | 缺点 | 是否采纳 |
| ---- | ---- | ---- | ---- | -------- |
| A（选中）product 聚合 inventory，公开三态 | 浏览器只认 product；内部一次批量 | 无 N+1；隐藏精确库存；降级集中 | product 多一个下游依赖 | 是 |
| B inventory 直接对网关公开三态接口 | 少一跳 | 浏览器知两个域；网关白名单/鉴权分散；购物车还得再聚合一次 | 否 |
| C ES 承接列表/首页 | 搜索/筛选强 | M3 无 ES 设施；数据同步链路重 | 否（M5） |
| D 详情内嵌实时库存（一次渲染） | 前端少一个请求 | 详情接口被库存可用性拖垮，降级粒度过粗；购物车无法复用 | 否 |

## 3. 仓库影响（Repository Impact）

- 受影响仓库数: 2

### 3.1 repo-1（ai-platform-backend）

- mall-product：4 个新商城 Controller + DTO；列表 sort/brandIds/子孙分类；详情 specDimensions/skuIndex；InventoryAvailabilityClient（X-Internal-Token）；三态阈值常量；application.yml inventory uri。
- mall-inventory：internal availability 端点 + mapper 批量查询（无 DDL）。
- mall-gateway：product 路由 predicate 扩展（/api/mall/categories|brands|home|skus）；白名单枚举。

### 3.2 repo-2（ai-platform-frontend）

- mall-web：首页/列表/详情三视图、SKU 选择器与统一状态组件、catalog api/store、路由懒加载。

## 4. 跨仓协作（Cross-Repository Contract）

- 公开契约（匿名，UnifyResult，ID 全字符串）：
  - GET /api/mall/home → {banners:[], categories:CategoryNode[], newArrivals:ListItem[], recommends:{source,items:ListItem[]}}
  - GET /api/mall/categories/tree → CategoryNode[]{id,name,sort,children[]}
  - GET /api/mall/brands?keyword=&page=&size= → {items:BrandView[]{id,name,logoUrl,sort}, total}
  - GET /api/mall/products?categoryId&brandIds（逗号分隔多值）&sort&page&size（价区/主图/名称）
  - GET /api/mall/products/{id}（增 specDimensions、skuIndex）
  - POST /api/mall/skus/availability {skuIds:string[](≤100)} → {items:{skuId,stockStatus:IN_STOCK|LOW_STOCK|OUT_OF_STOCK|UNKNOWN}[]}
  - 错误：400 参数非法（含超 100）；404 商品不存在/下架。
- 内部契约（X-Internal-Token）：
  - POST /api/internal/inventory/availability {skuIds:long[](≤100)} → {items:{skuId,availableQuantity}[]}；缺失 SKU 行返 0；凭证错误 401。
- 仓库依赖: repo-2 → repo-1；product 运行期直连 inventory 8106。
- 集成边界: 精确库存数字不出 inventory/internal 边界；阈值映射在 product 单点。
- Migration Impact: 无。
- 跨仓时序: inventory availability 先行 → product 聚合 → 前端联调。

## 5. Story 设计分派（Story Design Assignments）

| Story ID | 技术要点摘要 | 涉及仓库 | 公共组件/契约归属 |
| -------- | ------------ | -------- | ----------------- |
| STORY-003-02-01-02 | 公开分类树/品牌接口 + 网关白名单（先行，无独立 FE 页面） | repo-1 | CategoryNode/BrandView 契约为首页/列表复用 |
| STORY-003-02-03-01 | inventory availability 内部端点 + product 聚合公开端点 + 阈值常量 + 降级 | repo-1 | availability 契约被详情/购物车复用 |
| STORY-003-02-01-01 | /home 聚合接口 + mall-web 首页（导航/新品推荐/Banner 占位/状态态） | repo-1、repo-2 | ProductCard 组件为列表页复用 |
| STORY-003-02-02-01 | 列表 sort/brandIds/子孙分类/分页收敛 + 列表页（筛选排序分页空态） | repo-1、repo-2 | 列表 ListItem 契约 |
| STORY-003-02-02-02 | 详情 specDimensions/skuIndex + 详情页/SKU 选择器/三态联动/404 | repo-1、repo-2 | SkuSelector、StockBadge |

### 5.1 公共组件与共享契约

- 三态枚举 SSOT：IN_STOCK/LOW_STOCK/OUT_OF_STOCK（公开）+ UNKNOWN（降级）；阈值 10。
- ListItem：{id(string),name,mainImageUrl,minPrice,maxPrice}；金额永远 number（整数分）。
- 统一状态组件：StateView（loading/empty/error 三插槽）。

## 6. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-702 | repo-1 | 公开分类树/品牌接口与网关白名单 | AC-003,004,005 | — |
| DU-BE-705 | repo-1 | inventory availability 内部端点 + product 三态聚合公开端点 + 降级 | AC-015,016,017 | — |
| DU-BE-701 | repo-1 | GET /home 聚合接口（分类入口+新品+推荐占位） | AC-001,002 | DU-BE-702 |
| DU-FE-701 | repo-2 | 首页与 Banner 占位、状态态、ProductCard | AC-001,002,018,019 | DU-BE-701 |
| DU-BE-703 | repo-1 | 列表 sort/多选品牌/子孙分类/分页收敛 | AC-006,007,008,009,010,020 | — |
| DU-FE-703 | repo-2 | 列表页（筛选/排序/分页/空错误态） | AC-006,007,008,009,018,019,020 | DU-BE-703, DU-BE-702 |
| DU-BE-704 | repo-1 | 详情 specDimensions/skuIndex 与下架 404 | AC-011,013 | DU-BE-705 |
| DU-FE-704 | repo-2 | 详情页/SKU 选择器/三态联动/缺货标识/404 | AC-011,012,013,014,018,019,020 | DU-BE-704, DU-BE-705 |

> 全局依赖（跨 Change）：所有 DU 依赖 CHG-0015 DU-BE-501（@StringId、网关白名单机制、价区/有效 SKU 过滤）。

## 7. 风险

- 子孙分类展开：深树情况下 IN 列表过大；M3 分类深度 ≤3 级（后台约束），内存展开 + IN 查询可控；加深度断言保护。
- 价区排序：price_asc 按聚合 minPrice 排序在 MySQL 中需子查询/JOIN SKU 分组派生表；用派生表 JOIN，禁止内存排序分页（否则 total 失真）。
- inventory 抖动：UNKNOWN 比例需可观测（日志/指标），避免静默大面积降级。
- 品牌全量接口：上限 200 条硬保护，超出走分页参数。
- >100 SKU 商品：规格交互分批请求；前端禁用一次性超 100 的批量。

## 8. 待澄清问题

- 推荐位算法：M3 占位（与新品同源 + source 标注），M5 接推荐；Banner 无运营后台，前端静态配置位。
- 关键词搜索：本 Change 不开放入口（spec 已明确 M5）；列表 keyword 参数保留但前端不渲染搜索框。
