---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-002-01-01-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0010
- Story ID: STORY-002-01-01-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed

## 1. 模块改动（Module Changes）

- 涉及仓库: repo-1、repo-2
- 模块改动摘要: mall-product 新增分类 DDD 四层与 V1 建表（product_category）；mall-admin 新增分类树管理页。安全配置、权限码注册、网关路由由 Requirement 级 DU-BE-301 先行落地，本 Story 直接依赖。

### 1.1 repo-1（mall-product / mall-gateway / mall-identity）

- `infrastructure/persistence/category/po/CategoryPO.java`：`@TableName("product_category")` 字段 id/name/parentId/level/sort/status/createdAt/updatedAt。
- `infrastructure/persistence/category/mapper/CategoryMapper.java`：继承 MyBatis-Plus BaseMapper；自定义按父级查同级、统计子节点、按 id 集合加载的方法（LambdaQueryWrapper，无 XML）。
- `infrastructure/persistence/category/CategoryRepositoryImpl.java`：实现 domain Repository 端口。
- `infrastructure/persistence/category/CategoryTreeAssembler.java`：平铺列表 → 多级树 DTO。
- `domain/category/`：`Category`（聚合根，含 rename/move/disable/enable 行为与不变量）、`CategoryLevel`（常量 MAX=3、ROOT_PARENT_ID=0）、`CategoryRepository`（端口）、`CategoryTree`、`CategoryException`（BusinessException 子类 + 错误码）。
- `application/category/CategoryApplicationService.java`：`createTreeRoot/createChild/update/move/changeStatus/loadTree/getById`；`@Transactional`；移动时执行父链加载与循环/层级判定；唯一性冲突（DuplicateKeyException）转 CategoryException。
- `interfaces/rest/admin/CategoryAdminController.java`：路由 `/api/admin/categories`；`@PreAuthorize("hasAuthority('product:category:xxx')")`；DTO：CreateCategoryRequest/UpdateCategoryRequest/CategoryStatusRequest/CategoryView/CategoryTreeView；javax.validation 校验。
- 资源文件：`db/migration/V1__create_product_category_and_brand.sql` 中 product_category 段（DU-BE-303 同脚本追加 brand 段，同 V1）。

### 1.2 repo-2（mall-admin）

- `src/api/product/category.ts`：tree/get/create/update/changeStatus 五个方法，类型定义 CategoryNode/CreatePayload。
- `src/views/product/CategoryTreeView.vue`：el-tree（或 el-table tree）展示全量分类（含禁用置灰）、节点上"新增子级/编辑/启停/排序"操作、el-dialog 表单（名称/父级/排序）、ElMessage 反馈。
- `src/router/component-registry.ts`：登记 `CategoryTree: () => import('../views/product/CategoryTreeView.vue')`。

## 2. 接口契约细化

基 `/api/admin/categories`，统一 UnifyResult；权限码 product:category:*。

| 方法与路径 | 权限码 | 入参 | 成功输出/错误 |
| --- | --- | --- | --- |
| GET /tree | product:category:list | 无 | data: CategoryTreeView[]（id,name,parentId,level,sort,status,children[]），含禁用节点 |
| GET /{id} | product:category:list | path id | CategoryView；不存在 → 业务错误 404 语义 |
| POST / | product:category:create | {name 1~32, parentId(可空→0), sort 默认0} | 201/200 + 新 id；父不存在/禁用父/超 3 级/同级重名 → 业务错误 |
| PUT /{id} | product:category:update | {name,parentId,sort} | 同上，另加自引用/循环错误 |
| PUT /{id}/status | product:category:disable | {status: ENABLED\|DISABLED} | 当前最新状态 |

移动判定算法（application 层）：
1. target=load(parentId)；为空且 parentId≠0 → 父不存在；parentId==id → 自引用。
2. 沿 parentId 向上最多 3 跳，若途经 id 即"新父在原子树"→ 循环；target.level+1>3（移动带子树时按"新父深度 + 原子节点最大相对深度"校验）→ 超层级。
3. 更新本节点 level；子树 level 递归重算（3 级上限内数量极小，同事务批量 update）。

## 3. 数据变更

- 是否需 Migration: 是
- 变更摘要（mall_product 库 V1 前半段）：
  - `product_category`：id BIGINT PK AI；name VARCHAR(32) NOT NULL；parent_id BIGINT NOT NULL DEFAULT 0；level TINYINT NOT NULL；sort INT NOT NULL DEFAULT 0；status VARCHAR(16) NOT NULL DEFAULT 'ENABLED'；created_at/updated_at DATETIME NOT NULL；INDEX idx_parent_sort(parent_id,sort,id)；UNIQUE KEY uk_parent_name(parent_id,name)。
  - 无跨库外键（微服务自治库），层级合法性由应用层保证。

## 4. 错误处理

- 父分类不存在 / 自引用 / 形成循环 / 超过 3 级 / 禁用父下建子级 / 同级重名：抛 CategoryException(BusinessException)，由 GlobalExceptionHandler 转 UnifyResult + 4xx，中文 message；错误码在 product 模块定义 `PRODUCT_CATEGORY_*` 常量。
- 数据库唯一索引并发冲突：捕获 DuplicateKeyException 转"同级分类名称已存在"。
- 401/403：由 ProductSecurityConfiguration 统一 JSON 输出（DU-BE-301）。
- 参数非法：@Valid → MethodArgumentNotValidException 既有处理。

## 5. DU 划分（Delivery Units）

| DU | 仓库 | 职责 | covers AC | depends on |
| --- | --- | --- | --- | --- |
| DU-BE-302 | repo-1 | 分类表、聚合、不变量、REST、测试 | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010, AC-012 | — |
| DU-FE-301 | repo-2 | 分类树管理页与 API 封装、组件注册 | AC-011 | DU-BE-302 |

> 公共前置（安全配置/权限码注册/网关路由，requirement-design §6）已并入 DU-BE-302 内部先置任务；DU-BE-303（品牌 Story）在 Change 级依赖图中依赖 DU-BE-302。

## 6. 测试策略

- 领域单测（H2/纯 JUnit）：建根/建子到 3 级、第四级拒绝、自引用、祖先挂后代循环、悬空父、禁用父挂子级、同级重名、移动后子树 level 重算、sort/id 稳定排序。
- API 集成测试（mall-common-test 基线，Mock JWT/切片权限）：tree 返回结构与排序；各错误路径 4xx；无权限身份 403、有权限 200（AC-010）；禁用语义不级联。
- 前端（sdd-test 阶段）：构建通过 + 手工/浏览器验证树渲染、新增子级、编辑、启停、权限按钮显隐（AC-011 证据截图/记录）。
