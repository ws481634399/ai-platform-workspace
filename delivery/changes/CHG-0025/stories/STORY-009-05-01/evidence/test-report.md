# Test Report — STORY-009-05-01 消费幂等与补偿机制

## 1. 测试范围

| 层 | 范围 | 方式 |
| --- | --- | --- |
| 领域 | CompensationTask OP_AUTO_CANCEL_ORDER、manualComplete（保留 lastError） | 单测 |
| 应用 | OrderAutoCancelCompensationHandler（payload→systemCancel）、CompensationService（执行器列表化调度/enqueueOrderAutoCancel/MDC traceId）、PaymentTimeoutCheckHandler（失败登记补偿后重抛/冲突归并） | 单测（Mockito） |
| 基础设施 | V3/V6 consumed_event 迁移（uk_event_group、result 默认值）；CompensationRepository.page 6 参过滤（type/operation 精确、businessId like、空串忽略） | H2 MySQL 模式 + Flyway @SpringBootTest |
| 接口 | AdminCompensationController（operation 白名单/aggregateId 转义/payload 透传/complete/审计） | 单测 |
| 权限 | mall-identity V15 三权限 + 菜单 permission_code 切换 + 超管授权 | Flyway 迁移验证 |
| 前端 | compensationApi（operation/aggregateId/complete）、CompensationListView 结构契约 | Vitest |

## 2. 测试执行汇总

| # | 命令 | 模块 | 结果 | 计数 |
| --- | --- | --- | --- | --- |
| 1 | `mvn -pl mall-services/mall-order clean test` | mall-order | 通过 | 118/118（0 失败、0 错误、0 跳过；基线 105 + 本 Story 新增 13） |
| 2 | `mvn -pl mall-services/mall-inventory clean test` | mall-inventory | 通过 | 37/37（0 失败、0 错误、0 跳过） |
| 3 | `mvn -pl mall-services/mall-identity -Dtest=InternalMemberSeedApiTest test` | mall-identity | V15 迁移成功（Flyway 版本 15 日志确认） | 该模块 3 个既有失败与本次无关 |
| 4 | `npx vitest run` | mall-admin 前端 | 通过 | 33 个测试文件 / 134 用例全部通过（基线 31 文件 + 本 Story 新增 2 文件） |

关键用例结论：

- AC-033（TC-001）：V3/V6 在两模块全迁移上下文中成功；列定义/唯一键/默认值与 ConsumedEventRepository SQL 对齐。
- AC-034（TC-002）：mall-common-mq ConsumedEventRepository 单测（INSERT IGNORE 1→FIRST_PROCESSED / 0→DUPLICATE、markResult、deletePlaceholder、同 eventId 不同 group、表名白名单）；真实并发重复消费运行态归 M7 Integration Gate。
- AC-035（TC-003）：PaymentTimeoutCheckHandlerTest——非 STATUS_CONFLICT 异常调 enqueueOrderAutoCancel 后重抛；CONFLICT 仍归并 SKIPPED 不登记。
- AC-036（TC-004/005）：OrderAutoCancelCompensationHandler 4 用例（systemCancel(COMPENSATION)/CANCELLED 幂等/CONFLICT 退避/坏载荷）；CompensationService dispatch/enqueueTrace 7 用例（supports 选择、insertIgnore、退避序列、MDC 写入与 remove）。
- AC-037（TC-006/007）：manualComplete 三态与 lastError 保留；控制器 operation 白名单、aggregateId %/_ 转义、size 上限、payload 原文透传。
- AC-038（TC-006/008/010）：compensation-audit 含 operator/taskId/after/at；V15 三权限与菜单切换可重复执行；前端 API 3 用例 + 视图契约 7 用例。
- AC-039（TC-005/009）：补偿执行 MDC=task.traceId、finally remove；payload/traceId 全链字段贯通（真实跨服务运行态归 Integration Gate）。
- AC-040（TC-011）：M4/M5 及 S1~S4 既有用例零回退。

## 3. 遗留与风险

- AC-034 真实并发重复消费、AC-039 eventId/traceId 真实链路跨服务运行态证据在 Change 级 converge + M7 Integration Gate 产出（force-level + 真实 RocketMQ）。
- mall-identity 既有失败（M1AuditAppendOnlyTest / InternalMemberSeedApiTest）属仓库其他在途改动，不阻塞本 Story。
