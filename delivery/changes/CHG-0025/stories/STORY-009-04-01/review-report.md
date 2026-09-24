# Review Report — STORY-009-04-01 延迟订单自动取消

> 阶段：sdd-review 产物
> 位置：stories/STORY-009-04-01/review-report.md
> 状态流转：testing → completed

## 0. 元信息

- Change ID: CHG-0025（M7 分布式增强）
- Test Report: stories/STORY-009-04-01/evidence/test-report.md
- Evidence: stories/STORY-009-04-01/evidence/evidence.yaml
- 检查时间: 2026-05-25T21:20:00+08:00

## 1. 检查结论

整体结论：检查全部执行；发现 3 项（minor×2 / info×1），均已闭环或属外部在途事项。追踪链 AC→DES→DU→TC→EVD 无断链。mall-order 105/105、mall-admin 前端 31 个测试文件全绿。

### 1.1 需求一致性

| AC | test-run 证据（covers） | 结论 |
| --- | --- | --- |
| AC-026（建单同事务两事件，延迟 payload 含 orderId/orderNo/expireAt） | EV-014 | ✅ 事件收集 + V5 + assembler 延迟 payload |
| AC-027（延迟消息真实到期触发全链路） | — | ⏳ 静态链路已齐，运行态证据在 Change converge（force-level + 真实 RocketMQ） |
| AC-028（到期回查状态，仅 PENDING 取消，重复幂等） | EV-014 | ✅ PaymentTimeoutCheckHandlerTest 5 用例 |
| AC-0029（行内 delay_level 延迟投递） | EV-014 | ✅ OutboxDeliveryTaskTest sendDelay 分支 |
| AC-030（定时补偿兜底，双路径 CAS 一致） | EV-014 | ✅ 扫描器 3 用例 + systemCancel 共用 CAS |
| AC-031（admin 可查可介入） | EV-014 | ✅ union 三源集成 + 管理服务/控制器 9 用例 |
| AC-032（前端延迟任务页） | EV-015 | ✅ API/纯逻辑/视图契约 10 用例 |

### 1.2 设计一致性

| 检查 | 核对内容 | 结论 |
| --- | --- | --- |
| a. DU ↔ Design | 12+4 任务与 story-design §1.3~1.9 结构同向 | ✅（无 Deviations） |
| b. Implementation ↔ DU | 存储/策略/映射/事件/组装/路由/取消/消费者/扫描/admin/权限/配置全部落地 | ✅ |
| c. AC 满足 | AC-026/028~032 由用例覆盖；AC-027 归 converge | ✅ |

### 1.3 跨模块一致性

- 建单侧 Outbox append 的 delay_level ↔ 投递任务 sendDelay ↔ 契约 Topic `aimall-order-delay` / Tag PAYMENT_TIMEOUT_CHECK / ConsumerGroups.ORDER_DELAY_CONSUMER_GROUP 对齐。
- 消费者 `@IntegrationEventListener` 声明 ↔ V14 权限/菜单（DelayTaskList）↔ 前端 component-registry 注册键三方对齐。
- 延迟消息、兜底扫描、人工取消三入口全部收敛到 `OrderCancelService.systemCancel`（CAS + ORDER_CANCELLED Outbox + 库存释放链路），并发安全同源。

### 1.4 代码质量

- ✅ 全量构造器注入；超时分钟数一次 flush 只读一次，paymentDeadline/expireAt/延迟级别同源。
- ✅ 事务边界清晰：OutboxRecordWriter MANDATORY；延迟级别与业务数据同事务落库。
- ✅ 失败安全：消费者非预期状态/冲突归并 SKIPPED，其他异常上抛重试/DLQ；扫描器查询与单条异常均隔离。
- ✅ union SQL 避免 JSON 函数，H2 MySQL 模式/MySQL 双兼容。

## 2. 发现清单

| ID | 严重度 | 状态 | 说明 |
| --- | --- | --- | --- |
| RV-001 | minor | 已闭环 | 消费者测试 verify 三参 assemble 时基本类型 long 用 any() 触发拆箱 NPE → 改 anyLong() 修复 |
| RV-002 | minor | 已闭环（接受规避） | harness 0.5.0 CLI bug：`--du` 路径调用未导入的 `join`（workflow.js）→ 改用不带 --du 的 run 推进，DU 状态按机检要求手工维护；建议后续升级 harness |
| RV-003 | info | 外部事项 | mall-identity 3 个既有失败（M1AuditAppendOnlyTest / InternalMemberSeedApiTest），对照确认非本 Story 引入，随对应 DU 收口 |

无 blocker / major。

## 3. 回归验证

- `mvn -pl mall-services/mall-order -am test`：105/105 全绿。
- `pnpm vitest run`（mall-admin）：31 个测试文件全部通过。
- AC-027/029/030 真实跨服务运行态验证在 Change 级 converge 执行。
