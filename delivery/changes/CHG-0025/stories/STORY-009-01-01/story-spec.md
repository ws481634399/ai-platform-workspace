---
story-id: "STORY-009-01-01"
change-spec-ref: "requirement-spec.md#3-功能范围"
scope-refs: [S1, S6]
---

# Story Spec（Story 产品规格）— RocketMQ 事件基础设施

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3 [S1]/[S6]、§4、§5（AC-001~009, AC-041）
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0025
- Story ID: STORY-009-01-01 RocketMQ 事件基础设施（REQ-M7-001，P0）
- Change spec 引用: requirement-spec.md#3-功能范围（S1/S6）
- 仓库分工: repo-1 mall-common mq 子模块（主：Envelope/生产者/消费者封装）+ mall-contracts（事件契约集中声明）+ mall-bom（依赖管理）、repo-4 infra（docker-compose 新增 RocketMQ）
- 下游依赖: 本 Story 是 REQ-M7-002/003/004/005 的前置（投递任务依赖生产者封装，消费者依赖消费抽象）

## 1. Story 目标

为 M7 全部事件能力建立统一底座：

1. 环境：docker-compose 一键启动 RocketMQ（NameServer+Broker，Dashboard 可选），业务服务经 Nacos 配置获取地址并连接；
2. 封装：mall-common 提供统一 Envelope、生产者（同步/异步/延迟）、消费者抽象（幂等检查挂点/异常重试/TraceId 透传/消费日志），业务服务零样板接入；
3. 治理：Topic/Tag/消费者组/事件版本在 mall-contracts 集中声明；DLQ 可查询不静默；`rocketmq.enabled` 开关关闭时行为可预期（同步降级，无半开）。

## 2. Scope（范围）

### 2.1 包含

- [S1] docker-compose 新增 RocketMQ 服务（NameServer+Broker+健康检查+卷+网络，Dashboard 可选），与既有 MySQL/Redis/Nacos/MinIO/ES 统一纳管。
- [S1] mall-bom 新增 RocketMQ 客户端依赖管理（版本与 Spring Boot 3.5.15/Spring Cloud Alibaba 2025.0.0.0 兼容矩阵由 design 定）；各服务 pom 不散落版本号。
- [S1] mall-contracts 新增集成事件契约：Envelope 七字段定义（eventId/eventType/eventVersion/occurredAt/producer/traceId/payload，对齐 02-统一语言词汇表.md §19）、Topic 常量（order-events/inventory-events）、Tag 常量（ORDER_CREATED/PAYMENT_SUCCEEDED/ORDER_CANCELLED/ORDER_COMPLETED）、消费者组常量（inventory-consumer-group/order-delay-consumer-group）、事件版本支持矩阵常量。
- [S1] mall-common mq 子模块实现：IntegrationEventProducer（sendSync/sendAsync/sendDelay 三种，delayLevel 参数化）、消费者注解抽象与统一处理链（幂等检查挂点→TraceId 写 MDC→异常重试交 RocketMQ→消费日志）、eventVersion 兼容拒绝（高于支持版本拒绝+告警）、消息 keys=eventId。
- [S1] TraceId 透传：生产者从 MDC 读取当前 traceId 注入 Envelope；消费者接收后写 MDC 并传播至下游 internal 调用（与 M5 X-Trace-Id 约定同源）；缺失时生成新 ID 不阻断。
- [S1] 重试与 DLQ：消费失败按 RocketMQ 默认重试策略，超限进 DLQ；提供 DLQ/失败消息查询能力（首期服务端内部接口，管理页归属 STORY-009-05-01 的 mall-admin 统一入口）。
- [S1] `rocketmq.enabled` 配置开关（复用 M5 配置模型）：false 时生产者/消费者 Bean 不初始化，调用方走同步路径，服务正常启动；不允许半开半闭。
- [S6] mall-common mq 子模块单元测试与集成测试基线（Envelope 构建/三种发送/消费链/TraceId/版本拒绝/开关）。

### 2.2 不包含

- Outbox 表与投递任务（STORY-009-02-01）；业务事件发布时机（STORY-009-03-01/04-01）；consumed_event 表与补偿扩展（STORY-009-05-01）。
- Kafka/Pulsar、消息轨迹大盘、回溯 UI、跨集群路由、事务反向查询。
- mall-admin DLQ/任务管理页 UI（归 STORY-009-05-01 统一入口，本 Story 仅提供查询能力）。

## 3. 业务规则

- [Envelope 完整性] 七字段缺一不可；traceId 缺失自动生成，不阻断发送（规则 6/AC-002）。
- [契约集中] Topic/Tag/消费者组名只在 mall-contracts 声明，业务服务引用常量，禁止散落硬编码（规则 5/AC-003）。
- [版本拒绝] eventVersion 高于消费者支持版本 → 明确拒绝+告警，禁止静默按旧版本解析（规则 8/AC-006）。
- [幂等键] 消息 keys 一律 eventId（规则 7）。
- [DLQ 不静默] 重试超限进 DLQ 且可查询（规则 17/AC-007）。
- [开关语义] rocketmq.enabled=false → 不初始化 MQ Bean + 同步路径，行为可预期（规则 19/AC-008）。
- [依赖治理] RocketMQ 客户端版本只在 mall-bom 管理（规则见 §6 补充约束/AC-041）。

## 4. 接口与字段规格

- Envelope（mall-contracts）：`{eventId: String(UUID), eventType: String, eventVersion: int, occurredAt: Instant, producer: String, traceId: String, payload: JsonNode}`。
- 生产者 API（mall-common mq）：`sendSync(TopicTag, Envelope)` / `sendAsync(TopicTag, Envelope, SendCallback)` / `sendDelay(TopicTag, Envelope, int delayLevel)`；消息 keys=eventId，消息 body=Envelope JSON。
- 消费者 SPI（mall-common mq）：注解式声明（Topic/Tag/消费者组）+ `onMessage(Envelope)` 实现；统一处理链在框架层完成（幂等挂点/TraceId/日志/重试交接）。
- 配置键（Nacos/复用 M5 模型）：`rocketmq.enabled`（默认 false 安全启动）、`rocketmq.name-server`（经 Nacos 下发）、producer group、consumer 重试参数。
- 错误语义：发送失败向上抛业务异常（由 Outbox 投递任务捕获退避，见 STORY-009-02-01）；消费失败交 RocketMQ 重试，不在框架层吞异常。

## 5. Story 验收标准

requirement-spec.md §5 Story 1 表（AC-001~AC-009）+ AC-041，此处不重复。

## 6. 待设计确认（已移至 design 定稿）

- RocketMQ 客户端选型与版本兼容矩阵（starter vs 原生 5.x 客户端）、mall-bom 管理方式——§4.F-23，design 定稿后记入 requirement-design.md。
- 消费者注解抽象实现方式（自研 @IntegrationEventListener 组合 rocketmq-spring vs 直接暴露原生注解）。
- Topic 环境隔离策略（前缀 vs namespace）；Windows 下 RocketMQ 容器兼容性验证；DLQ 查询服务端接口形态。
