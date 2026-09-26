# Review Report — STORY-009-05-01 消费幂等与补偿机制

> 阶段：sdd-review 产物
> 位置：stories/STORY-009-05-01/review-report.md
> 状态流转：testing → completed

## 0. 元信息

- Change ID: CHG-0025（M7 分布式增强）
- Test Report: stories/STORY-009-05-01/evidence/test-report.md
- Evidence: stories/STORY-009-05-01/evidence/evidence.yaml
- 检查时间: 2026-05-26T15:30:00+08:00

## 1. 检查结论

整体结论：检查全部执行；发现 3 项（major×1 已闭环 / minor×1 已闭环 / info×1 外部事项）。追踪链 AC→DES→DU→TC→EVD 无断链。mall-order 118/118、mall-inventory 37/37、mall-admin 33 文件/134 用例全绿。

### 1.1 需求一致性

| AC | test-run 证据（covers） | 结论 |
| --- | --- | --- |
| AC-033（两服务 consumed_event 实体表） | EV-015（TC-001） | ✅ V3/V6 全迁移成功，uk_event_group + idx 对齐 |
| AC-034（先占位后处理，重复消费幂等） | EV-015（TC-002） | ✅ 组件层 INSERT IGNORE 分支全覆盖；真实并发运行态归 converge |
| AC-035（失败即登记补偿） | EV-015（TC-003） | ✅ PaymentTimeoutCheckHandler 非 CONFLICT 登记后重抛；CONFLICT 归并 |
| AC-036（复用 M4 补偿体系执行自动取消） | EV-015（TC-004/005） | ✅ 执行器接口化 + 退避/MDC，无新补偿体系 |
| AC-037（按类型/状态/聚合筛选、查 payload） | EV-015（TC-006/007） | ✅ 白名单/通配符转义/payload 透传 |
| AC-038（手动重试/完成 + 审计） | EV-015、EV-016（TC-008/010） | ✅ V15 三权限 + compensation-audit + 前端二次确认 |
| AC-039（eventId/traceId 全链路） | EV-015（TC-005/009） | ✅ MDC 沿用/移除；真实跨服务运行态归 Integration Gate |
| AC-040（既有能力零回退） | EV-015、EV-016（TC-011） | ✅ 两后端模块 + 前端全量回归通过 |

### 1.2 设计一致性

| 检查 | 核对内容 | 结论 |
| --- | --- | --- |
| a. DU ↔ Design | 11+5 任务与 story-design §1~§2 结构同向 | ✅（DEV-1/2/3 已记录并评估） |
| b. Implementation ↔ DU | 迁移/聚合/执行器/服务/消费者/仓储/控制器/V15/前端全部落地 | ✅ |
| c. AC 满足 | AC-033~040 均有用例覆盖；真实运行态项归 converge | ✅ |

### 1.3 跨模块一致性

- V3/V6 DDL 字段（event_id/consumer_group/result/trace_id）↔ mall-common-mq ConsumedEventRepository SQL ↔ AbstractIntegrationHandler 六步链对齐。
- CompensationTask.OP_AUTO_CANCEL_ORDER ↔ OrderAutoCancelCompensationPayload ↔ OrderAutoCancelCompensationHandler.supports ↔ 前端操作类型下拉四值（含库存两值）对齐。
- 控制器权限码 system:compensation:* ↔ V15 种子与菜单 permission_code 切换 ↔ 前端 v-permission 三方对齐；旧 order:compensation 保留不破坏历史数据。
- PaymentTimeoutCheckHandler、补偿执行器、延迟消息、兜底扫描四入口全部收敛到 OrderCancelService.systemCancel，CAS 与 traceId 同源。

### 1.4 代码质量

- ✅ ObjectProvider 延迟解析打破构造器循环，未引入 @Lazy 散点或 setter 注入。
- ✅ LIKE 通配符在控制器转义、operation/status 白名单，避免任意值透传。
- ✅ 失败安全：补偿登记本身失败仅 ERROR 不掩盖主异常；manualComplete 不抹除原 lastError。
- ✅ 审计日志 compensation-audit 含 operator/taskId/after/at。
- ✅ DDL 全守卫（ON DUPLICATE/INSERT IGNORE/UPDATE 定位），H2/MySQL 双兼容。

## 2. 发现清单

| ID | 严重度 | 状态 | 说明 |
| --- | --- | --- | --- |
| RV-001 | major | 已闭环 | 执行器列表化引入构造器循环（CompensationService→Handler→OrderCancelService→CompensationService），集成上下文 31 错误；改 ObjectProvider 延迟解析 + 保留单测构造器，全量回归通过 |
| RV-002 | minor | 已闭环 | 权限码切换后 OrderApiTest 旧 order:compensation 授权 403；测试同步切 system:compensation:list/retry 并保留无权限 403 断言 |
| RV-003 | info | 外部事项 | mall-identity 3 个既有失败（M1AuditAppendOnlyTest / InternalMemberSeedApiTest），对照确认非本 Story 引入，随对应 DU 收口 |

无遗留 blocker。

## 3. 回归验证

- `mvn -pl mall-services/mall-order clean test`：118/118 全绿。
- `mvn -pl mall-services/mall-inventory clean test`：37/37 全绿。
- `npx vitest run`（mall-admin）：33 个测试文件 / 134 用例全部通过。
- AC-034 真实并发重复消费、AC-039 真实全链路的跨服务运行态验证在 Change 级 converge + M7 Integration Gate 执行。
