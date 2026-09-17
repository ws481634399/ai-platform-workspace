# Test Report — STORY-004-03-01-01 会员订单列表与详情

> 阶段：sdd-test 产物。

## 0. 元信息

- Change ID：CHG-0019
- Story ID：STORY-004-03-01-01
- 执行时间：2026-09-17
- 覆盖：AC-001~AC-007
- 实施来源：repo-1 DU-BE-904（a06ed4c）、repo-2 DU-FE-902（22ad40f）。

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| TC-001 | 多订单创建倒序分页，total/pages 正确，size 上限 100 | MockMvc | passed | OrderApiTest#orderListIsolationAndAdminFilter |
| TC-002 | status 五态筛选；非法 status 400；startAt/endAt 过滤与 start>end 400 | MockMvc | passed | 分页用例 + Controller 参数绑定 |
| TC-003 | 列表仅本人；详情全字段快照、history 升序 | MockMvc | passed | orderListIsolationAndAdminFilter、fullHappyPath |
| TC-004 | Member B 访问 Member A 单号 → 404；未认证 401 | MockMvc | passed | crossMemberAccess404、authBoundaries |
| TC-005 | 列表页 Tab/分页/空态/行摘要/跳详情/金额 fen 格式 | Vitest 纯函数 + 组件四门 | passed | utils/order.spec.ts、OrderListView.vue |
| TC-006 | 详情页状态/地址/商品/金额/时间/轨迹，待付款支付取消后重查 | 组件 + 集成场景 | passed | OrderDetailView.vue；Integration Gate Gate-1 |
| TC-007 | mall-web type-check/lint/test/build | pnpm | passed | 90/90、lint 0 error、build SUCCESS |

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-order | `mvn -pl mall-services/mall-order -am test` | **18/18** |
| mall-web | `pnpm test` / `pnpm build` | **90/90**（19 files），build SUCCESS |
| 日志 | `evidence/logs/backend-m4-test.log`、`frontend-mall-web-test.log`、`frontend-mall-web-build.log` | 完整输出 |

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
