---
affected-repositories: [repo-1]
story-id: "STORY-004-04-01-01"
change-design-ref: "requirement-design.md#24-创建链路与补偿编排"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design §2.4/§2.9/§4.5
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-04-01-01
- 状态流转: specified → designed
- 需要 Migration: yes（mall_order V2 compensation_task）
- 数据变更概要: 新增 compensation_task 表；@EnableScheduling 启用

## 1. 模块改动（Module Changes）

### mall-order（repo-1）

- `db/migration/V2__compensation_init.sql`：requirement-design §2.2 字段；uk_business_op、idx_status_next；H2/MySQL 兼容。
- domain.compensation：CompensationType 枚举（ORDER_CREATE/ORDER_PAY/ORDER_CANCEL × INVENTORY_RELEASE/INVENTORY_CONFIRM，采用两个字段 businessType+operation）；CompensationTask 聚合（recordFailure/markSuccess/backoff 计算 [30s,60s,120s,300s,600]、canDeadline、manualReset）；CompensationRepository（insertIgnore/upsert、findDue(limit)、casClaim 或条件 update、findById/page）。
- application.compensation.InventoryCompensationHandler：handle(task)：解析 payload reservationIds，逐个 inventoryPort.release/confirm；client 异常或状态非目标 → 失败；reservation 当前态=目标态 → 视为成功（幂等）。
- CompensationService：
  - `compensateOnceOrRecord(type, orderNo, op, reservationIds, runnableCall)`：先执行调用；成功直接返回；失败 → repository.insertIgnoreOrGet（唯一键冲突取既有行并追加 payload 合并）→ markFailure(backoff) upsert，WARN 日志；
  - `runDueTask(task)`：handler 执行 → success/fail 更新（条件 status='PENDING' 防并发重复拾取）；
  - `manualRetry(id)`：加载 → SUCCESS 拒绝（400）→ reset+nextRetryAt=now → runDueTask；
  - `page(status,page,size)`。
- CompensationRetryScheduler：@Scheduled(fixedDelayString="${mall.order.compensation.scan-delay-ms:30000}")；findDue(PENDING, now, 50) 逐条 runDueTask try/catch；单条异常不中断。
- 接线替换：OrderCreateService（锁中途失败的已锁 release、落库异常后的 release）、PaymentService（confirm 异常）、OrderCancelService（release 异常）统一改调 compensateOnceOrRecord（传入"逐行调用"动作）。
- interfaces.rest.admin.AdminCompensationController：GET /api/admin/compensations、POST /{id}/retry；@PreAuthorize("hasAuthority('order:compensation')")；DTO CompensationView。
- MallOrderApplication 增加 @EnableScheduling（test profile 用属性关闭调度避免干扰：@ConditionalOnProperty 或 scheduler fixedDelay 极大——实现采用 @ConditionalOnProperty mall.order.compensation.scheduler-enabled 默认 true、测试置 false）。

## 2. 接口契约细化

| 方法 | 路径 | 权限 | 响应/错误 |
| --- | --- | --- | --- |
| GET | /api/admin/compensations | order:compensation | 200 Page<CompensationView> |
| POST | /api/admin/compensations/{id}/retry | order:compensation | 200 View；404；400 ALREADY_SUCCESS |

## 3. 数据变更

- V2 compensation_task（requirement-design §2.2）；payload text 存 JSON `{"reservationIds":[...]}`。
- 调度开关属性：mall.order.compensation.scheduler-enabled（默认 true）、scan-delay-ms（默认 30000）、scan-limit（默认 50）。

## 4. 错误处理

- 任务执行异常不外泄到调度器（catch 记录 lastError/日志）；FAILED_DEAD 仅 ERROR 告警。
- 人工 retry 的立即执行结果按当前真实状态返回（可能再次 FAILED_DEAD/退避）。
- 日志禁止字段：password/token/secret；地址/手机号不进补偿日志（payload 仅 reservationId 与 orderNo，天然无敏感信息）。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-906 | repo-1 | V2/聚合/服务/调度/管理端点/三处业务接线 | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007 | 无 |

> 跨 Story 依赖（不入本表 depends-on）：DU-BE-906 实际前置 DU-BE-903（STORY-004-02-01-01，库存 CAS 与 pay/cancel 挂点）。

## 6. 测试策略

- 领域：退避序列、retryCount 边界、manualReset、payload 合并。
- 应用/集成（mock inventoryPort 故障脚本）：场景 A（落库失败+release 失败→任务→重试成功）、场景 B、handler 对目标态幂等成功、唯一键复用、FAILED_DEAD 转换、manual retry 全链路；调度器用直接调用 service 方法 + 开关属性测试（不依赖真实定时）。
- 审计：日志捕获断言含 orderNo/traceId 且无 secret 字样。
- Integration Gate 场景 A~E 在 change 级 test-design 统一编排执行。
