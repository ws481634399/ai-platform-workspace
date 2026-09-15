# Test Report — STORY-003-02-03-01 SKU 可售状态聚合

> 阶段：sdd-test 产物。

## 0. 元信息

- Change ID：CHG-0017
- Story ID：STORY-003-02-03-01
- 执行时间：2026-09-15
- 覆盖：AC-015、AC-016、AC-017
- 测试基线：repo-1 `mvn -pl mall-services/mall-inventory test`（24/24）、`mvn -pl mall-services/mall-product test`（81/81）。

## 1. TC 执行结果

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| TC-001 | 批量精确数量、无记录=0、按顺序 | MockMvc + JDBC fixture | passed | InternalInventoryAvailabilityApiTest::batchAvailableQty |
| TC-002 | product 一次 inventory 调用（无 N+1） | @MockBean | passed | MallSkuAvailabilityApiTest |
| TC-003 | 三态映射 0/1-9/≥10 | MockMvc | passed | MallSkuAvailabilityApiTest::threeStateMapping |
| TC-004 | 白名单 DTO 无数量字段 | MockMvc | passed | MallSkuAvailabilityApiTest::whitelistNoQuantity |
| TC-005 | inventory 故障 → UNKNOWN，HTTP 200 | @MockBean throw | passed | MallSkuAvailabilityApiTest::degradationOnInventoryFailure |
| TC-006 | 空/>100/非正 400；无 token 401 | MockMvc | passed | 两模块校验测试 |

合计：10 passed / 0 failed / 0 skipped。

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-inventory | `mvn -pl mall-services/mall-inventory test` | 24/24（新增 4 + 既有 20） |
| mall-product | `mvn -pl mall-services/mall-product test` | 81/81（新增 6 + 既有 75） |

## 3. 红→绿记录

无红基线（首跑即绿）。

## 4. AC 覆盖

| AC | 覆盖 TC |
|----|---------|
| AC-015 | TC-001, TC-006 |
| AC-016 | TC-003, TC-004 |
| AC-017 | TC-005 |
