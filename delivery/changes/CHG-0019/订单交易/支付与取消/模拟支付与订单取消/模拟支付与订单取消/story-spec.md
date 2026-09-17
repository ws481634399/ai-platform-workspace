---
story-id: "STORY-004-02-01-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S3]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §4.3 + requirement-design.md §2.3/§2.5
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-02-01-01 模拟支付与订单取消
- 状态流转: specified → specified（细化）

## 1. Story 目标

交付待支付订单的模拟支付与主动取消：以 Order 聚合集中状态机 + 数据库条件更新（CAS）仲裁支付/取消并发，仅一个合法迁移生效；获胜方在状态提交后幂等调用库存 confirm（Locked→Deducted）或 release（→Released）；重复请求幂等解读不重复副作用；每次迁移写状态历史。同步加固 mall-inventory release/confirm 的原子条件更新，根除并发重复增减库存隐患。

## 2. Scope（范围）

### 2.1 包含

- [S3] PaymentService.pay：本人/存在校验（不匹配 404）→ 聚合判定（PENDING→迁移 / PAID→幂等成功 / 其他→B0407）→ CAS+paidAt+history 同事务 → 事务外逐行 confirm；confirm 失败本 Story 先 ERROR 日志（STORY-004-04-01-01 补补偿任务）。
- [S3] OrderCancelService.cancel：同构 → CAS CANCELLED（cancelledAt/reason/history）→ 逐行 release；失败同日志策略。
- [S3] CAS 竞争失败解读：rows=0 重读订单，按当前状态返回幂等成功或 B0407 冲突。
- [S3] mall-inventory 加固：InventoryMapper releaseStock/deductStock 条件 SQL、reservation casStatus；InventoryApplicationService release/confirm 重写为 reservation CAS 仲裁（目标态直接幂等返回、仅 CAS 赢家改库存与写日志）。
- [S3] mall-web：详情/列表待支付状态的"立即支付/取消订单（原因）"按钮与操作后重查（页面主体在 DU-FE-902，本 Story 交付 api 接线与最小交互，列表/详情页随 STORY-004-03-01-01 完整呈现——交互并入 DU-FE-902）。

### 2.2 不包含

- compensation_task 落表/调度（STORY-004-04-01-01；本 Story 预留日志挂点）；发货/收货；真实支付。

## 3. 业务规则

- 仅订单本人可 pay/cancel；不存在/非本人 → 404（统一文案）。
- pay：PENDING_PAYMENT→PAID；CANCELLED/其他状态 → B0407；已 PAID 重复 pay → 200 幂等成功，不调 confirm。
- cancel：PENDING_PAYMENT→CANCELLED（reason 可空，≤255）；PAID/SHIPPED/COMPLETED → B0407；已 CANCELLED 重复 cancel → 200 幂等成功，不调 release。
- 顺序：先订单状态 CAS 提交，后库存副作用；库存失败不回滚订单状态（PAID 保持支付事实、CANCELLED 保持取消事实）。
- reservationId 沿用下单 `orderNo:skuId`；库存 confirm/release 按当前 reservation 状态幂等。
- history：每次真实迁移写一条（from/to/operation/operator=memberId/reason/occurredAt）；幂等重放不写历史。
- 并发：Pay||Cancel 同单并发压测，终态唯一且库存终态与订单一致，无 PAID+released / CANCELLED+deducted。

## 4. 接口与字段规格

- `POST /api/mall/orders/{orderNo}/pay`（MEMBER）→ OrderDetailView；404 非本人/不存在；B0407 状态不允许（409）。
- `POST /api/mall/orders/{orderNo}/cancel` `{reason?:string}` → OrderDetailView。
- inventory 内部契约响应不变（ReservationView.status 终态语义不变）；实现侧条件化。
- 前端：DU-FE-902 中 pay/cancel 调 api/order，操作中防连点。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | PENDING 单 pay → PAID、paidAt、history(PAY)；全部 reservation DEDUCTED；stock total/locked 同减 |
| AC-002 | 重复 pay：第二次 200 幂等成功，confirm 仅生效一次，库存只扣一次，无新增 history |
| AC-003 | CANCELLED 单 pay → B0407；他人/不存在单 pay → 404 |
| AC-004 | PENDING 单 cancel → CANCELLED、cancelledAt/reason、history(CANCEL)；reservation RELEASED、可用量归还 |
| AC-005 | 重复 cancel：幂等成功，库存只释放一次；PAID/SHIPPED/COMPLETED cancel → B0407；他人 404 |
| AC-006 | Pay||Cancel 并发（多线程/多请求）→ 终态唯一；PAID 必 DEDUCTED、CANCELLED 必 RELEASED，无撕裂 |
| AC-007 | mall-inventory 同一 reservationId 重复 release/confirm：库存数量不重复变化，返回当前 status；锁后直接 confirm（未锁路径之外）非法态返回业务错误 |
| AC-008 | inventory 既有全量测试保持绿，新增 CAS 并发重复请求测试通过 |
| AC-009 | 库存副作用异常时订单状态不回滚且 ERROR 日志含 orderNo/traceId（补偿任务在下一 Story 落表） |
