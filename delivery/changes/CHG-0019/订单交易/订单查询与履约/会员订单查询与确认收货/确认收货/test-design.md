# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-03-01-02
- Feature Path: 订单交易 > 订单查询与履约 > 会员订单查询与确认收货 > 确认收货
- 状态流转: designed → tasked
- TC 总数: 6

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API：SHIPPED 单 confirm-receipt → COMPLETED/completedAt/CONFIRM_RECEIPT history(operator=memberId)；inventoryPort 零交互 | AC-001 | DU-BE-905 | [S5] |
| TC-002 | API：PENDING/PAID/CANCELLED → B0407；他人/不存在 → 404 | AC-002 | DU-BE-905 | [S5] |
| TC-003 | API：COMPLETED 重复确认 → 200 幂等、无新 history、无库存调用 | AC-003 | DU-BE-905 | [S5] |
| TC-004 | 并发：双确认（首次+重复同时）→ CAS 仲裁一条迁移、一条幂等返回 | AC-001,003 | DU-BE-905 | [S5] |
| TC-005 | 前端 vitest：按钮仅 SHIPPED 出现、二次确认弹层、成功重查、B0407 冲突提示后刷新 | AC-004 | DU-FE-902 | [S5] 复用 DU |
| TC-006 | 单测：Order.confirmReceipt 状态解释（首次/幂等/非法） | AC-001~003 | DU-BE-905 | [S5] |

## 2. 测试策略

- H2 真实 CAS 与并发 latch；前端并入 DU-FE-902 测试集。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-903/904；本 Story 与 STORY-004-03-02-01 同属 DU-BE-905，dev 阶段一次性实现收货+发货。
