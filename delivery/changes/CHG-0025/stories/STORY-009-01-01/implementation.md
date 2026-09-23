# Story Implementation — STORY-009-01-01

## 0. 元信息

- Change: CHG-0025（M7 分布式增强）
- Story: STORY-009-01-01 — RocketMQ 事件基础设施
- Feature Path：分布式增强(FEAT-009) / RocketMQ 事件基础设施(FEAT-009-01) / 事件基础能力(FEAT-009-01-01)
- Tasks Source：DU task-spec.md（DU-INFRA-001 / DU-BE-001，权威划分见 story-design.md §5）
- Primary Repo：repo-1（implementation/ai-platform-backend）
- Started At：2026-09-22T20:30:00+08:00

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
|---|---|---|---|---|
| DU-INFRA-001 | repo-4 | testing | — | e2256b4 |
| DU-BE-001 | repo-1 | testing | — | ebdbbd9 |

> Baseline 以「—」表示：完整 baseline/result 哈希与指针记录于各仓 DU metadata.yaml
> （repo-4 基线为 CHG-0025 工作开始前提交，repo-1 基线为 CHG-0024 收口提交），
> 可经 `openspec du show CHG-0025 <DU-ID>` 与 `openspec du sync-status CHG-0025` 校验对齐。
> 执行顺序符合依赖图：DU-INFRA-001（compose 三服务先行）→ DU-BE-001（bom/contracts/mq）。

## 2. Commit 记录

- e2256b4（repo-4，DU-INFRA-001，本地未推送）：feat(infra) RocketMQ 三服务定义、broker.conf、.env 版本变量与冒烟
- 14290de（repo-4，DU-INFRA-001，本地未推送）：docs(sdd) 实施记录回填与 TC-001 冒烟证据
- 1c53407（repo-1，DU-BE-001，本地未推送）：feat(bom) rocketmq-spring-boot-starter 2.3.6 版本权威声明
- e7c8598（repo-1，DU-BE-001，本地未推送）：feat(contracts) 集成事件契约 event 包（Envelope/常量/Payload DTO）
- 963a28c（repo-1，DU-BE-001，本地未推送）：feat(mq) RocketMQEnvelopeProducer 三路发送（Tag/keys/traceId MDC）
- 68fcdc8（repo-1，DU-BE-001，本地未推送）：feat(mq) 集成事件消费链与开关装配（六步链/幂等占位/版本裁决/fail-closed）
- ebdbbd9（repo-1，DU-BE-001，本地未推送）：test(mq) TC-002~009 测试基线（26/26 全绿）
- f178ccc（repo-1，DU-BE-001，本地未推送）：docs(sdd) dev 实施记录与证据回填

## 3. 各仓实施引用

- DU-INFRA-001：implementation/ai-platform-infrastructure/delivery/CHG-0025/分布式增强/RocketMQ 事件基础设施/事件基础能力/RocketMQ 事件基础设施/DU-INFRA-001/implementation.md
  ——compose rocketmq-namesrv/rocketmq-broker/rocketmq-dashboard 三服务、broker.conf、.env 版本变量；Deviations 5 条。
- DU-BE-001：implementation/ai-platform-backend/delivery/CHG-0025/分布式增强/RocketMQ 事件基础设施/事件基础能力/RocketMQ 事件基础设施/DU-BE-001/implementation.md
  ——mall-bom 版本权威、mall-event-contracts 契约包、mall-common-mq 生产端/消费端/开关装配；Deviations 5 条。

## 4. 与 Task 对应关系

| Commit | DU | 对应任务 | 验收 |
|---|---|---|---|
| e2256b4 | DU-INFRA-001 | 任务 1 compose 三服务 / 任务 2 broker.conf / 任务 3 .env 版本变量 | AC-001 |
| 14290de | DU-INFRA-001 | 任务 4 红绿灯冒烟记录与实施文档回填 | AC-001 |
| 1c53407 | DU-BE-001 | 任务 1 mall-bom starter 版本权威 | AC-041 |
| e7c8598 | DU-BE-001 | 任务 2 mall-event-contracts 契约包 | AC-002, AC-003 |
| 963a28c | DU-BE-001 | 任务 3 生产端三路发送 | AC-002, AC-005 |
| 68fcdc8 | DU-BE-001 | 任务 4 六步消费链 / 任务 5 幂等与开关装配 | AC-006, AC-007, AC-008 |
| ebdbbd9 | DU-BE-001 | 任务 6 测试基线（TC-002~009） | AC-002~AC-009 |
| f178ccc | DU-BE-001 | 任务 7 回归收口与实施文档回填 | AC-041 |

## 5. Fan-in 状态

- [x] du-materialized：DU-INFRA-001、DU-BE-001 均物化到对应仓（materialized: yes）
- [x] du-fan-in-testing：两 DU 均 status=testing，baseline/result 经 `openspec du sync-status CHG-0025` 与各仓 HEAD 对齐
- [ ] du-fan-in-complete：待 test 阶段 Integration Gate 通过后，两 DU 推进 completed（sdd-converge 闭环）

## 6. 实施要点与验证摘要

- TC-001（repo-4 冒烟）：compose 两服务 healthy；clusterList 含 broker-a(V5_3_4)；sendMessage SEND_OK；consumeMessage 收到 body/keys——证据：repo-4 DU-INFRA-001 evidence/logs/smoke.log。
- TC-002~009（repo-1）：26/26 全绿——契约快照 5、生产端单测 5、处理链单测 7、H2 幂等 4、开关切片 3、Testcontainers 真实 broker IT 7（收发/延迟/v2 拒绝/DLQ/重复幂等）；依赖树 0 冲突——证据：repo-1 DU-BE-001 evidence/evidence.yaml EV-001~EV-005。
- 红灯→绿灯记录：TDD 过程真实拦截缺陷 2 个——红灯阶段分别为 sendDelay 被宽化为 send(timeout) 的 NPE、List.of() 不可变炸消费链的 60s 超时；绿灯阶段修复（setDelayTimeLevel、CopyOnWriteArrayList）后 26/26 全绿。
- 关键设计落地：rocketmq.enabled 单开关 fail-closed、幂等组件无 JdbcTemplate 拒绝装配、eventId 幂等键、版本不匹配 WARN+ACK、异常 RECONSUME_LATER 超限进 DLQ。
