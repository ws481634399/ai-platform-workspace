---
affected-repositories: [repo-1, repo-2]
---

# Requirement Design（需求级方案设计）

> 层级：Requirement 级产物——本次 Change 的技术方案骨架
> 业界锚点：ADR（Context → Decision → Alternatives → Consequences）+ 跨仓影响面
> 输入：requirement-spec.md + product/06 §7.1 Product 聚合 + product/09 mall_product_db
> 产出状态：specified
> 分层关系：本文是 Requirement 级；Story 内部的详细设计见各 Story 目录 story-design.md。

## 0. 元信息

- Change ID: CHG-0011
- spec 来源: requirement-spec.md（REQ-M2-002 商品与 SKU 管理）
- 相关仓库: repo-1（ai-platform-backend）、repo-2（ai-platform-frontend）
- 受影响仓库数: 2

## 1. 当前状态

- 当前架构模式: Spring Boot 3.5 / Spring Cloud 微服务 + 独立前端仓；后端 DDD 四层，鉴权经网关 + JWT 资源服务器。
- 相关模块:
  - `mall-services/mall-product`：CHG-0010 已落地 Category/Brand 聚合、`ProductSecurityConfiguration`、Flyway V1（product_category/product_brand）、网关到 mall-product 路由、权限码 product:category/brand:*；pom 已含 mybatis-plus、mall-common-security、spring-security-oauth2-resource-server、mybatis-plus-jsqlparser。
  - `mall-common/mall-common-security`：`JwtSubjectConverter` 从 JWT permissions claim 映射 GrantedAuthority，方法级 `hasAuthority` 直接可用。
  - `mall-identity`：V2 已注册分类/品牌权限与菜单；商品权限/菜单待 V3 追加。
  - 前端 `mall-admin`：CHG-0010 已交付分类/品牌页，http.ts 解包 UnifyResult、permission store has()、组件注册表已有分类/品牌组件；商品页面待新增。
  - 复用基础：`UnifyResult`、`GlobalExceptionHandler`+`BusinessException`、`PageView`。

## 2. 提议方案

- 方案概要: 在 mall-product 内按 DDD 四层实现 Product 聚合根与 SKU 聚合内实体；Flyway V2 建 product_spu/product_image/product_attribute、V3 建 product_sku；Product 状态枚举 DRAFT/ON_SALE/OFF_SALE/DISABLED，创建即 DRAFT；价格用 Money（amountInCents，long）；规格用 specification_json + specification_hash（SHA-256 排序键值）保证同商品组合唯一；图片存 object_key+image_url，主图唯一；mall-identity V3 注册 product:product/sku:* 权限与商品菜单；mall-admin 新增商品列表/创建/编辑/查看整体表单页。
- 关键组件:
  - 后端 mall-product：`domain.product.Product`（聚合根）、`Sku`（聚合内实体）、值对象 Money/Specification/SpecificationHash；`ProductRepository` 端口 + MyBatis-Plus 适配器；`ProductAdminAppService`（create/update/changeStatus/get/page）；`ProductAdminController`（/api/admin/products/**，权限 product:product:*）。
  - 数据：product_spu、product_sku、product_image、product_attribute（mall_product 库，V2/V3）。
  - 权限资产：mall-identity V3 增量（14 个权限码 + 商品菜单）。
  - 前端：`src/views/product/ProductListView.vue`、`ProductEditView.vue`；`src/api/product/product.ts`。
- 关键不变量实现:
  - Product 创建：校验 category_id/brand_id 存在且启用；product_code 唯一；状态 DRAFT；至少一 SKU（SKU 随 Product 同事务写入）。
  - SKU 唯一：sku_code 全局唯一（existsBySkuCode + uk）；同商品 specification_hash 唯一（uk(product_id, specification_hash, deleted)）。
  - 价格：Money 构造校验 amountInCents >= 0；DB BIGINT。
  - 主图：Product 仅一条 main_flag=1 图片（应用服务层 replace 主图）。
  - 领域事件：聚合内 registerEvent（ProductCreated/Updated、SkuAdded/Updated/PriceChanged/Enabled/Disabled），本阶段不发布 MQ。

## 2.1 备选方案对比（Alternatives Considered）

| 方案 | 描述 | 优点 | 缺点 | 是否采纳 |
| ---- | ---- | ---- | ---- | -------- |
| A（选中） | Product 聚合内含 SKU 集合；规格存 specification_json+hash；Money(分,long)；图片 product_image 表 object_key+url | 对齐 product/06 §7.1 设计；单商品 SKU 可控；JSON+hash 兼顾灵活与唯一约束；分避免浮点 | 规格检索需后续拆 spec 表（product/09 §9.8 已预留） | 是 |
| B（备选） | SKU 独立聚合；规格拆 product_sku_spec 明细表；价格用 BigDecimal | 高 SKU 数量下聚合性能好；规格筛选高效 | 违背 product/06 第一版结论；过度设计；跨聚合事务复杂 | 否 |

## 3. 仓库影响（Repository Impact）

- 受影响仓库数: 2
- 主要修改点: repo-1 承担后端（mall-product Product/SKU 实现 + mall-identity 权限菜单 + 网关路由已存在无需改）；repo-2 承担 mall-admin 商品维护页面。

### 3.1 repo-1（ai-platform-backend）

- `mall-product`：新增 domain.product（Product/Sku/Money/Specification）、application（ProductAdminAppService）、interfaces.rest.admin（ProductAdminController + DTO）、infrastructure.persistence（PO/Mapper/Repository）；Flyway V2（product_spu/product_image/product_attribute）、V3（product_sku）。
- `mall-identity`：新增 `V3__add_product_permissions.sql`，插入 product:product:*（list/detail/create/update/disable）与 product:sku:*（create/update/disable）共 8 个权限码 + "商品列表"页面菜单。
- `mall-gateway`：路由已由 CHG-0010 建立（/api/admin/products/** 转发到 mall-product），无需改动。

### 3.2 repo-2（ai-platform-frontend）

- `mall-admin`：新增商品列表页、创建/编辑页（含 SKU 表单、图片、属性区块）、商品 API 模块；component-registry 注册 ProductList 组件。

## 4. 跨仓协作（Cross-Repository Contract）

- 接口契约: 前端 → 网关 → mall-product 的 REST 契约；统一 UnifyResult；分页 PageView。
- 仓库依赖: repo-2 运行期依赖 repo-1 HTTP；源码与部署独立。
- 集成边界: 权限事实源 mall-identity；mall-product 消费 JWT claim；网关只做认证转发。
- Migration Impact: mall_product V2/V3 新表；mall_identity V3 纯插入权限菜单。
- 跨仓时序: 后端 DU 先于前端 DU 联调。

## 5. Story 设计分派（Story Design Assignments）

| Story ID | 技术要点摘要 | 涉及仓库 | 公共组件/契约归属 |
| -------- | ------------ | -------- | ----------------- |
| STORY-002-02-01-01 | Product 聚合、product_spu/product_image/product_attribute 表、SPU REST（CRUD+状态）、商品属性、图片主图唯一、状态生命周期、领域事件 | repo-1、repo-2 | Requirement 级公共：ProductSecurityConfiguration、UnifyResult、网关路由由 CHG-0010 落地；ProductStatus 枚举、权限码 product:product:* 由本 Story 锁定 |
| STORY-002-02-02-01 | SKU 实体、product_sku 表、specification_hash 组合唯一、Money 价格、SKU REST（增改启停）、领域事件 | repo-1、repo-2 | 复用 Product 聚合与 Repository；权限码 product:sku:*；SkuStatus 枚举 |

### 5.1 公共组件与共享契约

- `ProductStatus`：DRAFT/ON_SALE/OFF_SALE/DISABLED（本文锁定）。
- `SkuStatus`：ENABLED/DISABLED。
- Money.amountInCents（long），DB BIGINT。
- 权限码 SSOT：product:product:{list,detail,create,update,disable}、product:sku:{create,update,disable}。
- 路由路径 SSOT：/api/admin/products、/api/admin/products/{id}/skus。

## 6. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-304 | repo-1 | 商品权限码注册（identity V3）+ Product 聚合、SPU 管理端 API、图片/属性、状态生命周期、领域事件 | AC-001,002,007,008,009,010,012,013,014,015 | CHG-0010 公共前置 |
| DU-BE-305 | repo-1 | SKU 实体、规格组合唯一（specification_hash）、Money 价格、SKU 管理端 API | AC-003,004,005,006,008,013,014,015 | DU-BE-304 |
| DU-FE-303 | repo-2 | mall-admin 商品列表/创建/编辑/查看页（含 SKU 表单、图片、属性） | AC-011,013 | DU-BE-304、DU-BE-305 |

## 7. 风险

- 规格组合唯一依赖 specification_hash 算法稳定：需前后端/测试用同一哈希函数，避免顺序/大小写差异。
- 并发创建同 SKU 编码：DB uk 兜底，需捕获 DuplicateKeyException 转业务错误。
- Product 编辑时替换主图：需保证仅一条 main_flag=1，应用服务层先清旧主图再设新主图。

## 8. 待澄清问题

- SKU 物理删除：本阶段不提供，仅启停；是否需要"删除"入口待与 CHG-0013 库存联动确认。
- 商品详情 published_at：本阶段发布归 REQ-M2-003，published_at 字段预留但不写入。
