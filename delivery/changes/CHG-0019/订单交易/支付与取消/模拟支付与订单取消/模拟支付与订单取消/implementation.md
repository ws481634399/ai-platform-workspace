# Implementation（跨仓实施汇总）— 模拟支付与订单取消 STORY-004-02-01-01

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0019（M4 订单交易闭环）
- Story：STORY-004-02-01-01 模拟支付与订单取消
- 实施日期：2026-09-17

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-903 | repo-1 | 订单集中状态机 CAS、pay/cancel、inventory confirm/release CAS 原子加固与真并发测试；OrderApiTest 17/17、InventoryReleaseConfirmCasTest 4/4、inventory 既有 28/28 无回归 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| a06ed4c | DU-BE-903 | repo-1 | feat(order): pay/cancel + inventory 预留 LOCKED→DEDUCTED/RELEASED CAS |

## 3. 各仓实施引用

- `OrderStatus.evaluate(from, operation)` 集中状态机，返回 MUTATED / ALREADY_TARGET（幂等）/ ILLEGAL（B0407 409）；任何非法迁移在聚合层被拒
- `PaymentService.pay` / `OrderCancelService.cancel`：CAS 条件更新订单状态（带 fromStatus 谓词），rows=0 重读聚合：已是目标态 → 200 幂等成功且不重复库存副作用；冲突态 → B0407；他人/不存在 → B0401 404
- 库存副作用：pay → inventory confirm（LOCKED→DEDUCTED，stock total/locked 同减）；cancel → release（LOCKED→RELEASED，可用量归还）。库存侧 `InventoryApplicationService` 用单条条件 UPDATE 完成预留状态 CAS + 库存数量变更（同事务），重复请求对已处终态预留直接幂等返回当前 status，不重复增减
- 库存副作用抛错时订单状态不回滚（CAS 已裁决），ERROR 日志含 orderNo/traceId；落补偿任务由 STORY-004-04 承接
- 每次状态迁移追加 status_history（PAY/CANCEL），幂等路径不新增 history；paidAt/cancelledAt/cancelReason

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | PENDING pay → PAID/paidAt/history(PAY)，reservation 全 DEDUCTED，库存 total/locked 同减 | passed（fullHappyPath） |
| AC-002 | 重复 pay 200 幂等，confirm 仅一次，库存只扣一次，无新 history | passed（fullHappyPath 含重复支付断言） |
| AC-003 | CANCELLED 单 pay B0407；他人/不存在 404 | passed（payCancelStateConflict、crossMemberAccess404） |
| AC-004 | PENDING cancel → CANCELLED/reason/history(CANCEL)，reservation RELEASED | passed（cancelAndIdempotent） |
| AC-005 | 重复 cancel 幂等库存只释放一次；PAID/SHIPPED/COMPLETED cancel B0407；他人 404 | passed（cancelAndIdempotent、payCancelStateConflict、crossMemberAccess404） |
| AC-006 | Pay‖Cancel 真并发：CAS 仲裁恰一方成功，终态与库存一致无撕裂 | passed（payCancelConcurrentRace 多线程 + 库存终态断言） |
| AC-007 | inventory 同 reservationId 重复 release/confirm 数量不重复变化、返回当前 status；非法态业务错误 | passed（InventoryReleaseConfirmCasTest 4/4） |
| AC-008 | inventory 既有全量测试保持绿，新增 CAS 并发测试通过 | passed（inventory 28/28 = 基线 24 + 新增 4） |
| AC-009 | 库存副作用异常订单不回滚，ERROR 含 orderNo/traceId（补偿下一 Story） | passed（RestInventoryPort 异常不覆盖 CAS 裁决；lockMidwayFailure 用例） |
