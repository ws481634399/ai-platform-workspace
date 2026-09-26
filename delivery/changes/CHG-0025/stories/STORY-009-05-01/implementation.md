# Story Implementation — STORY-009-05-01

## 0. 元信息

- Change: CHG-0025（M7 分布式增强）
- Story: STORY-009-05-01 — 消费幂等与补偿机制
- Feature Path：分布式增强(FEAT-009) / 消费幂等与补偿机制(FEAT-009-05) / 幂等与补偿能力(FEAT-009-05-01)
- Tasks Source：DU task-spec.md（DU-BE-005 / DU-FE-003，权威划分见 story-design.md）
- Started At：—

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
|---|---|---|---|---|
| DU-BE-005 | repo-1 | completed | —（baseline 见 DU metadata） | d30f9a7 |
| DU-FE-003 | repo-2 | completed | —（baseline 见 DU metadata） | 5ce2ad0 |

> 后端 10 个提交、前端 4 个提交按依赖顺序落位；T11/T5 全量回归：mall-order 118/118、mall-inventory 37/37、mall-admin 134/134 全绿。

## 2. Commit 记录

- 25f83ee（T1，本地未推送）：mall-inventory V3 consumed_event
- ce8d0e9（T2，本地未推送）：mall-order V6 consumed_event（DEV-1）
- aa5be7f（T3，本地未推送）：CompensationTask OP_AUTO_CANCEL_ORDER + manualComplete
- 0050c01（T8，本地未推送）：CompensationRepository.page 过滤扩展（提前实施保证编译）
- 2bb9123（T4-T5，本地未推送）：执行器接口化 + OrderAutoCancelCompensationHandler
- e3bb8d2（T6，本地未推送）：CompensationService 列表化调度/MDC traceId/自动取消登记
- f9f2b81（T7，本地未推送）：PaymentTimeoutCheckHandler 失败登记补偿后重抛
- aba4dca（T9，本地未推送）：补偿台操作/聚合筛选 + 人工完成 + 审计 + payload 透传
- 9c2849c（T10，本地未推送）：V15 补偿管理三权限 + 菜单切换 + 超管授权
- d30f9a7（T11，本地未推送）：ObjectProvider 打破补偿循环 + 权限码测试对齐；全量回归
- 5425717（FE T1，本地未推送）：补偿 API operation/aggregateId + complete；payload/traceId
- 344fefd（FE T2，本地未推送）：操作类型下拉 + 聚合 ID 输入
- 93a7ff2（FE T3，本地未推送）：payload 查看 + 重试权限 + 标记完成
- 5ce2ad0（FE T4，本地未推送）：RocketMQ Dashboard 外链

## 3. 各仓实施引用

- DU-BE-005：implementation/ai-platform-backend/delivery/CHG-0025/分布式增强/消费幂等与补偿机制/幂等与补偿能力/消费幂等与补偿机制/DU-BE-005/implementation.md
  ——V3/V6 consumed_event 迁移、聚合 OP_AUTO_CANCEL_ORDER/manualComplete、执行器接口化与自动取消执行器、服务列表化调度/MDC traceId、失败即登记补偿、仓储过滤扩展、管理台筛选/payload/人工完成/审计、V15 权限菜单。
- DU-FE-003：implementation/ai-platform-frontend/delivery/CHG-0025/分布式增强/消费幂等与补偿机制/幂等与补偿能力/消费幂等与补偿机制/DU-FE-003/implementation.md
  ——补偿 API operation/aggregateId/complete、CompensationListView 操作类型/聚合 ID 筛选、payload 弹窗、标记完成（popconfirm/权限/刷新）、RocketMQ Dashboard 外链。

## 4. 测试结果

- mall-order：`mvn -pl mall-services/mall-order clean test` **118/118 全绿**（基线 105，本 Story 新增 13：CompensationTask manualComplete、OrderAutoCancelCompensationHandler 4、CompensationService dispatch/enqueueTrace 7、AdminCompensationController 3 等；OrderApiTest 权限码对齐）。
- mall-inventory：`mvn -pl mall-services/mall-inventory clean test` **37/37 全绿**。
- mall-identity：V15 在 InternalMemberSeedApiTest 启动上下文中迁移成功（Flyway 版本 15 日志）；该模块 3 个既有失败（M1AuditAppendOnlyTest / InternalMemberSeedApiTest）与本次变更无关。
- mall-admin（前端）：`npx vitest run` **33 个测试文件 / 134 用例全绿**（基线 31 文件，本 Story 新增 order.spec.ts 与 CompensationListView.contract.spec.ts）。

## 5. 延后与边界

- AC-034（真实并发重复消费）、AC-039（eventId/traceId 全链路）的真实跨服务运行态证据在 Change 级 converge + M7 Integration Gate 产出（force-level + 真实 RocketMQ）。
- DLQ 衔接按 design 定稿：失败即登记补偿，本 Story 不新建独立 DLQ 体系。
