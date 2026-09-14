---
affected-repositories: [repo-1, repo-2]
---

# Requirement Design（需求级方案设计）

> 层级：Requirement 级产物——本次 Change 的技术方案骨架
> 业界锚点：ADR（Context → Decision → Alternatives → Consequences）+ 跨仓影响面
> 输入：requirement-spec.md + M2 既有代码现状
> 产出状态：designed
> 分层关系：本文是 Requirement 级；Story 内部的详细设计见 Story 目录 story-design.md。

## 0. 元信息

- Change ID: CHG-0015
- spec 来源: requirement-spec.md（REQ-M3-READY M3 前置就绪修复）
- 相关仓库: repo-1（ai-platform-backend）、repo-2（ai-platform-frontend）
- 受影响仓库数: 2
- 需要 Migration: no

## 1. 当前状态

- 架构模式: Spring Boot 3.5 / Spring Cloud 微服务 + DDD 四层；网关 Spring Cloud Gateway（响应式）+ JWT 资源服务器；下游服务 servlet 栈 + `JwtSubjectConverter`。
- 已实证缺口与代码定位：
  - **网关 401**：`mall-gateway/.../GatewaySecurityConfiguration.java` 白名单仅 `/api/admin/auth/login`、`/api/admin/auth/refresh`、`/api/mall/products/**`、`/actuator/health`。表面上 products 已放行，M3.md 记录的 401 发生在白名单补配前；本 Change 需经网关实测回归，并把后续公开路径白名单机制做成显式枚举（categories/brands/home 在 CHG-0017 追加）。
  - **internal 暴露**：`application.yml` 中 `mall-product-internal` 与 `mall-inventory-admin`（含 `/api/internal/inventory/**`）路由经网关可达；安全链 `anyExchange().authenticated()` 仅做到"要登录"，做不到"外部不可达 + 服务凭证"。
  - **服务凭证缺失**：`mall-inventory/.../client/SkuClient.java` 用裸 RestClient 直连 8103，无任何凭证头；product 内部接口也无凭证校验。
  - **分页 total=0**：`mall-product` 有 `infrastructure/config/MybatisPlusConfig.java`（注册 PaginationInnerInterceptor），而 **mall-inventory 无此配置类**——MyBatis-Plus 无分页插件时 `Page` 不生成 count 查询且不分页，total 恒为 0/默认值。dev 阶段以集成测试证实并补配置。
  - **Long 精度**：全仓无全局 Jackson 定制（`WebFoundationAutoConfiguration` 只注册 TraceIdFilter/GlobalExceptionHandler）；对外 DTO（如 `MallProductDtos`）ID 均为 `long`；雪花 ID（19 位）超 JS `Number.MAX_SAFE_INTEGER`。
  - **价区 null**：`MallProductController.toListItemView()` 硬编码传 `null, null`；`ProductPo` 已有 min_price/max_price 列但领域加载/商城查询未使用；`mallPage()` 未过滤"无启用 SKU"商品。
- 复用基础：`UnifyResult`、`BusinessException`+`GlobalExceptionHandler`、`PageView`、`JwtSubjectConverter`、`SecurityContextFacade`、`SubjectType`（GUEST/MEMBER/ADMIN/SERVICE）。

## 2. 提议方案

- 方案概要:
  1. **字符串 ID（精细字段级，非全局 Long 一刀切）**：在 `mall-common-web` 新增元注解 `@StringId`（`@JacksonAnnotationsInside` + `@JsonSerialize(ToStringSerializer)`），标注于所有对外 REST DTO 的业务 ID 字段（record 组件注解，Jackson 原生支持）。金额（priceInCents）、分页（total/page/size）等非 ID 数值保持 JSON number。入参兼容：Path/Query/Body 中的 ID 声明为 `Long/long`，Jackson/Spring 原生即可同时接受 `"123"` 与 `123`，无需额外反序列化器；对请求体 DTO 中 ID 字段补 `@JsonDeserialize` 宽松处理以双保险。
  2. **网关白名单显式化 + internal 外拒**：白名单仅枚举匿名 GET 只读商城路径（本 Change 保持 products 两项，CHG-0017 再扩）；新增 `.pathMatchers("/api/internal/**").denyAll()`（网关层 404 语义由自定义 entry point 输出，对外不暴露内部存在）；服务间一律直连服务端口（不经网关），延续 SkuClient 模式。
  3. **服务间共享凭证**：`mall-common-security` 提供 servlet `InternalIdentityFilter`（校验请求头 `X-Internal-Token: ${mall.security.internal.shared-secret}`，通过后注入 `SubjectType.SERVICE` 的 Authentication）；product/inventory 的 internal 包接口由该过滤器保护（配置化路径前缀 `/api/internal/**`）。密钥从环境变量注入，默认值仅本地开发。SkuClient 增加请求头拦截器携带凭证。
  4. **库存分页**：mall-inventory 新增 `infrastructure/config/MybatisPlusConfig.java`（DbType.MYSQL + PaginationInnerInterceptor），对齐 product；补 Repository 分页集成测试。
  5. **价区与有效 SKU 过滤**：Product 领域/PO 已具备 minPrice/maxPrice，商城列表改为由"启用状态 SKU"实时聚合价区（一条分组 SQL：`SELECT product_id, MIN(sale_price), MAX(sale_price) FROM product_sku WHERE status='ENABLED' AND product_id IN (...) GROUP BY product_id`，禁止 N+1），`mallPage` SQL 增加 `EXISTS(启用 SKU)` 过滤；列表 View 填充价区。同步以 SKU 状态迁移后列表消失为测试。
- 关键组件:
  - `mall-common-web`：`annotation/StringId.java`；可选 `config/JacksonLongIdConfiguration`（只放 ObjectMapper 宽松反序列化，不做全局 Long→String）。
  - `mall-common-security`：`InternalIdentityFilter`、`InternalSecurityProperties`（shared-secret + path）。
  - `mall-gateway`：白名单与 denyAll 调整。
  - `mall-product`：内部接口加过滤器保护；`MallProductDtos` 全 ID 字段 @StringId；价区聚合 mapper 方法；mallPage EXISTS 过滤；`SkuClient` 式调用方凭证。
  - `mall-inventory`：MybatisPlusConfig；对外 DTO @StringId；内部接口凭证过滤器。
  - `mall-admin`（repo-2）：API 类型与页面 ID 改 string 回归（商品/SKU/分类/品牌/库存）。
- 关键不变量:
  - 只有业务 ID 变字符串；金额、库存数量、分页元数据保持 number。
  - internal 接口"无凭证 = 拒绝"，凭证不经过浏览器/网关。
  - 价区只统计 ENABLED SKU；无启用 SKU 商品在任何商城列表（含 CHG-0017 首页位）不可见。

## 2.1 备选方案对比（Alternatives Considered）

| 方案 | 描述 | 优点 | 缺点 | 是否采纳 |
| ---- | ---- | ---- | ---- | -------- |
| A（选中）字段级 @StringId | 仅 DTO 业务 ID 字段序列化为字符串 | 精确；金额/分页不受污染；改造范围可 grep 审计 | 需逐 DTO 标注，略繁琐 | 是 |
| B 全局 Long→String | ObjectMapper 注册 Long/long 统一 ToStringSerializer | 零遗漏 | 金额、total、count 全部变字符串，破坏数值语义与 mall-admin 分页 | 否 |
| C 内部接口 mTLS | 服务间证书互信 | 最强安全 | 本地开发与 M3 阶段成本过高 | 否（M7+ 评估） |
| D 内部接口仅靠网络隔离不校验 | 私网 + 网关 denyAll | 零代码 | 本地/容器同网内任一被攻破服务均可横向调用 | 否（与 A 中共享密钥组合） |

## 3. 仓库影响（Repository Impact）

- 受影响仓库数: 2

### 3.1 repo-1（ai-platform-backend）

- `mall-common/mall-common-web`：新增 `@StringId` 元注解。
- `mall-common/mall-common-security`：新增 `InternalIdentityFilter` + 属性类（servlet 栈服务复用）。
- `mall-gateway`：`GatewaySecurityConfiguration` 白名单保持最小枚举；`/api/internal/**` denyAll 与统一错误体。
- `mall-services/mall-product`：DTO 标注 @StringId（mall 与 admin 对外 DTO 全量）；价区分组聚合 + EXISTS 过滤；内部接口接入凭证过滤器。
- `mall-services/mall-inventory`：新增 MybatisPlusConfig；DTO @StringId；内部接口接入凭证过滤器；SkuClient 携带 `X-Internal-Token`。
- 各服务 `application.yml`：增加 `mall.security.internal.shared-secret` 环境变量占位（本地默认 dev-only 值）。

### 3.2 repo-2（ai-platform-frontend）

- `mall-admin`：`src/api/**` 类型定义中 ID 字段 number→string；列表行 key、路由参数、表单回显、比较逻辑回归；vue-tsc 兜底类型不兼容点。
- `mall-web`：无页面改动（接口层基线已就绪），仅记录后续消费 string ID 的约定。

## 4. 跨仓协作（Cross-Repository Contract）

- 接口契约:
  - 对外契约形态变化：业务 ID 由 JSON number → string（入参双形态兼容期）。错误结构 UnifyResult 不变。
  - 服务间契约：`GET /api/internal/products/{productId}/skus/{skuId}`、`GET /api/internal/products/skus/{skuId}` 增加必传请求头 `X-Internal-Token`；HTTP 401 表示凭证缺失/错误。
- 仓库依赖: repo-2 运行期依赖 repo-1；inventory 运行期直连 product（8103）。
- 集成边界: 网关是浏览器唯一入口；internal 前缀在网关 denyAll；共享密钥经环境变量 `MALL_INTERNAL_SHARED_SECRET` 注入，禁止入库前端。
- Migration Impact: 无 DDL。
- 跨仓时序: repo-1 先行（接口契约冻结）→ repo-2 类型回归与联调。

## 5. Story 设计分派（Story Design Assignments）

| Story ID | 技术要点摘要 | 涉及仓库 | 公共组件/契约归属 |
| -------- | ------------ | -------- | ----------------- |
| STORY-002-03-02-01 | @StringId 注解与全量 DTO 标注；网关白名单/internal denyAll；InternalIdentityFilter 共享凭证；SkuClient 带头；库存分页插件；价区分组 SQL + EXISTS 过滤；mall-admin ID 字符串回归 | repo-1、repo-2 | @StringId、InternalIdentityFilter、价区聚合 mapper 均为本 Story 新增并成为 CHG-0016/17/18 公共依赖 |

### 5.1 公共组件与共享契约

- `@StringId`：mall-common-web 元注解，SSOT 字符串 ID 出参手段。
- `X-Internal-Token`：服务间凭证头 SSOT；属性 `mall.security.internal.shared-secret`。
- 价区口径：`MIN/MAX(product_sku.sale_price) WHERE status='ENABLED'`，整数分。

## 6. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-501 | repo-1 | @StringId + 全 DTO 标注；网关白名单/internal denyAll；InternalIdentityFilter 与 SkuClient 凭证；inventory 分页插件修复；价区聚合与有效 SKU 过滤 | AC-001~010, AC-012 | — |
| DU-FE-501 | repo-2 | mall-admin API 类型与页面 ID 字符串回归（商品/SKU/分类/品牌/库存） | AC-011, AC-012 | DU-BE-501 |

## 7. 风险

- 字符串 ID 改造遗漏：以 grep 审计对外 DTO 包（`interfaces/rest/**/dto`）Long 字段清单 + 集成测试断言 JSON 节点为字符串；金额字段误标风险通过 code review 清单防范。
- mall-admin 回归面广：严格依赖 vue-tsc 编译失败清单逐个修复；路由 query/params 中 ID 均为字符串，禁止数值运算。
- 共享密钥在本地默认值：仅 dev profile 提供默认值；生产缺失密钥时服务启动失败（fail-fast），避免"忘配=裸奔"。
- 价区聚合性能：一条分组 SQL + IN 批量；P95 恶化为 N+1 是唯一红线，测试中断言 SQL 调用次数。

## 8. 待澄清问题

- 无阻塞问题。生产密钥注入方式（环境变量名 `MALL_INTERNAL_SHARED_SECRET`）按现有 JWT 密钥环境变量惯例执行，deploy 侧配置在 M7 部署阶段纳入。
