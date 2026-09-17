# Test Report — STORY-004-02-01-01 模拟支付与订单取消

> 阶段：sdd-test 产物。

## 0. 元信息

- Change ID：CHG-0019
- Story ID：STORY-004-02-01-01
- 执行时间：2026-09-17
- 覆盖：AC-001~AC-009
- 实施来源：repo-1 DU-BE-903（a06ed4c）。

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| TC-001 | PENDING pay：PAID/paidAt/history(PAY)，预留全 DEDUCTED，total/locked 同减 | MockMvc | passed | OrderApiTest#fullHappyPath |
| TC-002 | 重复 pay：第二次 200 幂等，confirm 仅一次、库存只扣一次、无新 history | MockMvc（计数 inventory 调用） | passed | fullHappyPath 重复支付段 |
| TC-003 | CANCELLED pay → 409 B0407；他人/不存在 → 404 | MockMvc | passed | payCancelStateConflict、crossMemberAccess404 |
| TC-004 | PENDING cancel：CANCELLED/cancelledAt/reason/history(CANCEL)，预留 RELEASED、可用量归还 | MockMvc | passed | cancelAndIdempotent |
| TC-005 | 重复 cancel 幂等（release 1 次）；PAID/SHIPPED/COMPLETED cancel B0407；他人 404 | MockMvc | passed | cancelAndIdempotent、payCancelStateConflict、crossMemberAccess404 |
| TC-006 | Gate-7 Pay‖Cancel 真并发：恰一方成功，PAID 必 DEDUCTED / CANCELLED 必 RELEASED | 多线程 + JDBC 终态断言 | passed | OrderApiTest#payCancelConcurrentRace |
| TC-007 | inventory 同 reservationId 重复 release/confirm 数量不重复变化、返回当前 status；非法态业务错误 | H2 + 条件 UPDATE | passed | InventoryReleaseConfirmCasTest 4/4 |
| TC-008 | inventory 既有全量回归（领域/管理端/内部端点/安全/冒烟） | mvn test | passed | mall-inventory 28/28（基线 24 + 新增 4） |
| TC-009 | 库存副作用异常时订单 CAS 裁决不回滚，ERROR 含 orderNo/traceId | MockMvc（端口异常注入） | passed | lockMidwayFailureReleasesAndCompensates 错误路径 |

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-order | `mvn -pl mall-services/mall-order,mall-services/mall-inventory -am test` | **18/18** |
| mall-inventory | 同上 | **28/28**（新增 InventoryReleaseConfirmCasTest 4），0 failures/0 errors |
| 日志 | `delivery/changes/CHG-0019/evidence/logs/backend-m4-test.log` | 完整 Maven 输出 |

## 3. AC 覆盖

| AC | 覆盖 TC |
|----|---------|
| AC-001 | TC-001 |
| AC-002 | TC-002 |
| AC-003 | TC-003 |
| AC-004 | TC-004 |
| AC-005 | TC-005 |
| AC-006 | TC-006 |
| AC-007 | TC-007 |
| AC-008 | TC-008 |
| AC-009 | TC-009 |
