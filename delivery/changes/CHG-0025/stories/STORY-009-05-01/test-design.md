# Test Design（TC 测试用例设计）— STORY-009-05-01 消费幂等与补偿机制

## 0. 元信息

- Change ID: CHG-0025
- design 来源: requirement-design.md + stories/STORY-009-05-01/story-design.md
- feature-path: FEAT-009 > FEAT-009-05 > FEAT-009-05-01 > STORY-009-05-01
- TC 总数: 11（AC-033~040 全部有 Story 级验证；AC-034 并发重复消费与 AC-039 真实链路的跨服务运行态证据另在 M7 Integration Gate 3 产出）

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | H2 + Flyway 全迁移集成测试（mall-inventory / mall-order 各一） | AC-033 | DU-BE-005 | V3/V6 迁移成功：consumed_event 列定义/默认值（result=PROCESSING）、uk_event_group(event_id,consumer_group)、idx_aggregate；既有全部迁移零回退 |
| TC-002 | ConsumedEventRepository 单测（mock JdbcTemplate）+ 集成测试占位冲突 | AC-034 | DU-BE-005 | INSERT IGNORE 返回 1→FIRST_PROCESSED、返回 0→DUPLICATE；markResult 按 eventId+group 更新 SUCCESS/SKIPPED；deletePlaceholder；同 eventId 不同 group 视为不同消费；表名白名单拒绝非法标识符。真实并发重复消费运行态归 Gate 3 |
| TC-003 | 单测 PaymentTimeoutCheckHandlerTest 扩展 | AC-035 | DU-BE-005 | systemCancel 抛非 STATUS_CONFLICT 异常 → 调 enqueueOrderAutoCancel(orderId,orderNo,reason,traceId) 后原样重抛；STATUS_CONFLICT 仍归并 skipped 不登记；登记本身失败仅 ERROR 不掩盖原异常 |
| TC-004 | 单测 OrderAutoCancelCompensationHandlerTest | AC-036 | DU-BE-005 | payload 反序列化 → systemCancel(orderId,PAYMENT_TIMEOUT,COMPENSATION)；CANCELLED 幂等返回视为成功；STATUS_CONFLICT 上抛记退避；坏载荷抛 IllegalStateException |
| TC-005 | 单测 CompensationServiceTest（重构后） | AC-036 | DU-BE-005 | 执行器列表按 supports 选择（库存两类/订单取消），无匹配抛异常；enqueueOrderAutoCancel payload=OrderAutoCancelCompensationPayload(orderId,orderNo,eventId)、insertIgnore false 不重复；失败 recordFailure 退避序列 30s→10m、5 次 FAILED_DEAD；MDC traceId 写入/finally remove（AC-039） |
| TC-006 | 单测 CompensationTaskTest 扩展 + AdminCompensationControllerTest 扩展 | AC-037, AC-038 | DU-BE-005 | manualComplete：PENDING/FAILED_DEAD→SUCCESS、nextRetryAt=null、lastError 保留+MANUAL_COMPLETE 标记；SUCCESS 直接返回；complete 不存在 404；compensation-audit 日志含 operator/id/before/after/at |
| TC-007 | 单测 AdminCompensationControllerTest + MyBatis 仓储过滤单测 | AC-037 | DU-BE-005 | operation 白名单（CONFIRM_INVENTORY/RELEASE_INVENTORY/AUTO_CANCEL_ORDER，非法忽略）；aggregateId→businessId LIKE 且 %/_ 转义；status/operation/aggregateId 三筛选组合；分页 size 上限 100；CompensationView 含 payload 原文 |
| TC-008 | mall-identity V15 SQL 核对（仿 V13/V14 对照） | AC-038 | DU-BE-005 | system:compensation:list/retry/complete 三权限、/orders/compensations 菜单 permission_code 更新、SUPER_ADMIN 授权；INSERT IGNORE/ON DUPLICATE/守卫可重复执行 |
| TC-009 | 单测 MDC 贯通断言 + 日志核对 | AC-039 | DU-BE-005 | 补偿执行期间 MDC=task.traceId、结束 remove；systemCancel 下游日志 traceId 同源；payload.eventId 与 consumed_event/Outbox eventId 一致 |
| TC-010 | 前端单测 compensation API spec + CompensationListView 契约 spec | AC-038 | DU-FE-003 | page 新参数 operation/aggregateId URL 与解包；complete POST；操作类型/聚合 ID 筛选控件契约；重试/标记完成二次确认、成功 toast + 刷新；payload 查看区；Dashboard 外链 |
| TC-011 | 回归合集（mall-order/mall-inventory 全量 mvn test + mall-admin vitest run） | AC-040 | DU-BE-005、DU-FE-003 | TC-001~010 全绿；M4/M5 及 S1~S4 既有订单/库存/Outbox/延迟用例零回退 |

覆盖核对：AC-033→TC-001、AC-034→TC-002、AC-035→TC-003、AC-036→TC-004/005、AC-037→TC-006/007、AC-038→TC-006/008/010、AC-039→TC-005/009、AC-040→TC-011；无 TC-NOT-TESTABLE 项。

## 2. 测试策略

- **后端分层**：JUnit5 + Mockito 单测为主，不起 RocketMQ：
  - 迁移：H2 MySQL 模式真实 Flyway 全迁移断言（@SpringBootTest test profile，两模块各自上下文）。
  - 幂等组件：mock JdbcTemplate 验证 SQL 与返回值分支；冲突路径另以集成测试唯一键插入验证。
  - 补偿：执行器/调度服务全部 mock 下游（OrderCancelService/InventoryPort/Repository），verify 调用顺序与 MDC 状态。
  - 控制器直调：参数转译/白名单/审计日志用 logger 或 mock 验证。
- **前端分层**：vitest，HTTP 调用 mock；视图以契约/纯逻辑 spec 覆盖筛选、二次确认与按钮行为。
- **数据准备**：CompensationTask 各状态夹具（register/reconstitute）、consumed_event 行夹具、三类 payload JSON 夹具。
- **不覆盖项**：真实并发重复消费、eventId/traceId 生产→Outbox→投递→消费→补偿真实链路运行态归 Change converge（Integration Gate 3）。
- **环境要求**：后端 `mvn -pl mall-services/mall-order,mall-services/mall-inventory -am test`（Java 21）；前端 mall-admin 目录 `pnpm vitest run`。

## 3. DU 覆盖矩阵

| DU | verifies TC | covers AC |
| --- | --- | --- |
| DU-BE-005（repo-1，[S5]） | TC-001~009、TC-011（后端部分） | AC-033~037, AC-039, AC-040 |
| DU-FE-003（repo-2，[S5]） | TC-010、TC-011（前端部分） | AC-038 |
