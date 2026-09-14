---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-002-03-02-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0015
- Story ID: STORY-002-03-02-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed

## 1. 模块改动（Module Changes）

### repo-1 mall-common-web

- `annotation/StringId.java`：元注解（`@JacksonAnnotationsInside`、`@JsonSerialize(using=ToStringSerializer.class)`、`@Target({FIELD,METHOD,PARAMETER,RECORD_COMPONENT})`、`@Retention(RUNTIME)`）。

### repo-1 mall-common-security

- `InternalIdentityFilter extends OncePerRequestFilter`：仅对配置路径（默认 `/api/internal/**`）生效；校验头 `X-Internal-Token` 与 `mall.security.internal.shared-secret` 一致，失败 401（UnifyResult 错误体）；成功设置 `Authentication`（principal=AuthenticatedSubject[subjectId="SERVICE", subjectType=SERVICE], authority ROLE_SERVICE）。
- `InternalSecurityProperties`：prefix `mall.security.internal`（sharedSecret、path）；`@ConditionalOnProperty` 注册；缺失 secret 且非 dev profile 时启动失败。

### repo-1 mall-gateway

- `GatewaySecurityConfiguration`：白名单仅显式枚举匿名 GET（本 Change：products 列表/详情已在其中，回归实测）；新增 `.pathMatchers("/api/internal/**").denyAll()`（404 响应体由现有 writeError 工具输出，避免暴露内部端点存在性）。

### repo-1 mall-product

- `MallProductDtos`：id/categoryId/brandId/SkuView.id/ImageView.id/AttributeView.id 标注 @StringId（priceInCents 不动）；admin 侧 ProductDtos、分类/品牌 View 同步标注。
- `infrastructure/persistence/product/SkuMapper`（或注解 SQL）：新增分组聚合 `selectPriceRanges(productIds)` → (productId, min, max)；`ProductRepositoryImpl.mallPage()` 增加 EXISTS 启用 SKU 过滤并批量填价区；Controller 不再传 null。
- internal 接入：注册 InternalIdentityFilter（internal 包路径）；安全配置保持 JWT 资源服务器不变。
- `application.yml`：`mall.security.internal.shared-secret: ${MALL_INTERNAL_SHARED_SECRET:dev-internal-secret}`。

### repo-1 mall-inventory

- 新增 `infrastructure/config/MybatisPlusConfig.java`：MybatisPlusInterceptor + PaginationInnerInterceptor(DbType.MYSQL)。
- DTO（InventoryDtos/InternalInventoryDtos）：skuId 等业务 ID @StringId；totalQuantity/lockedQuantity/available 保持 number。
- 注册 InternalIdentityFilter 保护 `/api/internal/inventory/**`；`SkuClient` RestClient 加 `defaultHeader("X-Internal-Token", secret)`（@Value 注入）。

### repo-2 mall-admin

- `src/api/**/*.ts`：业务 ID 类型 number→string（product/sku/category/brand/inventory）；编译驱动修复视图中的类型点；不在 ID 上做算术。

## 2. 接口契约细化

| 方法 | 路径 | 变化 |
| --- | --- | --- |
| GET | /api/mall/products、/{id} | 匿名可访问；ID 输出 string；列表补 minPrice/maxPrice（number，整数分）；过滤无启用 SKU 商品 |
| * | /api/internal/** | 网关 denyAll（外网 404）；服务直连必带 X-Internal-Token，缺失 401 |
| GET | /api/admin/inventory/stocks | total 与实际行数一致；skuId 输出 string |
- 入参：ID 传 `"123"` 或 `123` 均被接受（Jackson/Spring 原生能力 + 关键 Body DTO 抽检测试）。

## 3. 数据变更

- 无 DDL。仅新增 MyBatis-Plus 分页插件配置（inventory）与一条只读分组查询。

## 4. 错误处理

- internal 无凭证：401 `{"success":false,"code":"INTERNAL_UNAUTHORIZED",...}`；网关外部访问 internal：404 同构错误体。
- 价区聚合 SQL 异常：按依赖失败处理（500 业务码），不得返回 null 价区（无启用 SKU 的商品已被过滤）。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-501 | repo-1 | 五项修复全量落地（见 §1） | AC-001~010, AC-012 | — |
| DU-FE-501 | repo-2 | mall-admin ID 字符串类型回归 | AC-011, AC-012 | DU-BE-501 |

## 6. 测试策略

- 后端：网关层 WebTest（匿名 200、internal 404）；InternalIdentityFilter 单测（无头 401/正确头 200）；分页插件集成测试（33 行→total=33、翻页 total 恒定）；价区 mapper 测试（禁用 SKU 后价区变化/商品消失）；JSON 断言 ID 节点是字符串、金额节点是数字；入参双形态参数化测试；grep 审计 dto 包 Long 字段。
- 前端：vue-tsc --noEmit、eslint、build 全绿；商品/库存列表页冒烟（记录 ID 为 string 时 CRUD 正常）。
