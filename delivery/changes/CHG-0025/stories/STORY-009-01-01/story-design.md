---
story-id: "STORY-009-01-01"
change-id: "CHG-0025"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
feature-path: "FEAT-009/FEAT-009-01/FEAT-009-01-01/STORY-009-01-01"
---

# Story Design（Story 技术设计）— RocketMQ 事件基础设施

## 0. 元信息

- Change ID：CHG-0025；Story ID：STORY-009-01-01（REQ-M7-001，P0）
- 两 DU：DU-INFRA-001（repo-4 RocketMQ compose）、DU-BE-001（repo-1 mall-bom+mall-contracts+mall-mq）
- 实施顺序：DU-INFRA-001 → DU-BE-001（连接与冒烟依赖 broker 就绪）

### 现状事实（已核实）

- repo-4 docker-compose.infra.yml 统一模式：镜像固定版本、健康检查、共享 ai-platform-network、命名卷；.env.example 管版本变量。
- repo-1 mall-bom 为唯一版本权威（已导入 Spring Boot/Cloud/Cloud Alibaba BOM）；mall-common 为多模块聚合（含 mq 骨架子模块）；mall-contracts 已有内部契约 DTO 模式（M2/M4）。
- mall-common-web 已有 X-Trace-Id 拦截器与 MDC 约定（M5/CHG-0023）；TraceId 键名为 X-Trace-Id（MDC key=traceId）。
- mall-order/mall-inventory 当前无任何 MQ 依赖与事件代码。

## 1. 模块改动（Module Changes）

### repo-4（DU-INFRA-001）

- docker-compose.infra.yml 新增三服务：
  - `rocketmq-namesrv`：apache/rocketmq:5.x，command `mqnamesrv`，端口 9876，健康检查 `mqadmin clusterList -n localhost:9876`。
  - `rocketmq-broker`：同镜像，command `mqbroker -n rocketmq-namesrv:9876 -c /home/rocketmq/broker.conf`；挂载 broker.conf（brokerIP1=宿主可达地址/自动探测、brokerClusterName=aimall-default、brokerName=broker-a、brokerId=0、deleteWhen=04、fileReservedTime=48）；内存 `JAVA_OPT_EXT=-Xms512m -Xmx512m -Xmn128m`（本地资源友好）；端口 10909/10911/10912。
  - `rocketmq-dashboard`（profiles: [dev]，可选）：apacherocketmq/rocketmq-dashboard，`JAVA_OPTS=-Drocketmq.namesrv.addr=rocketmq-namesrv:9876`，端口 8180（避开已占用段）。
- 卷：namesrv-logs/broker-logs/broker-store；健康检查+depends_on(namesrv healthy) 随既有模式；.env.example 增 ROCKETMQ_IMAGE 版本变量。
- 红绿灯：compose up 后 `mqadmin clusterList` 成功 + 用 `mqadmin sendMsg`/Dashboard 冒烟收发一条消息。

### repo-1（DU-BE-001）

- **mall-bom**：dependencyManagement 新增 `org.apache.rocketmq:rocketmq-spring-boot-starter:2.3.x`（精确版本 dev 首任务锁定）；业务服务 pom 仅声明 groupId/artifactId 不带版本。
- **mall-contracts** 新增 `event` 包（纯 POJO/常量，零 Spring 依赖）：
  - `Envelope`：eventId(String)/eventType(String)/eventVersion(int)/occurredAt(Instant)/producer(String)/traceId(String)/payload(JsonNode)；build 工厂 + Jackson 序列化。
  - `EventTopics`（aimall-order-events/aimall-order-delay/aimall-inventory-events）、`EventTags`（5 个 Tag 常量）、`ConsumerGroups`（inventory-consumer-group/order-delay-consumer-group）、`EventVersions`（v1 矩阵）。
  - Payload DTO×5（§41 四事件+OrderDelayPayload）——字段与 requirement-design §4 Event Contract 一致。
- **mall-mq 子模块**实现：
  - `RocketMQAutoConfiguration`：`@ConditionalOnProperty(name="rocketmq.enabled", havingValue="true")` 装配 Producer/ListenerContainer；false 时全部不装配（Nacos 配置下发 rocketmq.name-server）。
  - `IntegrationEventProducer` 接口 + `RocketMQEnvelopeProducer` 实现：sendSync（同步，返回 SendResult，异常上抛）/sendAsync（回调）/sendDelay(delayLevel)；统一构造 org.apache.rocketmq 消息（topic=前缀+Topic 常量、tag=eventType、keys=eventId、body=Envelope JSON）。
  - `@IntegrationEventListener`（组合注解：topic/tag/consumerGroup/eventType/maxSupportedVersion）+ `AbstractIntegrationHandler<E>` 模板：处理链 = ①版本检查（eventVersion>maxSupportedVersion → WARN+ACK 返回）→ ②traceId 写 MDC（缺失生成）→ ③tryConsume 幂等占位（注入 IdempotentConsumer，可选关闭供基线测试）→ ④子类 handle(payload) → ⑤markResult/SKIPPED → ⑥消费日志（eventId/耗时/result）；异常上抛交 starter 重试（DLQ 由 starter 默认策略）。
  - `IdempotentConsumer` 组件：接口 + `ConsumedEventRepository` JDBC 实现（INSERT IGNORE/UPDATE result/DELETE 占位），表名可配置（默认 consumed_event，mall-inventory 先行建表）。
  - 配置属性类 RocketMQProperties（enabled/nameServer/producerGroup/retry 参数）。
- 测试：mall-mq 单测（Envelope 序列化/退避参数/版本拒绝纯逻辑）+ Testcontainers 集成测试（apache/rocketmq 容器：三种发送/消费/TraceId MDC/版本拒绝/keys 断言）；mall-contracts 契约校验测试（DTO 字段快照对齐 §41）。

### repo-2

- 本 Story 无改动（mall-admin 管理页随 DU-BE-002/004/005 交付）。

## 2. 接口契约细化

- SSOT 见 requirement-design.md §2.1/§4；Story 侧补充：
  - Envelope JSON body 即消息体（不再嵌套信封外层）；Tag=eventType；延迟消息 topic=aimall-order-delay。
  - `@IntegrationEventListener` 消费失败语义：handle 抛异常 → 删除幂等占位（tryConsume 已占位时）→ 异常上抛 → starter 按 maxReconsumeTimes 重试 → 超限 DLQ。
  - IdempotentConsumer 结果枚举 FIRST_PROCESSED/DUPLICATE；SKIPPED 由 handler 显式调用 markSkipped。

## 3. 数据变更

- 本 Story 无业务库迁移（consumed_event 表随 DU-BE-005 建表；本 Story 的 IdempotentConsumer 组件以接口+可配置 SQL 先行，集成测试用 Testcontainers 自建表）。

## 4. 错误处理

- 发送失败：sendSync 抛 MQClientException/RemotingException——业务侧（DU-BE-002 投递任务/DU-BE-003 同步降级）捕获处理，mall-mq 不吞。
- rocketmq.enabled=false：Producer 注入点改为 NoOpProducer（调用即抛 MQDisabledException，提示走同步路径）或调用方按开关分支——采用后者（开关语义由业务服务裁决，mall-mq 保持纯粹）。
- 消费异常：统一上抛；框架层只记 ERROR 日志（含 eventId/traceId/重试次数），不中断容器。

## 5. DU 划分（Delivery Units）

| DU | 仓库 | 范围 | 覆盖 AC | depends on |
| --- | --- | --- | --- | --- |
| DU-INFRA-001 | repo-4 | compose namesrv/broker/dashboard+broker.conf+健康检查+冒烟收发 | AC-001 | — |
| DU-BE-001 | repo-1 | mall-bom 版本；mall-contracts event 包；mall-mq（Producer/组合注解/处理链/IdempotentConsumer/开关装配/版本拒绝）；单测+Testcontainers 集成测试 | AC-001~009, AC-041 | DU-INFRA-001 |

## 6. 测试策略

| TC | AC | 位置/类型 | 关键断言 |
| --- | --- | --- | --- |
| TC-001 | AC-001 | repo-4 compose + repo-1 集成 | clusterList 成功；服务经 Nacos 地址连通 |
| TC-002 | AC-002/003 | mall-contracts 快照测试 | Envelope 七字段非空；Topic/Tag/组常量齐备无散落 |
| TC-003 | AC-004 | mall-mq Testcontainers | 三种发送均达；delayLevel 参数生效 |
| TC-004 | AC-005 | mall-mq Testcontainers | 消费端 MDC.traceId==Envelope.traceId；缺失自动生成 |
| TC-005 | AC-006 | mall-mq Testcontainers | 构造 v2 事件 → WARN+ACK，handler 未执行 |
| TC-006 | AC-007 | mall-mq Testcontainers | 持续失败 → 重试 N 次后 DLQ 可查 |
| TC-007 | AC-008 | mall-mq Spring 上下文测试 | enabled=false → 无 MQ Bean；true → 装配齐全 |
| TC-008 | AC-041 | mall-bom 依赖树测试 | 各服务 pom 无版本号；dependency:tree 无冲突 |

## 7. 待 dev 确认

- starter 精确版本锁定与兼容矩阵冒烟（DU-BE-001 首任务）。
- brokerIP1 Windows 宿主实测值；Testcontainers apache/rocketmq 镜像可用性（不可用则集成测试改 compose 环境驱动）。
