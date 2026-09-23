# Test Report — STORY-009-01-01 RocketMQ 事件基础设施

> 阶段：sdd-test 产物（独立测试验证，不读 implementation.md）
> 位置：stories/STORY-009-01-01/evidence/test-report.md
> 输入：test-design.md + requirement-spec/story-spec + requirement-design/story-design + 仓内 task-spec.md
> 产出状态：developing → testing

## 0. 元信息

- Change ID：CHG-0025（M7 分布式增强）
- Story：STORY-009-01-01 RocketMQ 事件基础设施
- Implementation 来源：stories/STORY-009-01-01/implementation.md（仅指针来源，测试未参照其正文）
- 状态流转：developing → testing
- 执行时间：2026-09-23
- Evidence 索引：stories/STORY-009-01-01/evidence/evidence.yaml（EV-009、EV-010 为本阶段 test-run）
- 测试环境：Java 21 / Maven 3.9+ / Spring Boot 3.5.15；Docker（apache/rocketmq:5.3.4 容器）；Windows 宿主机

## 1. 测试范围

### 1.1 覆盖 DU

| DU | 仓库 | 范围 |
| --- | --- | --- |
| DU-INFRA-001 | repo-4 | compose RocketMQ 三服务环境层冒烟（TC-001） |
| DU-BE-001 | repo-1 | mall-event-contracts 契约 + mall-common-mq 生产/消费/开关（TC-002~009） |

### 1.2 测试模块与类型

| 模块 | 测试类 | 类型 |
| --- | --- | --- |
| mall-event-contracts | EventContractsSnapshotTest（5） | 单元 |
| mall-common-mq | RocketMQEnvelopeProducerTest（5） | 单元 |
| mall-common-mq | AbstractIntegrationHandlerTest（7） | 单元 |
| mall-common-mq | ConsumedEventRepositoryTest（4，H2 MySQL 模式真实 SQL） | 集成 |
| mall-common-mq | RocketMQAutoConfigurationTest（3，Spring 上下文切片） | 集成 |
| mall-common-mq | RocketMQBrokerIntegrationTest（7，Testcontainers 真实 broker） | 集成 |

- 环境层：repo-4 compose namesrv/broker healthy + mqadmin 冒烟场景 1 个（TC-001）。
- 测试分层与 test-design §2 一致；跨服务运行态串联（mall-order 发布 → mall-inventory 消费）属 M7 Integration Gate 七场景，不在本 Story 范围。

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 单元测试 | 17 | 17 | 0 | 0 |
| 集成测试 | 14 | 14 | 0 | 0 |
| E2E 测试 | 0 | 0 | 0 | 0 |
| **JUnit 合计** | **31** | **31** | **0** | **0** |
| 环境冒烟场景（TC-001） | 1 | 1 | 0 | 0 |

- 通过率：100%（JUnit 31/31；冒烟 1/1）
- 模块口径：mall-event-contracts 5 + mall-common-mq 26 = 31；dev 阶段 DU 证据中的「26/26」为 mall-common-mq 单模块聚合，全 Story 口径以本报告 31 为准。
- 命令：`mvn -B -pl mall-common/mall-common-mq -am test` → BUILD SUCCESS（Total time 01:42 min；Testcontainers IT 72.63s）

### 2.1 TC 执行结果（照 test-design §1 逐条）

| TC | 验证方式 | 结果 | 证据 |
| --- | --- | --- | --- |
| TC-001 | compose 冒烟：两服务 healthy + clusterList 含 broker-a + sendMessage SEND_OK + consumeMessage 收到 body/keys | ✅ | EV-010 / smoke.log |
| TC-002 | 契约快照：Envelope 七字段、traceId 缺失自动生成、常量集中 | ✅ | EventContractsSnapshotTest 5/5 |
| TC-003 | sendSync/sendAsync/sendDelay 三种发送均达，delayLevel 属性生效 | ✅ | RocketMQBrokerIntegrationTest |
| TC-004 | MDC.traceId == Envelope.traceId；缺失自动生成不阻断 | ✅ | RocketMQBrokerIntegrationTest |
| TC-005 | eventVersion=v2：WARN+ACK 拒绝，handler 未执行 | ✅ | RocketMQBrokerIntegrationTest（v2 对照组） |
| TC-006 | 持续失败重试超限进 DLQ，DLQ 原文可查不静默 | ✅ | RocketMQBrokerIntegrationTest（DLQ 组） |
| TC-007 | rocketmq.enabled=false 不装配；true 装配齐全；无 JdbcTemplate fail-closed | ✅ | RocketMQAutoConfigurationTest 3/3 |
| TC-008 | dependency:tree 0 冲突；pom 扫描版本仅 mall-bom | ✅ | dev evidence EV-004（依赖树断言非 JUnit） |
| TC-009 | 回归合集全绿（契约 + mall-mq） | ✅ | 31/31（本报告 §2） |

## 3. 证据清单

- evidence-ref（repo-1 / DU-BE-001）→ implementation/ai-platform-backend/delivery/CHG-0025/分布式增强/RocketMQ 事件基础设施/事件基础能力/RocketMQ 事件基础设施/DU-BE-001/evidence/logs/test-output.log（完整 Maven 输出，31 用例）
- evidence-ref（repo-4 / DU-INFRA-001）→ implementation/ai-platform-infrastructure/delivery/CHG-0025/分布式增强/RocketMQ 事件基础设施/事件基础能力/RocketMQ 事件基础设施/DU-INFRA-001/evidence/logs/smoke.log（TC-001 原始记录）
- Story evidence 索引：evidence/evidence.yaml（EV-001~008 code-change / EV-009~010 test-run）
- 依赖树证据：repo-1 DU-BE-001 evidence（TC-008，dev 阶段采集，0 conflict）

## 4. AC 覆盖矩阵

| AC | TC | 状态 |
| --- | --- | --- |
| AC-001 | TC-001 | ✅ |
| AC-002 | TC-002 | ✅ |
| AC-003 | TC-002 | ✅ |
| AC-004 | TC-003 | ✅ |
| AC-005 | TC-004 | ✅ |
| AC-006 | TC-005 | ✅ |
| AC-007 | TC-006 | ✅ |
| AC-008 | TC-007 | ✅ |
| AC-009 | TC-009 | ✅ |
| AC-041 | TC-008 | ✅ |

- AC-001~009 + AC-041 全部有 TC 覆盖且执行通过；无 TC-NOT-TESTABLE 项；无失败/跳过项。

## 5. 失败项分析

无失败项、无跳过项。测试过程中未发现新的实现缺陷（dev 红绿阶段拦截的 2 个缺陷已修复并在本次独立复跑中保持全绿）。
