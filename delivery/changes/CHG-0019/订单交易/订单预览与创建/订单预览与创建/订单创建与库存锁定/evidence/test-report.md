# Test Report — STORY-004-01-01-02 订单创建与库存锁定

> 阶段：sdd-test 产物。

## 0. 元信息

- Change ID：CHG-0019
- Story ID：STORY-004-01-01-02
- 执行时间：2026-09-17
- 覆盖：AC-001~AC-011
- 实施来源：repo-1 DU-BE-902（a06ed4c）、repo-2 DU-FE-901（22ad40f）。

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| TC-001 | Gate-1 成功交易：预览→下单→支付→发货→收货，lock/confirm 各一次，快照/金额/history 完整 | MockMvc + Redis | passed | OrderApiTest#fullHappyPath |
| TC-002 | Gate-3 预览后调价：下单按服务端二次核价，篡改金额无入口 | MockMvc | passed | OrderApiTest#priceChangedBetweenPreviewAndCreate |
| TC-003 | Gate-4 令牌行指纹漂移（quantity/SKU 不一致）→ 400 B0406 | MockMvc | passed | OrderApiTest#tamperedFingerprintRejected |
| TC-004 | Gate-5a 同 submitToken 双提交 → 第二次 400 B0406，仅 1 单 | MockMvc + Redis DEL 原子消费 | passed | OrderApiTest#duplicateSubmitRejected |
| TC-005 | Gate-2 二次核价库存为 0 → 409 B0404，不锁库不建单 | MockMvc | passed | OrderApiTest#insufficientStockOnCreate |
| TC-006 | Gate-8 锁库中途失败：已锁行立即 RELEASED；release 再失败登记补偿并可人工重试成功 | MockMvc | passed | OrderApiTest#lockMidwayFailureReleasesAndCompensates |
| TC-007 | CART 成功后按令牌行 batch-delete 清购物车 | MockMvc（cart 内部端点） | passed | OrderApiTest#cartSourceClearsPurchasedItems；mall-cart 回归 CartReadApiTest |
| TC-008 | 网关边界：未认证 401、MEMBER 可达、internal 经网关 404 | MockMvc + 网关回归 | passed | OrderApiTest#authBoundaries |
| TC-009 | 结算页：不可下单阻断、提交防双击、成功跳详情、失败重预览重签；双入口 | 前端组件 + 四门（type-check/lint/test/build） | passed | CheckoutView.vue；mall-web 90/90、build SUCCESS |

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| 后端 5 模块 | `mvn -pl mall-order,mall-inventory,mall-member,mall-cart,mall-gateway -am test` | mall-order **18/18**，全模块 0 失败 |
| mall-web | `pnpm test` / `pnpm build` | **90/90**（19 files），build SUCCESS |
| 日志 | `evidence/logs/backend-m4-test.log`、`evidence/logs/frontend-mall-web-test.log`、`frontend-mall-web-build.log` | 完整输出 |

## 3. AC 覆盖

| AC | 覆盖 TC |
|----|---------|
| AC-001 | TC-003、TC-004 |
| AC-002 | TC-003 |
| AC-003 | TC-002 |
| AC-004 | TC-001（地址归属前置） |
| AC-005 | TC-001 |
| AC-006 | TC-005 |
| AC-007 | TC-006 |
| AC-008 | TC-006 |
| AC-009 | TC-007、TC-009 |
| AC-010 | TC-008 |
| AC-011 | TC-009 |
