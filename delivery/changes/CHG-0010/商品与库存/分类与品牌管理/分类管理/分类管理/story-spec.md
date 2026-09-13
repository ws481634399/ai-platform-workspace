---
story-id: "STORY-002-01-01-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S1, S2, S3, S4, S8]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 对应行 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0010
- Story ID: STORY-002-01-01-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

在 mall-product 建立 Category 树形聚合，提供分类创建、修改（含层级移动与排序）、分类树查询、启用/禁用能力，并在 mall-admin 提供可视化维护页面，使商品能够被组织进合法、稳定、可控启停的多级分类，为商品 SPU 建模与上架校验提供可信分类主数据。

## 2. Scope（范围）

### 2.1 包含

- 分类创建（S1）：名称、parentId（可空=一级）、sort，层级上限 3 级。
- 分类修改（S2）：改名、移动父分类、改排序；保存时自引用/循环/悬空父级/层级校验。
- 分类查询（S3）：详情查询与一次性返回全量启用+禁用分类树（后台管理需要看到禁用节点）。
- 分类启用/禁用（S4）：状态切换与准入后果（不可被新商品引用、禁用节点不可挂子分类）。
- mall-admin 分类管理页面（S8）：分类树展示、新增、编辑、启停弹窗/表单、权限按钮控制。

### 2.2 不包含

- 品牌维护（STORY-002-01-02-01）。
- 商品/SPU/SKU 实体与绑定关系维护（REQ-M2-002）；本 Story 只提供分类查询与状态供其校验引用。
- 分类物理删除（需求级统一排除，仅禁用）。
- 分类图片、图标字段（M2 不需要）。
- 分类拖拽排序的具体交互形态（实现细节，Design 决定；能力上保证 sort 可改、次序稳定即可）。

## 3. 业务规则

- 层级上限：树深最多 3 级；创建与移动后若 newLevel > 3 → 拒绝。
- 自引用：newParentId == self.id → 拒绝。
- 防循环：移动时若 newParentId 位于当前节点子树内（含后代任意层级）→ 拒绝。
- 悬空父级：newParentId 非空且记录不存在 → 拒绝；parentId 为空表示一级分类。
- 禁用父级：父分类为禁用态时不允许在其下新建子分类。
- 禁用语义：禁用后不出现在商品发布/编辑的可选分类列表；不级联禁用子分类、不影响存量商品数据、不强制下架。
- 排序：同级按 sort 升序，sort 相同按 id 升序保证稳定；sort 为整数。
- 名称：同级分类名称建议不重复（降低误操作），全局分类名允许跨父级重复——硬唯一性只在同级校验提示，不作为数据库全局约束（Design 可在同级落唯一索引）。
- 权限：list/create/update/disable 分别对应 product:category:list/create/update/disable；未授权写操作返回 403。

## 4. 接口与字段规格

字段（Category）：

| 字段 | 类型 | 约束 |
| --- | --- | --- |
| id | long | 主键，系统生成 |
| name | string | 必填，1~32 字符，去首尾空格 |
| parentId | long/null | 空=一级；非空必须存在 |
| level | int | 1~3，由父级推导，不可手工指定 |
| sort | int | 同级排序，默认 0 |
| status | enum | ENABLED / DISABLED，默认 ENABLED |
| createdAt / updatedAt | datetime | 系统维护 |

接口（REST，经网关 /api 前缀，统一 UnifyResult 返回；具体路径 Design 定稿，以下为产品意图）：

- `GET /admin/categories/tree`：全量分类树（含禁用节点，需 list 权限）。
- `GET /admin/categories/{id}`：分类详情。
- `POST /admin/categories`：创建，入参 name/parentId/sort，需 create 权限。
- `PUT /admin/categories/{id}`：修改 name/parentId/sort，需 update 权限；移动做循环与层级校验。
- `PUT /admin/categories/{id}/status`：启用/禁用，入参 status，需 disable 权限。
- 面向商品服务/其他上下文的启用分类选项查询可复用 tree 接口或提供只含启用节点的变体（Design 决定），但本 Story 不输出商品快照类跨上下文契约（属 REQ-M2-003）。

异常响应：父级不存在、循环、自引用、超层级、无权限均返回明确业务错误码与中文提示。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
| --- | --- | --- |
| AC-001 | 给定有权限管理员，提交合法一级分类 → 创建成功，tree 接口根节点含该分类且 level=1。 | |
| AC-002 | 给定一级分类，在其下连续创建到第三级 → 均成功；在第三级下再创建 → 被拒绝并提示最多 3 级。 | |
| AC-003 | 将分类父级设为自身 → 返回业务错误，原父子关系不变。 | 防自引用 |
| AC-004 | 将祖先分类 A 挂到其后代 B 下 → 返回循环错误，A 与 B 子树数据不变。 | 防循环 |
| AC-005 | 创建/移动时 parentId 指向不存在 id → 返回父分类不存在错误。 | 防悬空 |
| AC-006 | 在禁用分类下新建子分类 → 被拒绝；换启用父级后成功。 | 禁用父级 |
| AC-007 | tree 接口一次性返回全部分类（含禁用态标记），嵌套层级正确，同级按 sort、id 稳定排序。 | |
| AC-008 | 禁用某分类后，商品可选分类列表不含该分类；启用后恢复出现；其子分类仍存在且未被级联禁用。 | 禁用准入 |
| AC-009 | 修改同级两个分类 sort 后再次查询，返回次序严格符合 sort 升序、sort 相同按 id 升序。 | 稳定排序 |
| AC-010 | 无 product:category:create/update/disable 权限的身份直调对应接口 → 403 且数据不变；有权限 → 成功。 | RBAC |
| AC-011 | mall-admin 分类页可渲染分类树，并完成新增子分类、编辑改名、上移/下移（或改 sort）、启停操作，页面与接口数据一致且有操作反馈。 | 端到端 |
| AC-012 | 自引用、循环、悬空父级、超层级、禁用父级挂子分类均有领域层自动化测试且通过。 | 核心规则 |
