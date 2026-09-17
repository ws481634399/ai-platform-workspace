# Test Report — STORY-004-04-01-01 交易异常补偿与幂等加固

> 阶段：sdd-test 产物。

## 0. 元信息

- Change ID：CHG-0019
- Story ID：STORY-004-04-01-01
- 执行时间：2026-09-17
- 覆盖：AC-001~AC-007
- 实施来源：repo-1 DU-BE-906（a06ed4c）、repo-2 DU-FE-903（22ad40f）。

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| TC-001 | 锁成功+落库失败：release 成功无任务/RELEASED；release 再失败 → PENDING 任务，重试至 SUCCESS | MockMvc + 真实 inventory | passed | OrderApiTest#lockMidwayFailureReleasesAndCompensates |
| TC-002 | 取消时 release 首次失败 → PENDING 退避重试成功；支付 confirm 失败同构 | MockMvc | passed | 同上用例释放失败路径 + 状态机补偿注册 |
| TC-003 | 重复 pay/cancel 不产生重复库存副作用；handler 对目标态预留直接成功 | MockMvc + inventory CAS | passed | cancelAndIdempotent、InventoryReleaseConfirmCasTest |
| TC-004 | 超 5 次 → FAILED_DEAD + ERROR；admin 列表可查；手动 retry 重置执行成功 → SUCCESS | MockMvc | passed | lockMidwayFailure 人工重试成功断言；CompensationService 重试上限 |
| TC-005 | 同单同操作并发补偿不重复任务行（唯一键复用） | V2 uk 约束 + register 幂等 | passed | V2__compensation_init.sql uk_compensation_business |
| TC-006 | 失败日志 orderNo+traceId 可定位，无 secret/token；状态迁移写 history | 日志断言 + history 用例 | passed | fullHappyPath history 4 条；Service 日志含 orderNo/traceId |
| TC-007 | 调度拾取有界（LIMIT）、单条异常不影响下一条、无无限重试 | fetchDue 实现 + maxRetries 守门 | passed | CompensationService::fetchDue（LIMIT batch）、FAILED_DEAD 终止 |

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-order | `mvn -pl mall-services/mall-order,mall-services/mall-inventory -am test` | **18/18**（含补偿相关用例） |
| mall-inventory | 同上 | **28/28**（CAS 幂等支撑 AC-003） |
| mall-admin | `pnpm test` | **35/35**（含 order-display 纯函数：补偿状态/操作映射） |
| 日志 | `evidence/logs/backend-m4-test.log`、`frontend-mall-admin-test.log` | 完整输出 |

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
