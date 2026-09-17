---
affected-repositories: [repo-1]
story-id: "STORY-004-02-01-01"
change-design-ref: "requirement-design.md#23-集中状态机与并发"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §2.3/§2.5
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-02-01-01
- 状态流转: specified → designed
- 需要 Migration: no
- 数据变更概要: 无 DDL；inventory_stock/inventory_reservation 新增条件 SQL

## 1. 模块改动（Module Changes）

### mall-order（repo-1）

- Order 聚合方法定型：`pay()`（PENDING→PAID + 内部 pendingHistory；PAID 返回幂等标记；其他抛 STATUS_NOT_ALLOWED）、`cancel(reason)` 同构；迁移规则唯一来自 OrderStatus.NEXT。
- OrderRepository 新增：`int casStatus(CasCommand)`（UPDATE orders SET status=#{to},version=version+1, 时间列=now() WHERE id=#{id} AND status=#{from} AND version=#{version}）；`appendHistory(...)` 在同事务调用；repository 暴露 `@Transactional transitionStatus(...)` 组合方法（CAS+history 原子）。
- PaymentService（无 @Transactional 包裹库存调用）：loadForMember(orderNo,memberId)（404 归一）→ 聚合解释当前状态：
  - PAID：直接返回视图（幂等）；
  - PENDING：transitionStatus CAS；rows=0 → 重读订单再解释（读到 CANCELLED→B0407；PAID→幂等返回）；rows=1 → 提交后逐行 inventoryPort.confirm(orderNo:skuId)，失败 ERROR 日志（STORY-004-04 替换补偿落表），返回 PAID 视图；
  - 其他：B0407。
- OrderCancelService 镜像：CAS CANCELLED + cancelledAt + reason；副作用 release。
- InventoryPort 补 lock/release/confirm 完整方法（lock 在创建 Story 已用）。
- Controller：MemberOrderController 增加 POST /{orderNo}/pay、/{orderNo}/cancel（@RequestBody CancelRequest validated reason 长度）。

### mall-inventory（repo-1，幂等加固，契约不变）

- InventoryMapper 新增：
  - `releaseStock(@Param("skuId") long, @Param("qty") long)`：`UPDATE inventory_stock SET locked_quantity = locked_quantity - #{qty}, updated_at = NOW() WHERE sku_id = #{skuId} AND locked_quantity >= #{qty}`
  - `deductStock(...)`：`SET total_quantity = total_quantity - #{qty}, locked_quantity = locked_quantity - #{qty} WHERE sku_id = #{skuId} AND locked_quantity >= #{qty}`
  - InventoryReservationMapper.casStatus(id,from,to)：`UPDATE inventory_reservation SET status=#{to},updated_at=NOW() WHERE id=#{id} AND status=#{from}`
- InventoryApplicationService.release/confirm 重写（@Transactional）：
  1. 加载 reservation；status 已是目标态 → 直接返回（幂等，不写 stock/log）；
  2. status 与操作冲突（如 release DEDUCTED）→ 抛业务冲突；
  3. casStatus(LOCKED→RELEASED/DEDUCTED) rows=1 → 执行 releaseStock/deductStock 条件 SQL（rows 必须 1，否则抛异常回滚事务）→ 写 log → 返回；rows=0 → 重读 reservation 走 1/2 分支。
- 复用现有 NOW() 与 H2 MODE=MySQL 兼容；既有 release/confirm/lock/availability API 测试必须全绿，新增并发重复用例。

## 2. 接口契约细化

| 方法 | 路径 | 请求 | 响应/错误 |
| --- | --- | --- | --- |
| POST | /api/mall/orders/{orderNo}/pay | — | 200 OrderDetailView；404；B0407 409 |
| POST | /api/mall/orders/{orderNo}/cancel | {reason?≤255} | 200 OrderDetailView；404；B0407 409；400 reason 超长 |

- 内部 inventory /release /confirm 响应体不变；行为差异仅在并发安全与"目标态直接幂等返回"。

## 3. 数据变更

- 无新表。orders 列 paid_at/cancelled_at/cancel_reason 在 V1 已建（上一 Story）。

## 4. 错误处理

- B0407 ORDER_STATUS_NOT_ALLOWED：HTTP 409，message 含当前状态与允许动作。
- confirm/release 依赖失败：503 由 client 归一；本 Story 捕获后不回滚订单、记 ERROR（orderNo/reservationId/traceId/error），返回仍为成功（语义见 requirement-design §2.4）。
- inventory CAS 内部异常：抛 500 并使事务回滚（不应发生；发生说明数据不一致，需人工）。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-903 | repo-1 | pay/cancel 服务与 CAS + 库存 release/confirm 原子加固 + 并发测试 | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009 | 无 |

> 跨 Story 依赖（不入本表 depends-on）：DU-BE-903 实际前置 DU-BE-902（STORY-004-01-01-02，订单聚合/V1/创建链路）。

## 6. 测试策略

- 领域：Order.pay/cancel 三态解释（首次/重复/非法）与 history 追加规则。
- order API 集成：pay/cancel 成功/重复/越权/非法状态；mock inventory confirm/release 单次生效断言。
- 并发：CountDownLatch 两线程 pay||cancel（H2 同库连接），重复 50 轮断言终态唯一且库存调用与终态一致；inventory 侧直接对 service 并发重复 release/confirm 断言库存只变一次、reservation 终态正确。
- 回归：inventory 既有测试套件全绿。
