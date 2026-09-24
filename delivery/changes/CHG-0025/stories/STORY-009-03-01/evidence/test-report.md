# Test Report — STORY-009-03-01 订单集成事件与库存异步消费者

> 阶段：sdd-test 产物（独立测试验证，不读 implementation.md）
> 位置：stories/STORY-009-03-01/evidence/test-report.md
> 输入：test-design.md + story-spec + story-design + 仓内 task-spec.md
> 产出状态：developing → testing

## 0. 元信息

- Change ID：CHG-0025（M7 分布式增强）
- Story：STORY-009-03-01 订单集成事件与库存异步消费者
- 状态流转：developing → testing
- 执行时间：2026-09-24
- Evidence 索引：stories/STORY-009-03-01/evidence/evidence.yaml（EV-010、EV-011 为本阶段 test-run）
- 测试环境：JDK 17 / Maven / Windows；JUnit5 + Mockito（单测不起 Spring 上下文）；本地仓库 D:\maven-repository

## 1. 测试范围

### 1.1 覆盖 DU

| DU | 仓库 | 范围 |
| --- | --- | --- |
| DU-BE-003 | repo-1 | 发布侧 mall-order 四事件接入 Outbox + 消费侧 mall-inventory 两异步消费者（TC-001~008） |

### 1.2 测试模块与类型

| 模块 | 测试类（用例数） | 类型 |
| --- | --- | --- |
| mall-order | OrderIntegrationEventsTest（5） | 单元 |
| mall-order | OrderEnvelopeAssemblerTest（4） | 单元 |
| mall-order | OutboxOrderEventFlusherTest（3） | 单元 |
| mall-order | PaymentServiceTest（4）、OrderCancelServiceTest（4） | 单元 |
| mall-order | OrderStatusInternalControllerTest（2）、CompensationInternalControllerTest（2） | 单元 |
| mall-inventory | PaymentSucceededInventoryHandlerTest（4） | 单元 |
| mall-inventory | OrderCancelledInventoryHandlerTest（5） | 单元 |

- 本 Story 新增 33 个单测；跨服务运行态串联（真实 RocketMQ + 两服务）属 M7 Integration Gate 七场景，在 Change 级 converge 产出，不在本 Story 范围。

## 2. 测试执行汇总

| 模块 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| mall-order（全量） | 70 | 70 | 0 | 0 |
| mall-inventory（全量） | 37 | 37 | 0 | 0 |
| **合计** | **107** | **107** | **0** | **0** |

- 通过率：100%（107/107）
- 其中本 Story 新增 33（mall-order 24 + mall-inventory 9），既有用例 74 零回退。
- 命令：`mvn -pl mall-services/mall-order,mall-services/mall-inventory -am test` → BUILD SUCCESS
- 原始日志：logs/test-output.log

### 2.1 TC 执行结果（照 test-design 逐条）

| TC | 验证方式 | 结果 | 证据 |
| --- | --- | --- | --- |
| TC-001 | assembler 四事件信封/裁决字段（reservationNo=orderNo、paymentNo="PAY"+orderNo、paymentDeadline=createdAt+30m） | ✅ | OrderEnvelopeAssemblerTest 4/4 |
| TC-002 | flusher async 逐事件 append、sync 丢弃、空列表 noop | ✅ | OutboxOrderEventFlusherTest 3/3 |
| TC-003 | 支付/取消 async 不调同步链路；sync 降级 confirm/release，失败登记补偿 | ✅ | PaymentServiceTest 4/4、OrderCancelServiceTest 4/4 |
| TC-004 | 聚合四迁移事件收集顺序、pull 清空、reconstitute 无事件 | ✅ | OrderIntegrationEventsTest 5/5 |
| TC-005 | internal 端点状态回查（含 404）、补偿登记两类分发 | ✅ | 两 controller 测试 4/4 |
| TC-006 | PAYMENT_SUCCEEDED：确认扣减、CANCELLED 跳过、失败先登记补偿再抛、回查异常传播 | ✅ | PaymentSucceededInventoryHandlerTest 4/4 |
| TC-007 | ORDER_CANCELLED：释放、PAID/SHIPPED/COMPLETED 跳过防误释放、失败登记补偿 | ✅ | OrderCancelledInventoryHandlerTest 5/5 |
| TC-008 | 两模块全量回归零回退 | ✅ | 107/107（本报告 §2） |

## 3. 证据清单

- Story evidence 索引：evidence/evidence.yaml（EV-001~009 code-change / EV-010~011 test-run）
- 完整 Maven 输出：evidence/logs/test-output.log（两模块 107 用例）
- DU 实施记录：implementation/ai-platform-backend/delivery/CHG-0025/分布式增强/订单集成事件与库存异步消费者/订单事件与库存消费能力/订单集成事件与库存异步消费者/DU-BE-003/implementation.md（仅指针来源）

## 4. AC 覆盖矩阵

| AC | TC | 状态 |
| --- | --- | --- |
| AC-018 | TC-001/002/004 | ✅ |
| AC-019 | TC-006 | ✅ |
| AC-020 | TC-006 | ✅ |
| AC-021 | TC-007 | ✅ |
| AC-022 | TC-008 | ✅ |
| AC-023 | TC-005/006/007 | ✅ |
| AC-024 | TC-002/003 | ✅ |
| AC-025 | TC-003/008 | ✅ |

- AC-018~025 全部有 TC 覆盖且执行通过；无失败/跳过项。
- AC-019/020/022 的真实跨服务运行态证据在 Change 级 converge 七场景补齐（story-design §6 边界声明）。

## 5. 失败项分析

无失败项、无跳过项。测试过程中未发现新的实现缺陷（dev 红绿阶段拦截的问题——OrderSource 常量名、long→int 收窄、YAML 科学计数法——均已修复并在独立复跑中保持全绿）。
