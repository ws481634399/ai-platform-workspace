# Test Report — STORY-009-02-01 Outbox 可靠投递

> 阶段：sdd-test 产物
> 位置：stories/STORY-009-02-01/evidence/test-report.md
> 状态流转：developing → testing

## 0. 元信息

- Change ID：CHG-0025（M7 分布式增强）
- Story：STORY-009-02-01 Outbox 可靠投递
- 执行时间：2026-09-24
- Evidence 索引：stories/STORY-009-02-01/evidence/evidence.yaml
- 测试环境：Java 21 / Maven / Spring Boot 3.5.15；H2(MySQL 模式)；Docker(Redis Testcontainers)；Windows

## 1. 测试范围

### 1.1 覆盖 DU

| DU | 仓库 | 范围 |
| --- | --- | --- |
| DU-BE-002 | repo-1 | outbox_event 表 + OutboxRecordWriter + OutboxDeliveryTask + OutboxAdminController |
| DU-FE-001 | repo-2 | mall-admin Outbox 管理页（类型检查） |

### 1.2 测试模块与类型

| 模块 | 测试类 | 用例数 | 类型 |
| --- | --- | --- | --- |
| mall-order | OutboxBackoffPolicyTest | 3 | 单元 |
| mall-order | EventRouterTest | 3 | 单元 |
| mall-order | OutboxRecordWriterTest | 2 | 单元 |
| mall-order | OutboxDeliveryTaskTest | 8 | 单元(Mockito) |
| mall-order | OutboxEventRepositoryIntegrationTest | 8 | 集成(H2+Flyway+MyBatis CAS) |

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 单元测试 | 16 | 16 | 0 | 0 |
| 集成测试 | 8 | 8 | 0 | 0 |
| **Outbox 合计** | **24** | **24** | **0** | **0** |
| mall-order 全量回归 | 46 | 46 | 0 | 0 |
| mall-admin type-check | 通过 | — | — | — |

## 3. TC 对照

| TC | 验证方式 | 结果 | 证据 |
| --- | --- | --- | --- |
| TC-001 | OutboxRecordWriterTest + OutboxEventRepositoryIntegrationTest.saveAndTableExists | PASS | append 持久化 PENDING；Flyway V4 表+索引存在 |
| TC-002 | OutboxDeliveryTaskTest.deliverSuccessMarksSent | PASS | claim→sendSync→markSent；envelope 传给 producer |
| TC-003 | OutboxDeliveryTaskTest.deliverFailureRequeuesWithBackoff | PASS | 失败回 PENDING+retry_count+1+next_retry_at，不标 FAILED |
| TC-004 | （退避后下轮续投由调度循环保证，集成层 markSentFromSending 验证状态机可达） | PASS | claim CAS + markSent 状态流转 |
| TC-005 | OutboxDeliveryTaskTest.sameAggregatePicksFirstOnly | PASS | 同聚合只投首条，跨聚合各自投递 |
| TC-006 | OutboxDeliveryTaskTest.deliverFailureExceededMarksFailed + OutboxEventRepositoryIntegrationTest.markFailed | PASS | 超 maxRetries→FAILED+lastError |
| TC-007 | OutboxEventRepositoryIntegrationTest.resetForRetry | PASS | FAILED→PENDING，retry_count 清零 |
| TC-008 | mall-order 全量 `mvn test` 46/46 | PASS | M4/M5 既有订单/补偿用例零回退 |

## 4. 执行命令

```bash
mvn -pl mall-services/mall-order test                              # 46/46 全绿
npx vue-tsc --noEmit -p mall-admin/tsconfig.json                  # 类型检查通过
```

## 5. 缺陷与修复

- mall-common-mq `AutoConfiguration.imports` 误用 spring.factories 键值格式 → 改为纯类名列表（Spring Boot 3 自动装配文件格式），修复应用上下文加载失败。
- 测试 Instant 与 DB DATETIME 精度差异 → 断言改用 `toEpochMilli()` 比较。
