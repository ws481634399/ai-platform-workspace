---
affected-repositories: [repo-1, repo-2, repo-4]
---

# Requirement Design（需求级方案设计）— CHG-0025 M7 分布式增强

> 层级：Requirement 级；主 Story 细化设计见 stories/STORY-009-01-01/story-design.md，其余 Story 细化设计在该 Story 进入开发时按同模板补产出
> 输入：requirement-spec.md + exploration.md + product/10-API与事件契约.md §41 + product/02-统一语言词汇表.md §19
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0025
- spec 来源: CHG-0025/requirement-spec.md（REQ-M7-001~005）
- 相关仓库: repo-1（ai-platform-backend：mall-common、mall-contracts、mall-bom、mall-order、mall-inventory）、repo-2（ai-platform-frontend：mall-admin）、repo-4（ai-platform-infrastructure：docker-compose）
- 受影响仓库数: 3
- 需要 Migration: yes（mall-order 新增 outbox_event 表、mall-inventory 新增 consumed_event 表；均为新增，不改既有表；CompensationTask 表不扩列）

## 1. 当前状态

- **repo-1 mall-common**：8 个技术子模块（web/log/security/db/redis/mq/trace/contracts 等），其中 mq 子模块当前为骨架未实现；mall-contracts 已有内部 API 契约 DTO 模式（M2/M4 交付）；mall-bom 是全平台唯一版本权威（Spring Boot 3.5.15 / Spring Cloud 2025.0.3 / Spring Cloud Alibaba 2025.0.0.0 BOM 已导入）。
- **repo-1 mall-order**（M4/M5 交付）：OrderCancelService（CAS 状态迁移+释放库存预留+重复取消幂等）、CompensationService（30s 扫描）、CompensationTask 聚合（businessType/businessId/operation/status/retryCount/lastError/nextRetryAt/trace_id，幂等登记+有界退避+人工重试端点）、InventoryCompensationHandler、OrderStatusHistory；Flyway 版本随 M4/M5 递增（dev 阶段核对最新号）。
- **repo-1 mall-inventory**（M2/M4 交付）：confirm（预留→确认扣减，幂等）/ release（释放，幂等）/ lock 内部 API；库存流水（INIT/ADJUST/LOCK/RELEASE/DEDUCT）。
- **repo-2 mall-admin**：Vue3 + Element Plus，RBAC（v-permission）、表格/筛选/操作审计模式成熟（CHG-0022/0023 交付）。
- **repo-4 infra**：docker-compose.infra.yml 已有 MySQL 8.4.11、Redis 7.4.11、ES 8.17.4、MinIO、Nacos（共享 ai-platform-network，健康检查统一模式）；无 RocketMQ。
- **M5 遗产**：X-Trace-Id 跨服务拦截器（CHG-0023 A3，12 个 internal RestClient）、compensation_task.trace_id 列、FeatureGate/SystemParameterProvider 配置模型与缓存分发。

## 2. 提议方案

### 2.0 总体策略

**mall-common 吸收全部 MQ 样板复杂度，业务服务只写"发布点 + 消费者业务逻辑"；消息可靠性靠 Outbox（发送侧）+ consumed_event（消费侧）+ CompensationTask（兜底侧）三件套；M4 同步路径整体保留作为降级路径，双路径业务结果一致。**

1. **中间件定稿：RocketMQ（apache/rocketmq 5.x Broker + NameServer）+ rocketmq-spring-boot-starter 2.3.x 客户端**。理由：Spring Cloud Alibaba 生态原生支持、延迟消息（delayLevel 18 级）开箱可用、@RocketMQMessageListener 注解消费成熟；不引入 Kafka/Pulsar（spec 红线）。版本由 mall-bom 统一管理；Broker 用经典 remoting 协议（兼容 starter），Windows 兼容性 dev 首日验证（DU-INFRA-001 红绿灯）。
2. **发送可靠性定稿：全量事件走 Outbox**。业务服务（首期 mall-order）在业务事务内调 OutboxRecordWriter.append() 写 outbox_event；独立 OutboxDeliveryTask（@Scheduled fixedDelay=5s，批 100）扫描 PENDING 投递。**延迟消息同样走 Outbox**（event_type=ORDER_PAYMENT_TIMEOUT_CHECK，投递任务按 event_type 路由 order-delay Topic + delayLevel），保证与 ORDER_CREATED 同事务原子性（spec §4.F-22 定稿）。
3. **投递任务并发控制定稿：数据库抢占式 CAS**——`UPDATE outbox_event SET status='SENDING', sent_at=now() WHERE id=? AND status='PENDING'` 抢占（SENDING 为中间态），发送成功置 SENT，失败回置 PENDING+退避；多实例天然安全，无需分布式锁。**同聚合顺序定稿**：每组扫描按 aggregate_id 分组，仅投递该聚合 created_at 最早的一条 PENDING，SENT 后下轮投下一条。
4. **退避参数定稿**：初始 10s、倍数 2、上限 10min、最大重试 8 次；超限标 FAILED 记 lastError，仅人工重投（mall-admin）恢复。
5. **消费幂等定稿：先占位后处理**。tryConsume（INSERT IGNORE into consumed_event，唯一键 event_id+consumer_group）→ 首占则执行业务 → 成功 UPDATE result；失败 DELETE 占位交 RocketMQ 重试；乱序跳过占位 result=SKIPPED。幂等键=eventId（禁业务字段）。mall-common 提供 IdempotentConsumer 组件，mall-inventory 先行接入。
6. **乱序裁决定稿：回调订单状态查询**。mall-order 新增 internal 端点 `GET /internal/orders/{orderId}/status`（SERVICE 身份/X-Internal-Token，复用 M2 内部鉴权模式）；库存消费者收到 PAYMENT_SUCCEEDED/ORDER_CANCELLED 先回查订单状态，非预期状态 → ACK+WARN（含 eventId/orderId/当前状态）。查询失败 → 抛异常交重试（保守不丢消息）。
7. **DLQ 衔接定稿：失败即登记补偿任务**。消费端业务异常时直接登记对应 CompensationTask（第一次重试即业务级重放），不等进 DLQ；DLQ 仅作 RocketMQ 侧最终兜底存储，查询入口=mall-admin 补偿任务页提供 RocketMQ Dashboard 链接（Dashboard 可选部署，开发环境默认开启）。符合 spec"不要求实时处理 DLQ"。
8. **开关语义定稿**：`rocketmq.enabled=false`（SystemParameter，复用 M5 模型）→ MQ Producer/Consumer Bean 不初始化、投递任务挂起、**outbox_event 照写**（保留审计与恢复能力），支付/取消的库存操作走 M4 同步路径并记降级日志；置 true 重启后投递任务自动续投积压事件。运行中 MQ 连接故障（开关仍 true）→ 发送失败走 Outbox 退避 + 当次业务走同步降级（快速失败判断：sendSync 抛连接异常即降级同步，业务结果一致）。
9. **版本拒绝定稿**：eventVersion > 消费者支持版本 → ACK + WARN 告警日志（明确拒绝语义，不重试——版本不兼容重试无意义），不按旧版本解析。
10. **事件契约落点定稿**：mall-contracts 新增 `event` 包——Envelope POJO、Topic/Tag/ConsumerGroup 常量类、4 个订单事件 Payload DTO、OrderDelayPayload DTO；mall-common mq 实现 EnvelopeProducer（sendSync/sendAsync/sendDelay）、@IntegrationEventListener 组合注解 + AbstractIntegrationListener 基类（TraceId MDC/日志/幂等挂点/版本拒绝统一处理）。
11. **延迟级别映射定稿**：timeout-minutes → RocketMQ delayLevel（1s/5s/10s/30s/1m/2m/3m/4m/5m/6m/7m/8m/9m/10m/20m/30m/1h/2h）**向上取整**到最近级别（30min→L16；25min→L16；不提前取消）；映射器纯函数可测。
12. **Topic 环境隔离定稿**：topic 统一前缀 `aimall-`（aimall-order-events / aimall-order-delay / aimall-inventory-events 预留），单环境无 namespace（本地作品集项目，简化）。

### 2.1 新增模块（repo-1 backend）

```
mall-common/mall-mq/                     # S1 基础设施（DU-BE-001）
├── envelope/Envelope.java               # 七字段 POJO（对齐 §19）
├── producer/IntegrationEventProducer.java   # sendSync/sendAsync/sendDelay(delayLevel)
├── producer/RocketMQEnvelopeProducer.java   # starter 封装实现（keys=eventId）
├── consumer/IntegrationEventListener.java   # 组合注解（topic/tag/consumerGroup/eventType/支持版本）
├── consumer/AbstractIntegrationHandler.java # 统一处理链：版本拒绝→TraceId MDC→幂等挂点→业务→日志
├── consumer/IdempotentConsumer.java     # tryConsume/markResult（consumed_event 通用组件）
└── config/RocketMQAutoConfiguration.java    # rocketmq.enabled 开关装配

mall-contracts/…/event/                  # 事件契约（DU-BE-001）
├── EventTopics.java                     # aimall-order-events / aimall-order-delay / aimall-inventory-events
├── EventTags.java                       # ORDER_CREATED/PAYMENT_SUCCEEDED/ORDER_CANCELLED/ORDER_COMPLETED/PAYMENT_TIMEOUT_CHECK
├── ConsumerGroups.java                  # inventory-consumer-group / order-delay-consumer-group
├── EventVersion.java                    # 各 eventType 当前版本 v1
├── payload/OrderCreatedEventPayload.java … OrderCompletedEventPayload.java（§41 字段）
└── payload/OrderDelayPayload.java       # orderId/orderNo/expireAt

mall-order/                              # S2/S3/S4（DU-BE-002/003/004）
├── outbox/OutboxEvent.java + OutboxEventRepository.java + OutboxRecordWriter.java
├── outbox/OutboxDeliveryTask.java       # @Scheduled(5s) 扫描/CAS 抢占/退避/同聚合顺序/event_type 路由
├── order/事件发布点×4                   # create/pay/cancel/complete 事务内 writer.append()
├── order/OrderDelayCheckListener.java   # order-delay-consumer-group：回查状态→OrderCancelService
├── order/internal/OrderStatusInternalController.java  # GET /internal/orders/{id}/status（SERVICE）
└── compensation/（扩展 businessType 枚举：INVENTORY_CONFIRM_DEDUCT/INVENTORY_RELEASE/ORDER_AUTO_CANCEL + 对应 Handler×3）

mall-inventory/                          # S3/S5（DU-BE-003/005）
├── idempotency/consumed_event 表 + Repository
├── consumer/PaymentSucceededInventoryListener.java   # 确认扣减（幂等+乱序裁决）
└── consumer/OrderCancelledInventoryListener.java     # 释放（幂等+乱序裁决）

mall-admin（repo-1 后端）                 # 查询 API（DU-BE-002/004/005）
├── OutboxAdminApi: GET /api/admin/outbox/events(+/{id}, POST /{id}/retry)
├── DelayTaskAdminApi: GET /api/admin/order-delay/tasks, POST /{orderId}/cancel
└── CompensationAdminApi: 扩展既有任务查询（POST /{id}/retry|complete）
```

关键契约（入参/出参/错误码）：
- Envelope（JSON body）：`{eventId:UUID, eventType:String, eventVersion:int, occurredAt:ISO8601, producer:String, traceId:String, payload:object}`；消息 keys=eventId，Tag=eventType。
- OutboxDeliveryTask 状态机：PENDING →(CAS 抢占)→ SENDING →(成功)→ SENT / (失败)→ PENDING(next_retry_at 退避) ；重试超限 → FAILED(lastError)。
- `GET /internal/orders/{orderId}/status`：出 `{orderId, status}`；鉴权 X-Internal-Token（SERVICE）；404 订单不存在。
- mall-admin 三组 API 均 ADMIN 角色 + RBAC 权限码（system:outbox:*/order-delay:*/compensation:*，DML 种子随 dev 核对现有版本递增）；重试/重投/取消/标记完成全部写审计（操作人/时间/前后状态/traceId）。

### 2.2 新增改动（repo-2 mall-admin）

- `src/api/distributed.ts`（Outbox/延迟任务/补偿任务三组接口封装）。
- `views/distributed/OutboxListView.vue`（状态/类型/聚合筛选+payload 抽屉+重投按钮）、`views/distributed/DelayTaskListView.vue`（任务列表+手动取消）、`views/distributed/CompensationListView.vue`（类型/状态筛选+重试+标记完成）；复用既有表格/筛选/审计模式；v-permission 用新增权限码。
- 菜单新增"分布式任务"分组（三页面）。

### 2.3 新增改动（repo-4 infrastructure）

- docker-compose.infra.yml 新增：rocketmq-namesrv（apache/rocketmq:5.x，mqnamesrv）、rocketmq-broker（mqbroker -n namesrv:9876，BROKER_MEM 参数调优，挂载 broker.conf）、rocketmq-dashboard（可选 profile=dev，apacherocketmq/rocketmq-dashboard）；健康检查+卷+共享网络随既有模式；.env.example 增 ROCKETMQ 版本变量。

## 2.1 备选方案对比（Alternatives Considered）

| 决策点 | 采用 | 备选 | 理由 |
|---|---|---|---|
| MQ 中间件 | RocketMQ 5.x + starter 2.3.x | Kafka/Pulsar/RabbitMQ | Spring Cloud Alibaba 原生、delayLevel 开箱、spec 红线禁多中间件 |
| 发送可靠 | 全量走 Outbox | 事务消息（RocketMQ half-msg） | 事务消息需回查实现且与 DB 事务耦合弱；Outbox 模式直观、可查询可人工介入、教学价值高 |
| 延迟消息 | 经 Outbox 统一投递 | 下单后直接 sendDelay | 与 ORDER_CREATED 同事务原子；发送失败不丢（spec §4.F-22 定稿） |
| 投递并发控制 | DB 抢占 CAS（SENDING 中间态） | SELECT FOR UPDATE/分布式锁 | 无需锁管理；多实例天然安全；崩溃自愈（SENDING 超时回置 PENDING） |
| 消费幂等 | 先占位后处理（INSERT IGNORE） | 先查后插/业务状态判断 | 唯一键兜底并发安全；spec 规则 10 禁仅业务状态判断 |
| 乱序裁决 | 回调订单状态 internal API | 库存聚合自身状态判断 | 库存态无法区分"已取消未释放"等中间态；订单态是裁决权威（spec §4.F-22） |
| DLQ 衔接 | 失败即登记补偿任务 | 扫描 DLQ 登记 | DLQ 无便捷业务级扫描 API；补偿第一次重试即业务重放，语义等价且更及时 |
| 事件版本拒绝 | ACK+WARN | RECONSUME_LATER 重试 | 版本不兼容重试永不成功，重试只堵队列；WARN 已满足"明确拒绝" |
| 幂等表位置 | mall-inventory 先行 | mall-common 通用表 | consumed_event 属消费方数据库（事务一致性）；组件代码在 mall-common 复用 |
| 客户端封装 | starter @RocketMQMessageListener + 自研组合注解/基类 | 完全自研监听容器 | 复用 starter 重试/DLQ 成熟能力，自研只做横切（TraceId/幂等/日志） |

## 3. 仓库影响（Repository Impact）

- **repo-1**：mall-bom（rocketmq starter 依赖管理）；mall-contracts（event 包新增）；mall-common mall-mq 子模块全量新增；mall-order（outbox 表+Flyway、Outbox 三件套、4 发布点、延迟监听、internal 状态端点、补偿 3 类型扩展+Handler、admin API）；mall-inventory（consumed_event 表+Flyway、2 消费者、幂等组件接入）；mall-admin 后端（3 组管理 API+权限码 DML）。mall-gateway/mall-product/mall-search/mall-member/mall-system 零改动。
- **repo-2**：mall-admin 前端（api/distributed.ts + 3 视图 + 菜单 + v-permission）。
- **repo-4**：compose 新增 namesrv/broker/dashboard 可选 + .env.example。
- **repo-3 ai-service 不参与**（M7 为 Java 微服务集群事件驱动，AI 经网关 HTTP，不消费 MQ）。

## 4. 跨仓协作契约

- **API Contract**：mall-admin 前端（repo-2）→ repo-1 mall-admin 后端 3 组管理 API（§2.1）；mall-inventory → mall-order `GET /internal/orders/{id}/status`（SERVICE/X-Internal-Token）；库存 confirm/release 内部 API 为 M2 既有契约（消费与补偿共用）。
- **Event Contract（本 Change 核心）**：
  - Topic `aimall-order-events`（Tag：ORDER_CREATED/PAYMENT_SUCCEEDED/ORDER_CANCELLED/ORDER_COMPLETED），Payload 见 §41 契约（OrderCreated：orderId/orderNo/memberId/reservationNo/orderAmount/currency/paymentDeadline；PaymentSucceeded：orderId/orderNo/paymentNo/reservationNo/paymentAmount/currency/paidAt；OrderCancelled：orderId/orderNo/reservationNo/cancelReason/cancelledAt；OrderCompleted：orderId/orderNo/memberId/completedAt）。
  - Topic `aimall-order-delay`（Tag：PAYMENT_TIMEOUT_CHECK），Payload {orderId, orderNo, expireAt}。
  - 投递语义 at-least-once（Outbox 重投+RocketMQ 重试）；消费语义=幂等消费（consumed_event）；顺序=同聚合内有序；keys=eventId；Envelope 七字段必填。
- **Data Contract**：outbox_event 归 mall-order 独占写（OutboxRecordWriter/投递任务）；consumed_event 归 mall-inventory 独占写；compensation_task 归 mall-order 独占写（mall-admin 只读+触发动作经后端 API）；事件 Schema 归 mall-contracts 单一事实源。
- **Repository Dependencies**：repo-2 依赖 repo-1 admin API 契约；repo-1 内部 mall-order/mall-inventory 依赖 mall-common mq + mall-contracts event 包；repo-1 依赖 repo-4 RocketMQ 运行时。
- **Integration Boundary**：Nacos 下发 rocketmq.name-server 地址；rocketmq.enabled 与 order.payment.timeout-minutes 走 M5 配置模型；X-Internal-Token 复用 M2 服务间鉴权；Dashboard 仅 infra 网络开放。
- **Cross-Repository Sequence**：DU-INFRA-001 → DU-BE-001（S1）→ DU-BE-002（S2）→ {DU-BE-003、DU-BE-004} 并行 → DU-BE-005（S5）；DU-FE-001/002/003 分别依赖对应 DU-BE-00x 契约冻结；全部完成后 Integration Gate 七场景联调（收尾）。

## 5. 数据变更

- mall_order 库（Flyway，版本号 dev 阶段核对现有最新后递增）：
```sql
-- Migration: add_outbox_event
CREATE TABLE outbox_event (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  aggregate_id VARCHAR(64) NOT NULL,          -- orderId
  event_type VARCHAR(64) NOT NULL,            -- ORDER_CREATED/.../PAYMENT_TIMEOUT_CHECK
  payload JSON NOT NULL,                       -- Envelope.payload（业务字段）
  status VARCHAR(16) NOT NULL DEFAULT 'PENDING',  -- PENDING/SENDING/SENT/FAILED
  retry_count INT NOT NULL DEFAULT 0,
  next_retry_at DATETIME NULL,
  trace_id VARCHAR(64) NULL,
  last_error VARCHAR(512) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  sent_at DATETIME NULL,
  KEY idx_status_retry (status, next_retry_at),
  KEY idx_aggregate (aggregate_id, created_at)
);
```
- mall_inventory 库（Flyway，同上）：
```sql
-- Migration: add_consumed_event
CREATE TABLE consumed_event (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  event_id VARCHAR(64) NOT NULL,
  consumer_group VARCHAR(64) NOT NULL,
  event_type VARCHAR(64) NOT NULL,
  aggregate_id VARCHAR(64) NULL,
  result VARCHAR(16) NOT NULL DEFAULT 'PROCESSING',  -- PROCESSING/SUCCESS/SKIPPED
  trace_id VARCHAR(64) NULL,
  processed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_event_group (event_id, consumer_group),
  KEY idx_aggregate (aggregate_id)
);
```
- compensation_task：**不扩列**（eventId/eventType 冗余进 payload JSON）；businessType 枚举代码层扩展 3 值。
- mall-identity：admin 权限码/菜单种子 DML（system:outbox:list/retry、system:order-delay:list/cancel、system:compensation:list/retry/complete）。
- 均为新增/枚举扩展，无既有表结构变更，无回填。

## 5. Story 设计分派（Story Design Assignments）

### 5.1 Story 拆分（5 Story，1 REQ → 1 L2 → 1 L3 → 1 Story，均已在 feature-tree）

| Story | 标题 | domain.id | 仓库 | Story 设计 | 覆盖 AC |
|---|---|---|---|---|---|
| STORY-009-01-01 | RocketMQ 事件基础设施（主） | FEAT-009-01-01 | repo-4 + repo-1 | stories/STORY-009-01-01/story-design.md | AC-001~009, AC-041 |
| STORY-009-02-01 | Outbox 可靠投递 | FEAT-009-02-01 | repo-1 + repo-2 | 本 Story 进入开发时补 story-design.md | AC-010~017 |
| STORY-009-03-01 | 订单集成事件与库存异步消费者 | FEAT-009-03-01 | repo-1 | 同上 | AC-018~025 |
| STORY-009-04-01 | 延迟订单自动取消 | FEAT-009-04-01 | repo-1 + repo-2 | 同上 | AC-026~032 |
| STORY-009-05-01 | 消费幂等与补偿机制 | FEAT-009-05-01 | repo-1 + repo-2 | 同上 | AC-033~040 |

### 5.2 DU 划分总表（design 产物，sdd-task 仅消费；DU create 登记于主 Story，其余 Story 的 DU 在各自 story-design 产出后登记；DU 1:1 单仓）

| DU | 仓库 | 职责 | covers AC | depends on |
|---|---|---|---|---|
| DU-INFRA-001 | repo-4 | compose 新增 RocketMQ namesrv/broker/dashboard(可选)+健康检查+.env+冒烟收发 | AC-001 | — |
| DU-BE-001 | repo-1 | mall-bom 版本管理；mall-contracts event 包；mall-mq 子模块（Producer/组合注解+处理链/IdempotentConsumer/开关装配/版本拒绝）；单测+Testcontainers 集成测试 | AC-001~009, AC-041 | DU-INFRA-001 |
| DU-BE-002 | repo-1 | mall-order outbox_event 表+Writer+投递任务（CAS/退避/同聚合顺序/延迟路由）；mall-admin 后端 Outbox 查询 API+权限码 DML | AC-010~015, AC-017 | DU-BE-001 |
| DU-FE-001 | repo-2 | mall-admin Outbox 管理页（筛选/payload/重投/审计展示） | AC-016 | DU-BE-002 |
| DU-BE-003 | repo-1 | mall-order 4 发布点+internal 状态查询端点；mall-inventory PAYMENT_SUCCEEDED/ORDER_CANCELLED 消费者（幂等+乱序裁决）；同步降级链路 | AC-018~025 | DU-BE-002 |
| DU-BE-004 | repo-1 | mall-order 延迟消息（Outbox 路由 order-delay+delayLevel 映射器）；回查消费者；定时兜底协同；mall-admin 后端延迟任务 API | AC-026~031 | DU-BE-002 |
| DU-FE-002 | repo-2 | mall-admin 延迟取消任务查询页+手动取消 | AC-032 | DU-BE-004 |
| DU-BE-005 | repo-1 | mall-inventory consumed_event 表；mall-order CompensationTask 扩展 3 类型+Handler+DLQ 衔接（失败即登记）；mall-admin 后端补偿管理 API | AC-033~037, AC-039, AC-040 | DU-BE-001, DU-BE-003, DU-BE-004 |
| DU-FE-003 | repo-2 | mall-admin 补偿任务管理页（筛选/重试/标记完成/审计展示） | AC-038 | DU-BE-005 |

> 依赖无环：INFRA→BE-001→BE-002→{BE-003∥BE-004}→BE-005；FE-001/002/003 分别依赖对应 BE 契约冻结；每 DU 单仓可独立红绿灯（repo-1 mvn test / repo-2 vitest / repo-4 compose healthcheck）。

## 6. 风险评估

| 风险项 | 级别 | 缓解措施 |
|---|---|---|
| rocketmq-spring-boot-starter 与 Spring Boot 3.5.15/Spring Cloud Alibaba 2025.0.0.0 兼容性 | 高 | DU-BE-001 首任务做依赖矩阵验证（mvn dependency:tree+冒烟测试）；不兼容则降级用原生 rocketmq-client 5.x 自封装（备选已留）；mall-bom 单点管版本 |
| Windows 本地 RocketMQ 容器兼容（broker 注册宿主 IP 问题） | 高 | DU-INFRA-001 首日红绿灯；broker.conf 显式配置 brokerIP1=宿主可达地址；Dashboard 验证收发 |
| 消息重复消费导致库存重复扣减/释放 | 高 | consumed_event 唯一键+先占位后处理（AC-021/034 并发测试）+业务幂等（M2 confirm/release 语义）双层防护 |
| 乱序消息错误处理（支付后立即取消） | 高 | 回查订单状态裁决+SKIPPED 占位+告警日志（AC-022 专项测试）；查询失败保守重试不丢消息 |
| 双路径（延迟消息 vs 定时兜底）双重取消 | 中 | 同一订单 CAS 状态迁移只成功一次（M4 既有）；并发竞争测试（AC-030） |
| Outbox 投递任务多实例重复投递 | 中 | SENDING 抢占 CAS+SENDING 超时回置 PENDING（自愈）；消费端幂等最终兜底 |
| 事件链路 TraceId 断链 | 中 | AbstractIntegrationHandler 统一 MDC 注入；AC-039 全链断言；复用 M5 X-Trace-Id 拦截器 |
| MQ 故障期间业务可用性 | 中 | rocketmq.enabled=false 明确关闭走同步；运行中故障 sendSync 快速失败即降级同步+降级日志（AC-024/043） |
| 新增消费者拖慢既有交易链路 | 低 | 事件写入为同事务单条 INSERT（微秒级）；投递异步；既有用例零回退门禁（AC-043） |

## 7. 待澄清问题

- spec §4.F-23 全部技术选型已在本设计定稿（§2.0/§2.4）：中间件=RocketMQ 5.x+starter 2.3.x；发送=全量 Outbox；并发=DB CAS；退避=10s/2x/10min/8 次；幂等=先占位后处理；乱序=回查订单状态；DLQ=失败即登记补偿；版本拒绝=ACK+WARN；Topic 前缀=aimall-；延迟映射=向上取整。
- 留待 dev 阶段核对（不阻塞设计）：mall-order/mall-inventory/mall-identity Flyway 当前最新版本号；starter 精确版本号（mall-bom 锁定）；Windows broker IP 配置实测值。
- 留待 Integration Gate（M7 收尾）：七场景运行态实测（MQ 停止/恢复、乱序、重复、超时取消）；Dashboard 生产化取舍。
