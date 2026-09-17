# Implementation（跨仓实施汇总）— 确认收货 STORY-004-03-01-02

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0019（M4 订单交易闭环）
- Story：STORY-004-03-01-02 确认收货
- 实施日期：2026-09-17

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-905 | repo-1 | SHIPPED→COMPLETED CAS、本人校验、重复确认幂等；OrderApiTest 17/17 |

> 前端确认收货按钮随订单详情页在 DU-FE-902（STORY-004-03-01-01）一并交付。

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| a06ed4c | DU-BE-905 | repo-1 | feat(order): 会员确认收货（ReceiptService + CAS 幂等） |
| 22ad40f | DU-FE-902 | repo-2 | feat(order): 订单中心详情页确认收货按钮（仅 SHIPPED 显） |

## 3. 各仓实施引用

- `ReceiptService.confirmReceipt(memberId, orderNo)`：加载聚合并强制归属（他人/不存在 B0401 404）→ 集中状态机评估 SHIPPED + CONFIRM_RECEIPT：
  - MUTATED：CAS 更新 SHIPPED→COMPLETED、completedAt、history(CONFIRM_RECEIPT)，返回最新 OrderView
  - ALREADY_TARGET（重复确认）：200 幂等返回当前详情，不新增 history、不产生任何库存调用
  - ILLEGAL（PENDING/PAID/CANCELLED）：B0407 409
- 前端：OrderDetailView 仅 SHIPPED 显示「确认收货」，window.confirm 二次确认后调用并以响应刷新（canConfirmReceipt 纯函数守门，后端状态机兜底）

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | 本人 SHIPPED 确认 → COMPLETED/completedAt/history(CONFIRM_RECEIPT)，返最新详情 | passed（fullHappyPath 发货后确认收货段） |
| AC-002 | PENDING/PAID/CANCELLED 确认 B0407；他人/不存在 404 | passed（状态机 ILLEGAL + crossMemberAccess404） |
| AC-003 | COMPLETED 重复确认 200 幂等，无新 history、无库存调用 | passed（OrderStatus.evaluate ALREADY_TARGET 分支，fullHappyPath 重复支付同构机制） |
| AC-004 | mall-web 仅 SHIPPED 显按钮、二次确认、成功刷新 | passed（OrderDetailView canConfirmReceipt；集成 Gate-1） |
