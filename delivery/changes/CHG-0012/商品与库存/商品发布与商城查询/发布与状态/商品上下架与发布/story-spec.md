---
story-id: "STORY-002-03-01-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S1, S2, S7, S8, S9]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 对应行 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0012
- Story ID: STORY-002-03-01-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

在 mall-product 的 Product 聚合根上增加 publish/unpublish 行为，提供商品上架/下架管理端 API（含上架前完整业务校验），注册 ProductPublished/ProductUnpublished 领域事件，并在 mall-admin 商品列表/详情页提供上架/下架操作入口，使后台维护的 DRAFT 商品可被激活为商城可售商品。

## 2. Scope（范围）

### 2.1 包含

- 商品上架（S1）：DRAFT/OFF_SALE→ON_SALE，上架前校验基本信息完整、分类有效、品牌有效、至少一个 ENABLED SKU、SKU 价格合法、主图存在；不满足拒绝。
- 商品下架（S2）：ON_SALE→OFF_SALE；下架后商城不可见，历史快照不受影响。
- 领域事件（S7）：publish 注册 ProductPublishedDomainEvent，unpublish 注册 ProductUnpublishedDomainEvent（聚合内事件）。
- 后台上下架入口（S8）：mall-admin 商品列表/详情页上架/下架按钮。
- RBAC（S9）：product:product:publish 权限码。

### 2.2 不包含

- 商城列表/详情查询（STORY-002-03-02-01）。
- 内部查询契约与商品快照（STORY-002-03-03-01）。
- 库存初始化/扣减（CHG-0013）；上架校验不强制依赖库存初始化状态。
- MQ 事件发布（M7）。

## 3. 业务规则

- 上架校验：商品名称/编码非空、categoryId/brandId 存在且启用、至少一个 status=ENABLED 的 SKU、所有 ENABLED SKU 价格 >= 0、mainImageUrl 非空。
- 状态流转：DRAFT→ON_SALE、OFF_SALE→ON_SALE（重新上架，需重校验）、ON_SALE→OFF_SALE。DISABLED 不可上架。
- 下架仅改 status，不删除商品/SKU。
- 领域事件在聚合行为内注册，不发布 MQ。
- 权限：product:product:publish。

## 4. 接口与字段规格

上架/下架接口：

| 方法 | 路径 | 权限 | 请求 | 响应 |
| --- | --- | --- | --- | --- |
| POST | /api/admin/products/{id}/publish | product:product:publish | - | void |
| POST | /api/admin/products/{id}/unpublish | product:product:publish | - | void |

上架失败错误码：INVALID_ARGUMENT（校验不通过，message 含具体原因）。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | DRAFT 商品含主图+ENABLED SKU+价格合法 → 上架成功，状态 ON_SALE |
| AC-002 | 无主图商品上架 → 拒绝，错误 INVALID_ARGUMENT |
| AC-003 | 无 ENABLED SKU 商品上架 → 拒绝 |
| AC-004 | DISABLED 商品上架 → 拒绝 |
| AC-005 | ON_SALE 商品下架 → 状态 OFF_SALE |
| AC-006 | OFF_SALE 商品重新上架（满足条件）→ 状态 ON_SALE |
| AC-007 | 上架注册 ProductPublished 领域事件；下架注册 ProductUnpublished |
| AC-008 | 无 product:product:publish 权限直调 → 403；有权限 → 成功 |
| AC-009 | mall-admin 商品页可执行上架/下架 |
