# Review Report — STORY-009-03-01 订单集成事件与库存异步消费者

> 阶段：sdd-review 产物
> 位置：stories/STORY-009-03-01/review-report.md
> 状态流转：testing（检查点，状态不变）

## 0. 元信息

- Change ID: CHG-0025（M7 分布式增强）
- Test Report: stories/STORY-009-03-01/evidence/test-report.md
- Evidence: stories/STORY-009-03-01/evidence/evidence.yaml
- 检查时间: 2026-09-24T19:50:00+08:00

## 1. 检查结论

整体结论：四项检查全部执行；发现 2 项（均 minor），均已闭环或接受；追踪链 AC→DES→DU→TC→EVD 无断链。mall-order 70/70、mall-inventory 37/37 全绿。

### 1.1 需求一致性

| AC | test-run 证据（covers） | 结论 |
| --- | --- | --- |
| AC-018（四状态迁移事务内发布事件） | EV-010 | ✅ 聚合事件测试 + assembler + flusher |
| AC-019（PAYMENT_SUCCEEDED 确认扣减） | EV-011 | ✅ PaymentSucceededInventoryHandlerTest |
| AC-020（乱序：CANCELLED 不确认扣减） | EV-011 | ✅ CANCELLED 分支 markSkipped |
| AC-021（ORDER_CANCELLED 释放） | EV-011 | ✅ OrderCancelledInventoryHandlerTest |
| AC-022（全量回归零回退） | EV-010/EV-011 | ✅ 107/107 |
| AC-023（失败登记补偿/裁决回查） | EV-010/EV-011 | ✅ 失败先 registerCompensation 再抛；internal 端点 |
| AC-024（Outbox 原子写入） | EV-010 | ✅ MANDATORY 同事务 append |
| AC-025（MQ 关闭降级同步路径） | EV-010 | ✅ sync 分支 confirmAfterPaid/releaseAfterCancel + WARN |

### 1.2 设计一致性

| 检查 | 核对内容 | 结论 |
| --- | --- | --- |
| a. DU ↔ Design | 10 任务与 story-design §4 发布侧/§5 消费侧结构同向 | ✅（3 条 Deviations 均合理） |
| b. Implementation ↔ DU | 聚合事件/assembler/flusher/仓储挂点/服务分支/internal 端点/两消费者全部落地 | ✅ |
| c. AC 满足 | AC-018~025 由 33 新增用例覆盖，无 NOT-TESTABLE | ✅ 107/107 |

### 1.3 跨模块一致性

- mall-order 发布 Tag（EventTags 四常量）↔ mall-event-contracts §41 DTO ↔ mall-inventory 两 Handler `@IntegrationEventListener.eventType` 对齐。
- 消费侧 OrderServiceClient 请求结构 ↔ 发布侧两个 internal 控制器入参（CompensationRequest/CompensationType/Line）逐字段对齐。
- 两侧 `/api/internal/**` 安全策略一致：ROLE_SERVICE + X-Internal-Token（共享 mall.security.internal.shared-secret）。
- 库存幂等口径一致：per-line reservationId=`orderNo:skuId`，仓储 LIKE 枚举与应用服务 CAS 终态判定同源。

### 1.4 代码质量

抽查主代码文件：
- ✅ 全量构造器注入，无字段注入；IntegrationMode 为单开关权威来源，无散落 @Value 判定。
- ✅ 事务边界清晰：事件 flush 仅由仓储在 @Transactional 内触发，OutboxRecordWriter MANDATORY 兜底。
- ✅ CAS 落败对象直接丢弃，不 flush 脏事件；`pullIntegrationEvents` 取出即清空防重复。
- ✅ 失败路径补偿登记异常不掩盖原始业务异常（catch 内仅 ERROR 日志）。
- ✅ 日志不打印订单金额明细，仅 orderNo/reservationId/eventId。
- 关注项见 §2：证据 sha 引号、状态未知保守抛错偏离。

### 1.5 知识同步候选

- 候选 standards：YAML 证据文件中所有 commit sha 一律加引号（含 `e` 的短 sha 会被 YAML 1.1 解析为科学计数法，如 `967e359`→Infinity）；可并入 openspec evidence 编写规范。

## 2. 发现清单

| ID | 严重度 | 状态 | 说明 |
| --- | --- | --- | --- |
| RV-001 | minor | 已闭环 | evidence.yaml 未加引号的 sha `967e359` 被解析为 Infinity 致 Gate 失败 → 全部 commit 字段加引号修复 |
| RV-002 | minor | 已闭环（接受偏离） | ORDER_CANCELLED 消费对 null/未知状态保守抛错重试而非 markSkipped，记 DEV-3，AC-023 失败安全语义满足 |

## 3. 回归验证

- `mvn -pl mall-services/mall-order,mall-services/mall-inventory -am test`：mall-order 70/70、mall-inventory 37/37 全绿。
- 真实跨服务运行态验证在 Change 级 converge 七场景执行（AC-019/020/022 运行态证据）。
