# Implementation（跨仓实施汇总）— CHG-0025 M7 分布式增强

> 阶段：sdd-dev 产物。本文件为 Change 级跨 Story 汇总，各 Story 实施正文见对应 Story 目录，本文件只引用不复制。

## 0. 元信息

- Change ID：CHG-0025（M7 分布式增强）
- 实施日期：2026-09-22 ~ 2026-09-26
- 范围：RocketMQ 事件基础设施（S1）、Outbox 可靠投递（S2）、订单集成事件与库存异步消费者（S3）、延迟订单自动取消（S4）、消费幂等与补偿机制（S5）
- 参与仓库：repo-1（ai-platform-backend）/ repo-2（ai-platform-frontend）/ repo-4（ai-platform-infrastructure）

## 1. Story 实施总览

| Story | DU | 仓库 | 状态 |
| --- | --- | --- | --- |
| STORY-009-01-01 RocketMQ 事件基础设施 | DU-INFRA-001 / DU-BE-001 | repo-4 / repo-1 | completed |
| STORY-009-02-01 Outbox 可靠投递 | DU-BE-002 / DU-FE-001 | repo-1 / repo-2 | completed |
| STORY-009-03-01 订单事件与库存消费者 | DU-BE-003 | repo-1 | completed |
| STORY-009-04-01 延迟订单自动取消 | DU-BE-004 / DU-FE-002 | repo-1 / repo-2 | completed |
| STORY-009-05-01 消费幂等与补偿机制 | DU-BE-005 / DU-FE-003 | repo-1 / repo-2 | completed |

## 2. Commit 记录

| Commit | 仓库 | DU | 说明 |
| --- | --- | --- | --- |
| e2256b4 / 14290de | repo-4 | DU-INFRA-001 | RocketMQ namesrv/broker/dashboard 三服务、broker.conf、版本变量与冒烟 |
| 1c53407 | repo-1 | DU-BE-001 | mall-bom rocketmq-spring-boot-starter 2.3.6 版本权威 |
| e7c8598 | repo-1 | DU-BE-001 | mall-event-contracts Envelope/常量/Payload 契约包 |
| 963a28c | repo-1 | DU-BE-001 | EnvelopeProducer 三路发送（Tag/keys/traceId MDC） |
| 68fcdc8 | repo-1 | DU-BE-001 | 六步消费链与 fail-closed 开关装配 |
| ebdbbd9 / f178ccc | repo-1 | DU-BE-001 | TC-002~009 测试基线与实施回填（26/26） |
| e375c40 | repo-1 | DU-BE-002 | outbox_event(V4) + Writer + DeliveryTask(CAS/顺序/退避/FAILED) + Admin + V13 + imports 修复 |
| c7e38ec | repo-2 | DU-FE-001 | OutboxListView（筛选/payload/重投） |
| 31f3b6c / 6d59155 / 2dca669 / 1482141 / 967e359 / 317eb15 | repo-1 | DU-BE-003 | 订单事件收集/Assembler/Flusher/仓储挂点/异步分支/internal 端点 |
| 94960dc / ae7cd00 / 16c506d | repo-1 | DU-BE-003 | 库存预留枚举/OrderServiceClient/两幂等消费者/配置 |
| ebdfb1a / d5fa92c / 9022c8f / 369ebc9 / 52e7b1c / 6d90dad | repo-1 | DU-BE-004 | V5 delay_level/Policy/Mapper/延迟事件/组装投递 |
| 740b4ab / 97b8665 / 3b7ff3d / be4a55e / 61aba4d / 04a905e | repo-1 | DU-BE-004 | systemCancel/到期消费者/兜底扫描/三源视图/V14/配置注入 |
| 61e2154（前端相关提交） | repo-2 | DU-FE-002 | DelayTaskListView 与 delayTaskApi |
| 25f83ee / ce8d0e9 | repo-1 | DU-BE-005 | mall-inventory V3 / mall-order V6 consumed_event |
| aa5be7f / 0050c01 / 2bb9123 / e3bb8d2 / f9f2b81 | repo-1 | DU-BE-005 | 补偿任务扩展/仓储/执行器接口化/服务列表化/超时失败登记 |
| aba4dca / 9c2849c / d30f9a7 | repo-1 | DU-BE-005 | 管理台筛选 complete 审计/V15 权限/ObjectProvider 收口 + 全量回归 |
| 5425717 / 344fefd / 93a7ff2 / 5ce2ad0 | repo-2 | DU-FE-003 | 补偿 API/筛选控件/payload 与 complete/Dashboard 外链 |

以上均为本地提交，未 push。

## 3. 各 Story 实施引用

- S1：[stories/STORY-009-01-01/implementation.md](stories/STORY-009-01-01/implementation.md)
- S2：[stories/STORY-009-02-01/implementation.md](stories/STORY-009-02-01/implementation.md)
- S3：[stories/STORY-009-03-01/implementation.md](stories/STORY-009-03-01/implementation.md)
- S4：[stories/STORY-009-04-01/implementation.md](stories/STORY-009-04-01/implementation.md)
- S5：[stories/STORY-009-05-01/implementation.md](stories/STORY-009-05-01/implementation.md)

## 4. Fan-in 状态

- [x] du-materialized：9 个 DU 全部物化到对应仓
- [x] du-fan-in-testing：各 Story 测试证据回传
- [x] du-fan-in-complete：9 个 DU 全部 completed，result commit 经 `openspec du sync-status CHG-0025` 与各仓 HEAD 对齐

## 5. 关键技术决策

1. **Envelope 七字段 + 契约集中**：mall-event-contracts 统管 Topic/Tag/组；eventId 兼作 keys 与幂等键，不以业务号作幂等键。
2. **Outbox 原子 + CAS 投递**：同事务落库、UPDATE CAS 抢占、同聚合 created_at 顺序、有界退避、FAILED 可重投；MQ 停机保留 PENDING。
3. **双幂等消费链**：consumed_event 先占位后处理（失败回滚占位）+ 业务操作自身幂等；乱序以订单聚合当前状态裁决，库存经 internal API 回查不直连订单库。
4. **三入口收敛**：延迟消息/兜底扫描/补偿执行器统一走 systemCancel；ORDER_AUTO_CANCEL 复用 M4 补偿体系，接口化 CompensationActionHandler。
5. **ObjectProvider 破循环**：执行器列表与被兜底服务互依时以 ObjectProvider 延迟解析，保留 List 构造器供单测。
6. **单开关降级一致**：rocketmq.enabled=false 生产消费全关、Outbox 仍写，降级 M4 同步路径并记日志，业务终态两路径一致。
