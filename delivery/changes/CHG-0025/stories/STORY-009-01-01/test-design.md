# Test Design（TC 测试用例设计）— STORY-009-01-01 RocketMQ 事件基础设施

## 0. 元信息

- Change ID: CHG-0025
- design 来源: delivery/changes/CHG-0025/requirement-design.md + stories/STORY-009-01-01/story-design.md
- feature-path: FEAT-009 > FEAT-009-01 > FEAT-009-01-01 > STORY-009-01-01
- TC 总数: 9（覆盖 AC-001~009 + AC-041 全部）

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | compose 集成冒烟（mqadmin clusterList + sendMsg/consume 冒烟收发） | AC-001 | DU-INFRA-001 | namesrv/broker 健康检查通过；mall-order/mall-inventory 经 Nacos 地址连通部分由 DU-BE-001 集成测试与 Integration Gate 佐证 |
| TC-002 | 单测（mall-contracts 契约快照测试） | AC-002, AC-003 | DU-BE-001 | Envelope 七字段非空（traceId 缺失自动生成）；Topic/Tag/消费者组常量集中声明，全仓扫描无散落硬编码 |
| TC-003 | Testcontainers 集成测试（mall-mq） | AC-004 | DU-BE-001 | sendSync/sendAsync/sendDelay 三种发送均达；delayLevel 参数生效（延迟级别向上取整） |
| TC-004 | Testcontainers 集成测试（mall-mq） | AC-005 | DU-BE-001 | 消费端 MDC.traceId == Envelope.traceId 且传播至下游 internal 调用日志；缺失 traceId 自动生成新 ID 且消费不阻断 |
| TC-005 | Testcontainers 集成测试（mall-mq） | AC-006 | DU-BE-001 | 构造 eventVersion=v2 事件 → WARN+ACK 拒绝，handler 未执行，不按旧版本解析 |
| TC-006 | Testcontainers 集成测试（mall-mq） | AC-007 | DU-BE-001 | 持续失败消息按策略重试，超限进 DLQ；DLQ 消息可经查询入口查到，不静默 |
| TC-007 | Spring 上下文切片测试（mall-mq） | AC-008 | DU-BE-001 | rocketmq.enabled=false → Producer/Listener Bean 不装配、调用方同步路径可用；true → 装配齐全 |
| TC-008 | 依赖树断言（mvn dependency:tree + pom 扫描） | AC-041 | DU-BE-001 | 各业务服务 pom 无散落版本号；依赖树与 Spring Boot 3.5.15/Spring Cloud Alibaba 2025.0.0.0 无冲突 |
| TC-009 | 回归合集（mvn test：mall-mq + mall-contracts 全绿） | AC-009 | DU-BE-001 | TC-002~008 全绿（Envelope 构建/发送/消费/TraceId/版本拒绝），作为 Story 1 完成基线 |

覆盖核对：AC-001~009 + AC-041 每条至少 1 个 TC（AC-001→TC-001、AC-002/003→TC-002、AC-004→TC-003、AC-005→TC-004、AC-006→TC-005、AC-007→TC-006、AC-008→TC-007、AC-009→TC-009、AC-041→TC-008）；无 TC-NOT-TESTABLE 项。

## 2. 测试策略

- **分层**：mall-mq/mall-contracts 单测为主（纯逻辑：Envelope 构建/常量声明/版本拒绝判定/退避参数）；Testcontainers 集成测试覆盖收发链路（真实 apache/rocketmq 容器，验证 starter 行为而非 mock）；Spring 上下文切片测试验证开关装配语义；repo-4 compose 红绿灯冒烟作为环境层验证。跨服务运行态串联（mall-order 发布 → mall-inventory 消费）留 Integration Gate（M7 七场景收尾实测），本 Story 不重复。
- **数据准备**：Envelope fixture 工厂（七字段合法/非法构造用例）；Testcontainers 启动 apache/rocketmq 5.x 单容器（namesrv+broker 同进程或复用 compose）；IdempotentConsumer 集成测试自建 consumed_event 表（本 Story 不依赖业务库迁移）。
- **环境要求**：repo-1 Maven（Java 21）`mvn test`（mall-mq/mall-contracts 模块）；Testcontainers 需本地 Docker（不可用则按 story-design §7 降级为 compose 环境驱动集成测试）；repo-4 `docker compose up` 冒烟。不依赖真实业务库/Nacos 生产配置（Nacos 地址经测试 profile 注入）。

## 3. DU 覆盖矩阵

| DU | verifies TC | covers AC |
| --- | --- | --- |
| DU-INFRA-001（repo-4，[S1]） | TC-001 | AC-001 |
| DU-BE-001（repo-1，[S1, S6]） | TC-002~009 | AC-001~009, AC-041 |
