---
affected-repositories: [repo-1]
story-id: "STORY-004-03-01-02"
change-design-ref: "requirement-design.md#23-集中状态机与并发"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design §2.3/§4.4
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-03-01-02
- 状态流转: specified → designed
- 需要 Migration: no
- 数据变更概要: 无（completed_at 列 V1 已建）

## 1. 模块改动（Module Changes）

### repo-1 mall-order（DU-BE-905 的收货部分）

- Order.confirmReceipt()：SHIPPED→COMPLETED 迁移 + completedAt=now + history；COMPLETED 返回幂等标记；其余 STATUS_NOT_ALLOWED。
- OrderRepository CAS 复用 STORY-004-02-01-01 的 transitionStatus（时间列为 completed_at，操作 CONFIRM_RECEIPT）。
- application.order.ReceiptService：loadForMember→解释→CAS（rows=0 重读解释）；无库存调用。
- MemberOrderController：POST /{orderNo}/confirm-receipt。

### repo-2 mall-web（DU-FE-902 内）

- OrderDetailView：SHIPPED 状态显示"确认收货"按钮 + 确认弹层；成功后 detail 重查；B0407 冲突时提示并刷新。

## 2. 接口契约细化

| 方法 | 路径 | 请求 | 响应/错误 |
| --- | --- | --- | --- |
| POST | /api/mall/orders/{orderNo}/confirm-receipt | — | 200 Detail；404；B0407 409 |

## 3. 数据变更

无。

## 4. 错误处理

- B0407 文案"当前状态不允许确认收货"；前端收到后重查详情同步真实状态。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-905 | repo-1 | （本 Story 部分）确认收货 CAS COMPLETED；同 DU 另含 admin 查询发货（STORY-004-03-02-01） | AC-001, AC-002, AC-003 | 无 |

> 跨 Story 依赖与复用（不入本表）：DU-BE-905 实际前置 DU-BE-903、DU-BE-904；AC-004 的前端"确认收货"按钮并入 STORY-004-03-01-01 的 DU-FE-902 交付（实体在其 Feature Path 下），本 Story test-design TC-005 仅做归属标注。

## 6. 测试策略

- API 集成：五状态下 confirm 的首次/非法/幂等矩阵；越权 404；history 仅一条 CONFIRM_RECEIPT；断言无 inventory 调用。
- 前端：按钮仅 SHIPPED 出现、确认弹层、成功刷新、冲突提示。
