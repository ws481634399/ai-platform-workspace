# Requirement Spec（需求规格）— CHG-0025 M7 分布式增强

## 0. 元信息

- Change ID：CHG-0025
- Requirement：REQ-M7（REQ-M7-001 RocketMQ 事件基础设施 / REQ-M7-002 Outbox 可靠投递 / REQ-M7-003 订单集成事件与库存异步消费者 / REQ-M7-004 延迟订单自动取消 / REQ-M7-005 消费幂等与补偿机制）
- 主 Story：STORY-009-01-01（RocketMQ 事件基础设施，全链前置）；同 Change 并列 Story：STORY-009-02-01 / STORY-009-03-01 / STORY-009-04-01 / STORY-009-05-01（design 阶段补绑 stories[] 索引）
- Target User：平台工程自身（mall-common/mall-order/mall-inventory/mall-contracts）；运营/管理员（mall-admin Outbox/延迟取消/补偿任务查询与人工介入）；消费者间接获益（订单取消与库存释放最终一致、超时订单自动取消）
- Pain Points：M4 支付确认扣减/取消释放为同步强耦合调用，服务故障相互拖累；"业务提交成功但消息发送失败"缺乏原子性保障；定时扫描超时订单延迟不确定且消耗资源；重复/乱序消息与 DLQ 积压缺乏统一兜底
- Expected Value：把 V1 同步调用+定时补偿升级为可靠异步事件驱动（RocketMQ + Outbox + 延迟消息 + 幂等补偿），形成具备分布式一致性亮点的工程作品集；核心原则：**业务一致性优先于消息吞吐量**
- Scope In：五个 REQ 全部功能点（见 §3 S1~S6）+ 分布式横切要求（TraceId 贯通/事件版本/降级一致/审计）
- Scope Out：Kafka/Pulsar 接入、消息轨迹大盘、消息回溯 UI、跨集群路由、事务反向查询（REQ-001）；CDC/Debezium、跨库 Outbox、事件溯源（REQ-002）；库存超卖风控、预拆分、多仓路由、跨境隔离（REQ-003）；XXL-Job、秒级超时精度、多级提醒、催付通知（REQ-004）；Seata/2PC、TCC、Saga 编排、全量事件回溯（REQ-005）；M7 Integration Gate 七场景运行态联调（收尾阶段执行，本 Change 以单测/集成测试为自动化边界）
- 优先级：REQ-M7-001/002/003/005 为 P0，REQ-M7-004 为 P1

## 1. 背景

M0~M6 已交付同步交易闭环（M4 订单+库存+CompensationService 补偿）、系统配置（M5 FeatureGate）、Trace 贯通（M5 X-Trace-Id）与 AI 应用层（M6）。当前跨服务写操作以同步调用为主：支付成功同步调库存 confirm、取消同步调库存 release，服务故障相互拖累；超时订单靠定时任务扫描。M7 是"分布式增强"阶段：引入 RocketMQ 作为唯一消息中间件（不引入 Kafka/Pulsar），用 Outbox 解决业务事务与消息发送的原子性，用延迟消息替代定时扫描实现订单自动取消，用 consumed_event 幂等表 + 既有 CompensationTask 聚合兜底重复/乱序/DLQ 场景。

依赖顺序：001（基础设施）→ 002（Outbox）→（003 订单事件与库存消费者 ∥ 004 延迟取消）→ 005（幂等与补偿，与 003/004 并行）。

与 exploration.md §4 冲突检测结论一致：本规格不与 `standards/architecture-principles.md` 分层规则、M5 dynamic-config 契约、X-Trace-Id 标准、CHG-0019/0022/0023 既有交付冲突；M4 CompensationService/CompensationTask/OrderCancelService 复用不重开；事件契约严格对齐 product/10-API与事件契约.md §41 与 product/02-统一语言词汇表.md §19。

## 2. 用户价值

- 平台工程（架构演进）：When 支付成功/订单取消需要跨服务写库存, I want to 发布集成事件由库存服务异步幂等消费, So that 订单与库存解耦、故障隔离、最终一致，且 MQ 故障时事件不丢失。
- 平台工程（原子性）：When 业务事务提交需要同时对外发消息, I want to 只写本地 Outbox 表与业务同事务提交, So that 不会出现"业务成功但消息丢失"，MQ 恢复后自动续投。
- 平台工程（延迟任务）：When 用户创建订单后 30 分钟未支付, I want to 收到延迟消息到期回查并自动取消, So that 库存及时释放、订单状态及时收敛，不再依赖全表定时扫描。
- 运营/管理员：When 出现消息投递失败/消费死信/补偿失败, I want to 在 mall-admin 查询 Outbox/延迟任务/补偿任务状态并手动重投重试, So that 异常可排查、可介入、可审计，死信不静默丢失。
- 消费者（间接）：订单超时未支付被及时自动取消、库存被及时释放，可重新下单购买。
- 平台/公司：形成可演示的分布式一致性能力与 Integration Gate 七大场景（支付→扣减/取消→释放/重复消费幂等/乱序跳过/MQ 停止保留/MQ 恢复续投/超时自动取消），为后续事件驱动扩展建立模式（Envelope/Topic/消费者组/幂等/补偿）。

## 3. 功能范围

- [S1] **RocketMQ 事件基础设施（STORY-009-01-01，repo-1 mall-common 主 + mall-contracts + repo-4 infra）**：docker-compose 新增 RocketMQ（NameServer+Broker，Dashboard 可选）；mall-common mq 子模块实现统一事件 Envelope（eventId/eventType/eventVersion/occurredAt/producer/traceId/payload，与 §19 一致）；mall-contracts 集中声明 Topic/Tag 命名（order-events/inventory-events）与消费者组名（inventory-consumer-group/order-delay-consumer-group 等）；生产者封装（同步/异步/延迟三种发送，延迟级别参数化）；消费者抽象（注解式入口统一处理幂等检查、异常重试、TraceId 透传、消费日志）；事件版本兼容拒绝（高版本不静默按旧解析）；消费失败按 RocketMQ 重试策略重试、超限进 DLQ 且提供查询入口；`rocketmq.enabled` 配置开关（关闭时降级同步调用，不允许半开半闭）。
- [S2] **Outbox 可靠投递（STORY-009-02-01，repo-1 mall-order 主 + mall-common + repo-2 mall-admin）**：mall-order 新增 outbox_event 表（Flyway，字段含 id/aggregate_id/event_type/payload/status PENDING|SENT|FAILED/retry_count/next_retry_at/created_at/sent_at/trace_id）；业务事务与 Outbox 记录原子写入（写入失败回滚业务事务）；独立投递任务扫描 PENDING 且到期记录推送 RocketMQ，成功标 SENT、失败递增 retry_count 有界退避；MQ 停止保留 PENDING 不删不标失败，恢复后自动续投；同聚合按 created_at 顺序投递；eventId 作消息 keys；超最大重试标 FAILED 进人工队列；mall-admin Outbox 查询（按状态/类型/聚合筛选+查看 payload）+ 手动重投（记审计）。
- [S3] **订单集成事件与库存异步消费者（STORY-009-03-01，repo-1 mall-order + mall-inventory + mall-contracts）**：mall-order 在订单创建/支付/取消/完成四个状态迁移事务提交后经 Outbox 发布 4 个 Tag（ORDER_CREATED/PAYMENT_SUCCEEDED/ORDER_CANCELLED/ORDER_COMPLETED），Payload 与 §41 契约一致；mall-inventory 消费 PAYMENT_SUCCEEDED 将预留库存转确认扣减（基于 reservationNo 业务幂等+eventId 消费幂等）、消费 ORDER_CANCELLED 释放锁定库存（同口径幂等）；乱序消息按订单当前状态判断（已取消收 PAYMENT_SUCCEEDED 跳过+告警、已完成收 ORDER_CANCELLED 跳过+告警）；消费失败进 DLQ 由既有 CompensationService 兜底；RocketMQ 不可用时降级同步调用 mall-inventory 内部 API（与 M4 一致）并记降级日志，降级与异步路径业务结果一致。
- [S4] **延迟订单自动取消（STORY-009-04-01，repo-1 mall-order + mall-contracts）**：订单创建事务提交后经 Outbox 投递延迟消息至 order-delay Topic（延迟级别映射 SystemParameter `order.payment.timeout-minutes`，默认 30 分钟，动态生效复用 M5）；Payload 含 orderId/orderNo/expireAt；到期回查订单聚合当前状态（不依赖消息内状态快照）：PENDING_PAYMENT→调用 OrderCancelService 自动取消（cancelReason=PAYMENT_TIMEOUT，复用 M4 CAS+释放+补偿登记全流程）；已支付/已取消/已完成→ACK 跳过；重复延迟消息基于订单状态幂等不重复取消；保留 CompensationService 定时扫描兜底防消息丢失，双路径业务结果一致无双重取消；mall-admin 延迟取消任务查询+手动触发取消（记审计）。
- [S5] **消费幂等与补偿机制（STORY-009-05-01，repo-1 mall-inventory + mall-order + mall-common + repo-2 mall-admin）**：mall-inventory 新增 consumed_event 表（event_id 唯一键/event_type/consumer_group/aggregate_id/processed_at/result/trace_id，Flyway）；消费前幂等检查（INSERT 冲突即跳过），幂等键统一 eventId 禁用业务字段；复用 mall-order CompensationTask 聚合扩展三种补偿类型（INVENTORY_CONFIRM_DEDUCT/INVENTORY_RELEASE/ORDER_AUTO_CANCEL），同一业务操作只保留一条补偿任务、幂等登记、有界退避；CompensationService 每 30s 扫描（与 M4 一致，不引入新调度器）；超最大重试标 FAILED 等人工介入；mall-admin 补偿任务查询（按类型/状态/聚合筛选）+ 手动重试 + 手动标记完成（记审计含操作前后状态）；DLQ 由补偿任务接管不要求实时处理；eventId/traceId 在事件→Outbox→投递→消费→补偿全链路贯通。
- [S6] **分布式横切（并入 S1~S5，跨仓）**：TraceId 贯通（生产者从 MDC 注入 Envelope.traceId→Outbox.trace_id→投递保留→消费者写入 MDC 传播下游→补偿任务保留原 traceId，与 M5 X-Trace-Id 约定同源）；事件版本演进（eventVersion 兼容拒绝）；降级一致性（MQ 不可用降级同步与异步路径业务结果一致）；RocketMQ 客户端版本由 mall-bom 统一管理并与 Spring Cloud Alibaba 2025.0.0.0 对齐。

## 4. 业务规则总纲

**A. 一致性与原子性（最高优先级）**
1. 业务一致性优先于吞吐量：所有跨服务写操作经幂等表 + 事件版本 + 补偿任务保证最终一致，不做高吞吐优化。
2. Outbox 原子性：业务事务提交时 Outbox 记录一并持久化；禁止"先发消息后写库"或"先写库后发消息"的非原子模式；Outbox 写入失败必须回滚业务事务。
3. MQ 停止不丢事件：RocketMQ 不可用时投递任务保留 Outbox 记录 PENDING，不删除、不标失败；MQ 恢复后自动续投，无需人工干预。
4. 降级一致：RocketMQ 不可用降级同步调用（与 M4 一致）时，业务结果与异步路径一致，且必须记录降级日志；`rocketmq.enabled=false` 为明确配置时走同步路径，不允许半开半闭。

**B. 事件契约与版本**
5. 契约对齐 §41：4 个订单事件 Tag 与 Payload 字段严格按 product/10-API与事件契约.md §41，字段变更须先改契约文档。
6. Envelope 对齐 §19：eventId/eventType/eventVersion/occurredAt/producer/traceId/payload 七字段缺一不可。
7. 幂等键统一 eventId：消费幂等与消息 keys 一律用 eventId；禁止以业务字段（reservationNo/orderNo）作幂等键。
8. 版本拒绝：消费者收到高于自身支持 eventVersion 的事件必须明确拒绝/降级并告警，不允许静默按旧版本字段解析。
9. 顺序保证范围：同聚合（同 orderId）内按 created_at 顺序投递；跨聚合顺序不保证，消费端不得依赖跨聚合顺序。

**C. 幂等与乱序**
10. 消费幂等表先行：消费前查 consumed_event（event_id 唯一），已存在直接 ACK 跳过；不允许仅依赖业务状态判断幂等。
11. 乱序以订单状态裁决：订单已取消收 PAYMENT_SUCCEEDED → 跳过+告警；订单已完成收 ORDER_CANCELLED → 跳过+告警；判断基于订单聚合当前状态，不依赖消息内状态快照。
12. 延迟消息幂等：同一订单多条延迟消息，订单已非 PENDING_PAYMENT 直接 ACK 跳过，不重复触发取消。
13. 补偿幂等：同一业务操作只保留一条 CompensationTask；补偿执行幂等（重复执行不产生重复扣减/释放/取消）。

**D. 取消与补偿协同**
14. 自动取消必经 OrderCancelService：延迟消息到期回查确认未支付后，调用 OrderCancelService（cancelReason=PAYMENT_TIMEOUT）复用 M4 既有取消流程（CAS 状态迁移+库存释放+补偿登记）；禁止绕过自行实现取消逻辑。
15. 双路径兜底：延迟消息主路径与 CompensationService 定时扫描兜底并存，业务结果一致，不允许双重取消或取消冲突。
16. 补偿复用不重建：M7 消费失败/延迟取消失败登记为既有 CompensationTask 聚合的新类型，不新建独立补偿体系；扫描周期 30s 与 M4 一致。
17. DLQ 不静默：消费失败按 RocketMQ 默认策略重试，超限进 DLQ；DLQ 由补偿任务接管，提供查询入口，不允许死信静默丢弃。
18. 人工介入全审计：mall-admin 手动重投/重试/标记完成/手动取消必须记录审计（操作人/时间/操作前后状态/traceId）。

**E. 配置与开关**
19. 开关语义：`rocketmq.enabled=false` → 生产与消费关闭，订单/库存相关跨服务写操作走 M4 同步路径；配置读取复用 M5 FeatureGate/SystemParameterProvider 模型。
20. 超时配置动态生效：`order.payment.timeout-minutes` 经 SystemParameter 配置，动态生效（复用 M5 能力），默认 30 分钟；延迟级别与配置值映射由 design 定（RocketMQ 18 级延迟向最近级别对齐策略）。
21. 中间件统一纳管：RocketMQ（NameServer+Broker+Dashboard 可选）进 docker-compose 与既有 MySQL/Redis/Nacos/MinIO/ES 统一管理，服务经 Nacos 配置获取地址。

**F. 待澄清项定稿（prd 阶段决议）**
22. 已定稿（产品层）：`rocketmq.enabled=false` 时订单状态迁移仍写 Outbox 保持审计与恢复能力，但投递任务与消费者关闭，跨服务库存操作走 M4 同步路径（降级日志照记）；延迟消息经 Outbox 通道投递（订单创建事务内与 ORDER_CREATED 同事务写入 Outbox，投递任务按 event_type 路由延迟级别），保证与业务同原子性；乱序判断数据源=消费者回调 mall-order 订单状态查询内部 API（库存服务不直查订单库）；DLQ 查询入口首期合入 mall-admin 补偿任务查询页（按来源 DLQ 筛选），RocketMQ Dashboard 可选部署用于开发调试；Outbox FAILED/补偿超限人工介入入口统一 mall-admin；Outbox 投递任务并发控制由 design 定（乐观锁或 SELECT FOR UPDATE）；CompensationTask 字段扩展范围由 design 评估。
23. 待设计阶段确认（技术选型，不阻塞 spec）：RocketMQ 客户端版本与 Spring Cloud Alibaba 2025.0.0.0/Spring Boot 3.5.15 兼容矩阵与 mall-bom 管理方式；Envelope 落地形态（mall-contracts 接口 + mall-common mq 实现）；消费者注解抽象实现方式（自研 @IntegrationEventListener vs 直接用 rocketmq-spring 注解）；Topic 环境隔离（前缀/namespace）；事件版本拒绝具体策略（重试进 DLQ vs ACK+告警）；退避策略具体参数值；投递任务扫描批量/间隔；延迟级别对齐算法；consumed_event/outbox_event 表索引与分区；Flyway 版本号衔接；Windows 下 RocketMQ 容器兼容性验证；DU 拆分边界（按 REQ vs 按仓）。

## 5. 全局验收标准

### Story 1（STORY-009-01-01 RocketMQ 事件基础设施）

| ID | 验收标准（可测试） | 备注 |
| --- | --- | --- |
| AC-001 | `docker compose up` 启动 RocketMQ（NameServer+Broker）健康检查通过；mall-order/mall-inventory 经 Nacos 配置连接成功 | P0 |
| AC-002 | 生产者发送事件后消息到达指定 Topic/Tag；Envelope 含 eventId/eventType/eventVersion/occurredAt/producer/traceId/payload 七字段且非空（traceId 缺失时自动生成） | |
| AC-003 | mall-contracts 中可查到 order-events/inventory-events Topic、4 个订单 Tag、inventory-consumer-group/order-delay-consumer-group 消费者组集中声明；各服务无散落硬编码 | |
| AC-004 | 生产者封装支持同步/异步/延迟三种发送；延迟发送的 delayLevel 参数化（单测验证三种模式调用路径） | |
| AC-005 | 消费者收到事件后 MDC 写入 Envelope.traceId，下游 internal 调用日志含同一 traceId；缺失 traceId 时生成新 ID 且消费不阻断 | |
| AC-006 | 消费者收到 eventVersion 高于自身支持版本的事件 → 拒绝处理并告警，不按旧版本解析（测试构造 v2 事件验证） | |
| AC-007 | 消费抛异常 → 按 RocketMQ 策略重试；构造持续失败消息 → 超限后进入 DLQ；DLQ 消息可通过查询入口查到，不静默丢弃 | |
| AC-008 | rocketmq.enabled=false → 生产者/消费者不初始化，调用方走同步路径，服务正常启动无半开状态；置 true 重启后恢复事件收发 | |
| AC-009 | mall-common mq 子模块单测/集成测试通过（Envelope 构建/发送/消费/TraceId/版本拒绝） | |

### Story 2（STORY-009-02-01 Outbox 可靠投递）

| ID | 验收标准（可测试） | 备注 |
| --- | --- | --- |
| AC-010 | 订单业务事务提交后 outbox_event 表存在对应 PENDING 记录（同事务写入）；Outbox 写入失败 → 业务事务回滚（测试注入写失败验证回滚） | P0 |
| AC-011 | 投递任务扫描到期 PENDING 记录发送 RocketMQ → 成功标 SENT 并写 sent_at；RocketMQ 中消息 keys 含 eventId | |
| AC-012 | 停止 RocketMQ → 投递失败记录保留 PENDING 且 retry_count 递增、next_retry_at 按退避推迟；不删除、不标 FAILED | MQ 停止保留 |
| AC-013 | 重启 RocketMQ → 投递任务无需人工干预自动续投 PENDING 记录直至 SENT；消费端幂等保证不重复处理 | MQ 恢复续投 |
| AC-014 | 同一 orderId 多条事件按 created_at 顺序投递（测试构造 3 条事件断言到达顺序）；跨聚合顺序不保证 | |
| AC-015 | 持续失败超过最大重试次数 → 标 FAILED 并记录失败原因；FAILED 记录可在 mall-admin 查询（按状态/类型/聚合筛选+查看 payload） | |
| AC-016 | mall-admin 手动重投 FAILED 记录 → 状态回 PENDING 并被投递成功；审计记录含操作人/时间/操作前后状态 | |
| AC-017 | Outbox 核心（事务原子写入/扫描投递/退避/顺序/管理查询）单测+集成测试通过 | |

### Story 3（STORY-009-03-01 订单集成事件与库存异步消费者）

| ID | 验收标准（可测试） | 备注 |
| --- | --- | --- |
| AC-018 | 订单创建/支付成功/取消/完成四个事务提交后，order-events Topic 分别出现 ORDER_CREATED/PAYMENT_SUCCEEDED/ORDER_CANCELLED/ORDER_COMPLETED 消息；Payload 字段与 §41 契约一致（契约校验测试） | P0 |
| AC-019 | 支付成功事件被 mall-inventory 消费 → 预留库存转为确认扣减（reservationNo 对应库存聚合状态正确变化） | Integration Gate 1 |
| AC-020 | 订单取消事件被 mall-inventory 消费 → 锁定库存释放（Available 恢复，流水记录 RELEASE） | Integration Gate 2 |
| AC-021 | 同一 PAYMENT_SUCCEEDED 事件重复投递消费 N 次 → 库存仅扣减一次；同一 ORDER_CANCELLED 重复投递 → 仅释放一次（consumed_event 各只有一条记录） | 重复消息 |
| AC-022 | 订单已取消后投递 PAYMENT_SUCCEEDED → 消费者跳过并记录告警日志；订单已完成（或已取消）后投递 ORDER_CANCELLED → 跳过+告警；库存数据不变 | Integration Gate 4 |
| AC-023 | 构造消费失败 → 事件进入 DLQ 后，对应补偿任务（INVENTORY_CONFIRM_DEDUCT/INVENTORY_RELEASE）被登记并可查询 | |
| AC-024 | RocketMQ 不可用时支付/取消 → 降级同步调用 mall-inventory 内部 API，业务结果与异步路径一致（库存终态相同）；降级日志可查 | 同步降级 |
| AC-025 | 库存消费者核心（幂等扣减/释放/乱序跳过/降级）单测+集成测试通过 | |

### Story 4（STORY-009-04-01 延迟订单自动取消）

| ID | 验收标准（可测试） | 备注 |
| --- | --- | --- |
| AC-026 | 订单创建事务提交后 order-delay Topic 出现延迟消息（Payload 含 orderId/orderNo/expireAt；延迟级别与 order.payment.timeout-minutes 映射正确）；该写入与 ORDER_CREATED 事件同事务进 Outbox | P1 |
| AC-027 | 延迟到期（测试用短延迟级别）后消费者回查订单状态：PENDING_PAYMENT → 触发自动取消，订单状态变 CANCELLED 且 cancelReason=PAYMENT_TIMEOUT，库存已释放 | Integration Gate 7 |
| AC-028 | 已支付订单的延迟消息到期 → 订单不被取消，消费者 ACK 跳过；已取消/已完成订单同理 | |
| AC-029 | 同一订单重复投递延迟消息（模拟 Outbox 重投）→ 仅触发一次取消流程，无重复取消/重复释放库存 | |
| AC-030 | 禁用延迟消息路径（模拟消息丢失）→ CompensationService 定时扫描兜底取消超时订单；两路径对同一订单不产生双重取消（并发竞争测试） | 定时兜底 |
| AC-031 | 修改 order.payment.timeout-minutes 配置 → 新建订单按新超时时间映射延迟级别（动态生效，无需重启） | |
| AC-032 | mall-admin 可查询延迟取消任务（待取消/已取消/失败）并手动触发取消；手动操作留审计记录 | |

### Story 5（STORY-009-05-01 消费幂等与补偿机制）

| ID | 验收标准（可测试） | 备注 |
| --- | --- | --- |
| AC-033 | mall-inventory 每成功处理一个事件 → consumed_event 表新增一条记录（event_id 唯一键/event_type/consumer_group/aggregate_id/processed_at/result/trace_id） | P0 |
| AC-034 | 重复消费同一 eventId → 幂等检查命中直接 ACK 跳过，业务不重复执行（并发重复消费测试） | Integration Gate 3 |
| AC-035 | 事件消费失败 → 登记对应类型 CompensationTask（INVENTORY_CONFIRM_DEDUCT/INVENTORY_RELEASE/ORDER_AUTO_CANCEL）；同一业务操作重复失败仅保留一条任务 | |
| AC-036 | CompensationService 30s 扫描到期补偿任务执行重试 → 成功标完成；持续失败按有界退避重试 | |
| AC-037 | 补偿任务超过最大重试次数 → 标 FAILED 等待人工；mall-admin 可按类型/状态/聚合筛选查询并查看 payload | |
| AC-038 | mall-admin 手动重试 FAILED 任务 → 任务恢复重试且成功后状态正确；手动标记完成 → 状态变更且审计记录含操作人/时间/前后状态 | |
| AC-039 | 一次事件全链路（生产→Outbox→投递→消费→补偿）各环节记录/日志含同一 eventId 与 traceId；补偿任务执行日志沿用原事件 traceId | TraceId 贯通 |
| AC-040 | 幂等与补偿核心（幂等表/任务登记/扫描重试/人工介入/TraceId）单测+集成测试通过 | |

### 跨 Story 验收（S6 横切 + Integration Gate 汇总）

| ID | 验收标准（可测试） | 备注 |
| --- | --- | --- |
| AC-041 | RocketMQ 客户端版本由 mall-bom 统一管理；各服务 pom 无散落版本号；依赖树与 Spring Boot 3.5.15/Spring Cloud Alibaba 2025.0.0.0 无冲突 | |
| AC-042 | Integration Gate 七场景演练脚本/用例就绪：支付→扣减、取消→释放、重复幂等、乱序跳过、MQ 停止保留、MQ 恢复续投、超时自动取消+重复延迟幂等（本 Change 以集成测试覆盖，运行态联调收尾执行） | |
| AC-043 | 既有 M0~M6 自动化用例零回退（同步路径在 rocketmq.enabled=false 与 MQ 故障降级场景下行为与 M4 一致） | |

## 6. 补充约束

- 仓库与分支：沿用各仓当前工作分支，本地按 DU 提交不 push（push 需用户确认）；mall-bom 新增 RocketMQ 依赖管理，禁止散落版本。
- 复用边界：CompensationService/CompensationTask/InventoryCompensationHandler/OrderCancelService 复用 M4 既有实现（扩展不重开）；FeatureGate/SystemParameterProvider 复用 M5 配置模型；X-Trace-Id 与 MDC 约定复用 M5（CHG-0023 A3）；docker-compose 模式复用 M0；事件契约复用 product/10-API与事件契约.md §41 与 02-统一语言词汇表.md §19。
- 架构红线：消费者处理业务调用服务内部聚合方法（Service 层），不绕过到 Repository 直改库；库存服务判断乱序需查订单状态时经 mall-order 内部 API，不直连订单库；AI Service 不接入 RocketMQ（M7 范围内 Java 微服务集群事件驱动）。
- 安全红线：mall-admin 手动操作全部审计；SERVICE 身份鉴权的内部 API 不对 mall-web/mall-admin 暴露；JWT 双算法验证等 M6 安全设计不受影响。
- 待澄清项（§4.F-23）由 design 阶段逐项定稿并在 requirement-design.md 记录决策依据；Integration Gate 七场景运行态联调在 M7 收尾执行。

## 7. 成功指标

- Integration Gate 七大场景全部可演示通过（支付→库存扣减/取消→库存释放/重复消费幂等/乱序跳过/MQ 停止保留/MQ 恢复续投/超时自动取消+重复延迟幂等）。
- 数据一致性零违例：测试与演示中不出现库存重复扣减/重复释放、订单双重取消、死信静默丢失（AC-021/022/029/030/034 等守护）。
- 可用性提升可观测：MQ 停机期间订单/支付业务不中断（Outbox 保留+同步降级），MQ 恢复后事件自动续投成功率 100%（AC-012/013/024）。
- 自动化用例净增：mall-common mq 子模块、mall-order（Outbox/延迟/补偿扩展）、mall-inventory（消费者/幂等表）测试覆盖五 REQ 核心，既有用例零回退。
- 可观测：事件全链路一次投递一个 eventId+traceId 串联（生产→Outbox→投递→消费→补偿），mall-admin 三类任务（Outbox/延迟/补偿）100% 可查询可介入可审计。
