---
story-id: "STORY-004-03-01-02"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S5]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §4.4
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-03-01-02 确认收货
- 状态流转: specified → specified（细化）

## 1. Story 目标

会员对已发货（SHIPPED）的本人订单执行确认收货，订单经集中状态机迁移为 COMPLETED 并记录 completedAt 与状态历史；未发货/非本人/重复请求按"首次/非法/幂等"规则处理；mall-web 详情页在待收货状态提供确认收货操作。

## 2. Scope（范围）

### 2.1 包含

- [S5] ReceiptService.confirmReceipt：加载（不存在/非本人 404）→ 聚合解释（SHIPPED→CAS 迁移 COMPLETED + completedAt + history(CONFIRM_RECEIPT,operator=memberId)；COMPLETED→幂等成功；其他→B0407）。
- [S5] `POST /api/mall/orders/{orderNo}/confirm-receipt`（MEMBER）。
- [S5] mall-web 详情页"确认收货"按钮（SHIPPED 显示、二次确认弹层、操作后重查）；随 DU-FE-902 交付。

### 2.2 不包含

- 自动确认收货/超时（后续阶段）；admin 发货（STORY-004-03-02-01）；评价。

## 3. 业务规则

- 仅订单本人；他人/不存在 → 404。
- 仅 SHIPPED 可确认；PENDING_PAYMENT/PAID/CANCELLED → B0407；COMPLETED 重复请求 → 200 当前视图幂等返回，不重复写历史。
- 迁移仅经 Order.confirmReceipt 领域行为 + CAS 条件更新；无库存副作用（库存已在支付时 DEDUCTED）。

## 4. 接口与字段规格

- `POST /api/mall/orders/{orderNo}/confirm-receipt`（MEMBER，无 body）→ OrderDetailView；404；B0407 409。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 本人 SHIPPED 单确认 → COMPLETED、completedAt、history(CONFIRM_RECEIPT)，返回最新详情 |
| AC-002 | PENDING/PAID/CANCELLED 单确认 → B0407；他人/不存在 → 404 |
| AC-003 | COMPLETED 单重复确认 → 200 幂等成功，无新增 history、无库存调用 |
| AC-004 | mall-web 仅 SHIPPED 显示确认收货按钮，二次确认后调用成功并刷新；非 SHIPPED 无按钮 |
