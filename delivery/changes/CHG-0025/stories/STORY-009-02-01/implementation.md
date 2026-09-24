# Story Implementation — STORY-009-02-01

## 0. 元信息

- Change: CHG-0025（M7 分布式增强）
- Story: STORY-009-02-01 — Outbox 可靠投递
- Feature Path：分布式增强(FEAT-009) / Outbox 可靠投递(FEAT-009-02) / Outbox 投递能力(FEAT-009-02-01)
- Tasks Source：DU task-spec.md（DU-BE-002 / DU-FE-001，权威划分见 story-design.md §5）
- Started At：2026-09-24T18:00:00+08:00

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
|---|---|---|---|---|
| DU-BE-002 | repo-1 | completed | — | e375c40 |
| DU-FE-001 | repo-2 | completed | — | （repo-2 HEAD） |

> 执行顺序符合依赖图：DU-BE-002（后端 Outbox 核心 + admin API）→ DU-FE-001（前端管理页）。

## 2. Commit 记录

- e375c40（repo-1，DU-BE-002，本地未推送）：CHG-0025 STORY-009-02-01 Outbox 可靠投递——outbox_event 表(V4) + OutboxRecordWriter + OutboxDeliveryTask(CAS/同聚合顺序/退避/FAILED/路由) + OutboxAdminController + mall-identity V13 权限码 + mall-common-mq AutoConfiguration.imports 修复 + 24 测试
- c7e38ec（repo-2，DU-FE-001，本地未推送）：api/distributed.ts + OutboxListView.vue + component-registry 注册

## 3. 各仓实施引用

- DU-BE-002：implementation/ai-platform-backend/delivery/CHG-0025/分布式增强/Outbox 可靠投递/Outbox 投递能力/Outbox 可靠投递/DU-BE-002/implementation.md
  ——Flyway V4 outbox_event、OutboxRecordWriter(MANDATORY 事务)、OutboxDeliveryTask(@Scheduled CAS 抢占/同聚合顺序/有界退避/超限 FAILED/eventType 路由)、OutboxAdminController(查询/重投/审计)、mall-identity V13 权限码；附带修复 mall-common-mq AutoConfiguration.imports 格式。
- DU-FE-001：implementation/ai-platform-frontend/delivery/CHG-0025/分布式增强/Outbox 可靠投递/Outbox 投递能力/Outbox 可靠投递/DU-FE-001/implementation.md
  ——mall-admin Outbox 管理页（筛选/payload 抽屉/FAILED 重投）。

## 4. 测试结果

- mall-order：`mvn test` **46/46 全绿**（Outbox 24：16 单测 + 8 仓储集成；既有 M4/M5 22）。
- mall-admin：`vue-tsc --noEmit` 通过。
