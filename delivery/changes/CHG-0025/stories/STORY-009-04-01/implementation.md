# Story Implementation — STORY-009-04-01

## 0. 元信息

- Change: CHG-0025（M7 分布式增强）
- Story: STORY-009-04-01 — 延迟订单自动取消
- Feature Path：分布式增强(FEAT-009) / 延迟订单自动取消(FEAT-009-04) / 延迟取消能力(FEAT-009-04-01)
- Tasks Source：DU task-spec.md（DU-BE-004 / DU-FE-002，权威划分见 story-design.md §5）
- Started At：—

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
|---|---|---|---|---|
| DU-BE-004 | repo-1 | completed | —（baseline 见 DU metadata） | 04a905e |
| DU-FE-002 | repo-2 | completed | —（baseline 见 DU metadata） | 61e2154 |

> 后端 12 个提交按依赖顺序落位；T13 全量回归 105/105 全绿。

## 2. Commit 记录

- ebdfb1a（任务 1，本地未推送）：outbox_event 加 delay_level 列并全链承载
- d5fa92c（任务 2，本地未推送）：PaymentTimeoutPolicy 动态读取超时参数
- 9022c8f（任务 3，本地未推送）：DelayLevelMapper 18 级向上对齐映射
- 369ebc9（任务 4，本地未推送）：建单收集 PAYMENT_TIMEOUT_CHECK 事件
- 52e7b1c（任务 5，本地未推送）：assembler/flusher 支持延迟事件与同 flush 单超时
- 6d90dad（任务 6，本地未推送）：延迟路由注册 + 投递按行内 delay_level sendDelay
- 740b4ab（任务 7，本地未推送）：抽出 doCancel，新增 systemCancel 系统取消入口
- 97b8665（任务 8，本地未推送）：PAYMENT_TIMEOUT_CHECK 到期回查消费者
- 3b7ff3d（任务 9，本地未推送）：findExpiredPending + 超时兜底扫描器
- be4a55e（任务 10，本地未推送）：union 三源延迟任务视图 + 管理端查询/人工取消/审计
- 61aba4d（任务 11，本地未推送）：V14 延迟取消权限/菜单种子
- 04a905e（任务 12，本地未推送）：延迟强制级别与兜底扫描配置 env 注入
- 任务 13：全量回归执行，无源码变更，无独立提交

## 3. 各仓实施引用

- DU-BE-004：implementation/ai-platform-backend/delivery/CHG-0025/分布式增强/延迟订单自动取消/延迟取消能力/延迟订单自动取消/DU-BE-004/implementation.md
  ——延迟级别存储与全链承载、动态超时策略、18 级向上对齐映射、建单延迟事件、组装/落库、路由/投递、systemCancel、到期回查消费者、兜底扫描器、管理端三源视图与人工取消审计、V14 权限菜单、配置注入。
- DU-FE-002：implementation/ai-platform-frontend/delivery/CHG-0025/分布式增强/延迟订单自动取消/延迟取消能力/延迟订单自动取消/DU-FE-002/implementation.md
  ——distributed.ts delayTaskApi、状态 Tag 纯逻辑、DelayTaskListView（筛选/分页/手动取消二次确认）、component-registry 注册。

## 4. 测试结果

- mall-order：`mvn -pl mall-services/mall-order -am test` **105/105 全绿**（本 Story 新增：事件收集 2、policy/mapper 单测、assembler 5、flusher 3、取消服务 systemCancel 3、到期消费者 5、兜底扫描 3、管理服务 6、控制器 3、union 集成 3）。
- mall-identity：V14 迁移在模块全量运行中成功；该模块另有 3 个既有失败（M1AuditAppendOnlyTest / InternalMemberSeedApiTest），经移除 V14 对照确认与本次变更无关。
- mall-admin（前端）：`pnpm vitest run` 31 个测试文件全部通过（本 Story FE 新增 10 用例）。

## 5. 延后与边界

- consumed_event 建表与消费幂等通用化、ORDER_AUTO_CANCEL 补偿归 STORY-009-05-01；本 Story Handler 单测 mock IdempotentConsumer。
- AC-027/029/030 的真实跨服务运行态证据（force-level + 真实 RocketMQ 到期触发）在 Change 级 converge 产出。
