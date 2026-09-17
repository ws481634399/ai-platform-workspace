---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-004-03-01-01"
change-design-ref: "requirement-design.md#4-跨仓协作cross-repository-contract"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design §4.4
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-03-01-01
- 状态流转: specified → designed
- 需要 Migration: no
- 数据变更概要: 仅读 V1 既有表（用 idx_member_created / idx_status_created）

## 1. 模块改动（Module Changes）

### repo-1 mall-order

- OrderRepository 读方法：`pageForMember(MemberOrderPageQuery)`（WHERE member_id + 可选 status + created_at 区间，ORDER BY created_at DESC,id DESC，MyBatis-Plus Page）；`findDetailByOrderNoForMember(orderNo,memberId)`（聚合 order+items+history 三查询装配）；不存在/非归属均 empty。
- application.order.OrderQueryService：listForMember / getDetailForMember；参数校验（status 枚举、时间区间、分页上限）；assembler 输出 Summary/Detail（读库直出，不调用任何下游服务）。
- MemberOrderController：GET /api/mall/orders、GET /api/mall/orders/{orderNo}。
- DTO：OrderSummaryView/OrderDetailView/StatusHistoryView/ReceiverView/OrderItemView（record，ID 字符串、金额 *Fen、Instant ISO）。

### repo-2 mall-web（DU-FE-902 主体）

- api/order.ts：listOrders(params)/getOrder(orderNo)/payOrder/cancelOrder/confirmReceipt（后两个本 Story 接通）。
- stores/order.ts：ordersPage（list/status/page/size/total/loading）、currentDetail、actions（fetchList/fetchDetail/pay/cancel/confirm 占位）。
- views/order/OrderListView.vue：Tab 条（全部/待支付/待发货/待收货/已完成/已取消与枚举映射常量表）、分页器、行卡片（首图/名称/规格/数量/金额/状态/总件数）、空态；router /orders。
- views/order/OrderDetailView.vue：/orders/:orderNo；顶部状态与操作区（PENDING：立即支付/取消订单（取消原因 prompt/弹层）；其他状态按钮位由后续 Story 补）、地址卡、商品清单、金额明细、物流信息区（发货后显示）、状态历史时间线；操作后 await fetchDetail 重查；404 引导回列表。
- 路由与菜单："我的订单"入口（会员中心/Layout），需登录守卫。

## 2. 接口契约细化

| 方法 | 路径 | 请求 | 响应/错误 |
| --- | --- | --- | --- |
| GET | /api/mall/orders | status?,page,size,startAt?,endAt? | 200 PageView<Summary>；400 参数；401 |
| GET | /api/mall/orders/{orderNo} | — | 200 Detail；404 不存在/越权 |

## 3. 数据变更

无。

## 4. 错误处理

- 404 统一 OrderErrorCode.ORDER_NOT_FOUND（"订单不存在"），不区分越权。
- 参数非法 400 明确字段；时间解析失败 400。
- 前端 detail 404 → 展示"订单不存在"并提供返回入口，不暴露原始错误体。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-904 | repo-1 | 会员分页/详情查询与归属、读模型 assembler | AC-001, AC-002, AC-003, AC-004 | 无 |
| DU-FE-902 | repo-2 | 我的订单列表/详情 + 支付/取消交互（确认收货按钮下一 Story 启用） | AC-005, AC-006, AC-007 | DU-BE-904 |

> 跨 Story 依赖（不入本表 depends-on）：DU-BE-904 前置 DU-BE-902；DU-FE-902 前置 DU-FE-901（STORY-004-01-01-02）与 DU-BE-903（支付/取消后端）。

## 6. 测试策略

- API 集成：多会员多状态造单 → 分页/排序/Tab/时间区间断言；越权 404（含被取消单）；参数 400；详情快照字段完整。
- SQL 索引验证（执行计划/功能层面分页正确即可，M4 不强制 EXPLAIN 断言）。
- 前端 vitest：tab 映射、store 分页与详情加载、详情操作刷新、404 态；组件快照/交互测试。
