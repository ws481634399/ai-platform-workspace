# Requirement

- Change：CHG-0025
- 需求标识：REQ-M7（含 REQ-M7-001~005 五个子需求）
- 来源：《product/14-开发计划.md》§11 阶段 5：RocketMQ 与分布式一致性（M7 分布式增强）
- 标题：M7 分布式增强——RocketMQ 事件基础设施、Outbox 可靠投递、库存异步消费者、延迟订单取消、消费幂等与补偿

## 需求描述

### 一、阶段目标

在 M0~M6 已经建立的同步交易闭环与 AI 能力基础上，把 V1 中以同步调用、定时补偿为主的后续处理升级为可靠异步事件驱动，形成具备分布式一致性亮点的工程作品集项目。M7 围绕 RocketMQ 构建四项核心能力：

1. **RocketMQ 事件基础设施**：统一事件 Envelope、Topic/Tag、消费者组、TraceId 透传、事件版本与生产/消费通用封装，作为 mall-common 的可复用能力。
2. **Outbox 可靠投递**：业务事务与消息发送解耦，业务提交时仅写 Outbox 表，投递任务异步推送至 RocketMQ，保证 MQ 停止时事件不丢失、恢复后继续发送。
3. **库存异步消费者**：mall-inventory 订阅 PaymentSucceeded / OrderCancelled，完成支付后确认扣减、取消后释放锁定的幂等处理，容忍重复与乱序消息。
4. **延迟订单自动取消**：创建订单后投递延迟消息，到期回查订单状态并自动取消未支付订单，与 mall-order 既有 CompensationService 协同，保证延迟消息重复投递的幂等。

M7 的核心原则：**业务一致性优先于消息吞吐量**。所有跨服务写操作必须通过幂等表 + 事件版本 + 补偿任务保证最终一致性，不追求高吞吐；延迟消息与 Outbox 是演示分布式能力的载体，不引入 Kafka/Pulsar 等额外中间件。

整体关系：mall-order 在订单状态迁移时写入 Outbox 事件 → Outbox 投递任务推送至 RocketMQ → mall-inventory 消费者幂等处理库存扣减/释放；同时 mall-order 创建订单后投递延迟消息 → 到期回查并自动取消。

### 二、REQ-M7-001 RocketMQ 事件基础设施

**类型**：技术基础设施需求　**优先级**：P0　**前置依赖**：REQ-M0-001、REQ-M4-001　**主要服务**：mall-common、mall-order、mall-inventory　**主要前端**：无

1. **需求目标**：在 mall-common 建立统一的 RocketMQ 事件封装能力，作为订单、库存等业务服务发布与消费集成事件的基础，避免各服务重复实现生产者/消费者样板代码。
2. **RocketMQ 环境接入**：在 docker-compose 基础设施中新增 RocketMQ（NameServer + Broker + Dashboard 可选），与既有 MySQL/Redis/Nacos/MinIO 统一管理，服务通过 Nacos 配置获取 RocketMQ 地址；本地开发可一键启动。
3. **事件 Envelope**：建立统一集成事件信封结构，字段至少包含 `eventId`、`eventType`、`eventVersion`、`occurredAt`、`producer`、`traceId`、`payload`，与 product/02-统一语言词汇表.md §19 集成事件统一字段一致；Envelope 由 mall-contracts 定义，禁止跨服务共享领域实体。
4. **Topic 与 Tag**：按业务域划分 Topic（如 `order-events`、`inventory-events`），同一 Topic 下用 Tag 区分事件子类型（如 `ORDER_CREATED`、`PAYMENT_SUCCEEDED`、`ORDER_CANCELLED`、`ORDER_COMPLETED`）；Topic/Tag 命名规范在 mall-contracts 集中声明，不散落各服务。
5. **消费者组**：每个消费者归属明确消费者组（如 `inventory-consumer-group`），消费者组名在 mall-contracts 声明；同一组内集群消费、不同组独立消费，符合"库存消费者"与"延迟订单任务"分别订阅的场景。
6. **生产者封装**：提供模板/抽象封装同步发送、异步发送、延迟消息发送三种能力；延迟级别参数化（对接 RocketMQ delayLevel），不硬编码业务语义。
7. **消费者封装**：提供 `@RocketMQMessageListener` 等价抽象或注解式消费入口，统一处理幂等检查、异常重试、TraceId 透传、消费日志；消费者失败不应导致服务崩溃。
8. **TraceId 透传**：事件 Envelope 携带生产者当前 TraceId，消费者接收后写入 MDC 并传播至下游调用；TraceId 缺失时生成新 ID，不阻断消费流程。
9. **事件版本**：Envelope.eventVersion 用于兼容演进；消费者必须能识别并拒绝/降级处理高于自身支持的版本，不允许静默按旧版本字段解析。
10. **重试与死信**：消费失败按 RocketMQ 默认重试策略重试，超过最大重试次数进入死信队列（DLQ）；提供死信/失败任务查询入口，不允许死信消息静默丢弃。
11. **配置开关**：RocketMQ 接入通过配置开关控制（如 `rocketmq.enabled`），关闭时业务服务降级到同步调用或直接拒绝相关写操作，不允许半开半闭导致行为不可预期。
12. **验收标准**：docker-compose 可启动 RocketMQ；服务可注册并连接；生产者可发送事件至指定 Topic/Tag；消费者可订阅并处理事件；事件 Envelope 字段完整；TraceId 在生产→消费→下游调用链贯通；事件版本不兼容时消费者明确拒绝；消费失败按策略重试并进入 DLQ；RocketMQ 关闭时业务服务行为可预期；基础设施测试通过。
13. **非本需求范围**：Kafka/Pulsar 接入、消息轨迹大盘、消息回溯 UI、跨集群消息路由、消息事务反向查询。

### 三、REQ-M7-002 Outbox 可靠投递

**类型**：分布式一致性需求　**优先级**：P0　**前置依赖**：REQ-M7-001　**主要服务**：mall-order、mall-common　**主要前端**：无

1. **需求目标**：建立 Outbox 模式，保证业务事务与消息发送的原子性，解决"业务提交成功但消息发送失败"导致的数据不一致问题。
2. **Outbox 表**：在 mall-order（发布订单事件的服务）数据库新增 `outbox_event` 表，至少包含 `id`、`aggregate_id`、`event_type`、`payload`（JSON）、`status`（PENDING/SENT/FAILED）、`retry_count`、`next_retry_at`、`created_at`、`sent_at`、`trace_id`；同一业务事务内写入 Outbox 记录，与业务数据一起提交。
3. **事务边界**：业务事务提交时 Outbox 记录一并持久化；禁止"先发消息后写库"或"先写库后发消息"的非原子模式；Outbox 写入失败必须回滚业务事务。
4. **投递任务**：建立独立 Outbox 投递任务（@Scheduled 或 Spring Task），扫描 `status=PENDING` 且到 `next_retry_at` 的记录，调用 RocketMQ 生产者发送，发送成功标记 SENT，失败递增 retry_count 并按退避策略更新 next_retry_at。
5. **MQ 停止保留**：RocketMQ 不可用时投递任务必须保留 Outbox 记录在 PENDING 状态，不删除、不标记失败；MQ 恢复后继续扫描并发送，保证事件最终投递。
6. **MQ 恢复续投**：MQ 恢复后投递任务自动恢复，无需人工干预；恢复后从 PENDING 队列继续发送，不丢失、不重复（重复由消费端幂等保证）。
7. **退避策略**：失败重试采用有界退避（如指数退避 + 最大重试次数），超过最大重试次数标记 FAILED 并记录失败原因，进入人工介入队列，不允许无限重试拖垮系统。
8. **事件顺序**：同一聚合（如同一 orderId）的事件按 created_at 顺序投递；Outbox 投递任务按聚合内顺序发送，避免乱序导致业务状态错乱；跨聚合顺序不保证。
9. **幂等键**：Outbox 事件 id 作为消息 keys，消费者可基于 eventId 做幂等去重；禁止以业务字段作为幂等键（业务字段可能重复）。
10. **管理查询**：mall-admin 提供 Outbox 事件查询入口（按状态/类型/聚合 ID 筛选、查看 payload、手动重投），便于人工排查未投递事件；手动重投必须记录操作审计。
11. **验收标准**：业务事务提交后 Outbox 表存在对应记录；投递任务可将 PENDING 事件发送至 RocketMQ；MQ 停止时 Outbox 记录保留 PENDING；MQ 恢复后事件继续发送；重复发送由消费端幂等保证不重复处理；失败超过最大重试次数标记 FAILED；mall-admin 可查询 Outbox 状态并可手动重投；Outbox 测试通过。
12. **非本需求范围**：CDC（Change Data Capture）接入 Debezium、跨数据库 Outbox、事件溯源（Event Sourcing）全量重建。

### 四、REQ-M7-003 订单集成事件与库存异步消费者

**类型**：业务事件需求　**优先级**：P0　**前置依赖**：REQ-M7-001、REQ-M7-002、REQ-M4-001、REQ-M2-002　**主要服务**：mall-order、mall-inventory　**主要前端**：无

1. **需求目标**：mall-order 在订单状态迁移时发布集成事件，mall-inventory 作为消费者异步处理库存确认扣减与释放，替代 V1 中同步调用库存接口的强耦合方式，实现订单与库存的最终一致性。
2. **订单集成事件**：在 `order-events` Topic 下定义四个 Tag（与 product/10-API与事件契约.md §41 一致）：
   - `ORDER_CREATED`：订单创建，Payload 含 orderId/orderNo/memberId/reservationNo/orderAmount/currency/paymentDeadline；
   - `PAYMENT_SUCCEEDED`：支付成功，Payload 含 orderId/orderNo/paymentNo/reservationNo/paymentAmount/currency/paidAt；
   - `ORDER_CANCELLED`：订单取消，Payload 含 orderId/orderNo/reservationNo/cancelReason/cancelledAt；
   - `ORDER_COMPLETED`：订单完成，Payload 含 orderId/orderNo/memberId/completedAt。
3. **事件发布时机**：
   - ORDER_CREATED：订单创建事务提交后发布，用于延迟取消任务订阅；
   - PAYMENT_SUCCEEDED：支付成功事务提交后发布，触发库存确认扣减；
   - ORDER_CANCELLED：订单取消事务提交后发布，触发库存释放；
   - ORDER_COMPLETED：订单完成事务提交后发布，用于统计/通知扩展（M7 不强制实现下游消费者）。
4. **库存消费者-支付成功确认扣减**：mall-inventory 消费 PAYMENT_SUCCEEDED，调用库存聚合将预留库存转为确认扣减；必须基于 reservationNo 幂等，同一支付事件重复消费不重复扣减。
5. **库存消费者-订单取消释放**：mall-inventory 消费 ORDER_CANCELLED，调用库存聚合释放锁定库存；基于 reservationNo 幂等，同一取消事件重复消费不重复释放。
6. **重复消息处理**：消费者必须建立消费幂等表（如 `consumed_event` 表，以 eventId 为唯一键），消费前检查是否已处理，已处理直接 ACK 跳过；不允许依赖业务状态判断幂等（业务状态可能因其他流程变化）。
7. **乱序消息处理**：可能存在 PAYMENT_SUCCEEDED 与 ORDER_CANCELLED 乱序到达（如支付成功后用户立即取消）；消费者必须基于订单当前状态判断是否处理：订单已取消时收到 PAYMENT_SUCCEEDED 应跳过并记录告警，订单已完成时收到 ORDER_CANCELLED 应跳过并记录告警。
8. **补偿任务协同**：消费失败进入死信后，由 mall-order 既有 CompensationService 机制兜底（M7 不新建独立补偿服务，复用 M4 已建立的补偿任务聚合）；补偿任务可通过 mall-admin 查询状态。
9. **同步降级**：RocketMQ 不可用时，支付成功与取消的库存处理可降级为同步调用 mall-inventory 内部 API（与 M4 一致），但必须记录降级日志；降级路径与异步路径业务结果一致。
10. **验收标准**：支付成功后库存最终确认扣减；订单取消后库存最终释放；重复消费同一事件不重复处理；乱序消息按订单状态正确跳过或处理；消费幂等表记录已处理 eventId；DLQ 消息可由补偿任务兜底；RocketMQ 不可用时降级同步调用且业务结果一致；订单集成事件 Payload 与 §41 契约一致；库存异步消费者测试通过。
11. **非本需求范围**：库存超卖实时风控、库存预拆分、多仓库存路由、跨境库存隔离。

### 五、REQ-M7-004 延迟订单自动取消

**类型**：业务流程需求　**优先级**：P1　**前置依赖**：REQ-M7-001、REQ-M7-002、REQ-M4-001　**主要服务**：mall-order　**主要前端**：无

1. **需求目标**：替代 V1 中基于定时任务扫描超时订单的方式，改用 RocketMQ 延迟消息实现"创建订单→延迟到期→回查状态→自动取消"的轻量延迟流程，降低定时扫描的资源消耗与延迟不确定性。
2. **延迟消息发送**：订单创建事务提交后（与 ORDER_CREATED 事件同事务写入 Outbox），投递一条延迟消息至 `order-delay` Topic，延迟级别对应订单超时时间（由 SystemParameter 配置，默认 30 分钟）；延迟消息 Payload 至少含 orderId、orderNo、expireAt。
3. **到期回查**：延迟消息到期后消费者收到，回查订单当前状态：若仍为 PENDING_PAYMENT 则触发自动取消；若已支付/已取消/已完成则跳过；状态回查必须基于订单聚合当前状态，不依赖消息内缓存的状快照。
4. **自动取消**：回查确认未支付时调用 OrderCancelService 执行取消（cancelReason=PAYMENT_TIMEOUT），复用 M4 既有取消流程（CAS 状态迁移 + 库存释放 + 补偿任务登记）；禁止绕过 OrderCancelService 自行实现取消逻辑。
5. **重复延迟消息幂等**：同一订单可能因 Outbox 重投或多副本消费收到多条延迟消息；消费者必须基于订单状态幂等：订单已非 PENDING_PAYMENT 时直接 ACK 跳过；不重复触发取消流程。
6. **定时补偿兜底**：保留 mall-order 既有 CompensationService 定时扫描作为兜底，防止延迟消息丢失或 DLQ 未及时处理；定时补偿与延迟消息取消路径业务结果一致，不允许出现双重取消或取消冲突。
7. **超时时间配置**：订单超时时间通过 SystemParameter（如 `order.payment.timeout-minutes`）配置，支持动态生效（复用 M5 功能配置能力）；延迟级别与超时时间的映射关系由 mall-order 在设计阶段确定。
8. **管理查询**：mall-admin 提供延迟取消任务查询入口（查看待取消/已取消/失败任务、手动触发取消），与既有 CompensationTask 查询入口对齐；手动取消必须记录审计。
9. **验收标准**：创建订单后延迟消息成功投递；到期后消费者回查订单状态；未支付订单自动取消；已支付订单不被取消；重复延迟消息不重复取消；延迟消息丢失时定时补偿兜底生效；超时时间可通过配置调整；mall-admin 可查询延迟取消任务；延迟订单取消测试通过。
10. **非本需求范围**：分布式定时任务框架（XXL-Job 等）、订单超时精度秒级、多级延迟提醒、取消前自动催付通知。

### 六、REQ-M7-005 消费幂等与补偿机制

**类型**：分布式一致性需求　**优先级**：P0　**前置依赖**：REQ-M7-001、REQ-M7-003　**主要服务**：mall-order、mall-inventory、mall-common　**主要前端**：mall-admin

1. **需求目标**：建立统一的消费幂等表与补偿任务机制，作为 M7 所有异步消费者与延迟任务的最终一致性兜底，避免消息重复消费、乱序、DLQ 积压导致的数据不一致。
2. **消费幂等表**：在 mall-inventory（及未来扩展消费者）数据库新增 `consumed_event` 表，至少包含 `event_id`（唯一键）、`event_type`、`consumer_group`、`aggregate_id`、`processed_at`、`result`、`trace_id`；消费前 INSERT IGNORE 或 ON DUPLICATE KEY 检查，已存在直接跳过。
3. **幂等粒度**：幂等键统一使用事件 eventId（全局唯一），不使用业务字段（如 reservationNo）作为幂等键；业务字段可能因多事件触发重复，eventId 是事件级别的唯一标识。
4. **补偿任务聚合**：复用 mall-order 既有 CompensationTask 聚合（M4 已建立），同一业务操作只保留一条补偿任务，幂等登记、有界退避重试；M7 新增的事件消费失败、延迟取消失败场景登记为 CompensationTask，不新建独立补偿体系。
5. **补偿任务类型**：至少支持 `INVENTORY_CONFIRM_DEDUCT`（库存确认扣减补偿）、`INVENTORY_RELEASE`（库存释放补偿）、`ORDER_AUTO_CANCEL`（订单自动取消补偿）三种类型；补偿任务调用对应业务服务内部 API 或事件重发执行。
6. **补偿任务扫描**：CompensationService 每 30 秒扫描到期补偿任务，失败记录重试状态，超过最大重试次数标记为 FAILED 等待人工介入；扫描周期与 M4 一致，不引入新调度器。
7. **人工查询与介入**：mall-admin 提供补偿任务查询入口（按类型/状态/聚合 ID 筛选、查看 payload、手动重试、手动标记完成）；手动操作必须记录审计日志，包含操作人、操作时间、操作前后状态。
8. **DLQ 与补偿衔接**：RocketMQ 死信队列消息由补偿任务接管，不要求实时处理 DLQ；DLQ 积压告警可作为 M8 可观测能力，M7 不强制实现告警。
9. **TraceId 贯通**：事件 eventId、traceId 在生产→Outbox→投递→消费→补偿任务全链路贯通；补偿任务执行时保留原事件 traceId，便于跨服务链路追踪（与 M5 Trace 贯通 Story 协同）。
10. **验收标准**：消费幂等表记录已处理 eventId；重复消费同一事件不重复处理；补偿任务可登记事件消费失败；CompensationService 可扫描并重试补偿任务；超过最大重试次数标记 FAILED；mall-admin 可查询补偿任务并可手动重试；TraceId 在事件→消费→补偿链路贯通；消费幂等与补偿机制测试通过。
11. **非本需求范围**：分布式事务（Seata/2PC）、TCC 补偿框架、Saga 编排引擎、全量事件回溯重建。

### 七、M7 推荐依赖关系与 Integration Gate

五个 Requirement 不可完全并行。推荐顺序：

```
REQ-M7-001 RocketMQ 基础设施（P0，前置）
  → REQ-M7-002 Outbox 可靠投递（P0，依赖 001）
    → REQ-M7-003 订单事件与库存消费者（P0，依赖 001+002）
    → REQ-M7-004 延迟订单取消（P1，依赖 001+002）
  → REQ-M7-005 消费幂等与补偿（P0，依赖 001+003，与 003/004 并行）
```

REQ-M7-001 是所有后续需求的前置；REQ-M7-002 依赖 001 提供的生产者封装；REQ-M7-003 与 REQ-M7-004 可在 002 完成后并行；REQ-M7-005 与 003/004 并行，为消费者与延迟任务提供兜底。

Integration Gate 七大场景：
1. 支付成功 → 库存最终确认扣减（REQ-M7-003）；
2. 订单取消 → 库存最终释放（REQ-M7-003）；
3. 重复消费同一事件不重复处理（REQ-M7-005）；
4. 乱序消息按订单状态正确跳过（REQ-M7-003）；
5. MQ 停止时 Outbox 保留事件（REQ-M7-002）；
6. MQ 恢复后事件继续发送（REQ-M7-002）；
7. 超时订单自动取消 + 延迟消息重复投递幂等（REQ-M7-004）。

### 八、Definition of Done（阶段验收）

- REQ-M7-001：RocketMQ docker-compose / 事件 Envelope / Topic+Tag 命名 / 消费者组 / 生产者封装 / 消费者封装 / TraceId 透传 / 事件版本 / 重试+DLQ / 配置开关；
- REQ-M7-002：Outbox 表 / 业务事务原子写入 / 投递任务 / MQ 停止保留 / MQ 恢复续投 / 退避策略 / 聚合内顺序 / eventId 幂等键 / mall-admin 查询重投；
- REQ-M7-003：四个订单集成事件 / 发布时机 / 支付确认扣减 / 取消释放 / 重复消息处理 / 乱序消息处理 / 补偿任务协同 / 同步降级；
- REQ-M7-004：延迟消息发送 / 到期回查 / 自动取消 / 重复消息幂等 / 定时补偿兜底 / 超时时间配置 / mall-admin 查询；
- REQ-M7-005：消费幂等表 / eventId 幂等粒度 / 复用 CompensationTask / 三种补偿类型 / 30s 扫描 / 人工查询介入 / DLQ 衔接 / TraceId 贯通；
- 分布式基础要求：业务事务与消息发送原子性 / 消费幂等 / 事件版本兼容 / DLQ 不静默丢弃 / 降级路径业务结果一致 / 补偿任务可人工查询 / TraceId 跨事件链路贯通；
- 阶段验收：支付→库存最终扣减 E2E / 取消→库存最终释放 E2E / 重复消费不重复处理 / MQ 停止恢复 Outbox 续投 / 超时订单自动取消 / 乱序消息正确跳过 / 补偿任务人工查询。

## 补充信息

- **与 M4 的关系**：M4 已建立同步订单闭环（同步锁库存、支付成功同步确认扣减、取消同步释放、CompensationService 定时补偿）。M7 不废弃 M4 同步路径，而是以异步事件作为主路径、同步调用作为降级兜底，保证 RocketMQ 故障时业务仍可用。
- **与 M5 的关系**：M5 已建立 FeatureGateService 与 SystemParameter；M7 复用其能力实现 `rocketmq.enabled` 开关与 `order.payment.timeout-minutes` 配置，不新建配置体系。
- **与既有 CompensationService 的关系**：M4 已建立 CompensationTask 聚合、CompensationService 每 30s 扫描、InventoryCompensationHandler 等机制；M7 新增的事件消费失败、延迟取消失败场景复用既有补偿体系，仅新增补偿任务类型，不新建独立补偿服务。
- **事件契约对齐**：订单集成事件 Topic/Tag/Payload 必须与 product/10-API与事件契约.md §41 保持一致；如需变更字段，须先更新 product/ 契约文档再实现，禁止代码先行契约后补。
- **不在 M7 范围**：Elasticsearch 商品索引事件同步（已在 M5 CHG-0021 实现）、退款事件、AI 写操作事件、跨集群消息路由、消息回溯 UI、分布式事务（Seata/2PC）。
