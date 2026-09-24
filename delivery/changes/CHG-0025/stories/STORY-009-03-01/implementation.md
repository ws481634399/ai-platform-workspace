# Story Implementation — STORY-009-03-01

## 0. 元信息

- Change: CHG-0025（M7 分布式增强）
- Story: STORY-009-03-01 — 订单集成事件与库存异步消费者
- Feature Path：分布式增强(FEAT-009) / 订单集成事件与库存异步消费者(FEAT-009-03) / 订单事件与库存消费能力(FEAT-009-03-01)
- Tasks Source：DU task-spec.md（DU-BE-003，权威划分见 story-design.md §5；无前端 DU）
- Started At：2026-09-24T19:00:00+08:00

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
|---|---|---|---|---|
| DU-BE-003 | repo-1 | developing | — | 16c506d |

> 单 DU 覆盖发布侧（mall-order）与消费侧（mall-inventory），同仓内九提交按依赖顺序落位。

## 2. Commit 记录

- 31f3b6c（任务 1，本地未推送）：订单聚合集成事件收集与 pull
- 6d59155（任务 2，本地未推送）：OrderEnvelopeAssembler 四类订单事件信封组装
- 2dca669（任务 3，本地未推送）：OutboxOrderEventFlusher 事务内 flush + IntegrationMode
- 1482141（任务 4，本地未推送）：仓储 insert/transition 事务内 flush + findStatusById
- 967e359（任务 5，本地未推送）：支付/取消异步分支与 MQ 关闭同步降级
- 317eb15（任务 6，本地未推送）：订单状态回查与补偿登记 internal 端点
- 94960dc（任务 7，本地未推送）：库存 pom+按订单号枚举预留+OrderServiceClient
- ae7cd00（任务 8，本地未推送）：PAYMENT_SUCCEEDED/ORDER_CANCELLED 库存消费者
- 16c506d（任务 9，本地未推送）：两侧 rocketmq 段与 order-uri/timeout-minutes 配置

## 3. 各仓实施引用

- DU-BE-003：implementation/ai-platform-backend/delivery/CHG-0025/分布式增强/订单集成事件与库存异步消费者/订单事件与库存消费能力/订单集成事件与库存异步消费者/DU-BE-003/implementation.md
  ——发布侧：领域事件收集、Envelope 组装器、事务内 Outbox Flusher、仓储挂点、支付/取消异步分支与同步降级、两个 internal 端点；
  消费侧：pom 依赖、按订单号枚举预留、OrderServiceClient、两个幂等消费者（乱序裁决/SKIPPED/失败登记补偿再重试）。

## 4. 测试结果

- mall-order：`mvn -pl mall-services/mall-order,mall-services/mall-inventory -am test` **70/70 全绿**（新增 24：聚合事件 5 + assembler 4 + flusher 3 + 服务分支 8 + internal 端点 4）。
- mall-inventory：同命令 **37/37 全绿**（新增 9：PAYMENT_SUCCEEDED 消费者 4 + ORDER_CANCELLED 消费者 5）。

## 5. 延后与边界

- consumed_event 建表与消费幂等通用化归 STORY-009-05-01；本 Story Handler 单测 mock IdempotentConsumer。
- AC-019/020/022 的真实跨服务运行态证据在 Change 级 converge 产出。
