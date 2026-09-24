# Test Report — STORY-009-04-01 延迟订单自动取消

## 1. 测试范围

| 层 | 范围 | 方式 |
| --- | --- | --- |
| 领域 | Order.create 收集 PAYMENT_TIMEOUT_CHECK；pull 清空 | 单测 |
| 应用 | PaymentTimeoutPolicy、DelayLevelMapper（18 级向上对齐/强制级别）、OrderEnvelopeAssembler（延迟 payload）、OutboxOrderEventFlusher（单超时/带级别 append）、EventRouter（延迟路由）、OutboxDeliveryTask（行内级别 sendDelay）、OrderCancelService（systemCancel）、PaymentTimeoutCheckHandler（回查/跳过/冲突归并）、OrderTimeoutFallbackScanner（cutoff/隔离）、DelayTaskAdminService（筛选/分页/审计） | 单测（Mockito） |
| 基础设施 | V5 delay_level 列与全链承载；union 三源 SQL（筛选/分页/订单消失回退）；findExpiredPending SQL 随上下文启动迁移 | H2 MySQL 模式 + Flyway @SpringBootTest |
| 接口 | DelayTaskAdminController 直调（DTO 映射、原因透传） | 单测 |
| 前端 | delayTaskApi（URL/参数/解包）、状态 Tag 纯逻辑、DelayTaskListView 结构契约 | Vitest |

## 2. 测试执行汇总

| # | 命令 | 模块 | 结果 | 计数 |
| --- | --- | --- | --- | --- |
| 1 | `mvn -pl mall-services/mall-order -am test` | mall-order（含依赖模块） | 通过 | 105/105（0 失败、0 错误、0 跳过） |
| 2 | `mvn -pl mall-services/mall-identity test` | mall-identity | V14 迁移成功；3 个既有失败与本次无关 | 80 通过 / 2 失败 / 1 错误（对照确认非本 Story 引入） |
| 3 | `pnpm vitest run` | mall-admin 前端 | 通过 | 31 个测试文件全部通过（本 Story 新增 10 用例） |

关键用例结论：

- AC-026：建单后领域收集两事件 [ORDER_CREATED, PAYMENT_TIMEOUT_CHECK]；T1 迁移/承载 + assembler 延迟 payload（orderId/orderNo/expireAt）由单测与 H2 集成测试覆盖。
- AC-028：到期消费者 5 用例——PENDING 才走 systemCancel；不存在/非 PENDING→SKIPPED；STATUS_CONFLICT→归并 SKIPPED；其他异常上抛重试。
- AC-029：投递分支单测验证行内 delay_level=16 走 sendDelay 到 order-delay Topic。
- AC-030：兜底扫描 3 用例——cutoff=now−policy 超时、逐单 systemCancel、单条异常隔离。
- AC-031：union 三源集成测试 3 用例——三源收集/状态筛选/分页、订单消失回退 aggregateId；管理服务 6 用例覆盖非法状态忽略与人工取消。
- AC-032：前端 API/纯逻辑/视图契约 10 用例。

## 3. 遗留与风险

- AC-027/029/030 的真实跨服务运行态证据（真实 RocketMQ 延迟投递 + force-level 到期触发 + 自动取消全链路）在 Change 级 converge 阶段产出。
- mall-identity 既有失败（M1AuditAppendOnlyTest / InternalMemberSeedApiTest）属仓库其他在途改动，需对应 DU 收口，不阻塞本 Story。
