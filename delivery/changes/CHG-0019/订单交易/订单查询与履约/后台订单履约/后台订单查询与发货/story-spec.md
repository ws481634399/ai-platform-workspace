---
story-id: "STORY-004-03-02-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S6]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §4.4
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-03-02-01 后台订单查询与发货
- 状态流转: specified → specified（细化）

## 1. Story 目标

运营在 mall-admin 按 orderNo/会员/状态/时间范围检索订单、查看完整详情与状态轨迹，并对 PAID 订单录入物流公司与运单号执行发货（PAID→SHIPPED）；接口受 M1 RBAC 保护（权限码 order:list/order:view/order:ship），发货经集中状态机，非法状态拒绝、重复发货幂等。

## 2. Scope（范围）

### 2.1 包含

- [S6] `GET /api/admin/orders`：orderNo（精确/前缀）、memberId、status、时间范围、分页；无归属过滤；`GET /api/admin/orders/{orderNo}` 全详情（含 memberId）。
- [S6] `POST /api/admin/orders/{orderNo}/ship` `{deliveryCompany,trackingNo}`：校验非空/长度；SHIPPED→幂等返回；非 PAID→B0407；PAID→CAS SHIPPED + shippedAt + 物流列 + history(SHIP,operator=admin username)。
- [S6] 方法级 @PreAuthorize 权限码；网关 ADMIN 路由（已在创建 Story 配 yml）。
- [S6] mall-admin DU-FE-903：订单列表页（搜索栏/分页/状态）、详情页（轨迹+发货弹窗）、动态菜单与权限码初始化。

### 2.2 不包含

- 真实物流对接；批量发货；补偿管理端点（STORY-004-04-01-01）；售后。

## 3. 业务规则

- 仅 ADMIN + 权限码；MEMBER 访问 /api/admin/** → 403。
- 发货仅 PAID→SHIPPED；PENDING_PAYMENT/CANCELLED/COMPLETED → B0407；SHIPPED 重复请求 → 200 幂等返回（若 body 物流信息与已存不同，以首次为准并忽略差异，不重复写历史）。
- deliveryCompany 必填 1–64；trackingNo 必填 1–64；非法 → 400。
- 列表 orderNo 查询为精确匹配（完整 orderNo）；memberId 精确；时间区间按 created_at。
- operator 取当前管理员 username（SecurityContext）。

## 4. 接口与字段规格

- `GET /api/admin/orders?orderNo=&memberId=&status=&page=&size=&startAt=&endAt=`（order:list）→ PageView<AdminOrderSummary>（含 memberId）。
- `GET /api/admin/orders/{orderNo}`（order:view）→ OrderDetailView。
- `POST /api/admin/orders/{orderNo}/ship`（order:ship）→ OrderDetailView；400/404/B0407。
- 错误：403 权限不足；401 未认证。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 多条件组合检索正确（orderNo/memberId/status/时间），分页排序正确 |
| AC-002 | 详情字段完整、history 可用于订单轨迹展示 |
| AC-003 | PAID 单发货成功 → SHIPPED、delivery_company/tracking_no/shippedAt、history(SHIP,operator) |
| AC-004 | PENDING/CANCELLED/COMPLETED 发货 → B0407；重复发货幂等返回且仅一条 SHIP 历史 |
| AC-005 | 物流字段缺失/超长 → 400；订单不存在 → 404 |
| AC-006 | 无 order:ship 权限码的管理员 → 403；MEMBER 访问 admin 接口 → 403 |
| AC-007 | mall-admin 列表/详情/发货弹窗可用，菜单按权限出现；type-check/lint/test/build 全绿 |
