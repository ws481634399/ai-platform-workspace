# Review Report — STORY-004-02-01-01 模拟支付与订单取消

## 0. 元信息

- Change ID：CHG-0019
- Story ID：STORY-004-02-01-01
- 审查对象：DU-BE-903（repo-1：订单 CAS + inventory 预留 CAS）
- 审查时间：2026-09-17
- 审查者：trae-agent
- 测试报告来源：`evidence/test-report.md`（mall-order 18/18、mall-inventory 28/28 = 基线 24 + 新增 4）

## 1. 检查结论

**通过（PASS）。** 订单状态迁移集中在 `OrderStatus.evaluate`（MUTATED/ALREADY_TARGET/ILLEGAL），pay/cancel 用带 fromStatus 谓词的 CAS UPDATE 原子裁决，rows=0 重读判幂等或冲突；inventory 预留 LOCKED→DEDUCTED/RELEASED 用单条条件 UPDATE 同时完成状态机与库存数量变更，重复请求对已处终态预留直接幂等返回不重复增减；Pay‖Cancel 真并发经 CAS 仲裁恰一方成功，终态与库存副作用一致无撕裂。

## 2. 发现清单

| 编号 | 严重度 | 发现 | 处理 |
|------|--------|------|------|
| F-001 | minor | InventoryApplicationService 缺少 InventoryErrorCode import，编译失败 | 已修复（a06ed4c）：补 import |
| F-002 | minor | 测试种子预置 locked=30 导致并发 release 终态断言失败 | 已修复（a06ed4c）：seedStock 改为 locked=0，由 lock() 产生锁定态 |

无遗留 blocker / major。

## 3. 完成确认

| 检查项 | 结论 |
|--------|------|
| PENDING pay → PAID/paidAt/history(PAY)，预留 DEDUCTED，total/locked 同减 | 通过（TC-001） |
| 重复 pay 200 幂等，confirm 仅一次、库存只扣一次、无新 history | 通过（TC-002） |
| CANCELLED pay B0407；他人/不存在 404 | 通过（TC-003） |
| PENDING cancel → CANCELLED/reason/history(CANCEL)，预留 RELEASED | 通过（TC-004） |
| 重复 cancel 幂等；PAID/SHIPPED/COMPLETED cancel B0407；他人 404 | 通过（TC-005） |
| Pay‖Cancel 真并发：恰一方成功，终态与库存一致 | 通过（TC-006 payCancelConcurrentRace） |
| inventory 重复 release/confirm 不重复变化、返回当前 status；非法态业务错误 | 通过（TC-007 InventoryReleaseConfirmCasTest 4/4） |
| inventory 既有全量回归绿 | 通过（TC-008，28/28） |
| 库存副作用异常订单不回滚，ERROR 含 orderNo/traceId | 通过（TC-009） |

## 4. Deviations

无实质偏离。
