# Exploration（需求探索报告）

> 阶段：sdd-explore 产物
> 输入：《product/14-开发计划.md》§11 阶段 5（M7 分布式增强）+《product/10-API与事件契约.md》§41（集成事件契约）+《product/02-统一语言词汇表.md》§19（集成事件统一字段）
> 产出状态：exploring

## 1. 需求要点

- 做什么：在 M0~M6 已建成的同步交易闭环（M4 订单+库存+补偿）与 AI 应用层（M6）基础上，把"以同步调用与定时补偿为主"的跨服务写操作升级为"可靠异步事件驱动 + 延迟消息 + 幂等与补偿兜底"的分布式一致性方案，形成具备分布式亮点的工程作品集。M7 围绕 RocketMQ 构建五项核心能力：
  1. **REQ-M7-001 RocketMQ 事件基础设施**（P0）：在 mall-common 建立统一事件封装——Envelope（eventId/eventType/eventVersion/occurredAt/producer/traceId/payload，与 §19 一致）、Topic/Tag 命名、消费者组、生产者（同步/异步/延迟三种）、消费者抽象（注解式入口+幂等检查+异常重试+TraceId 透传+消费日志）、事件版本兼容拒绝、重试与死信（DLQ）、配置开关（`rocketmq.enabled`，关闭降级同步）；docker-compose 新增 RocketMQ（NameServer+Broker+Dashboard 可选）。
  2. **REQ-M7-002 Outbox 可靠投递**（P0）：在 mall-order 新增 `outbox_event` 表，业务事务与 Outbox 记录原子写入；独立投递任务扫描 PENDING 推送到 RocketMQ；MQ 停止时保留 PENDING 不丢不删；MQ 恢复后续投；有界退避重试，超限标 FAILED 进人工队列；同聚合按 created_at 顺序投递；eventId 作幂等键；mall-admin 查询与手动重投。
  3. **REQ-M7-003 订单集成事件与库存异步消费者**（P0）：mall-order 在订单状态迁移时发布 4 个 Tag（ORDER_CREATED/PAYMENT_SUCCEEDED/ORDER_CANCELLED/ORDER_COMPLETED，与 §41 一致），mall-inventory 订阅 PAYMENT_SUCCEEDED/ORDER_CANCELLED 做幂等确认扣减与释放；乱序消息按订单当前状态判断（已取消收 PAYMENT_SUCCEEDED 跳过+告警）；消费失败进 DLQ 由 M4 既有 CompensationService 兜底；RocketMQ 不可用降级同步调用 mall-inventory 内部 API（与 M4 一致）。
  4. **REQ-M7-004 延迟订单自动取消**（P1）：订单创建事务提交后投递延迟消息至 `order-delay` Topic（延迟级别对应超时时间，由 SystemParameter `order.payment.timeout-minutes` 配置默认 30 分钟）；到期回查订单状态，未支付则调用 OrderCancelService（cancelReason=PAYMENT_TIMEOUT）复用 M4 既有取消流程；重复延迟消息基于订单状态幂等；保留 CompensationService 定时扫描兜底；mall-admin 延迟取消任务查询。
  5. **REQ-M7-005 消费幂等与补偿机制**（P0）：在 mall-inventory 新增 `consumed_event` 表（event_id 唯一键）；幂等键统一用 eventId（禁用业务字段）；复用 mall-order 既有 CompensationTask 聚合，新增 INVENTORY_CONFIRM_DEDUCT/INVENTORY_RELEASE/ORDER_AUTO_CANCEL 三种补偿类型；CompensationService 每 30s 扫描（与 M4 一致）；mall-admin 补偿任务查询+手动重试+标记完成；TraceId 在事件→Outbox→投递→消费→补偿链路贯通。
- 给谁：平台工程自身（mall-common/mall-order/mall-inventory/mall-admin）；不直接面向消费者，但消费者间接获益于"订单取消与库存释放最终一致"；mall-admin 运营/管理员通过 Outbox/延迟/补偿任务查询入口介入异常。
- 解决什么问题：
  1. 把 M4 "支付成功同步调用库存 confirm、取消同步调用库存 release" 的强耦合升级为"事件驱动 + 异步消费 + 幂等兜底"，降低服务间同步依赖、提升故障隔离；
  2. 把 M4 "CompensationService 每 30s 扫描待补偿任务" 的兜底机制升级为"消息驱动主路径 + CompensationService 兜底"，主路径实时性更高、兜底更聚焦；
  3. 把 V1 "定时任务扫描超时订单" 升级为 "RocketMQ 延迟消息 + 到期回查 + 自动取消 + 定时兜底"，降低扫描资源消耗与延迟不确定性；
  4. 用 Outbox 解决 "业务提交成功但消息发送失败" 的原子性问题；
  5. 用 consumed_event 表解决 "重复消费、乱序消费、DLQ 积压" 的最终一致性问题。
- 必须守住的边界（贯穿五 REQ 的核心约束）：
  1. **业务一致性优先于吞吐量**：不追求高 TPS，所有跨服务写操作通过幂等表 + 事件版本 + 补偿任务保证最终一致性；
  2. **异步为主、同步降级**：RocketMQ 故障时降级到 M4 同步调用，业务结果必须一致；不允许半开半闭导致行为不可预期；
  3. **复用既有补偿体系**：M4 已建 CompensationService/CompensationTask，M7 不新建独立补偿服务，仅扩展补偿类型与场景；
  4. **事件契约对齐 §41**：4 个订单事件 Tag 与 Payload 字段严格按 product/10-API与事件契约.md §41 定义，禁止临时变更字段；
  5. **幂等键用 eventId**：禁用业务字段（reservationNo/orderNo）作幂等键（业务字段可能因多事件重复触发）；
  6. **延迟取消复用 OrderCancelService**：禁止绕过 OrderCancelService 自行实现取消逻辑（CAS 状态迁移 + 库存 release + 补偿登记必须在聚合内）；
  7. **不引入额外中间件**：延迟消息与 Outbox 是演示分布式能力的载体，不引入 Kafka/Pulsar/Seata/TCC/Saga；
  8. **DLQ 不静默丢弃**：超过最大重试次数进 DLQ，必须提供查询入口，由补偿任务接管，不允许死信消息丢失。
- 知识检索结果（引用来源）：
  - 《14-开发计划.md》§11 阶段 5（M7 定义，含五 REQ 范围与 Integration Gate 七场景）；
  - 《10-API与事件契约.md》§41 L3069-3179：已定义 OrderCreated/PaymentSucceeded/OrderCancelled/OrderCompleted IntegrationEvent 的 topic/tag/payload/消费者，M7 直接复用此契约；
  - 《02-统一语言词汇表.md》§19 L1013-1039：集成事件统一字段（eventId/eventType/eventVersion/occurredAt/producer/traceId/payload），M7 Envelope 严格按此定义；
  - `product/feature-tree.yaml`：FEAT-004 订单交易 → FEAT-004-02 支付与取消（STORY-004-02-01 模拟支付与订单取消 delivered）+ FEAT-004-04 交易异常与补偿（STORY-004-04-01-01 planned）是 M7 直接复用的底座；FEAT-002-04 库存核心能力（STORY-002-04-03-01 库存确认扣减 delivered、STORY-002-04-02-01 库存锁定与释放 delivered）是 M7 库存消费者调用对象；FEAT-1-03 本地基础设施（STORY-1-03-01-01 delivered）是 M7 docker-compose 新增 RocketMQ 的挂靠点；FEAT-006 系统配置（delivered）是 M7 `order.payment.timeout-minutes` 配置消费底座；
  - `standards/architecture-principles.md` 分层架构与依赖规则——M7 跨服务事件发布/消费属跨进程横切，Outbox 投递任务与 CompensationService 扫描属服务内部 Scheduler，不破坏既有 Controller→Service→Repository 链；
  - 既有代码关键发现：
    - `mall-order` 已有 CompensationService.java（每 30s 扫描）、CompensationTask.java（聚合，幂等登记+有界退避）、InventoryCompensationHandler、OrderCancelService.java（CAS 状态迁移+释放库存+登记补偿），M7 直接扩展；
    - `mall-common` 已有 8 个技术子模块（web/log/security/db/redis/mq/trace/contracts），但 `mq` 子模块当前为骨架未实现 RocketMQ 封装——M7 REQ-M7-001 在此扩展；
    - `docker-compose` 当前已有 MySQL/Redis/Nacos/MinIO/Elasticsearch，未含 RocketMQ——M7 新增；
    - `mall-order/mall-inventory` 数据库均未含 outbox_event/consumed_event 表——M7 新增（Flyway 迁移）。
- 隐含需求（用户未明说但工程必须覆盖）：
  1. **TraceId 贯通扩展到事件链**：M5 CHG-0023 A3 已实现 X-Trace-Id 跨 12 个 internal RestClient 拦截器；M7 需扩展到 RocketMQ 生产者→Broker→消费者→下游调用的全链路，Producer 在发送前注入 Envelope.traceId，Consumer 接收后写入 MDC 并传播至下游；
  2. **事件版本演进策略**：消费者必须识别 eventVersion 高于自身支持版本时拒绝/降级，不允许静默按旧版本字段解析——此项在 REQ-M7-001 §9 已显式，但实现细节需 Design 阶段定（拒绝策略 vs 兼容策略）；
  3. **DLQ 查询入口**：REQ-M7-001 §10 要求提供 DLQ/失败任务查询入口，但入口形态（mall-admin 页面 vs RocketMQ Dashboard）需 Design 定；
  4. **Outbox 投递任务并发控制**：多实例部署时投递任务需避免重复扫描同一记录（SELECT FOR UPDATE 或乐观锁）；
  5. **延迟级别与超时时间映射**：RocketMQ 默认 18 个延迟级别（1s/5s/10s/30s/1m/2m/3m/4m/5m/6m/7m/8m/9m/10m/20m/30m/1h/2h），订单超时 30 分钟对应级别 16，但若配置为非标准值需向最接近级别对齐——需 Design 明确；
  6. **事件 Schema 注册中心**：mall-contracts 已定义集成事件契约模块，M7 Envelope/Tag/消费者组名应集中声明在 mall-contracts，避免散落各服务；
  7. **RocketMQ 配置开关 fail 行为**：`rocketmq.enabled=false` 时，订单状态迁移是否仍写 Outbox（PENDING 状态等待恢复）？还是直接降级同步？需 Design 明确——REQ-M7-001 §11 要求"关闭时业务服务降级到同步调用或直接拒绝相关写操作"，但具体策略需定；
  8. **延迟消息与 Outbox 关系**：REQ-M7-004 §2 要求"订单创建事务提交后投递延迟消息"，与 REQ-M7-002 Outbox 同事务写入——延迟消息也是 Outbox 事件的一种？还是独立通道？需 Design 明确；
  9. **补偿任务 TraceId 保留**：REQ-M7-005 §9 要求补偿任务执行时保留原事件 traceId，需扩展 CompensationTask 表 trace_id 列（M5 CHG-0023 A3 已加），并在登记补偿时写入；
  10. **Flyway 迁移版本号递增**：outbox_event/consumed_event 表的 Flyway 脚本版本号需与既有 mall-order/mall-inventory 迁移历史衔接，不重复不跳号。

## 2. Story 归属判定

- Feature ID: **FEAT-009**（新建 L1 Module：分布式增强，承载 M7 全部 RocketMQ 事件驱动与分布式一致性能力，与既有 FEAT-004 订单交易中的同步补偿 STORY-004-04-01-01 区分——前者是异步事件驱动基础设施与业务事件，后者是同步补偿兜底）。
- Feature 路径: 分布式增强 → 五个 L2 并行子功能（RocketMQ 事件基础设施 / Outbox 可靠投递 / 订单集成事件与库存异步消费者 / 延迟订单自动取消 / 消费幂等与补偿机制）→ 每个 L2 一个 Story。
- Story 节点（feature-tree.yaml 待新建，本 Change 含 5 个，均 planned，1:1 对应 5 个 REQ）：
  - **STORY-009-01-01 RocketMQ 事件基础设施**（repo-1 mall-common 主，repo-4 infra）：docker-compose 新增 RocketMQ（NameServer+Broker+Dashboard 可选）；mall-common mq 子模块实现 Envelope（与 §19 一致）+ Topic/Tag 命名 + 消费者组 + 生产者（同步/异步/延迟）+ 消费者抽象（注解式入口+幂等+异常重试+TraceId 透传+消费日志）+ 事件版本兼容拒绝 + 重试与 DLQ + `rocketmq.enabled` 开关；mall-contracts 集中声明事件契约与消费者组名。
  - **STORY-009-02-01 Outbox 可靠投递**（repo-1 mall-order 主，repo-1 mall-common，repo-2 mall-admin）：mall-order 数据库新增 outbox_event 表（Flyway）；订单状态迁移事务内原子写 Outbox；独立投递任务（@Scheduled）扫描 PENDING 推送到 RocketMQ；MQ 停止保留 PENDING，恢复续投；有界指数退避重试，超限标 FAILED；同聚合按 created_at 顺序投递；eventId 作消息 keys；mall-admin Outbox 查询+手动重投。
  - **STORY-009-03-01 订单集成事件与库存异步消费者**（repo-1 mall-order + mall-inventory，repo-1 mall-contracts）：mall-order 在 4 个订单状态迁移点写 Outbox 事件（ORDER_CREATED/PAYMENT_SUCCEEDED/ORDER_CANCELLED/ORDER_COMPLETED，Payload 与 §41 一致）；mall-inventory 消费 PAYMENT_SUCCEEDED 调库存聚合幂等确认扣减 + 消费 ORDER_CANCELLED 调库存聚合幂等释放；乱序按订单当前状态判断；消费失败进 DLQ 由 CompensationService 兜底；RocketMQ 不可用降级同步调用 mall-inventory 内部 API。
  - **STORY-009-04-01 延迟订单自动取消**（repo-1 mall-order，repo-1 mall-contracts）：订单创建事务提交后投递延迟消息至 order-delay Topic（延迟级别对应 order.payment.timeout-minutes 配置默认 30 分钟）；到期回查订单状态，未支付调 OrderCancelService（cancelReason=PAYMENT_TIMEOUT）复用 M4 既有取消流程；重复延迟消息基于订单状态幂等；保留 CompensationService 定时扫描兜底；mall-admin 延迟取消任务查询。
  - **STORY-009-05-01 消费幂等与补偿机制**（repo-1 mall-inventory + mall-order + mall-admin，repo-1 mall-common）：mall-inventory 数据库新增 consumed_event 表（event_id 唯一键，Flyway）；幂等键统一 eventId；复用 mall-order CompensationTask 聚合扩展 INVENTORY_CONFIRM_DEDUCT/INVENTORY_RELEASE/ORDER_AUTO_CANCEL 三种补偿类型；CompensationService 每 30s 扫描（与 M4 一致）；mall-admin 补偿任务查询+手动重试+标记完成；TraceId 在事件→Outbox→投递→消费→补偿链路贯通。
- is-new-candidate: 否。FEAT-009 为新建 L1 业务域，5 个 Story 全部源自 14-开发计划.md §11 的 5 个 REQ，无未确认候选；不触发 Candidate 兜底分支。
- 组划分理由：14-开发计划.md §11 明确"M7 围绕 RocketMQ 构建四项核心能力"（实际为五 REQ），每个 REQ 独立可交付，1 REQ → 1 L2 → 1 Story 的 1:1:1 映射最清晰；M7 推荐依赖关系图（001→002→（003∥004）→005）也支持 5 Story 串/并行编排。Design 阶段如某 Story 过大（如 003 含 4 个 Tag + 库存消费者 + 乱序处理 + 同步降级），可在该 Story 内部拆 DU 分批实施，不破坏 L2→Story 1:1 结构。
- 主 Story 绑定：本 Change 在 explore 阶段绑定 **STORY-009-01-01（RocketMQ 事件基础设施）** 作为 feature-path 主 Story（M7 第一个 REQ，是所有其他 REQ 的前置——002 投递任务依赖 001 生产者，003/004 依赖 001+002，005 依赖 001+003）；其余 4 Story 已在 feature-tree.yaml 创建，将在 design/story-splitting 阶段补绑至 stories[] 索引。

## 3. 证据评估

- 业务依据：14-开发计划.md §11 阶段 5 明确"M7 把 V1 中以同步调用、定时补偿为主的后续处理升级为可靠异步事件驱动，形成具备分布式一致性亮点的工程作品集项目"；M7 Integration Gate 七大场景（支付→库存扣减/取消→库存释放/重复消费幂等/乱序按订单状态跳过/MQ 停止保留/MQ 恢复续投/超时自动取消）逐项对应 5 REQ 验收标准，证据链完整。
- 工程依据：
  - M0 STORY-1-03-01-01（本地基础设施 delivered）已提供 docker-compose 统一管理 MySQL/Redis/Nacos/MinIO/Elasticsearch 的模式，M7 在此模式内新增 RocketMQ，无工程基线空白；
  - M2 库存核心能力（STORY-002-04-03-01 库存确认扣减 delivered、STORY-002-04-02-01 库存锁定与释放 delivered）已提供 confirm/release 幂等内部 API，M7 库存消费者直接调用；
  - M4 订单交易闭环（CHG-0019 completed）已交付：FEAT-004-01 订单预览与创建（STORY-004-01-01 delivered，订单创建事务+库存锁定+orderNo）、FEAT-004-02 支付与取消（STORY-004-02-01 delivered，CAS 状态迁移+幂等+库存 release）、FEAT-004-04 交易异常与补偿（STORY-004-04-01-01 planned，CompensationTask 聚合+有界退避+人工重试端点）——M7 复用此底座，OrderCancelService、CompensationService、InventoryCompensationHandler 已存在；
  - M5 系统配置（CHG-0022 completed）已交付 FeatureGate/SystemParameterProvider 统一配置访问边界，M7 `order.payment.timeout-minutes` 与 `rocketmq.enabled` 复用此模型；
  - M5 CHG-0023 A3（testing）已实现 X-Trace-Id 跨 12 个 internal RestClient 拦截器与 compensation_task.trace_id 列，M7 扩展到 RocketMQ 事件链；
  - M6 CHG-0024（completed）AI Service 已建 ai_action_audit 表与 traceId 模式，M7 审计与 TraceId 复用同源思路；
  - mall-web/mall-admin 前端基线（Router/Pinia/Axios/Layout/Element Plus）就绪，新增 Outbox/延迟/补偿任务查询页在既有模式内。
- 影响面：
  - **repo-1 ai-platform-backend**（主战场）：
    - mall-common mq 子模块：实现 Envelope/生产者/消费者抽象/TraceId 透传/重试与 DLQ/配置开关，是工作量最大的仓之一；
    - mall-contracts：集中声明 4 个订单事件 Tag + 消费者组名 + 事件 Payload DTO（与 §41 对齐）；
    - mall-order：新增 outbox_event 表+Flyway；订单状态迁移 4 个点（创建/支付/取消/完成）写 Outbox；投递任务（@Scheduled）；延迟消息投递与回查消费者；OrderCancelService 扩展 PAYMENT_TIMEOUT 取消原因；CompensationTask 扩展 3 种补偿类型；CompensationService 与延迟消息/Outbox 协同；mall-admin 新增 Outbox/延迟/补偿任务查询页；
    - mall-inventory：新增 consumed_event 表+Flyway；PAYMENT_SUCCEEDED 消费者调库存聚合 confirm 幂等；ORDER_CANCELLED 消费者调库存聚合 release 幂等；乱序处理（订单状态判断）；同步降级路径（与 M4 一致）；
  - **repo-2 ai-platform-frontend**：mall-admin 新增 3 个管理页（Outbox 查询+重投 / 延迟取消任务查询+手动取消 / 补偿任务查询+手动重试+标记完成），均复用既有 RBAC + 表格 + 操作审计模式；
  - **repo-3 ai-platform-ai-service**：无直接影响（M7 是 Java 微服务集群的分布式增强，AI Service 通过 mall-gateway 调用 Java API，不直接消费 RocketMQ）；
  - **repo-4 ai-platform-infrastructure**：docker-compose 新增 RocketMQ 服务（NameServer+Broker+Dashboard 可选），与既有 MySQL/Redis/Nacos/MinIO/Elasticsearch 统一管理。
- 风险评估：
  - 最高风险在 REQ-M7-003 乱序消息处理：PAYMENT_SUCCEEDED 与 ORDER_CANCELLED 可能乱序到达（支付成功后用户立即取消），消费者必须基于订单当前状态判断是否处理——订单已取消时收 PAYMENT_SUCCEEDED 应跳过+告警，订单已完成时收 ORDER_CANCELLED 应跳过+告警；此场景的工程化兜底单靠 consumed_event 表不够（consumed_event 只防重复，不防乱序），需结合订单聚合状态查询；
  - REQ-M7-002 Outbox 投递任务并发控制：多实例部署时投递任务需避免重复扫描同一记录，可能需 SELECT FOR UPDATE 或乐观锁版本号；
  - REQ-M7-004 延迟级别与超时时间映射：RocketMQ 默认 18 个延迟级别（1s/5s/10s/30s/1m/2m/3m/4m/5m/6m/7m/8m/9m/10m/20m/30m/1h/2h），订单超时 30 分钟对应级别 16，但若配置为非标准值（如 25 分钟）需向最接近级别对齐（25→30m，可能延后 5 分钟），需 Design 明确对齐策略；
  - REQ-M7-005 复用 CompensationTask 聚合的兼容性：M4 CompensationTask 已有 businessType/businessId/operation 字段，M7 新增 3 种补偿类型是否需要扩展字段（如 eventType/eventVersion/traceId）？需 Design 评估字段兼容性；
  - RocketMQ 单机故障：docker-compose 单 Broker 是开发环境配置，生产环境需集群，但 M7 范围内单机足够；MQ 故障时降级同步调用需保证业务结果一致，降级路径与异步路径业务结果一致性需 Integration Gate 实测；
  - RocketMQ Windows 兼容性：本地开发环境为 Windows，RocketMQ Broker 启动脚本（mqbroker.cmd）与 NameServer（mqnamesrv.cmd）需验证 Windows 容器兼容性。
- 证据结论：**充分**。14-开发计划.md §11 SSOT 完整（5 REQ 各含需求目标/约束/验收/非范围 + Integration Gate 七场景 + DoD 全清单）；§41 集成事件契约已定义 4 个 Tag/Payload/消费者；§19 集成事件统一字段已定义；M0~M6 既有能力足以支撑（docker-compose 模式/库存 confirm/release 幂等 API/订单状态机/CompensationTask 聚合/FeatureGate/SystemParameterProvider/X-Trace-Id 拦截器/前端基线全部就绪或 testing）；无阻断性技术未知；待澄清项均为 Design 阶段需定的技术选型与具体 Schema/参数，不构成 explore 阻断。

## 4. 冲突点检测

- 与 specs/standards 冲突：
  - `standards/architecture-principles.md` 分层架构与依赖规则——M7 跨服务事件发布/消费属跨进程横切，Outbox 投递任务与 CompensationService 扫描属服务内部 Scheduler，不属本仓内 Controller→Service→Repository 链；M7 必须确保事件消费者调用业务聚合根（如 mall-inventory 库存消费者调 InventoryService.confirm/release 内部方法，不绕过到 Repository 或直连数据库），与"AI 不直接访问业务数据库"原则一致，**无冲突**；
  - M5 dynamic-config-standard.md——M7 新增 `rocketmq.enabled` / `order.payment.timeout-minutes` 配置键，沿用 FeatureGate/SystemParameterProvider 既有 TTL/键约定与 fail-open 口径，**无冲突**；
  - M5 X-Trace-Id 标准（CHG-0023 A3）——M7 扩展 TraceId 到 RocketMQ 事件链（Envelope.traceId 生产者注入+消费者 MDC 写入+下游传播），属同模式扩展不重开，**无冲突**；
  - 安全/审计标准（M1/M4 既有 RBAC + 审计 + 补偿 trace_id）——M7 mall-admin 手动重投/手动重试/手动标记完成操作必须记录审计（操作人/时间/操作前后状态），与既有 admin_action_audit 模式同源，**无冲突**；
  - Java 21 + Spring Boot 3.5.15 + Spring Cloud 2025.0.3 + Spring Cloud Alibaba 2025.0.0.0 硬约束——RocketMQ 客户端版本需与 Spring Cloud Alibaba 2025.0.0.0 对齐（rocketmq-spring-boot-starter 2.3.x+ 兼容 Spring Boot 3.5），需 Design 阶段验证版本兼容性，**潜在风险但无规则冲突**；
  - mall-bom 是唯一版本权威——RocketMQ 客户端版本必须在 mall-bom 统一管理，禁止散落各服务 pom.xml，**无冲突但需 Design 阶段在 mall-bom 增加依赖管理**。
- 与已交付/进行中 Change 的关系：
  - **CHG-0019**（M4 订单交易闭环 completed）：M4 已交付 OrderCancelService（CAS+幂等+库存 release）、CompensationService（30s 扫描）、CompensationTask 聚合、InventoryCompensationHandler——M7 复用此底座，不重开生命周期；M7 STORY-009-03-01 库存消费者调用 InventoryService.confirm/release 内部方法（M4 已实现），属同源 API 复用；M7 STORY-009-05-01 扩展 CompensationTask 增加 3 种补偿类型，属同聚合扩展不重开；
  - **CHG-0022**（M5 系统配置 completed）：M7 `rocketmq.enabled` / `order.payment.timeout-minutes` 复用 FeatureGate/SystemParameterProvider 模型与缓存分发，不改变键名/TTL 契约；
  - **CHG-0023**（M5 验收缺口补强 testing）：A3 X-Trace-Id 拦截器（12 个 internal RestClient）需扩展到 RocketMQ 事件链（Producer/Consumer），属同模式扩展不重开；A4 参数消费为 `order.payment.timeout-minutes` 提供消费模式（夹范围校验），M7 直接复用；
  - **CHG-0024**（M6 AI 智能应用 completed）：M7 与 M6 无直接依赖（AI Service 通过 mall-gateway 调用 Java API，不直接消费 RocketMQ），但 M6 ai_action_audit 表与 traceId 模式为 M7 审计提供同源思路；
  - **CHG-0010~0013**（M2 商品/分类/品牌/SKU/库存 completed）：M7 库存消费者调用 FEAT-002-04 库存核心能力（confirm/release 幂等内部 API），属同源 API 复用；
  - **CHG-0016**（M3 商城会员 completed）：M7 不直接涉及会员能力，但订单事件 Payload 含 memberId 用于审计与可观测，属字段引用不冲突；
  - **CHG-0020/0021**（M5 搜索 completed）：M7 与搜索无直接依赖，**无重叠**。
- 与 feature-tree 已规划 Story 重复/矛盾：
  - **FEAT-004 > FEAT-004-04 交易异常与补偿 > STORY-004-04-01-01 交易异常补偿与幂等加固**（planned）——是 M7 的同步补偿底座，**不重复**：FEAT-004-04 是同步补偿任务（CompensationTask 聚合+有界退避+人工重试端点），FEAT-009 是异步事件驱动（RocketMQ+Outbox+库存异步消费者+延迟消息+消费幂等）；M7 STORY-009-05-01 复用 CompensationTask 聚合扩展 3 种补偿类型，属同聚合扩展不重复；
  - **FEAT-004 > FEAT-004-01 订单预览与创建 > STORY-004-01-01 订单预览与创建**（delivered）——M7 STORY-009-03-01 在订单创建事务提交后写 Outbox 事件（ORDER_CREATED），属同事务扩展不重复；
  - **FEAT-004 > FEAT-004-02 支付与取消 > STORY-004-02-01 模拟支付与订单取消**（delivered）——M7 STORY-009-03-01 在支付/取消事务提交后写 Outbox 事件（PAYMENT_SUCCEEDED/ORDER_CANCELLED），属同事务扩展不重复；M7 STORY-009-04-01 延迟取消调用 OrderCancelService（复用 M4 取消流程），属同服务复用不重复；
  - **MOD-1 > FEAT-1-03 本地基础设施 > STORY-1-03-01-01 建立本地基础设施环境**（delivered）——M7 在 docker-compose 新增 RocketMQ，属同文件扩展不重复；
  - **MOD-1 > FEAT-1 Maven 工程与版本治理 > STORY-2 建立 mall-common 与 mall-contracts 公共基础模块**（delivered）——M7 在 mall-common mq 子模块实现 RocketMQ 封装、在 mall-contracts 集中声明事件契约，属同模块扩展不重复；
  - FEAT-008 AI 智能应用（CHG-0024 completed）——M7 与 AI 应用层无重叠，**不重复**。
- 数据库演进冲突：M7 新增表：
  - mall-order 数据库：outbox_event 表（id/aggregate_id/event_type/payload JSON/status PENDING/SENT/FAILED/retry_count/next_retry_at/created_at/sent_at/trace_id）；
  - mall-inventory 数据库：consumed_event 表（event_id 唯一键/event_type/consumer_group/aggregate_id/processed_at/result/trace_id）；
  - mall-order compensation_task 表：M5 CHG-0023 A3 已加 trace_id 列，M7 可能需扩展 event_type/event_version 字段（Design 阶段定），属同表扩展；
  - 均属新表新增或同表扩展，不涉及既有表结构破坏性变更；Flyway 迁移按既有版本号递增，无回填要求。
- 处理决策：
  - 全部既有 Change 均 completed 或 testing，不重开生命周期；M7 独立交付，完成后在相关 Story 的 convergence 附录追加交叉引用；
  - FEAT-009 作为新 L1 承载 M7 全部分布式增强能力，与 FEAT-004 订单交易（同步补偿）分层共存，不合并；
  - RocketMQ 客户端版本与 Spring Cloud Alibaba 2025.0.0.0 兼容性、mall-bom 依赖管理，属 Design 阶段技术决策，explore 不预判；
  - Outbox 投递任务并发控制策略（SELECT FOR UPDATE vs 乐观锁）、延迟级别与超时时间对齐策略、CompensationTask 字段扩展范围，属 Design 阶段定，本 explore 不预判。

## 5. 待澄清问题

以下为 Design 阶段需定/需澄清项，按 REQ 分组列出（context-rules v0.4+ 注入下游，本清单下游 requirement-spec/design 直接可见）：

### REQ-M7-001 RocketMQ 事件基础设施
1. **RocketMQ 客户端版本与 Spring Cloud Alibaba 2025.0.0.0 兼容性**：rocketmq-spring-boot-starter 2.3.x+ 是否兼容 Spring Boot 3.5.15？是否需用原生 rocketmq-client-java 5.x 替代 starter？mall-bom 如何统一管理版本？
2. **Envelope 实现位置**：在 mall-contracts 定义 IntegrationEvent 接口/抽象类 + 在 mall-common mq 子模块提供生产/消费模板？还是 mall-common 直接定义 Envelope 类？
3. **Topic/Tag 命名规范**：order-events/inventory-events 是 Topic 名，ORDER_CREATED 等是 Tag——是否需要前缀（如 aimall-order-events）避免环境冲突？多环境（dev/staging/prod）是否用 namespace 隔离？
4. **消费者组命名规范**：inventory-consumer-group / order-delay-consumer-group 等命名是否需要环境前缀？多实例部署时同组集群消费的实例数限制？
5. **生产者封装三种发送模式**：同步发送（sendSync）/异步发送（sendAsync）/延迟发送（sendDelay）的接口契约；延迟级别参数化（int delayLevel）还是 Duration 转换？
6. **消费者抽象**：`@RocketMQMessageListener` 等价注解（如 `@IntegrationEventListener`）+ 实现 `IntegrationMessageListener<T>` 接口？还是直接用 rocketmq-spring 的 `@RocketMQMessageListener` 注解？幂等检查/异常重试/TraceId 透传/消费日志的切面实现方式？
7. **事件版本兼容拒绝策略**：消费者收到高于自身支持的 eventVersion 时，是返回 RECONSUME_LATER 重试（最终进 DLQ），还是直接 ACK 跳过+告警？还是降级处理（如按旧版本解析但记录 warning）？
8. **DLQ 查询入口形态**：mall-admin 单独 DLQ 查询页（调用 RocketMQ Admin API）还是合入 Outbox/补偿任务查询页？RocketMQ Dashboard 是否一并部署（开发环境便利）？
9. **`rocketmq.enabled=false` 降级行为**：订单状态迁移时是否仍写 Outbox（PENDING 等待恢复）？还是直接降级同步调用 mall-inventory？还是直接拒绝写操作？三种策略的业务影响？
10. **RocketMQ Windows 容器兼容性**：docker-compose 在 Windows 环境下 RocketMQ NameServer/Broker 容器是否正常启动？是否需调整 BROKER_HOST 或宿主机网络模式？

### REQ-M7-002 Outbox 可靠投递
1. **outbox_event 表 Schema 细节**：payload 是 JSON 字段（MySQL JSON 类型）还是 TEXT？status 枚举（PENDING/SENT/FAILED）是否需要 PARTITIONING_BY_RANGE 分区（按 created_at 月分区）支持大规模数据？索引（aggregate_id+status+next_retry_at 复合索引）的具体设计；
2. **投递任务并发控制**：多实例部署时如何避免重复扫描？SELECT FOR UPDATE（悲观锁）还是 version 乐观锁？扫描批量大小（如 100 条/次）与扫描间隔（如 5s）？
3. **退避策略具体值**：指数退避的初始值（如 1s）、倍数（如 2）、最大重试次数（如 5）、最大间隔上限（如 5min）？超过最大重试次数标 FAILED 后是否自动登记 CompensationTask？
4. **同聚合顺序投递实现**：投递任务扫描时是否按 aggregate_id 分组+按 created_at 排序？同一 aggregate_id 内多条 PENDING 是否串行发送（前一条 SENT 后才发下一条）？
5. **mall-admin Outbox 查询页**：按 status/event_type/aggregate_id 筛选 + 查看 payload + 手动重投 + 操作审计；RBAC 权限码（如 system:outbox:list/retry）？手动重投是否重置 retry_count？
6. **Outbox 投递任务与 CompensationService 关系**：投递任务标 FAILED 后是否自动登记 CompensationTask（businessType=OUTBOX_DELIVERY）？还是仅在人工介入时处理？

### REQ-M7-003 订单集成事件与库存异步消费者
1. **Outbox 写入时机**：订单创建/支付/取消/完成 4 个状态迁移点的事务边界——是在 OrderService 内部同事务写 Outbox（推荐），还是在事务提交后通过 Spring Application Event 写 Outbox（非原子）？
2. **库存消费者调用方式**：mall-inventory 消费 PAYMENT_SUCCEEDED 后调用 InventoryService.confirm 内部方法（同服务直接调用），还是通过 mall-inventory 内部 HTTP API（如已暴露）？confirm 幂等如何与 consumed_event 表协同（先查 consumed_event 再调 confirm，还是 confirm 内部幂等+ consumed_event 仅记录）？
3. **乱序消息处理实现**：消费者收到 PAYMENT_SUCCEEDED 时是否需要先查订单当前状态（调 mall-order 内部 API 或读 Outbox 已投递事件）？还是仅依赖库存聚合自身状态判断（如已释放则收到 PAYMENT_SUCCEEDED 跳过）？
4. **同步降级路径**：RocketMQ 不可用时，mall-order 支付/取消后如何降级调用 mall-inventory？通过 OpenFeign 内部 API（与 M4 一致）还是 RestClient？降级日志格式与告警？
5. **ORDER_COMPLETED 消费者**：REQ-M7-003 §2 明确"ORDER_COMPLETED 用于统计/通知扩展，M7 不强制实现下游消费者"——是否预留消费者骨架（如统计服务）还是仅发布事件不订阅？
6. **事件 Payload 与 §41 契约对齐验证**：4 个 Tag 的 Payload 字段（orderId/orderNo/memberId/reservationNo/orderAmount/currency/paymentDeadline/paymentNo/paymentAmount/paidAt/cancelReason/cancelledAt/completedAt）如何映射到 Java DTO？是否在 mall-contracts 定义 IntegrationEvent 子类（OrderCreatedEvent/PaymentSucceededEvent/OrderCancelledEvent/OrderCompletedEvent）？

### REQ-M7-004 延迟订单自动取消
1. **延迟消息投递方式**：通过 Outbox（与订单创建事件同事务写 Outbox，投递任务推送到 RocketMQ 延迟级别）还是直接调生产者 sendDelay（订单创建事务提交后立即发送）？前者保证原子性但增加 Outbox 复杂度，后者简单但有发送失败风险；
2. **延迟级别与超时时间对齐策略**：RocketMQ 默认 18 个延迟级别，order.payment.timeout-minutes 配置为非标准值（如 25 分钟）时如何对齐？向上取整（25→30m，可能延后 5 分钟）还是向下取整（25→20m，可能提前 5 分钟取消）？是否支持自定义延迟级别（RocketMQ 5.x 支持）？
3. **到期回查订单状态实现**：消费者收到延迟消息后，调用 OrderService.getById(orderId) 查当前状态？还是通过 OrderQueryService 内部 API？状态判断逻辑（PENDING_PAYMENT→触发取消，其他→ACK 跳过）？
4. **重复延迟消息幂等**：基于订单状态幂等（订单已非 PENDING_PAYMENT 时直接 ACK 跳过）——是否需要在 consumed_event 表登记延迟消息？还是仅依赖订单状态判断？
5. **定时补偿兜底与延迟消息协同**：保留 M4 CompensationService 定时扫描超时订单作为兜底——如何避免与延迟消息重复触发取消？CompensationService 扫描时是否检查"延迟消息已投递但未到期"避免提前取消？
6. **mall-admin 延迟取消任务查询页**：查看待取消/已取消/失败任务 + 手动触发取消 + 操作审计；与 Outbox/补偿任务查询页是否合入一个"分布式任务"页？

### REQ-M7-005 消费幂等与补偿机制
1. **consumed_event 表 Schema 细节**：event_id 唯一键的长度（UUID 36 字符还是雪花 ID long）？result 字段（SUCCESS/FAILURE/SKIPPED）？trace_id 索引？partitioning？
2. **幂等检查实现**：消费前 INSERT IGNORE（依赖唯一键约束）还是先 SELECT 后 INSERT？失败时返回 RECONSUME_LATER 还是 ACK 跳过？
3. **CompensationTask 字段扩展**：M7 新增 INVENTORY_CONFIRM_DEDUCT/INVENTORY_RELEASE/ORDER_AUTO_CANCEL 三种补偿类型，是否需要扩展 CompensationTask 表字段（如 event_type/event_version/original_payload）？还是复用既有 businessType/businessId/operation/payload 字段？
4. **补偿任务调用方式**：INVENTORY_CONFIRM_DEDUCT 补偿调用 mall-inventory 内部 API（与同步降级一致）还是重发事件？ORDER_AUTO_CANCEL 补偿调用 OrderCancelService 内部方法？补偿任务执行失败时是否重试（与 M4 一致的有界退避）？
5. **DLQ 与补偿任务衔接**：RocketMQ 死信队列消息如何被补偿任务接管？是定时扫描 DLQ 还是消息进入 DLQ 时触发补偿任务登记？
6. **TraceId 贯通实现**：事件 Envelope.traceId → Outbox.trace_id → 投递任务保留 → 消费者 MDC 写入 → 补偿任务 trace_id 字段（M5 CHG-0023 A3 已加）——每个环节如何透传？补偿任务执行时如何用原 traceId 关联事件链？

### 跨 REQ 共性待澄清
1. **Flyway 迁移版本号衔接**：mall-order 当前最新 Flyway 版本号？M7 outbox_event 表与 compensation_task 字段扩展的版本号（如 V20260922.1 或递增编号）？mall-inventory consumed_event 表版本号？
2. **RocketMQ 配置项**：namesrv.addr 配置键（如 rocketmq.name-server）？producer.group（如 aimall-producer-group）？consumer.max-reconsume-times（默认 16）？consumer.consumeThreadMin/Max？
3. **TraceId 与 MDC 扩展**：消费者接收后写入 MDC 的 key 名（与 M5 traceIdFilter 一致的 X-Trace-Id 还是 traceId）？生产者发送前从 MDC 读取还是从 SecurityContext 获取？
4. **多仓 DU 拆分**：M7 跨 repo-1/2/4，dev/test 阶段需按 DU 物化（Phase 4.4）；DU 边界按 REQ 划分（DU-M7-001 基础设施/DU-M7-002 Outbox/DU-M7-003 事件+消费者/DU-M7-004 延迟/DU-M7-005 幂等+补偿）还是按仓划分（DU-BE-XXX/DU-FE-XXX/DU-INFRA-XXX）？design/task 阶段需明确；
5. **Integration Gate 联调实测场景**：7 个场景（支付→扣减/取消→释放/重复幂等/乱序跳过/MQ 停止保留/MQ 恢复续投/超时取消）的自动化测试（Testcontainers + Embedded RocketMQ）还是手动联调？Testcontainers 是否支持 RocketMQ（目前 Testcontainers 官方未直接支持，需用 rocketmq-testcontainer-charts 第三方镜像）？

### 唯一在联调阶段验证项
- M7 Integration Gate 七大场景需在运行态实测：1) 支付成功→库存最终确认扣减；2) 订单取消→库存最终释放；3) 重复消费同一事件不重复处理；4) 乱序消息按订单状态正确跳过；5) MQ 停止时 Outbox 保留事件；6) MQ 恢复后事件继续发送；7) 超时订单自动取消+延迟消息重复投递幂等。本 Change 以单测/集成测试（Testcontainers + 嵌入式 RocketMQ 或 Mock）为自动化边界，Integration Gate 联调在 M7 收尾阶段执行。
