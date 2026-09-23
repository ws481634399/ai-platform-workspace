# Review Report — STORY-009-01-01 RocketMQ 事件基础设施

> 阶段：sdd-review 产物（Phase 2.2 同态检查点；检查通过后状态保持 testing）
> 位置：stories/STORY-009-01-01/review-report.md
> 输入：requirement-spec/requirement-design + story-spec/story-design + 两仓 DU task-spec/implementation + evidence/test-report.md + evidence/evidence.yaml + standards/

## 0. 元信息

- Change ID: CHG-0025（M7 分布式增强）
- Test Report 来源: stories/STORY-009-01-01/evidence/test-report.md
- Evidence 索引: stories/STORY-009-01-01/evidence/evidence.yaml
- 状态流转: testing（检查点，状态不变）
- 检查时间: 2026-09-23T23:15:00+08:00

## 1. 检查结论

整体结论：四项检查全部执行；发现 4 项（2 major / 2 minor），2 项 major 已闭环，2 项 minor 同步修复；修复后全量回归 32/32 通过。追踪链 AC→DES→DU→TC→EVD 无断链。

### 1.1 需求一致性

| AC | test-run 证据（covers） | 结论 |
| --- | --- | --- |
| AC-001 | EV-010（compose 冒烟） | ✅ |
| AC-002 | EV-009 / EV-018 | ✅ |
| AC-003 | EV-009 / EV-018 | ✅ |
| AC-004 | EV-009 / EV-018 | ✅ |
| AC-005 | EV-009 / EV-018 | ✅ |
| AC-006 | EV-009 / EV-018 | ✅ |
| AC-007 | EV-009 / EV-018 | ✅ |
| AC-008 | EV-009 / EV-018 | ✅ |
| AC-009 | EV-009 / EV-018 | ✅ |
| AC-041 | EV-009 / EV-018 | ✅ |

- 10 条 AC 全部有 covers 包含它的 test-run；评审修复后 EV-018 再次全量覆盖。

### 1.2 设计一致性（Design → DU → Implementation）

| 检查 | 核对内容 | 结论 |
| --- | --- | --- |
| a. DU ↔ Design | 两仓 task-spec 引用 story-design §5 权威表；契约 API/事件/开关语义与 requirement-design §2/§4 同向 | ✅（5 条原 Deviations + DEV-6 均合理） |
| b. Implementation ↔ DU | Envelope 七字段/三种发送/六步链/幂等组件/开关均落地；模块命名偏离评审补记 DEV-6 | ✅（EV-012 已闭环） |
| c. AC 满足 | 偏离（自建 DefaultMQPushConsumer、RECONSUME_LATER 返回码等）后 DU Acceptance 全部满足 | ✅ 32/32 |

- 设计声明组件 ↔ code-change：Envelope/EventTopics/EventTags/ConsumerGroups/EventVersions（EV-004）、IntegrationEventProducer/RocketMQEnvelopeProducer（EV-005）、@IntegrationEventListener/AbstractIntegrationHandler/ConsumedEventRepository/RocketMQAutoConfiguration（EV-006）均可在 files/symbols 中追溯。

### 1.3 跨仓一致性（Phase 2.4）

- Event Contract：Topic aimall-order-events / aimall-order-delay、Tag=eventType、keys=eventId、Envelope 七字段——由 repo-1 契约快照（EV-004）与真实 broker IT（EV-009/EV-018）共同验证；repo-4 broker 5.3.4 冒烟（EV-010）验证运行时承载。
- 依赖方向：repo-1 mall-common-mq 依赖 mall-event-contracts（单向，framework-standard §7.4.3）；repo-1 依赖 repo-4 RocketMQ 运行时，与 §4 Repository Dependencies 一致。
- affected-repositories：repo-1、repo-4 均有 DU code-change 证据；repo-2/repo-3 本 Story 无改动，与 §3 仓库影响一致。
- 跨服务运行态串联（mall-order ↔ mall-inventory）属后续 Story + Integration Gate，不在本检查点。

### 1.4 代码质量

- 抽查 10 个主代码文件，对照 standards 明确条目：发现并修复 3 项（EV-011 major：破坏框架生命周期；EV-013 minor：表名拼接；EV-014 minor：注释草稿表达），均有明确规范依据（framework-standard §2.2、database-access-standard §9.1、coding-standards 注释规则）。
- 其余：构造器注入、MDC key=traceId、日志不打印敏感信息、模块零业务领域模型，均符合规范。

### 1.5 知识同步候选

- 候选 standards：① Spring 托管的消息消费者须用 SmartLifecycle 承载 start/stop，禁止 JVM shutdown hook（可并入 framework-standard §3 或 §5）；② JDBC 无法参数化的标识符（表名/列名）须经标识符白名单校验（可并入 database-access-standard §9）。
- 候选 product：无（Envelope/Topic 术语已在统一语言词汇表 §19）。
- 以上仅列候选，沉淀由 sdd-converge 执行。

## 2. 发现清单

| EV | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-011 | RocketMQAutoConfiguration.java:integrationListenerRegistrar | major | JVM shutdown hook 脱离 Spring 生命周期，上下文关闭时消费者不释放、hook 泄漏 | 已改 SmartLifecycle Bean，见 EV-015；回归见 EV-018 |
| EV-012 | implementation.md#Deviations | major | 模块命名偏离（mall-mq→mall-common-mq）未记录 | 已补记 DEV-6，见 EV-017 |
| EV-013 | ConsumedEventRepository.java:<init> | minor | tableName 拼接 SQL | 标识符白名单校验，见 EV-015 |
| EV-014 | AbstractIntegrationHandler.java:processMessage | minor | 自问式草稿注释 | 已改陈述式注释，见 EV-015 |

- blocker 0 项；major 2 项均已闭环；minor 2 项均已修复（无遗留技术债）。

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 全部 blocker/major finding 已闭环（evidence.yaml resolution 非空）
- [x] minor finding 已记录（2 项已修复）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（两 DU 证据共同满足 §4 契约）
- [x] 追踪链完整：AC↔TC（test-design 9 条）、TC↔EVD（EV-009/010/018）、DU↔AC（story-design §5）
