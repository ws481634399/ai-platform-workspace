---
affected-repositories: [repo-1, repo-2]
---

# Requirement Design（需求级技术设计）

> 层级：Requirement 级产物（多 Story 统一一份）
> 输入：requirement-spec.md
> 产出状态：designed
> SSOT 声明：DU 划分唯一在本文 §6 定义；实现仓 task-design.md / task-spec.md 只引用不新造 DU。

## 0. 元信息

- Change ID: CHG-0010
- spec 来源: requirement-spec.md（REQ-M2-001 分类与品牌管理）
- 相关仓库: repo-1（ai-platform-backend）、repo-2（ai-platform-frontend）
- 受影响仓库数: 2

## 1. 当前状态

- 当前架构模式: Spring Boot 3.5 / Spring Cloud 微服务 + 独立前端仓；后端按 DDD 四层（interfaces / application / domain / infrastructure）分包，鉴权经网关初验 + 业务服务 JWT 资源服务器复验。
- 相关模块:
  - `mall-services/mall-product`：仅有 `MallProductApplication` 与 `application.yml`（端口 **8103**，库 **mall_product**，Flyway locations `db/migration`），pom 已含 mall-common-web/log、mybatis-plus、flyway(mysql)、mysql-connector、nacos-discovery（默认关闭）、mall-common-test；**尚无业务代码、未引入 mall-common-security**。
  - `mall-services/mall-identity`：RBAC 资产所在。权限表 `auth_permission(code uk,type,status,api_pattern,http_method)`、菜单表 `auth_menu(parent_id,name,type,path,component_key,permission_code,sort_order,visible)`，已有 V1 建表与初始化脚本；`AuthorizationGuard` 是 identity 内部组件（依赖本库授权关系表），**不跨服务复用**。
  - `mall-common/mall-common-security`：提供 `JwtSubjectConverter`——从 JWT `permissions` claim 直接映射 `SimpleGrantedAuthority` 并附加 `ROLE_<subject_type>`。因此业务服务方法级鉴权可直接 `hasAuthority('product:category:create')`，无需远程查 RBAC。
  - `mall-gateway`：`GatewaySecurityConfiguration` 已对 `/api/admin/**` 要求 `ROLE_ADMIN` 并透传 JWT；但 `application.yml` **无任何业务路由**（Nacos 默认关闭，无 discovery locator），目前网关不会把 `/api/admin/categories/**` 转发到 mall-product。
  - 前端 `mall-admin`（Vue3.5 + Vite + Element Plus 2.14 + Pinia + axios）：`src/api/http.ts` 统一带 Bearer；`src/router/component-registry.ts` 为动态菜单组件映射表（现仅 Users/Products 等占位视图）；`src/stores/permission.ts` 提供 `has(code)`；尚无商品类页面。
  - 复用基础：`UnifyResult`（mall-common-core）、`GlobalExceptionHandler` + `BusinessException`（mall-common-web）。

## 2. 提议方案

- 方案概要: 在 mall-product 内按 identity 同款 DDD 四层实现 Category 树聚合与 Brand 聚合；Flyway V1 建两张主数据表；服务内新增 JWT 资源服务器安全配置，方法级直接用 JWT permissions claim 做 `hasAuthority` 鉴权；mall-identity 新增 Flyway V2 注册 8 个权限码与 2 个菜单项；mall-gateway 新增静态路由把分类/品牌 API 转发到 mall-product；mall-admin 新增分类树管理页与品牌列表页并在组件注册表登记。
- 关键组件:
  - 后端 mall-product：`interfaces.rest.admin`（CategoryAdminController/BrandAdminController + DTO）、`application`（CategoryApplicationService/BrandApplicationService，事务与用例编排）、`domain.category`/`domain.brand`（聚合根、领域不变量校验、Repository 端口、ProductCategoryException 等业务异常）、`infrastructure.persistence`（PO、MyBatis-Plus Mapper、Repository 实现、树组装器）、`infrastructure.config`（ProductSecurityConfiguration、MybatisPlusConfig）。
  - 数据：`product_category`、`product_brand`（mall_product 库，V1）。
  - 权限资产：mall-identity 库 V2 增量脚本（只插数据，不改表）。
  - 网关：`spring.cloud.gateway.routes` 静态路由 + 本地 profile。
  - 前端：`src/views/product/CategoryTreeView.vue`、`BrandListView.vue`，`src/api/product/category.ts`、`brand.ts`。
- 接口契约: REST `/api/admin/categories/**`、`/api/admin/brands/**`，统一 UnifyResult；请求经网关 → mall-product；管理员 JWT 必须携带对应权限码。
  关键不变量实现：
  - 层级：`parent_id` 用 **0 表示一级根**（不用 NULL，保证 `(parent_id,name)` 唯一索引可对一级生效）；`level` 由父级推导（根=1），上限 3。
  - 防循环/防超层：移动节点时加载目标父链（最多 3 跳），校验新父不在原子树内且 newParent.level < 3；自引用直接拒。
  - 树查询：一次 `SELECT ... ORDER BY parent_id, sort, id` 内存组装为树，避免递归 SQL。
  - 品牌重名：`uk_product_brand_name` 唯一索引 + 服务端 trim 预校验，并发靠索引兜底转业务错误。

## 2.1 备选方案对比（Alternatives Considered）

| 方案 | 描述 | 优点 | 缺点 | 是否采纳 |
| ---- | ---- | ---- | ---- | -------- |
| A（选中） | 服务内 JWT claim 鉴权 + 邻接表(parent_id)树 + 内存组装；权限码与菜单由 identity Flyway V2 注册；网关静态路由 | 与 M1 架构完全一致，无新基础设施；层级仅 3 级，邻接表足够；权限随 Token 下发无跨服务调用 | Token 权限有刷新延迟（M1 已有 permission_version 失效机制兜底）；树深层时内存组装不优，但 3 级无此问题 | 是 |
| B（备选） | mall-product 通过 Fech/HTTP 实时调 identity 鉴权；分类用闭包表(category_closure)维护层级；网关路由放 Nacos 配置中心 | 权限实时一致；闭包表支持任意深度与快速子树查询 | 引入服务间强依赖与登录态可用性耦合；闭包表对固定 3 级过度设计；本地 Nacos 默认关闭，与现有本地联调方式不符，部署复杂度上升 | 否 |

## 3. 仓库影响（Repository Impact）

- 受影响仓库数: 2
- 主要修改点: repo-1 承担全部后端（mall-product 业务实现 + mall-identity 权限菜单数据 + mall-gateway 路由）；repo-2 承担 mall-admin 两个维护页面。

### 3.1 repo-1（ai-platform-backend）

- `mall-product`：pom 增补 `mall-common-security` 与 `spring-security-oauth2-resource-server`；新增 DDD 四层代码；V1 Flyway 建表；application.yml 增补 `mall.security.jwt.*` 配置。
- `mall-identity`：新增 `src/main/resources/db/migration/V2__add_product_category_brand_permissions.sql`，插入 8 个权限码与"商品管理"菜单（目录）+"分类管理""品牌管理"页面菜单及角色授权数据（超管角色放行方式遵循 V1 既有做法）。
- `mall-gateway`：application.yml 增加到 mall-product 的静态路由；为无 Nacos 的本地联调增加可配置 URI（`mall.gateway.product-uri`，默认 `lb://mall-product`，本地 profile 覆写 `http://localhost:8103`）。

### 3.2 repo-2（ai-platform-frontend）

- `mall-admin`：新增两个业务页面（分类树管理、品牌列表管理）、两个 API 模块；在 `component-registry.ts` 注册 `CategoryTree`、`BrandList` 组件 key；不改动鉴权/HTTP 既有机制。

## 4. 跨仓协作（Cross-Repository Contract）

- 接口契约: 前端 → 网关 → mall-product 的 HTTPS/JSON REST 契约（本文 §2 与 story-design 字段级细化）；无服务间 RPC、无消息事件。
- 仓库依赖: repo-2 在构建/运行期依赖 repo-1 的 HTTP 接口，但源码与部署独立；两仓通过相同的权限码字符串与路由路径约定耦合（在本文档锁定）。
- 集成边界: 权限事实源仍在 mall-identity（登录签发 Token 时写入 permissions）；mall-product 只消费 JWT claim，不读 identity 数据库；网关只做认证与转发，不做业务授权。
- Migration Impact: 两个库各一次增量迁移——mall_product V1（新建表，新服务首次建库）、mall_identity V2（纯插入权限菜单数据，可回滚=停用/删除新增行，不影响 M1 表结构）。
- 跨仓时序: 后端 DU 先于前端 DU 联调；其中权限/路由 DU 先行，保证端到端可达且 403/200 可验证。

## 5. Story 设计分派（Story Design Assignments）

| Story ID | 技术要点摘要 | 涉及仓库 | 公共组件/契约归属 |
| -------- | ------------ | -------- | ----------------- |
| STORY-002-01-01-01 | product_category 表与 Category 聚合（层级推导、自引用/循环/悬空/3 级校验、启停、树组装）；分类 REST；分类管理页 | repo-1、repo-2 | Requirement 级公共：ProductSecurityConfiguration、UnifyResult 用法、网关路由模式由 DU-BE-301 落地，本 Story 直接使用 |
| STORY-002-01-02-01 | product_brand 表与 Brand 聚合（名称唯一、分页关键字、启停）；品牌 REST；品牌管理页 | repo-1、repo-2 | 复用分类 Story 已建立的安全配置与分层骨架；品牌分页 MyBatis-Plus 配置可在本 Story 补全（供后续商品复用） |

### 5.1 公共组件与共享契约

- `ProductSecurityConfiguration`（mall-product infrastructure.config）：JWT decoder + JwtSubjectConverter + `/api/admin/**` hasRole ADMIN + 401/403 JSON 写出，配置形态对齐 mall-identity JwtConfiguration（仅解码侧，不签发）。在分类 Story 落地，品牌 Story 直接复用。
- 状态枚举 `common`：`CategoryStatus`/`BrandStatus` 共用字符串值 `ENABLED`/`DISABLED`。
- 权限码 SSOT：`product:category:{list,create,update,disable}`、`product:brand:{list,create,update,disable}`（本文锁定，SQL 与前端按钮、后端注解三处必须一致）。
- 路由路径 SSOT：分类 `/api/admin/categories`、品牌 `/api/admin/brands`。

## 6. DU 划分（Delivery Units）

> 说明：跨 Story 公共前置（安全配置/权限码注册/网关路由）并入首个后端 DU-BE-302，不单列 DU（harness 的 DU 聚合 SSOT 为各 story-design §5，公共前置与分类能力同仓同 Story 落地，品牌 Story 按依赖顺序复用）。

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-302 | repo-1 | 公共前置：注册分类/品牌权限码与菜单（identity V2）、mall-product 安全配置、网关到 mall-product 路由；Category 聚合、product_category 表与分类 REST（树/增改/启停/全部不变量） | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-013, AC-015, AC-016 | — |
| DU-BE-303 | repo-1 | Brand 聚合、product_brand 表与品牌 REST（唯一/分页/启停） | AC-009, AC-010, AC-011, AC-012, AC-015, AC-016 | DU-BE-302 |
| DU-FE-301 | repo-2 | mall-admin 分类树管理页面与 API 封装 | AC-014 | DU-BE-302 |
| DU-FE-302 | repo-2 | mall-admin 品牌列表管理页面与 API 封装 | AC-014 | DU-BE-303 |

### DU-BE-302

- id: DU-BE-302
- repository: repo-1
- goal: 打通"网关 → mall-product"网络与鉴权链路、登记分类/品牌权限码与菜单，并实现分类主数据后端能力与全部层级不变量
- scope: mall-identity Flyway V2（auth_permission 8 行 + auth_menu 3 行：商品管理目录/分类/品牌页面 + 既有超管角色授权）；mall-product pom（security 依赖）、ProductSecurityConfiguration、application.yml jwt 配置；mall-gateway 静态路由（categories/brands 前缀 → mall-product）；mall-product V1 中 product_category 表；domain.category（Category/CategoryTree/Repository 端口/不变量）、application CategoryApplicationService、infrastructure persistence（CategoryPO/Mapper/RepositoryImpl/TreeAssembler）、interfaces CategoryAdminController + DTO；领域与 API 测试
- covers:
  - AC-001
  - AC-002
  - AC-003
  - AC-004
  - AC-005
  - AC-006
  - AC-007
  - AC-008
  - AC-013
  - AC-015
  - AC-016
- depends on:
  - —
- affected-repositories:
  - repo-1

### DU-BE-303

- id: DU-BE-303
- repository: repo-1
- goal: 实现品牌主数据后端能力（唯一约束、分页、启停）
- scope: mall-product V1 中 product_brand 表；domain.brand、application BrandApplicationService、infrastructure persistence（BrandPO/Mapper/RepositoryImpl）、MyBatis-Plus 分页插件配置、interfaces BrandAdminController + DTO；领域与 API 测试
- covers:
  - AC-009
  - AC-010
  - AC-011
  - AC-012
  - AC-015
  - AC-016
- depends on:
  - DU-BE-301
- affected-repositories:
  - repo-1

### DU-FE-301

- id: DU-FE-301
- repository: repo-2
- goal: mall-admin 分类可视化维护端到端可用
- scope: src/api/product/category.ts；src/views/product/CategoryTreeView.vue（树表、新增/编辑弹窗、启停确认、sort 编辑）；component-registry 登记 CategoryTree；按钮权限指令接 product:category:*
- covers:
  - AC-014
- depends on:
  - DU-BE-302
- affected-repositories:
  - repo-2

### DU-FE-302

- id: DU-FE-302
- repository: repo-2
- goal: mall-admin 品牌可视化维护端到端可用
- scope: src/api/product/brand.ts；src/views/product/BrandListView.vue（分页表格、名称搜索、新增/编辑弹窗、启停）；component-registry 登记 BrandList；按钮权限指令接 product:brand:*
- covers:
  - AC-014
- depends on:
  - DU-BE-303
- affected-repositories:
  - repo-2

## 7. 风险

- 风险等级: 中低
- 主要风险:
  1. 网关联调链路（M1 遗留：网关本地无业务路由，曾导致前端登录不通）——本需求把 mall-product 路由显式落地并提供本地直连 profile，可顺带验证模式，但 identity 历史路由不在本 Change 范围。
  2. 权限码三处（identity SQL / 后端注解 / 前端指令+菜单）不一致会导致 403 或越权——以本文 §5.1 为 SSOT，测试中加入"无权限 403/有权限 200"用例。
  3. MySQL 唯一索引对 NULL 不去重导致一级分类同级重名——以 parent_id=0 约定规避。
  4. 超管角色授权数据的插入方式需与 V1 既有种子数据严格一致，避免菜单不显示。
- 缓解措施: DU-BE-302 内先落地公共前置（安全/权限/路由）打通链路再写业务；复用 identity 已验证配置类形态；核心不变量全部以领域单测 + API 集成测试固化。

## 8. 待澄清问题

- 超管角色在 V1 种子中的具体 role_id 与授权插入方式：实现 DU-BE-302 公共前置部分时以 V1 SQL 实际数据为准（id 可能随环境漂移，脚本用子查询按 role code 定位，避免硬编码 id）。
- 分类同级重名采用"硬唯一索引"还是"仅前端提示"：本设计定为数据库 `(parent_id,name)` 唯一索引硬约束（与 story-spec 规则一致），若后续业务要求允许同级同名，需回改本设计。
