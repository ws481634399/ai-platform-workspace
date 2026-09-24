# Test Design（TC 测试用例设计）— STORY-009-04-01 延迟订单自动取消

## 0. 元信息

- Change ID: CHG-0025
- design 来源: requirement-design.md + stories/STORY-009-04-01/story-design.md
- feature-path: FEAT-009 > FEAT-009-04 > FEAT-009-04-01 > STORY-009-04-01
- TC 总数: 10（AC-026~032 全部有 Story 级验证；AC-027/029/030 的真实跨服务运行态证据另在 M7 Integration Gate 产出）

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 单测 DelayLevelMapperTest | AC-026 | DU-BE-004 | 向上对齐：30m→16（恰好1800s）、1m→5、2m→6、45m→17（3600s）、60m→17、>120m→18 封顶+WARN、timeoutMinutes≤0→16+WARN；forceLevel 非 0 覆盖映射 |
| TC-002 | 单测 PaymentTimeoutPolicyTest + OrderEnvelopeAssemblerTest + OutboxOrderEventFlusherTest | AC-026, AC-031 | DU-BE-004 | policy 读 SystemParameter 命中动态值/缺键回退 yml 默认+WARN；create 聚合收集 [ORDER_CREATED,PAYMENT_TIMEOUT_CHECK]；assembler 延迟事件 payload=OrderDelayPayload(orderId,orderNo,expireAt=createdAt+传入timeout)、Tag/topic 正确；ORDER_CREATED.paymentDeadline 同步改传入值；flusher 一次 flush 只读取一次超时、两事件同一 timeout；延迟事件 append 携带映射级别、普通事件 delayLevel=0；sync 模式全部丢弃 |
| TC-003 | 仓储集成测试（H2+Flyway） | AC-026 | DU-BE-004 | V5 迁移：delay_level 列存在、INT、NOT NULL 默认 0；save 携带 delay_level；OutboxDeliveryTask 发送分支读取行内级别（delayLevel>0 走 sendDelay，=0 走 sendSync）；既有四事件行为不变 |
| TC-004 | 单测 PaymentTimeoutCheckHandlerTest | AC-027, AC-028, AC-029 | DU-BE-004 | PENDING_PAYMENT→systemCancel(PAYMENT_TIMEOUT,DELAY_MESSAGE)；PAID/SHIPPED/COMPLETED/CANCELLED→markSkipped ACK；订单不存在→markSkipped+WARN；STATUS_CONFLICT(409)→归并 markSkipped 不重试；其他异常上抛交重试；同 eventId 重放由处理链占位拦截、同单 Outbox 重投 N 次 CAS 只取消一次 |
| TC-005 | 单测 OrderCancelServiceTest（systemCancel） | AC-027, AC-029 | DU-BE-004 | 按 id 加载不做归属；doCancel 共用：CAS 赢+history+异步直接返回（ORDER_CANCELLED 事件 flush）；CANCELLED 幂等返回；CAS 落败重读 CANCELLED 幂等/PAID 抛 409；sync 模式 releaseAfterCancel 降级+WARN；operator="SYS:source" 入 history |
| TC-006 | 单测 OrderTimeoutFallbackScannerTest | AC-030 | DU-BE-004 | cutoff=now−timeoutMinutes；findExpiredPending 查询参数正确；逐单调 systemCancel(TIMEOUT_FALLBACK)；单条异常 catch 不中断整轮；CAS 被延迟路径抢先→CANCELLED 幂等；开关 enabled=false 时 Bean 不装配 |
| TC-007 | 单测 DelayTaskAdminControllerTest + DelayTaskAdminMapper H2 集成测试 | AC-032 | DU-BE-004 | union 三源：PENDING(PENDING_PAYMENT)/CANCELLED(CANCELLED+PAYMENT_TIMEOUT)/FAILED(outbox PAYMENT_TIMEOUT_CHECK FAILED，LEFT JOIN orders)；status 筛选与分页 total 正确；手动取消 POST 调 systemCancel(ADMIN_MANUAL)，404/409 语义；order-delay-audit 含 operator/orderId/before/after |
| TC-008 | mall-identity 权限种子核对（V14 SQL + 既有迁移风格） | AC-032 | DU-BE-004 | order-delay:list/order-delay:cancel 两权限、/distributed/delay 菜单页（component_key=DelayTaskList）、SUPER_ADMIN 授权；ON DUPLICATE/INSERT IGNORE 可重复执行 |
| TC-009 | 前端单测 distributed.spec.ts（delayTaskApi）+ DelayTaskList 逻辑 spec | AC-032 | DU-FE-002 | page URL/query（status/page/size）与解包；cancel POST；delayStatus→Tag 类型/中文标签映射；PENDING 行显示手动取消按钮、确认后调 API 并刷新；v-permission 指令码正确 |
| TC-010 | 回归合集（mall-order 全量 mvn test + mall-admin vitest run） | AC-026~032 | DU-BE-004、DU-FE-002 | TC-001~009 全绿；M4/M5 及 S1~S3 既有订单/Outbox/补偿用例零回退 |

覆盖核对：AC-026→TC-001/002/003、AC-027→TC-004/005、AC-028→TC-004、AC-029→TC-004/005、AC-030→TC-006、AC-031→TC-002、AC-032→TC-007/008/009；无 TC-NOT-TESTABLE 项。

## 2. 测试策略

- **后端分层**：JUnit5 + Mockito 单测为主，不起 RocketMQ：
  - DelayLevelMapper/Policy：纯函数 + mock SystemParameterProvider。
  - Assembler/Flusher：真实 ObjectMapper（findAndRegisterModules，Instant→epoch 秒），mock writer/policy；验证一次 flush 内 timeout 只读取一次（Mockito times(1)）。
  - Handler：直接调 protected `handle(envelope, payload)`，mock OrderRepository.findStatusById/OrderCancelService/IdempotentConsumer；markSkipped 经 mock 验证。
  - Scanner：mock repository.findExpiredPending + OrderCancelService，异常注入验证隔离。
  - Admin：控制器直调（service/mapper mock）；union 结果另起 H2 @SpringBootTest 集成测试（Flyway 全迁移，插入三源夹具）。
  - 迁移：H2 真实 Flyway 断言列定义；发送分支读取 delay_level 用 MyBatis 集成夹具。
- **前端分层**：vitest，HTTP 调用 mock（参照 http.spec.ts / api 既有 spec 模式）；视图交互以纯逻辑/组件挂载测试覆盖状态映射与按钮行为。
- **数据准备**：Order 聚合 fixture（create 未持久化/带 id、各状态）、OutboxEvent 各状态夹具、orders×outbox_event 三源 H2 夹具。
- **不覆盖项**：真实 RocketMQ 短延迟投递→消费→取消→库存释放的跨服务运行态归 M7 Integration Gate（force-level 配置 + 真实 broker，AC-027/029/030 证据 converge 时产出）；DLQ→ORDER_AUTO_CANCEL 补偿归 STORY-009-05-01。
- **环境要求**：后端 `mvn -pl mall-services/mall-order -am test`（Java 21）；前端 `pnpm --filter mall-admin test`（mall-admin 目录 vitest run）。

## 3. DU 覆盖矩阵

| DU | verifies TC | covers AC |
| --- | --- | --- |
| DU-BE-004（repo-1，[S4]） | TC-001~008、TC-010（后端部分） | AC-026~031、AC-032（后端 API） |
| DU-FE-002（repo-2，[S4]） | TC-009、TC-010（前端部分） | AC-032（前端页面） |
