---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-004-01-01-02"
change-design-ref: "requirement-design.md#22-数据模型mall_orderflyway-v1__order_initsqlutf8mb4instant-存-datetime6"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §2.2/§2.4
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-01-01-02
- 状态流转: specified → designed
- 需要 Migration: yes（mall_order V1：orders/order_item/order_status_history）
- 数据变更概要: 3 张新表；Redis 消费 order:submit-token；inventory LOCK 预留

## 1. 模块改动（Module Changes）

### repo-1 mall-order

- `db/migration/V1__order_init.sql`：三表（requirement-design §2.2 全字段），H2/MySQL 双兼容（datetime(6)、varchar 存 JSON、不使用 generated column）；uk_order_no、uk_member_submit_token、idx_member_created、idx_status_created、idx_order_id、idx_order_occurred。
- domain.order：Order（聚合：id/orderNo/memberId/status/source/Money/ReceiverSnapshot/items 列表/List<OrderStatusHistory>/version/keyTimes；静态工厂 create(...) 生成 PENDING_PAYMENT 聚合 + CREATE history；pay/cancel/ship/confirmReceipt 方法本 Story 先按状态机表实现但无应用调用——后续 Story 接线；reconstitute 供持久化装配）；OrderItem（快照 record）；ReceiverSnapshot；OrderStatusHistory；OrderStatus + OrderOperation（含 NEXT 迁移表与 canTransit/interpret）。
- infrastructure.id.SnowflakeOrderNoGenerator：`ORD + yyyyMMddHHmmssSSS + 4位`（4 位来自对时间内 AtomicLong 序列或雪花尾数取模 10000，JVM 内 AtomicSequence；uk 索引兜底，冲突重试 3 次）。
- infrastructure.persistence.order：OrderPo/OrderItemPo/OrderStatusHistoryPo + Mapper；OrderMapper 含自定义 CAS 方法（casStatus 带 status+version 条件，后续 Story 使用）；MyBatisOrderRepository（insert 同事务三表、findByOrderNo/findByOrderNoForMember/page）。
- application.order.OrderCreateService（@Transactional 落库方法独立 bean，锁在事务外）：
  1. SecurityContext 取 memberId；submitTokenStore.consume(memberId, token)；
  2. 解析/校验载荷（addressId、规范化 items 指纹等值）；
  3. productSkuPort.findSnapshots + inventoryPort.availability 二次重查（不可售/不足直接失败）；memberAddressPort.find 校验归属；
  4. Money 服务端计算；orderNoGenerator.next()；
  5. 逐行 inventoryPort.lock(orderNo:skuId,...)；收集 locked；失败 → locked.forEach(release best-effort) + 抛业务异常；
  6. repository.insertOrderTx(orderAggregate)；捕获 RuntimeException → locked.forEach(release) 并记录 ERROR 日志（STORY-004-04-01-01 替换为补偿任务落表）→ 抛 500/创建失败；
  7. DuplicateKeyException（uk_member_submit_token）→ findBySubmitToken 返回首单。
- interfaces.rest.mall.MemberOrderController：POST /api/mall/orders → OrderDetailView（assembler：ID 字符串、金额 Fen 后缀、history、receiver、items）。
- mall-gateway：yml mall-order-mall/mall-order-admin 两路由；GatewaySecurityConfiguration MEMBER 行加 /api/mall/orders/**。

### repo-2 mall-web（DU-FE-901）

- api/order.ts（preview/create 类型与 DTO 逐字段对齐）；stores/order.ts（preview 状态、submit 状态机 idle/submitting/done/error）。
- views/checkout/CheckoutView.vue：route query source（CART|BUY_NOW, skuId, quantity）；挂载 preview；地址选择（复用 shipping-address api 列表与默认选中，未选不可提交）；商品行/金额/不可下单原因展示；提交按钮禁用 availableToSubmit=false 与 submitting；成功：CART→cart batch-delete(已购 skuIds)→router.push 详情；BUY_NOW→直接跳详情；失败提示（令牌失效引导重新 preview）。
- 购物车页去结算按钮：选中有效项 → push /checkout?source=CART；ProductDetail 立即购买 → push /checkout?source=BUY_NOW&skuId=&quantity=。
- 路由 /checkout 需 member 登录守卫。

## 2. 接口契约细化

| 方法 | 路径 | 请求 | 响应/错误 |
| --- | --- | --- | --- |
| POST | /api/mall/orders | {submitToken,addressId,source,items?} | 200 OrderDetailView；B0402/B0403 400；B0404 409；B0405 400；B0406 409；503 |
| 内部 | /api/internal/inventory/lock | {reservationId,skuId,quantity} | ReservationView（本 Story 消费） |
| 内部 | /api/internal/inventory/release | {reservationId} | 幂等（本 Story 失败补偿用） |

## 3. 数据变更

- V1 三表（§requirement-design 2.2）；orders.submit_token 写入已消费令牌值（唯一索引幂等兜底）；order_item.specifications_json 存 product batch 返回 Map 的 JSON 字符串。
- 启动前确认 MySQL 存在 mall_order schema（本地 docker-compose 验证；Flyway 不建库）。

## 4. 错误处理

- 锁失败：业务不足抛 B0404（409 ORDER_STOCK_LOCK_FAILED 文案含 skuId）；依赖 503 抛 B0409；均触发已锁 release。
- release best-effort 失败：本 Story 记录 ERROR（orderNo/reservationId/traceId）；STORY-004-04-01-01 起补落 compensation_task。
- 重复提交命中唯一键：返回首单 200 + 响应头/日志标记 idempotent-replay，不作错误。
- 落库失败：500 + 同步释放；不向客户端返回 orderNo（订单不存在）。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-902 | repo-1 | V1 建表/订单聚合/orderNo/create 编排/双层幂等/逐行锁与失败释放/网关路由 | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009, AC-010 | 无 |
| DU-FE-901 | repo-2 | CheckoutView/order api+store/两入口接线/创建成功清购物车 | AC-011 | DU-BE-902 |

> 跨 Story 依赖（不入本表 depends-on）：DU-BE-902 实际前置 DU-BE-901（STORY-004-01-01-01，服务骨架/端口/preview）；执行顺序服从 requirement-design.md §2.10 DU 总表。

## 6. 测试策略

- 领域单测：Order.create 初始态与 CREATE history；Money 合计；OrderNoGenerator 唯一性（万次不重复/冲突重试）；状态机迁移表（非法转换拒绝）。
- API 集成（H2 + 端口 mock + Redis Testcontainers）：成功单全字段断言；无 token/重放/载荷篡改；篡改价格忽略；地址非归属；库存不足；第 N 行锁失败已锁释放（mock inventory 第 2 行抛不足）；落库失败释放（mock mapper 抛错）；唯一键冲突返回首单。
- inventory lock/release 调用次数与 reservationId 格式断言（orderNo:skuId）。
- 前端 vitest：checkout store（preview 不可下单/提交/成功清车主链路）、组件渲染与按钮禁用、路由守卫。
