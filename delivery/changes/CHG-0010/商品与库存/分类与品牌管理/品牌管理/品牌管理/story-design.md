---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-002-01-02-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0010
- Story ID: STORY-002-01-02-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed

## 1. 模块改动（Module Changes）

- 涉及仓库: repo-1、repo-2
- 模块改动摘要: mall-product 新增品牌 DDD 四层与 product_brand 建表（与分类同 V1 脚本）；补全 MyBatis-Plus 分页插件；mall-admin 新增品牌分页管理页。ProductSecurityConfiguration、权限码、网关路由由 DU-BE-301 先行落地；分层骨架由分类 DU-BE-302 建立的模式复用。

### 1.1 repo-1（mall-product）

- `infrastructure/persistence/brand/po/BrandPO.java`：`@TableName("product_brand")` 字段 id/name/logo/description/sort/status/createdAt/updatedAt。
- `infrastructure/persistence/brand/mapper/BrandMapper.java`：BaseMapper<BrandPO>，分页与 keyword 模糊查询用 LambdaQueryWrapper（name like、status 等值、orderBy sort,id）。
- `infrastructure/config/MybatisPlusConfig.java`：注册 `MybatisPlusInterceptor` + `PaginationInnerInterceptor(DbType.MYSQL)`（本 Story 落地，分类树不分页但后续商品复用）。
- `domain/brand/`：`Brand` 聚合根（create/rename/updateProfile/disable/enable，名称 trim 与非空校验）、`BrandRepository` 端口（existsByNameExcludeId、page 查询）、`BrandException`。
- `application/brand/BrandApplicationService.java`：`create/update/changeStatus/page/getById`；`@Transactional`；创建/改名前查同名，DuplicateKeyException 兜底转业务错误。
- `interfaces/rest/admin/BrandAdminController.java`：路由 `/api/admin/brands`；方法级 `@PreAuthorize("hasAuthority('product:brand:xxx')")`；DTO：BrandPageRequest(page,size,keyword,status)、SaveBrandRequest、BrandStatusRequest、BrandView、PageResult<BrandView>（UnifyResult 包裹）。

### 1.2 repo-2（mall-admin）

- `src/api/product/brand.ts`：page/get/create/update/changeStatus，类型定义 BrandItem/BrandQuery/SavePayload。
- `src/views/product/BrandListView.vue`：el-table 分页列表（ID/Logo 缩略图/名称/描述/排序/状态/操作）、顶部名称关键字搜索 + 状态筛选、新增/编辑 el-dialog 表单（Logo 仅 URL 输入框）、启停二次确认、ElMessage 反馈。
- `src/router/component-registry.ts`：登记 `BrandList`。

## 2. 接口契约细化

基 `/api/admin/brands`，统一 UnifyResult；权限码 product:brand:*。

| 方法与路径 | 权限码 | 入参 | 成功输出/错误 |
| --- | --- | --- | --- |
| GET / | product:brand:list | query: page(默认1),size(默认10),keyword(可空),status(可空) | data: {records:[BrandView],total,page,size}；按 sort,id 排序 |
| GET /{id} | product:brand:list | path id | BrandView；不存在 → 业务错误 |
| POST / | product:brand:create | {name 1~64 trim 唯一, logo?(url<=512), description?(<=255), sort 默认0} | 新 id；同名（trim 后、大小写不敏感）→ 业务错误 |
| PUT /{id} | product:brand:update | 同 POST（可改全部字段） | 改名撞唯一 → 业务错误，原值不变 |
| PUT /{id}/status | product:brand:disable | {status} | 最新状态 |

名称大小写不敏感策略：数据库列使用默认排序规则（MySQL 8 utf8mb4_0900_ai_ci 即大小写不敏感），唯一索引天然拦截大小写差异；应用层 trim 后比较，错误提示统一为"品牌名称已存在"。

## 3. 数据变更

- 是否需 Migration: 是
- 变更摘要（mall_product 库 V1 后半段，与分类同一脚本）：
  - `product_brand`：id BIGINT PK AI；name VARCHAR(64) NOT NULL；logo VARCHAR(512) NULL；description VARCHAR(255) NULL；sort INT NOT NULL DEFAULT 0；status VARCHAR(16) NOT NULL DEFAULT 'ENABLED'；created_at/updated_at DATETIME NOT NULL；UNIQUE KEY uk_product_brand_name(name)；INDEX idx_sort(sort,id)。

## 4. 错误处理

- 名称重复（创建/改名）：先应用层 existsByName 预判并抛 BrandException；并发漏网由 uk_product_brand_name 触发 DuplicateKeyException 后转同一业务错误（AC-009 并发恰好一个成功）。
- 字段超长/非法 URL 形态：@Valid 校验（logo 做 URL/ObjectKey 字符串长度与形态校验，不校验可达性）。
- 401/403：ProductSecurityConfiguration 统一处理。
- 分页参数越界：page<1 归一为 1、size 上限 100 截断，避免大查询。

## 5. DU 划分（Delivery Units）

| DU | 仓库 | 职责 | covers AC | depends on |
| --- | --- | --- | --- | --- |
| DU-BE-303 | repo-1 | 品牌表、聚合、唯一/分页/启停、REST、测试 | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-009 | — |
| DU-FE-302 | repo-2 | 品牌列表管理页与 API 封装、组件注册 | AC-008 | DU-BE-303 |

> 跨 Story 公共前置（安全配置/权限码注册/网关路由）由分类 Story 的 DU-BE-302 落地（requirement-design §6 依赖图：DU-BE-303 depends on DU-BE-302）；本 Story 实现时该前置必须已合入 repo-1，故本表内 DU 依赖列为 —。

## 6. 测试策略

- 领域/应用单测：trim 同名、大小写同名、改名撞名与改名成功、禁用语义、sort 默认与排序、分页参数归一。
- API 集成测试：分页 total/page/size 与 keyword 过滤、status 过滤；唯一冲突路径返回业务错误；无权限 403、有权限 200（AC-007）。
- 并发测试：并发插入同名（可在集成测试中开两个事务/线程）断言恰一成功（AC-009）。
- 前端：构建通过 + 浏览器验证分页、搜索、增改、启停、Logo URL 表单与权限按钮显隐（AC-008）。
