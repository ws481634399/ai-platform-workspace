# Test Report — STORY-004-03-02-01 后台订单查询与发货

> 阶段：sdd-test 产物。

## 0. 元信息

- Change ID：CHG-0019
- Story ID：STORY-004-03-02-01
- 执行时间：2026-09-17
- 覆盖：AC-001~AC-007
- 实施来源：repo-1 DU-BE-907（a06ed4c）、repo-2 DU-FE-903（22ad40f）。

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| TC-001 | admin 按 orderNo/memberId/status/时间组合检索、分页排序 | MockMvc | passed | OrderApiTest#orderListIsolationAndAdminFilter |
| TC-002 | 详情字段完整、history 可作订单轨迹 | MockMvc | passed | fullHappyPath admin 详情段 |
| TC-003 | PAID 发货 → SHIPPED/物流字段/shippedAt/history(SHIP,operator) | MockMvc | passed | fullHappyPath 发货段 |
| TC-004 | PENDING/CANCELLED/COMPLETED 发货 409 B0407；重复发货幂等仅一条 SHIP | MockMvc | passed | 状态机 ILLEGAL/ALREADY_TARGET |
| TC-005 | 物流字段缺失/超长 400；订单不存在 404 | MockMvc | passed | ShipRequest validation + 404 用例 |
| TC-006 | 无 order:ship 管理员 403；MEMBER 访问 admin 403 | MockMvc | passed | authBoundaries（会员 JWT /api/admin → 403） |
| TC-007 | mall-admin 列表/详情/发货弹窗可用、菜单按权限、四门全绿 | pnpm + Vite | passed | mall-admin 35/35、type-check 0、lint 0 error、build SUCCESS |

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-order | `mvn -pl mall-services/mall-order -am test` | **18/18** |
| mall-identity | `mvn -pl mall-services/mall-identity test`（含 V8 迁移） | **79/79** |
| mall-admin | `pnpm type-check && pnpm test && pnpm build` | type-check 0 error、**35/35**、build SUCCESS |
| 日志 | `evidence/logs/backend-m4-test.log`、`backend-mall-identity-test.log`、`frontend-mall-admin-*.log` | 完整输出 |

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
