---
id: "REQ-M4-001~004"
name: "M4 订单交易闭环"
content: "订单预览与创建（服务端重算价格/库存锁定/快照/orderNo/创建幂等/购物车清理）、模拟支付与订单取消（支付/取消幂等/确认扣减/释放/支付取消并发/状态历史）、订单查询与履约（会员列表详情/归属校验/admin 查询发货/确认收货/集中状态机）、交易异常与补偿基础（锁成功单失败补偿/CompensationTask 失败记录/有界重试/库存操作幂等/审计可观测）。"
source: requirement-doc
created-at: "2026-09-23T07:00:00.000Z"
---

# Requirement

> 原始需求全文归档于 `references/M4.md`（REQ-M4-001~004 全部章节 + M4 Integration Gate 十场景 + DoD），本文件记录本 Change 的输入边界。

## 需求描述

按 `docs/需求/M4/M4.md` 执行完整 SDD，一次交付 4 个 P0 Requirement，形成平台第一个完整核心业务闭环：

```text
购物车/立即购买 → 订单预览 → 服务端实时校验商品/价格/地址 → 服务端计算金额
→ 提交订单 → 锁定库存 → 待支付订单 → 模拟支付 → 确认扣减库存
→ 后台发货 → 会员确认收货 → COMPLETED
```

同时支持：用户取消与库存释放、创建失败补偿、重复请求幂等、订单状态历史、基础异常恢复。

### REQ-M4-001 订单预览与创建

- **Checkout Preview**：会员从购物车（选中项）与商品详情立即购买两个入口进入确认页；服务端重新查询商品/SKU/当前销售价/库存可用量/收货地址并重算金额；预览不产生订单号、不锁库存、不建单。
- **禁止信任前端价格**：前端只提交 skuId/quantity/addressId/items 等业务参数；productName/price/totalAmount/payAmount 一律服务端从 mall-product 重查重算，篡改价格无效。
- **实时校验**：预览与正式创建都必须重查 Product 存在且上架、SKU 存在且有效可售、当前价格、销售状态；库存不足订单创建失败，不得先建待支付单再发现缺货。
- **地址校验与快照**：Address.memberId 必须等于当前会员（mall-member 新增内部地址查询端点）；下单时复制地址快照，历史订单地址不随后续修改变化。
- **商品快照**：order_item 保存 productId/skuId/productName/skuCode/skuAttributes(specifications)/image/unitPrice/quantity/subtotal 快照。
- **金额模型**：goodsAmount 商品总额、payAmount 应付金额；M4 无优惠无运费 `payAmount = goodsAmount`；金额一律整数分（Long，项目既有约定），服务端计算，为未来优惠/运费预留字段；满足金额不变量。
- **订单模型/orderNo**：Order + OrderItem，orderNo 全局唯一、不暴露自增 ID、可作跨服务 Reference、高并发不重复；雪花 ID 经 @StringId 字符串传输。
- **状态机**：PENDING_PAYMENT / PAID / SHIPPED / COMPLETED / CANCELLED，命名全平台统一，禁止 Controller/Service/Mapper 任意 setStatus。
- **创建流程**：校验 MEMBER → 校验地址 → 重查 Product/SKU/价格 → 服务端算金额 → Inventory Lock（逐行，稳定 reservationId）→ 保存订单与快照 → 返回；锁成功但建单失败必须触发 Release 补偿（与 REQ-M4-004 共同设计）。
- **创建幂等**：Submit Token（一次性下单令牌）+ 服务端唯一键，双击/网络重试/网关重试不得产生重复订单与重复锁库存。
- **购物车处理**：仅订单创建成功后清理已购购物车选中项；创建失败不得错误清空（前端在创建成功响应后调用既有购物车批量删除接口）。

### REQ-M4-002 模拟支付与订单取消

- **Mock Payment**：会员对待支付订单执行模拟支付成功，按真实支付的安全与幂等思想设计，不是简单 UPDATE status。
- **支付规则**：校验当前用户=订单所有者、状态=PENDING_PAYMENT；已取消订单不能支付；他人订单不能支付。
- **支付幂等**：相同支付请求多次到达只产生一次 PENDING_PAYMENT→PAID 迁移；重复支付保持 PAID，不再次扣库存。
- **确认扣减**：支付状态迁移成功后调用 mall-inventory confirm（按稳定 reservationId 幂等），Locked→Deducted。
- **会员取消**：仅 PENDING_PAYMENT 可由订单本人取消；PAID/SHIPPED/COMPLETED 不能走普通取消（售后属后续阶段）。
- **取消释放**：取消状态迁移后调用 inventory release（幂等），重复取消不重复增加库存。
- **支付/取消并发**：Pay 与 Cancel 并发时最终只能一个合法迁移生效；通过数据库状态条件更新（CAS WHERE status=PENDING_PAYMENT）+ 集中领域状态机保证，不允许“订单 PAID 但库存已 Release / 订单 CANCELLED 但库存已 Deduct”。库存侧 release/confirm 需补原子条件更新加固。
- **状态历史**：OrderStatusHistory 记录 orderId/orderNo、fromStatus、toStatus、operation、operator、reason、occurredAt。
- **mall-web**：订单详情/待支付页按状态显示立即支付/取消，前端仅体验控制，后端强制校验。

### REQ-M4-003 订单查询与履约

- **会员订单列表**：全部/待支付/待发货/待收货/已完成/已取消状态 Tab 筛选 + 分页，UI 文案与领域状态映射。
- **会员订单详情**：orderNo、状态、商品/SKU 快照、成交价、数量、金额、地址快照、创建/支付/发货/完成时间、物流公司/运单号、状态历史。
- **资源归属**：所有会员订单接口强制 Order.memberId = 当前会员；猜 ID 越权返回 404（不泄露订单存在性）。
- **后台订单查询**：mall-admin 列表、orderNo 搜索、会员条件、状态筛选、时间范围、详情；受 M1 RBAC 保护（ADMIN）。
- **后台发货**：仅 PAID→SHIPPED，保存 deliveryCompany/trackingNo/shippedAt/操作人；PENDING_PAYMENT/CANCELLED 不能发货；重复发货按领域规则处理（幂等返回当前状态）。
- **确认收货**：仅订单本人对 SHIPPED 订单可执行 SHIPPED→COMPLETED；未发货不能确认；记录 completedAt。
- **集中状态机**：所有状态迁移只允许通过 Order 聚合领域行为完成。

### REQ-M4-004 交易异常与补偿基础

- **锁成功单失败补偿**：Inventory Lock SUCCESS → Order Persist FAIL 时同步触发 Release；释放再失败落 CompensationTask，不得 catch 后只打日志丢弃。
- **CompensationTask 模型**：businessType/businessId/operation/status(PENDING/SUCCESS/FAILED_DEAD)/retryCount/maxRetries/lastError/nextRetryAt/createdAt/updatedAt。
- **有界重试**：定时调度扫描到期 PENDING 任务，指数退避、最大次数上限、操作幂等、不无限循环、不重复业务副作用；超次数置 FAILED_DEAD。
- **人工处理基础**：内部/admin 端点支持查询失败任务列表与手动重试，为运维预留（不建复杂运维平台）。
- **库存幂等加固**：Lock/Release/Confirm 重复请求返回正确幂等结果；mall-inventory release/confirm 回写补状态条件 SQL（当前 updateById 无版本条件，为已知并发隐患）。
- **状态迁移幂等**：Pay/Cancel/Ship/ConfirmReceipt 按当前状态区分首次/重复/非法。
- **审计与可观测**：OrderStatusHistory + 含 orderNo/operation/traceId/error 的关键异常日志；禁止记录 password/token/secret 与不必要的完整敏感信息。

### M4 Integration Gate（十场景，change 级验收）

完整成功交易、库存不足、价格变化、前端篡改价格、重复提交订单、支付重复、取消重复、支付取消竞争、订单越权、锁后单失败补偿；另含库存始终 ≥0、无跨服务数据库查询、关键操作有 TraceId、M4 Integration Evidence。

## 补充信息

- 优先级：P0（4 个 Requirement 全部 P0）
- 开发依赖顺序：REQ-M4-001 →（REQ-M4-002 / REQ-M4-004 并行）→ REQ-M4-003 → Integration Gate
- 前置依赖：REQ-M2-003（商品/快照内部契约）、REQ-M2-004（库存锁/放/扣）、REQ-M3-001（MEMBER 身份/地址）、REQ-M3-003（购物车选中项/清理接口）、CHG-0015（内部服务凭证/网关）
- 主要服务：mall-order（新建，8105，库 mall_order）
- 协作服务：mall-product(8103)、mall-inventory(8106)、mall-member(8102)、mall-cart(8104)、mall-gateway(8080)
- 主要前端：mall-web（结算确认页/我的订单/订单详情）、mall-admin（订单管理/发货）
- 主要仓库：repo-1（backend：mall-order 新建 + mall-member/mall-inventory/mall-gateway 小改）、repo-2（frontend：mall-web + mall-admin）
- 技术约束：Java 21 + Spring Boot 3.5.x + MyBatis-Plus + MySQL/Flyway + Redis；跨服务 Spring RestClient + X-Internal-Token（不用 Feign）；金额整数分 Long；@StringId 字符串传输雪花 ID；中文注释。
- 非本需求范围：真实支付网关与回调安全、微信/支付宝、退款/售后、自动超时取消/关单、真实物流、自动确认收货、评价、发票、RocketMQ、Outbox、延迟消息、死信队列、Seata、分布式强事务、完整监控告警平台（M7 及后续阶段）。
