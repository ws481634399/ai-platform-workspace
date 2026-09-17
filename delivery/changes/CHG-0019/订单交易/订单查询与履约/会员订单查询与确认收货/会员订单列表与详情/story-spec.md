---
story-id: "STORY-004-03-01-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S4]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §4.4
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-03-01-01 会员订单列表与详情
- 状态流转: specified → specified（细化）

## 1. Story 目标

会员可分页查看本人订单（状态 Tab + 时间范围）并查看完整订单详情（商品/地址/金额快照、关键时间、物流、状态历史）；所有接口强制 memberId 资源归属，猜 orderNo 越权一律 404；mall-web 交付我的订单列表页与订单详情页（详情页同时承载后续支付/取消/确认收货按钮位，本 Story 先出只读 + 待支付操作随 DU-FE-902 一次接通）。

## 2. Scope（范围）

### 2.1 包含

- [S4] `GET /api/mall/orders`：memberId 强制过滤、status 可选（枚举校验）、startAt/endAt、page/size（≤100）、createdAt 倒序；OrderSummaryView 列表（orderNo/status/金额/行数与首条摘要/createdAt/keyTime）。
- [S4] `GET /api/mall/orders/{orderNo}`：完整 OrderDetailView（items 全快照、receiver、金额三项、物流、cancelReason、全部时间、statusHistory 升序）。
- [S4] 归属：findByOrderNoForMember 不区分不存在与非本人 → 404 ORDER_NOT_FOUND。
- [S4] mall-web DU-FE-902 主体：api/order 查询、stores/order、OrderListView（Tab/分页/空态）、OrderDetailView（状态条/历史时间线/地址卡/商品金额/物流）；支付/取消按钮在本 Story 接通（后端已上线）；确认收货按钮位随 STORY-004-03-01-02 启用。

### 2.2 不包含

- 确认收货动作（STORY-004-03-01-02）；admin 查询/发货（STORY-004-03-02-01）；补偿管理。

## 3. 业务规则

- 状态 Tab：全部（不传）/待支付 PENDING_PAYMENT/待发货 PAID/待收货 SHIPPED/已完成 COMPLETED/已取消 CANCELLED；非法 status 参数 400。
- 时间范围：startAt/endAt ISO-8601（含端点，按 created_at）；start>end → 400。
- 分页：page 默认 1、size 默认 10 上限 100；返回 total/pages。
- 列表只返回本人订单；排序 created_at DESC, id DESC。
- 详情快照原样读库（不再调 product/inventory）；历史按 occurred_at ASC。
- 越权响应 404 且响应体不含"订单存在但无权限"区分。

## 4. 接口与字段规格

- `GET /api/mall/orders?status=&page=1&size=10&startAt=&endAt=`（MEMBER）→ `PageView<OrderSummaryView>{records,total,page,size}`；SummaryView：`{orderNo,status,goodsAmountFen,payAmountFen,itemCount,firstItem:{mainImageUrl,productName,skuCode,quantity,unitPriceFen},createdAt,keyTime}`。
- `GET /api/mall/orders/{orderNo}` → OrderDetailView（requirement-design §4 全字段）。
- 401 未认证；404 不存在/越权；400 参数非法。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 多订单按创建倒序分页，total/pages 正确，size 上限 100 |
| AC-002 | 六个 Tab 筛选与领域状态映射正确；非法 status → 400；时间范围过滤正确、start>end → 400 |
| AC-003 | 列表仅含本人订单；详情返回全字段快照与升序 statusHistory，数据取自落库快照 |
| AC-004 | Member A 访问 Member B 的 orderNo → 404（列表与详情均不可见）；未认证 401 |
| AC-005 | mall-web 列表页：Tab/分页/空态/行摘要，点击进详情；金额 fen 格式化正确 |
| AC-006 | mall-web 详情页：状态、地址快照、商品行、金额、关键时间、状态历史时间线完整；待支付单展示支付/取消并可操作成功后重查 |
| AC-007 | type-check/lint/test/build 全绿 |
