# Test Report — STORY-004-03-01-02 确认收货

> 阶段：sdd-test 产物。

## 0. 元信息

- Change ID：CHG-0019
- Story ID：STORY-004-03-01-02
- 执行时间：2026-09-17
- 覆盖：AC-001~AC-004
- 实施来源：repo-1 DU-BE-905（a06ed4c）；前端在 DU-FE-902（22ad40f）。

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| TC-001 | 本人 SHIPPED 确认 → COMPLETED、completedAt、history(CONFIRM_RECEIPT)、返最新详情 | MockMvc | passed | OrderApiTest#fullHappyPath 收货段（statusHistory 4 条） |
| TC-002 | PENDING/PAID/CANCELLED 确认 → 409 B0407；他人/不存在 → 404 | MockMvc（状态机 + 归属） | passed | OrderStatus 评估 + crossMemberAccess404 |
| TC-003 | COMPLETED 重复确认 200 幂等，无新 history、无库存调用 | MockMvc（ALREADY_TARGET 分支） | passed | fullHappyPath 重复操作幂等机制（与重复 pay/cancel 同构） |
| TC-004 | mall-web 仅 SHIPPED 显按钮、二次确认、成功刷新 | Vitest 守门函数 + 组件 | passed | utils/order.spec.ts canConfirmReceipt；OrderDetailView |

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-order | `mvn -pl mall-services/mall-order -am test` | **18/18** |
| mall-web | `pnpm test`（90/90） | canConfirmReceipt/状态映射单测通过 |
| 日志 | `evidence/logs/backend-m4-test.log`、`frontend-mall-web-test.log` | 完整输出 |

## 3. AC 覆盖

| AC | 覆盖 TC |
|----|---------|
| AC-001 | TC-001 |
| AC-002 | TC-002 |
| AC-003 | TC-003 |
| AC-004 | TC-004 |
