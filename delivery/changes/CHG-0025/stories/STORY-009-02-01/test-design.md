# Test Design（TC 测试用例设计）— STORY-009-02-01 Outbox 可靠投递

## 0. 元信息

- Change ID: CHG-0025
- design 来源: delivery/changes/CHG-0025/requirement-design.md + stories/STORY-009-02-01/story-design.md
- feature-path: FEAT-009 > FEAT-009-02 > FEAT-009-02-01 > STORY-009-02-01
- TC 总数: 8（覆盖 AC-010~017 全部）

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 集成测试（mall-order，H2/Testcontainers DB + 事务回滚断言） | AC-010 | DU-BE-002 | @Transactional 内 OutboxRecordWriter.append 成功 → 事务提交后 outbox_event 存在 PENDING 记录；注入 append 抛异常 → 业务事务回滚，无 outbox 记录 |
| TC-002 | 集成测试（OutboxDeliveryTask + mock Producer） | AC-011 | DU-BE-002 | 到期 PENDING 记录 → sendSync 成功 → 记录 status=SENT 且 sent_at 非空；发送消息 keys 含 eventId（断言 producer 入参 envelope.eventId） |
| TC-003 | 集成测试（停止 broker / 模拟 sendSync 抛 MQClientException） | AC-012 | DU-BE-002 | 发送失败 → 记录保留 PENDING、retry_count+1、next_retry_at 按退避推迟；不删除、不标 FAILED |
| TC-004 | 集成测试（多轮调度） | AC-013 | DU-BE-002 | 失败记录在 next_retry_at 到期后下一轮被自动续投直至 SENT；无需人工 |
| TC-005 | 集成测试（构造同 aggregateId 3 条 PENDING） | AC-014 | DU-BE-002 | 每轮只投递该聚合 created_at 最早一条；前一条 SENT 后下一轮才投下一条；断言发送顺序 == created_at 顺序 |
| TC-006 | 集成测试（maxRetries 配置为 3，模拟持续失败） | AC-015 | DU-BE-002 | 第 3 次失败后 status=FAILED + last_error 非空；mall-admin GET 查询返回该 FAILED 记录 |
| TC-007 | 集成测试（mall-admin OutboxAdminController） | AC-016 | DU-BE-002 | POST /retry → FAILED→PENDING（retry_count 重置 0）；审计记录含操作人/时间/前后状态；重置后下一轮投递成功 |
| TC-008 | 回归合集（mvn test mall-order + mall-admin outbox 模块） | AC-017 | DU-BE-002 | TC-001~007 全绿，且不破坏 M4/M5 既有订单/补偿用例 |

覆盖核对：AC-010→TC-001、AC-011→TC-002、AC-012→TC-003、AC-013→TC-004、AC-014→TC-005、AC-015→TC-006、AC-016→TC-007、AC-017→TC-008；无 TC-NOT-TESTABLE 项。

## 2. 测试策略

- **分层**：mall-order outbox/ 包以 Spring Boot 集成测试为主（@SpringBootTest + H2 内存库承载 outbox_event 表 + Flyway 迁移）；Producer 用 Mockito mock（隔离 RocketMQ 运行时，专注 Outbox 状态机与退避逻辑）；同聚合顺序通过控制 findPendingDue 返回 + mock producer 记录调用顺序断言；mall-admin API 用 MockMvc 验证权限码与审计。真实 RocketMQ 收发留 Integration Gate。
- **数据准备**：OutboxEvent fixture 工厂（PENDING 多记录、同聚合不同 created_at）；mock IntegrationEventProducer 按场景返回成功/抛异常；审计切面可 mock 验证调用参数。
- **环境要求**：repo-1 Maven（Java 21）`mvn -pl mall-order -am test`；H2 内 Flyway 执行 add_outbox_event；不依赖 Nacos 生产配置（测试 profile 注入 outbox.delivery.*）。

## 3. DU 覆盖矩阵

| DU | verifies TC | covers AC |
| --- | --- | --- |
| DU-BE-002（repo-1，[S2]） | TC-001~008 | AC-010~017 |
| DU-FE-001（repo-2，[S2]） | （前端联调留 Integration Gate） | AC-016（后端契约侧由 TC-007 覆盖） |
