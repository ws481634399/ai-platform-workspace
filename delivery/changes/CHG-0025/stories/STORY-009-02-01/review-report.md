# Review Report — STORY-009-02-01 Outbox 可靠投递

> 阶段：sdd-review 产物
> 位置：stories/STORY-009-02-01/review-report.md
> 状态流转：testing（检查点，状态不变）

## 0. 元信息

- Change ID: CHG-0025（M7 分布式增强）
- Test Report: stories/STORY-009-02-01/evidence/test-report.md
- Evidence: stories/STORY-009-02-01/evidence/evidence.yaml
- 检查时间: 2026-09-24T18:50:00+08:00

## 1. 检查结论

整体结论：四项检查全部执行；发现 2 项（1 major / 1 minor），均已闭环；追踪链 AC→DES→DU→TC→EVD 无断链。mall-order 46/46 全绿，mall-admin type-check 通过。

### 1.1 需求一致性

| AC | test-run 证据（covers） | 结论 |
| --- | --- | --- |
| AC-010（事务内原子写入） | EV-003 | ✅ OutboxRecordWriterTest + 仓储集成 save |
| AC-011（CAS 抢占投递） | EV-003 | ✅ OutboxEventRepositoryIntegrationTest.claim CAS |
| AC-012（失败有界退避） | EV-003 | ✅ OutboxBackoffPolicyTest + requeueWithBackoff |
| AC-013（同聚合顺序） | EV-003 | ✅ OutboxDeliveryTaskTest.sameAggregatePicksFirstOnly |
| AC-014（超限 FAILED） | EV-003 | ✅ deliverFailureExceededMarksFailed |
| AC-015（人工重投） | EV-003 | ✅ OutboxEventRepositoryIntegrationTest.resetForRetry |
| AC-016（管理页+审计） | EV-003 / EV-004 | ✅ OutboxAdminController + OutboxListView + outbox-audit 日志 |
| AC-017（未知 eventType 直接 FAILED） | EV-003 | ✅ EventRouterTest + IllegalArgumentException 分支 |

### 1.2 设计一致性

| 检查 | 核对内容 | 结论 |
| --- | --- | --- |
| a. DU ↔ Design | task-spec 引用 story-design §5；CAS/退避/同聚合/路由语义与 story-design §3 同向 | ✅（2 条 Deviations 均合理） |
| b. Implementation ↔ DU | outbox_event 表/Writer/投递任务/admin API/权限码全部落地 | ✅ |
| c. AC 满足 | 偏离（审计用结构化日志）后 AC-016 可追溯性满足 | ✅ 46/46 |

### 1.3 跨仓一致性

- 后端 admin API（OutboxAdminController）契约 ↔ 前端 api/distributed.ts 字段对齐（status/eventType/aggregateId/page 与 OutboxView）。
- 权限码 system:outbox:list/retry 在 mall-identity V13 注册，前端 v-permission 对齐。
- EventRouter 默认路由订单四事件→aimall-order-events，与 STORY-009-01-01 契约一致；register() 扩展点供 STORY-009-04-01 延迟路由。

### 1.4 代码质量

抽查主代码文件：
- ✅ 构造器注入（OutboxDeliveryTask/OutboxRecordWriter）。
- ✅ CAS 原子性用原生 @Update SQL，无分布式锁依赖。
- ✅ 日志不打印 payload 敏感内容，仅 id/eventType/retryCount。
- ✅ @Transactional(MANDATORY) 强制业务事务边界。
- ✅ ObjectProvider 注入 producer，rocketmq.enabled=false 时优雅退避。
- 发现并修复：
  - **major**：mall-common-mq `AutoConfiguration.imports` 误用 spring.factories 键值格式 → 纯类名列表（Spring Boot 3 规范）。此缺陷导致任何依赖 mall-common-mq 的 SpringBootTest 上下文加载失败。已修复并随 e375c40 提交。
  - **minor**：重投审计首期用结构化 `outbox-audit` logger（含 operator/time/beforeStatus/afterStatus），未引入独立审计表。记录为 DEV-2，后续若引入通用审计框架可平滑替换。

### 1.5 知识同步候选

- 候选 standards：Spring Boot 3 自动装配文件 `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports` 必须为纯类名列表，禁止使用 spring.factories 的 `EnableAutoConfiguration=\` 键值语法（可并入 framework-standard 构建规范）。

## 2. 发现清单

| ID | 严重度 | 状态 | 说明 |
| --- | --- | --- | --- |
| RV-001 | major | 已闭环 | AutoConfiguration.imports 格式错误 → 修复（e375c40） |
| RV-002 | minor | 已闭环（接受偏离） | 审计用结构化日志，记 DEV-2 |

## 3. 回归验证

- `mvn -pl mall-services/mall-order test`：46/46 全绿（Outbox 24 + 既有 22）。
- `npx vue-tsc --noEmit -p mall-admin/tsconfig.json`：通过。
