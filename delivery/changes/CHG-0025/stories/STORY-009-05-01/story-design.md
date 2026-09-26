---
story-id: "STORY-009-05-01"
change-spec-ref: "requirement-spec.md#3-功能范围"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
scope-refs: [S5, S6]
---

# Story Design（Story 技术设计）— 消费幂等与补偿机制

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md（AC-033~040）、requirement-design.md（§4 决策 5/7、consumed_event DDL、DU-BE-005）
> 状态：designed

## 0. 元信息

- Change ID / Story: CHG-0025 / STORY-009-05-01
- 前置：STORY-009-01-01 / 03-01 / 04-01 均已 completed
- 关键复用：mall-common-mq 的 IdempotentConsumer 接口与 ConsumedEventRepository（JDBC，INSERT IGNORE 占位三段式）、AbstractIntegrationHandler 六步链、M4 CompensationTask 聚合 + CompensationService 30s 扫描 + 有界退避（30s/1m/2m/5m/10m，5 次 FAILED_DEAD）
- 总体结构沿用 requirement-design §2 三件套：**Outbox（发送侧）+ consumed_event（消费侧）+ CompensationTask（兜底侧）**。本 Story 补齐最后两块：消费方数据库落 consumed_event 实体表（代码组件已在，仅缺业务迁移）；补偿执行器从库存一类扩为"库存两类 + 订单自动取消"，失败即登记（决策 7），并增强管理台。

## 1. 模块改动（Module Changes）

### 1.1 mall-inventory：V3 迁移 consumed_event

- 文件：`mall-services/mall-inventory/src/main/resources/db/migration/V3__create_consumed_event.sql`
- DDL 与 requirement-design §4、`ConsumedEventRepository.ddl()` 逐字段对齐：id 自增主键、event_id VARCHAR(64)、consumer_group VARCHAR(64)、event_type VARCHAR(64)、aggregate_id VARCHAR(64) 可空、result VARCHAR(16) 默认 PROCESSING、trace_id VARCHAR(64) 可空、processed_at DATETIME 默认 CURRENT_TIMESTAMP；`UNIQUE KEY uk_event_group (event_id, consumer_group)`、`KEY idx_aggregate (aggregate_id)`。
- H2 MySQL 模式（测试 Flyway 全迁移）与 MySQL 均兼容，无方言函数。
- 既有两个消费者无需改动：AbstractIntegrationHandler 已实现占位成功后执行业务、成功 markResult(SUCCESS)、乱序 markResult(SKIPPED)、异常 deletePlaceholder 交 MQ 重试。

### 1.2 mall-order：V6 迁移 consumed_event（偏离见 §7 DEV-1）

- 与 1.1 同构 DDL（mall-order 库），供 PaymentTimeoutCheckHandler 的 IdempotentConsumer 占位使用。

### 1.3 mall-order：ORDER_AUTO_CANCEL 补偿类型

- 聚合常量：CompensationTask 新增 `public static final String OP_AUTO_CANCEL_ORDER = "AUTO_CANCEL_ORDER";`（businessType 仍为 TYPE_ORDER，businessId=orderNo；唯一键 (ORDER, orderNo, AUTO_CANCEL_ORDER) 保证同单同操作一条）。
- 登记点：PaymentTimeoutCheckHandler.handle 的 PENDING_PAYMENT 分支调用 systemCancel 时，捕获**非** STATUS_CONFLICT 异常（真正取消失败：锁/DB/下游库存释放异常等），先登记 ORDER_AUTO_CANCEL 补偿，再原样重抛交 MQ 重试。
  - 登记不经 HTTP：CompensationService 新增 `enqueueOrderAutoCancel(long orderId, String orderNo, String reason, String traceId)`；payload = `OrderAutoCancelCompensationPayload(long orderId, String orderNo, String eventId)` 序列化 JSON（eventId/traceId 冗余进 payload/列，compensation_task 不扩列）。
  - 登记异常仅 ERROR 日志，不掩盖原始异常（与既有 enqueue 同策略）。
- 执行器：新增 `OrderAutoCancelCompensationHandler`（@Component，application/compensation）：supports=OP_AUTO_CANCEL_ORDER；handle 反序列化 payload → `orderCancelService.systemCancel(orderId, "PAYMENT_TIMEOUT", "COMPENSATION")`；CANCELLED 幂等返回视为成功，STATUS_CONFLICT（已支付等）抛 BusinessException 由上层记退避。
- 调度改造：CompensationService 的单一 inventoryHandler 字段改为 `List<CompensationActionHandler>`（新接口 `boolean supports(String op)` + `void handle(CompensationTask task)`；InventoryCompensationHandler 改为 implements，行为不变）；execute 按 supports 选执行器，无匹配抛 IllegalStateException（既有语义）。
- TraceId（AC-039）：execute 前 `task.traceId()!=null` 时写 MDC（TraceConstants.MDC_KEY），finally remove；下游日志/Outbox 事件沿用同一 traceId。

### 1.4 mall-order：管理端增强

- 仓储：CompensationRepository.page 扩为 `page(String businessType, String businessId, String status, int page, int size)`；MyBatis wrapper 追加条件（空串忽略）。
- AdminCompensationController（路径沿用 `/api/admin/compensations`，理由见 DEV-2）：
  - GET 新增 `operation`（映射 operation 列，白名单 CONFIRM_INVENTORY/RELEASE_INVENTORY/AUTO_CANCEL_ORDER，非法忽略）与 `aggregateId`（映射 businessId 模糊匹配，%/_ 转义 escape）；
  - 新增 `POST /{id}/complete`：不存在 404；SUCCESS 直接返回；PENDING/FAILED_DEAD → 聚合新方法 `manualComplete(now)`（置 SUCCESS、nextRetryAt=null、lastError 追加 MANUAL_COMPLETE 标记不抹原错误）→ update；
  - 审计：retry/complete 经专用 logger `"compensation-audit"` 输出 operator（SecurityContext 认证名）、taskId、before/after 状态、at（AC-038）。
- DTO：AdminOrderDtos.CompensationView 增加 `payload`（task.payload() 原文透传）。

### 1.5 mall-identity：V15 权限菜单

`V15__compensation_manage_permissions.sql`（仿 V13/V14，NOT EXISTS / INSERT IGNORE / ON DUPLICATE KEY 守卫）：

- 三权限：system:compensation:list（GET /api/admin/compensations）、system:compensation:retry（POST .../{id}/retry）、system:compensation:complete（POST .../{id}/complete）；
- 既有菜单 /orders/compensations 的 permission_code 更新为 system:compensation:list（UPDATE 守卫，component_key/path 不变）；
- SUPER_ADMIN 三权限 INSERT IGNORE；旧 order:compensation 保留不删；控制器 @PreAuthorize 切换新码。

### 1.6 DLQ 衔接

按决策 7：失败即登记补偿（库存两类 STORY-03 已落地、订单取消类本 Story 落地），DLQ 仅作 RocketMQ 最终兜底存储，不做实时扫描；补偿页提供 Dashboard 外链（地址配置化），reason/lastError 保留原始失败信息。

## 2. 接口契约细化

| 项 | 方法/参数 | 契约 |
| --- | --- | --- |
| 补偿分页 | `GET /api/admin/compensations` | 参数 status（PENDING/SUCCESS/FAILED_DEAD）、operation（白名单三值，非法忽略）、aggregateId（businessId 模糊匹配）、page 默认 1、size 默认 10 上限 100；权限 system:compensation:list；返回 PageView\<CompensationView\> |
| 手动重试 | `POST /api/admin/compensations/{id}/retry` | 权限 system:compensation:retry；SUCCESS 直接返回；其余 rearm + 立即执行；审计日志；返回最新任务视图 |
| 手动完成 | `POST /api/admin/compensations/{id}/complete` | 权限 system:compensation:complete；PENDING/FAILED_DEAD→SUCCESS（manualComplete）；审计日志含前后状态 |
| CompensationView | DTO | id/businessType/businessId/operation/payload(String 原文)/status/retryCount/maxRetries/lastError/nextRetryAt/createdAt/updatedAt/traceId |
| 内部补偿登记 | `POST /api/internal/compensations` | 无改动（STORY-03 已支持 INVENTORY_CONFIRM_DEDUCT / INVENTORY_RELEASE） |
| 失败语义 | — | 幂等 DB 异常→不 ACK 交重试（fail-closed）；补偿执行失败→recordFailure 有界退避；5 次 FAILED_DEAD |

## 3. 数据变更

- mall-inventory V3：新增 consumed_event 表（DDL 见 §1.1）。
- mall-order V6：新增 consumed_event 表（同构）。
- compensation_task：不扩列（eventId/eventType 进 payload JSON）；operation 枚举代码层新增 AUTO_CANCEL_ORDER 值。
- mall-identity V15：权限/菜单 DML（见 §1.5）。
- 全部为新增/枚举扩展，无既有表结构变更，无回填。

## 4. 失败与并发语义

- 唯一键 uk_event_group 兜底并发占位，冲突 → DUPLICATE 直接 ACK；唯一键 uk_business_op 兜底补偿并发登记，insertIgnore 重复返回 false，同单多次失败仅一条。
- 三入口（MQ 重试、补偿执行、管理端手动）全部走 CAS/幂等语义，重复执行无二次数量变化。
- 手动重试不重置 retryCount；manualComplete 为人工终态，日志可区分。

## 5. 测试策略（Test Strategy，详见 test-design）

- 单测：OrderAutoCancelCompensationHandler（成功/冲突/坏载荷）、CompensationService（登记幂等/执行器选择/MDC 写入清理）、manualComplete 状态流转、PaymentTimeoutCheckHandler 失败登记分支、控制器 operation/aggregateId 转译、DTO payload。
- 集成（H2 + Flyway 全迁移）：V3/V6 迁移成功；consumed_event 并发占位冲突→DUPLICATE；page 三筛选组合。
- 前端：API 新参数/解包、列表筛选契约、complete/retry 二次确认与 toast。
- AC-034 并发重复消费、AC-039 真实链路 eventId/traceId 的运行态证据归 Change converge（Integration Gate 3）。

## 6. DU 划分

| DU | 仓库 | 范围 | 覆盖 AC | 依赖 |
| --- | --- | --- | --- | --- |
| DU-BE-005 | repo-1 | inventory V3 consumed_event；order V6 consumed_event；OP_AUTO_CANCEL 常量/登记/执行器/调度列表化/MDC；管理端筛选/complete/payload/审计；V15 权限菜单 | AC-033~037, AC-039, AC-040 | — |
| DU-FE-003 | repo-2 | CompensationListView 增强：操作类型/聚合 ID 筛选、payload 查看、手动重试/标记完成（二次确认+审计反馈）、Dashboard 外链；API 与 DTO 同步 | AC-038 | — |

## 7. Deviations（设计偏离）

| ID | 偏离点 | 理由 |
| --- | --- | --- |
| DEV-1 | story-spec §2.2 称"mall-order 侧消费幂等首期不做"，本设计给 mall-order 库同样落 consumed_event（V6） | STORY-04 的 PaymentTimeoutCheckHandler 继承 AbstractIntegrationHandler，构造必须注入 IdempotentConsumer；RocketMQAutoConfiguration 在 rocketmq.enabled=true 且存在 JdbcTemplate 时 fail-closed 自动装配 ConsumedEventRepository（无 NoOp 降级），表缺失会在首条延迟消息到达时抛 SQL 异常。业务幂等仍以订单状态为准，consumed_event 仅承担技术去重，不改变 spec 语义。 |
| DEV-2 | 管理端沿用 /api/admin/compensations 而非 spec §4 示例的 /api/admin/compensation/tasks | M4 已上线路径/菜单/权限，新路径产生双轨；原路径加参数/端点即可满足 AC-037/038。 |
