# Implementation（跨仓实施汇总）— 会员订单列表与详情 STORY-004-03-01-01

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0019（M4 订单交易闭环）
- Story：STORY-004-03-01-01 会员订单列表与详情
- 实施日期：2026-09-17

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-904 | repo-1 | 会员分页/状态/时间范围检索、详情聚合与归属校验；OrderApiTest 17/17 |
| DU-FE-902 | repo-2 | mall-web 订单列表/详情页 + 展示工具纯函数；test 90/90、build 成功 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| a06ed4c | DU-BE-904 | repo-1 | feat(order): 会员订单查询与详情聚合 |
| 22ad40f | DU-FE-902 | repo-2 | feat(order): 订单中心列表/详情（含状态 Tab/分页/时间线） |

## 3. 各仓实施引用

- repo-1：
  - `GET /api/mall/orders`：MyBatis-Plus 分页（独立 mybatis-plus-jsqlparser）+ memberId 强制谓词，created_at 倒序；status 必须命中五态枚举（非法 400），startAt/endAt ISO-8601 Instant（start>end 400），size 上限 100
  - `GET /api/mall/orders/{orderNo}`：OrderViewAssembler 聚合订单/商品行快照/收货快照/金额四件套/关键时间/statusHistory 升序
  - 资源归属：memberId 不匹配与不存在统一 B0401 404（不泄露存在性）；未认证 401
- repo-2：
  - OrderListView：?status query 初始化 Tab（全部+五态）、PAGE_SIZE=10、total>size 才显翻页、卡片行摘要（首图/名/数量/合计）、空态、跳详情
  - OrderDetailView：状态标签、收货信息、商品行、金额、关键时间、状态轨迹 timeline（CREATE/PAY/CANCEL/SHIP/CONFIRM_RECEIPT 中文操作）；待付款显支付/取消（取消 prompt 收集原因），操作后以响应替换本地状态并重查
  - utils/order.ts 纯函数（状态映射、canPay/canCancel/canConfirmReceipt、fenToYuan、formatDateTime）+ 5 describe 单测

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | 创建倒序分页、total/pages、size 上限 100 | passed（orderListIsolationAndAdminFilter） |
| AC-002 | 状态筛选与五态映射；非法 status 400；时间范围过滤、start>end 400 | passed（Controller bean 校验 + 应用服务区间校验用例） |
| AC-003 | 仅本人订单可见；详情全字段快照 + history 升序 | passed（orderListIsolationAndAdminFilter、fullHappyPath history 4 条断言） |
| AC-004 | Member A 访问 Member B orderNo 列表与详情均 404；未认证 401 | passed（crossMemberAccess404、authBoundaries） |
| AC-005 | 列表页 Tab/分页/空态/行摘要/跳详情/金额 fen 格式化 | passed（OrderListView + utils 单测 fenToYuan） |
| AC-006 | 详情页全信息 + 待付款支付/取消操作成功后重查 | passed（OrderDetailView + 端到端在 Integration Gate） |
| AC-007 | type-check/lint/test/build 全绿 | passed（mall-web 90/90，lint 0 error，build SUCCESS） |
