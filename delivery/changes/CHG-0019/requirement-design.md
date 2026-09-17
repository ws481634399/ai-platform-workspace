---
affected-repositories: [repo-1, repo-2]
---

# Requirement Design（需求级方案设计）

> 层级：Requirement 级产物——本次 Change 的技术方案骨架
> 业界锚点：ADR（Context → Decision → Alternatives → Consequences）+ 跨仓影响面
> 输入：requirement-spec.md + CHG-0015/0016/0017/0018 已交付契约
> 产出状态：designed
> 分层关系：本文是 Requirement 级；各 Story 内部详细设计见 Story 目录 story-design.md。

## 0. 元信息

- Change ID: CHG-0019
- spec 来源: requirement-spec.md（REQ-M4-001~004 订单交易闭环）
- 相关仓库: repo-1（ai-platform-backend）、repo-2（ai-platform-frontend）
- 受影响仓库数: 2
- 需要 Migration: yes（mall_order 新库 4 张表 Flyway V1；mall-inventory 无 DDL 仅 Mapper SQL 加固；mall-member 无 DDL）

## 1. 当前状态

- `mall-services/mall-order`（8105，库 mall_order）：仅 MallOrderApplication + smoke test + application.yml（端口 8105、空 datasource 占位）+ 空 `db/migration/.gitkeep`；pom 已有 common-web/common-log/mybatis-plus/flyway-mysql/mysql-connector/nacos/common-test，**缺 mall-common-security + oauth2-resource-server + mall-common-redis**；无分层包、无安全链、无下游 URI 配置。
- `mall-services/mall-inventory`（8106）：内部端点 `/api/internal/inventory` 的 lock/release/confirm/availability 已交付：
  - `POST /lock {reservationId,skuId,quantity}`、`/release {reservationId}`、`/confirm {reservationId}`、`/availability {skuIds:≤100}`，ReservationView `{reservationId,skuId(字符串),quantity,status:LOCKED|RELEASED|DEDUCTED}`；
  - lock 已防超卖（`lockStock` 原子条件 SQL + reservationId 查重幂等）；
  - **release/confirm 是已知并发隐患**：应用层先查 status 判断，再 `inventoryRepository.update(inventory)`（updateById 无数量条件）、reservation 也按 id 无条件 update——并发重复请求下库存数量可能重复增减；本 Change 在不改响应契约的前提下补条件 SQL。
- `mall-services/mall-product`（8103）：`POST /api/internal/products/skus/batch {skuIds}` 每入参必返回一项 SkuBatchItemView `{productId(String),productName,productStatus,skuId(String),skuCode,skuStatus,salePriceInCents(Long 分),mainImageUrl,specifications:Map<String,String>,salable:boolean}`，查不到占位 salable=false。
- `mall-services/mall-member`（8102）：仅 `POST /api/internal/members/provision`；地址领域齐备（ShippingAddress 聚合、`AddressRepository.findByIdForMember(id,memberId)` 归属双条件），**缺按 addressId 查询的内部端点**；shipping_address 主键 AUTO_INCREMENT。
- `mall-services/mall-cart`（8104）：`GET /api/internal/carts/members/{memberId}/selected-items → {items:[{skuId:String,quantity:int}]}`；会员写接口 `POST /api/mall/cart/items/batch-delete {skuIds:[]}` 可供前端下单后清理；RestClient 内部客户端样板（X-Internal-Token、UnifyResult 解包、故障 503、@StringId parseLong）已验证。
- `mall-gateway`（8080）：路径式路由；`/api/internal/**` 全局 denyAll→404；`/api/mall/**` 细粒度 hasRole MEMBER（需把 `/api/mall/orders/**` 加入）；`/api/admin/**` 统一 hasRole ADMIN（admin orders 自动覆盖，只需加路由到 8105）。
- 前端：mall-web 已有 member/cart/product 三套 store+api 与结算入口（去结算按钮当前置灰）；mall-admin 已有动态菜单/权限码体系与 product/inventory 管理页可仿。

## 2. 提议方案

### 2.1 服务架构与分层（mall-order，DDD 同构 mall-cart/inventory）

```
com.ai.mall.order
├── MallOrderApplication（@MapperScan、@EnableScheduling）
├── domain/
│   ├── order/
│   │   ├── Order.java                 # 聚合根：唯一状态机入口 pay/cancel/ship/confirmReceipt/reconstitute
│   │   ├── OrderItem.java             # 商品快照值对象（实体）
│   │   ├── OrderStatus.java           # 枚举 PENDING_PAYMENT/PAID/SHIPPED/COMPLETED/CANCELLED
│   │   ├── OrderOperation.java        # CREATE/PAY/CANCEL/SHIP/CONFIRM_RECEIPT
│   │   ├── OrderStatusHistory.java    # from/to/operation/operator/reason/occurredAt
│   │   ├── ReceiverSnapshot.java      # 地址快照值对象
│   │   ├── Money.java                 # 整数分金额值对象（goods/discount/freight/pay，不变量校验）
│   │   ├── OrderRepository.java       # 端口：insert/带 CAS 的状态迁移/查询/分页
│   │   ├── OrderNoGenerator.java      # 端口：全局唯一业务单号
│   │   └── OrderErrorCode.java        # B04xx
│   └── compensation/
│       ├── CompensationTask.java      # 聚合（PENDING/SUCCESS/FAILED_DEAD，退避计算）
│       ├── CompensationType.java      # businessType/operation 枚举
│       ├── CompensationRepository.java
│       └── CompensationErrorCode.java
├── application/
│   ├── order/
│   │   ├── CheckoutPreviewService.java    # 两入口聚合重查、签发 submitToken
│   │   ├── OrderCreateService.java        # 令牌消费→重算→逐行锁→落单→锁后补偿
│   │   ├── PaymentService.java            # pay：CAS→confirm→失败补偿
│   │   ├── OrderCancelService.java        # cancel：CAS→release→失败补偿
│   │   ├── ShipmentService.java           # admin ship
│   │   ├── ReceiptService.java            # member confirm-receipt
│   │   ├── OrderQueryService.java         # 会员/admin 列表详情 + 归属
│   │   ├── OrderViewAssembler.java
│   │   └── port/                          # 出站端口接口
│   │       ├── ProductSkuPort.java        # skus/batch
│   │       ├── InventoryPort.java         # lock/release/confirm/availability
│   │       ├── MemberAddressPort.java     # 内部地址查询
│   │       ├── CartSelectionPort.java     # selected-items
│   │       └── SubmitTokenStore.java      # Redis 一次性令牌
│   └── compensation/
│       ├── CompensationService.java       # 记录/同步执行/落任务
│       ├── CompensationRetryScheduler.java# @Scheduled 有界退避
│       └── InventoryCompensationHandler.java# 按 operation 调 InventoryPort
├── infrastructure/
│   ├── persistence/order/                 # OrderPo/OrderItemPo/OrderStatusHistoryPo + Mapper（含 CAS 自定义 SQL）
│   ├── persistence/compensation/          # CompensationTaskPo/Mapper
│   ├── client/                            # Rest*Port 四个客户端（仿 RestProductSkuClient）
│   ├── id/SnowflakeOrderNoGenerator.java  # ORD + yyyyMMddHHmmssSSS + 4位雪花尾数（对雪花 id 取模 10000 补零）
│   ├── redis/RedisSubmitTokenStore.java   # StringRedisTemplate + Lua GETDEL
│   └── config/{OrderSecurityConfiguration,MybatisPlusConfig,RestClientConfig}
└── interfaces/rest/
    ├── mall/{MemberOrderController.java,dto/OrderDtos.java}     # /api/mall/orders
    ├── admin/{AdminOrderController.java,AdminCompensationController.java,dto/}
    └── internal/  # mall-order 本期不提供内部业务端点（补偿管理走 admin）
```

### 2.2 数据模型（mall_order，Flyway `V1__order_init.sql`，utf8mb4，Instant 存 datetime(6)）

**orders（订单主表）**

| 列 | 类型 | 说明 |
| --- | --- | --- |
| id | bigint PK | 雪花 |
| order_no | varchar(32) UK not null | 业务单号 ORD+时间序列 |
| member_id | bigint not null | 下单会员 |
| status | varchar(24) not null | 状态枚举 |
| source | varchar(16) not null | CART/BUY_NOW |
| goods_amount | bigint not null | 商品总额（分） |
| discount_amount | bigint not null default 0 | M4 恒 0，预留 |
| freight_amount | bigint not null default 0 | M4 恒 0，预留 |
| pay_amount | bigint not null | 应付（分）= goods-discount+freight |
| receiver_name/phone/province/city/district/detail_address/postal_code | varchar | 地址快照 |
| delivery_company | varchar(64) null | 发货物流 |
| tracking_no | varchar(64) null | 运单号 |
| cancel_reason | varchar(255) null | |
| submit_token | varchar(64) null | 一次性下单令牌（联合幂等） |
| paid_at/cancelled_at/shipped_at/completed_at | datetime(6) null | 关键时间 |
| version | bigint not null default 0 | 乐观锁/CAS |
| created_at/updated_at | datetime(6) | |

索引：uk_order_no、uk_member_submit_token `(member_id, submit_token)`（submit_token 可空，MySQL 唯一索引多个 NULL 不冲突；令牌缺失的系统补单不会出现）、idx_member_created `(member_id, created_at)`、idx_status_created `(status, created_at)`。

**order_item（订单项/商品快照）**：id、order_id bigint、order_no varchar(32)、product_id bigint、sku_id bigint、product_name、sku_code、specifications_json text/JSON（Map<String,String> 原样落快照）、main_image_url、unit_price_fen bigint、quantity int、subtotal_fen bigint、created_at；索引 idx_order_id `(order_id)`。

**order_status_history**：id、order_id、order_no、from_status varchar(24) null、to_status、operation varchar(24)、operator varchar(64)（memberId/admin username）、reason varchar(255) null、occurred_at datetime(6)；索引 idx_order_occurred `(order_id, occurred_at)`。

**compensation_task**：id、business_type varchar(32)、business_id varchar(64)（orderNo）、operation varchar(32)、payload text（reservationId JSON）、status varchar(16)、retry_count int default 0、max_retries int default 5、last_error varchar(1000) null、next_retry_at datetime(6) null、created_at/updated_at；uk_business_op `(business_type,business_id,operation)`（同单同操作只允许一条任务，重试复用）、idx_status_next `(status,next_retry_at)`。

H2 测试（MODE=MySQL）：Flyway 脚本需兼容 H2——避免 MySQL 专有 DDL（JSON 列用 varchar/text、不使用 generated column、索引内联），与既有服务测试模式一致。

### 2.3 集中状态机与并发

- `OrderStatus` 持有静态合法迁移表：`Map<OrderOperation, OrderStatus> NEXT = {CREATE→PENDING_PAYMENT, PAY: PENDING_PAYMENT→PAID, CANCEL: PENDING_PAYMENT→CANCELLED, SHIP: PAID→SHIPPED, CONFIRM_RECEIPT: SHIPPED→COMPLETED}`；Order 聚合方法（pay/cancel/ship/confirmReceipt）内部校验当前状态：来源态→执行迁移并追加 history；目标态→标记"幂等重复"（返回当前态不追加 history、不触发副作用）；其他态→抛 OrderErrorCode.STATUS_NOT_ALLOWED。
- 持久层 CAS（每个动作一条自定义 SQL）：
  `UPDATE orders SET status=#{to}, version=version+1, <动作时间列>=now() WHERE id=#{id} AND status=#{from} AND version=#{version}` → rows=1 才插入 history 并执行库存副作用；rows=0 抛 STATUS_CONFLICT 由应用层重读订单走"首次/重复/非法"解读。
- history 与状态在同事务：CAS 成功后同事务 insert history；库存调用在事务提交后执行（事务方法只做订单落库；库存 confirm/release 在应用层方法、事务之外），保证"库存看到的调用一定对应已提交的订单状态"。
- 支付/取消竞争结论：仅一个 CAS 获胜；获胜方做副作用；失败方读到的状态若非自己的来源态也非目标态 → 业务冲突错误。撕裂组合（PAID+released / CANCELLED+deducted）在结构上不可能：库存调用只由 CAS 获胜方发出，且库存侧 CAS 保证 reservation 单向 LOCKED→{DEDUCTED|RELEASED}。

### 2.4 创建链路与补偿编排

1. preview（可下单时）：product batch + inventory availability + member address 组装响应；生成 UUID token，Redis `SET order:submit-token:{memberId}:{token} <json: source/addressId/items 指纹> EX 600`，返回 `{submitToken, ...}`。
2. create：Lua GETDEL 取令牌（属主不匹配/不存在→B0406）→ 校验 addressId 与行指纹 → 二次 product batch 重查（不可售/价格问题→业务失败）→ inventory availability 预检（快速失败，避免无谓锁）→ OrderNoGenerator 生成 orderNo → 逐行 lock（reservationId=`orderNo:skuId`）：
   - lock 业务失败（不足）：对已锁行同步 release（best-effort，失败落 compensation ORDER_CREATE/INVENTORY_RELEASE/orderNo），返回 B0404；
   - 全部锁定成功 → `@Transactional` insert orders+items+history（CREATE）；落库异常 catch：同步全量 release（失败落补偿任务），异常转创建失败 500/B04xx；
   - 成功提交 → 返回 OrderView；uk_member_submit_token 冲突（双击越过 Redis 的极端情况）→ DuplicateKey 捕获，按 token 查既有订单直接返回同视图。
3. pay：加载+归属→聚合判定→CAS 迁移 PAID（事务）→ 逐行 confirm；任一失败 → compensation ORDER_PAY/INVENTORY_CONFIRM（next_retry 30s），接口仍按成功返回（订单 PAID 即支付事实成立，库存扣减可补偿），WARN 日志。
4. cancel：同构 → release；失败落 ORDER_CANCEL/INVENTORY_RELEASE。
5. 补偿执行器：同步 best-effort 与调度重试共用 `InventoryCompensationHandler`：按 payload 的 reservationId 逐个调 release/confirm（库存侧按当前 reservation 状态幂等：RELEASED/DEDUCTED 直接视为成功）；全部成功 → SUCCESS；否则 retry_count+1、退避 30s/1m/2m/5m/10m；达 5 次 FAILED_DEAD。
6. 调度：`@Scheduled(fixedDelay=30s)` 每次 LIMIT 50 拾取 PENDING&到期任务，逐条经 repository CAS `UPDATE ... SET status='PROCESSING'?`——M4 不引入中间态，采用"立即执行+行条件 retry_count 比对"轻防重；单实例运行，process 中异常不影响下一条。

### 2.5 mall-inventory 幂等加固（不改契约）

- `InventoryMapper` 新增：`releaseStock(skuId, qty)` = `UPDATE inventory_stock SET locked_quantity=locked_quantity-#{qty}, updated_at=now() WHERE sku_id=#{skuId} AND locked_quantity>=#{qty}`；`deductStock(skuId,qty)` = total/locked 同减且 `locked_quantity>=qty`。
- `InventoryReservationMapper` 新增 CAS：`casStatus(id, from, to)` = `UPDATE inventory_reservation SET status=#{to},updated_at=now() WHERE id=#{id} AND status=#{from}`。
- release/confirm 应用服务重写为：reservation 已处于目标态→直接幂等返回；否则 reservation CAS rows=1 时才执行库存数量条件更新（rows=0 重读当前态返回）；log 仅在真实迁移时写；@Transactional 保证 reservation 与 stock 一致。锁行 lock 路径维持原原子 SQL。

### 2.6 mall-member 内部地址端点（新增，无 DDL）

- `GET /api/internal/members/{memberId}/addresses/{addressId}`（SERVICE，X-Internal-Token）：复用 `findByIdForMember(addressId, memberId)`（归属双条件）；命中→AddressInternalView（全部快照字段）；不存在→UnifyResult 业务失败 404 码（ADDRESS_NOT_FOUND，不泄露归属差异）。
- 安全链：MemberSecurityConfiguration 已对 `/api/internal/**` hasRole SERVICE，直接新增 controller 即可；新增 DTO record 放 internal/dto。

### 2.7 网关与服务配置

- mall-gateway yml 新增两条路由：`mall-order-mall → http://localhost:8105, Path=/api/mall/orders/**`；`mall-order-admin → 8105, Path=/api/admin/orders/**,/api/admin/compensations/**`。
- GatewaySecurityConfiguration：MEMBER 匹配列表追加 `/api/mall/orders/**`；admin 已被 `/api/admin/**` 覆盖；internal 全局 denyAll 不变。
- mall-order application.yml：port 8105；MySQL mall_order 库（环境变量同其他服务）；Flyway enabled；Redis（submit token）；JWT public key/issuer/audience；internal secret；下游 `mall.order.product-uri/inventory-uri/member-uri/cart-uri`（默认 8103/8106/8102/8104）；@Profile("!test") 安全链（仿 CartSecurityConfiguration：internal SERVICE、/api/mall MEMBER、/api/admin ADMIN）。
- mall-order pom：补 mall-common-security、spring-boot-starter-oauth2-resource-server、mall-common-redis；surefire 带 TESTCONTAINERS_RYUK_DISABLED。

### 2.8 前端方案

mall-web：
- `src/api/order.ts`：preview/create/get/list/pay/cancel/confirmReceipt，类型与后端 record 逐字段对齐（ID 字符串、金额 number 即分）。
- `src/stores/order.ts`：预览模型、提交状态、列表分页/tab、详情。
- `views/checkout/CheckoutView.vue`：路由 `/checkout`（query 带 source 与 buy-now 参数）；挂载调 preview；地址卡（选择已有地址，复用地址 api；未选不可提交）、商品行（图/名/规格/单价/小计/不可下单标识）、总额（payAmountFen 格式化）、提交（防双击，成功后：CART 来源调 cart batch-delete → 跳订单详情；失败展示原因并引导重新确认）。
- `views/order/OrderListView.vue`（/orders）：状态 Tab（全部/待支付/待发货/待收货/已完成/已取消）、分页、每行金额与状态、跳详情。
- `views/order/OrderDetailView.vue`（/orders/:orderNo）：状态步骤条/历史、地址快照、商品与金额、物流、按状态出按钮（待支付：立即支付/取消订单（取消原因弹框）；待收货：确认收货），操作后重查。
- 购物车页"去结算"接线：选中有效项 → router push `/checkout?source=CART`；商品详情"立即购买" → `/checkout?source=BUY_NOW&skuId=&quantity=`。
- 路由守卫：需登录（复用 member 守卫）。

mall-admin：
- `src/api/order.ts`：admin list/get/ship + compensations list/retry。
- `views/order/OrderListView.vue`（搜索栏 orderNo/memberId/状态/时间范围、分页、查看/发货操作）、`OrderDetailView.vue`（完整信息+状态轨迹+发货弹窗 deliveryCompany/trackingNo）。
- 接入动态菜单（订单管理一级菜单，权限码 order:list/order:view/order:ship）：菜单/权限数据经既有后台菜单管理初始化（Flyway/SQL bootstrap 到 admin 库或运营手动配置——dev 采用既有菜单种子方式，dev 实施时确认 admin 菜单表的迁移位置）。

### 2.9 关键不变量

- 订单金额只来自创建瞬间 product 重查价；前端任何金额字段不入领域。
- 无订单状态迁移能绕过 Order 聚合；无 setStatus 出现在 Service/Controller/Mapper 之外的语义（Mapper 仅承载 CAS SQL）。
- reservation 与订单 1:1（orderNo:skuId）；库存 reservation 终态 DEDUCTED⇔订单 PAID+，RELEASED⇔订单 CANCELLED 或建单失败补偿。
- 会员侧任何单订单访问不匹配归属 → 404。
- 补偿任务有界（max 5）、幂等、可人工重试；不吞异常。

## 2.1 备选方案对比（Alternatives Considered）

> 本节编号对应 gate 校验要求（章节顺序位于 §2 提议方案之后）。

| 方案 | 描述 | 优点 | 缺点 | 采纳 |
| --- | --- | --- | --- | --- |
| A 状态 CAS + 同步调用 + 补偿任务（选中） | 条件更新仲裁并发；库存同步调用失败落任务有界重试 | 无 MQ 即可闭环；实现与 M4 同步策略一致；可测可证 | 锁与单跨库非原子，靠补偿 | 是 |
| B Seata AT 强事务 | 全局事务包 inventory+order | 理论强一致 | 需求明确禁止；基础设施成本高 | 否 |
| C Outbox+RocketMQ | 事件驱动最终一致 | M7 目标架构 | M4 明确排除，超前建设 | 否（M7） |
| D 先落单 PENDING 再锁库存 | 订单先建 | 有订单载体挂补偿 | 需求明文禁止"先有效待支付单再发现缺货"；取消垃圾单 | 否 |
| E 令牌仅 Redis 不加 DB 唯一键 | 简单 | Redis 故障/键丢失即可能重复单 | 双层幂等成本低、防护强 | 否（双层） |
| F 支付后 confirm 失败回滚订单状态 | 维持强一致表象 | 回滚后订单可被取消再 release，与已 confirm 竞态形成撕裂 | 语义错误 | 否（保持 PAID+补偿） |

## 3. 仓库影响（Repository Impact）

- 受影响仓库数: 2。

### 3.1 repo-1（ai-platform-backend）

- `mall-services/mall-order`：新建全套（pom/yml/安全链/Flyway V1/domain/application/infrastructure/interfaces + 测试）。
- `mall-services/mall-member`：新增 InternalMemberAddressController + DTO（1 个端点，复用现有 service/repository；必要时 AddressApplicationService 增加内部 getRaw 方法，默认归属语义直接用 repository）。
- `mall-services/mall-inventory`：Mapper 新增 3 条条件 SQL；InventoryApplicationService release/confirm 重写为 CAS 幂等；补充并发测试。
- `mall-gateway`：yml 2 条路由；Java 安全配置 MEMBER 路径加 1 行。

### 3.2 repo-2（ai-platform-frontend）

- mall-web：api/order、store、3 个页面（checkout/order list/order detail）、购物车与详情入口接线、路由守卫、vitest。
- mall-admin：api/order、2 个页面（list/detail+ship）、菜单权限接入、vitest。

## 4. 跨仓协作（Cross-Repository Contract）

会员端（ROLE_MEMBER，UnifyResult 信封，ID 字符串，金额整数分）：

- `POST /api/mall/orders/preview` `{source:"CART|BUY_NOW", addressId?:String, items?:[{skuId:String,quantity:int}]}` → `PreviewView {submitToken, address:AddressView|null, items:[PreviewItem], goodsAmountFen, discountAmountFen:0, freightAmountFen:0, payAmountFen, availableToSubmit}`；PreviewItem `{skuId, productId, productName, skuCode, specifications:Map, mainImageUrl, quantity, unitPriceFen, subtotalFen, salable, stockStatus:OK|LOW|OUT_OF_STOCK, issueCodes:[...]}`。
- `POST /api/mall/orders` `{submitToken, addressId, source, items?}` → `200 OrderView`（幂等重放返回同一 OrderView）。
- `GET /api/mall/orders?status=&page=&size=&startAt=&endAt=` → `PageView<OrderSummaryView>`。
- `GET /api/mall/orders/{orderNo}` → `OrderDetailView`。
- `POST /api/mall/orders/{orderNo}/pay` → `OrderView`；`POST .../cancel {reason?}` → `OrderView`；`POST .../confirm-receipt` → `OrderView`。

OrderView/Detail：`{id, orderNo, status, source, goodsAmountFen, discountAmountFen, freightAmountFen, payAmountFen, receiver{...}, items:[{...snapshot}], deliveryCompany, trackingNo, cancelReason, createdAt, paidAt, cancelledAt, shippedAt, completedAt, statusHistory:[{fromStatus,toStatus,operation,operator,reason,occurredAt}]}`。

管理端（ROLE_ADMIN + 权限码）：

- `GET /api/admin/orders?orderNo=&memberId=&status=&page=&size=&startAt=&endAt=`；`GET /api/admin/orders/{orderNo}`；`POST /api/admin/orders/{orderNo}/ship {deliveryCompany,trackingNo}`。
- `GET /api/admin/compensations?status=&page=&size=`；`POST /api/admin/compensations/{id}/retry`（order:compensation）。

内部契约增量（X-Internal-Token，SERVICE）：

- member 新增 `GET /api/internal/members/{memberId}/addresses/{addressId}` → AddressInternalView | 业务 404。
- 既有消费：product `POST /api/internal/products/skus/batch`；inventory `/lock|/release|/confirm|/availability`；cart `GET /api/internal/carts/members/{memberId}/selected-items`。

错误码（B04xx，最终命名 design 微调）：ORDER_NOT_FOUND_404、ADDRESS_NOT_OWNED_404（对外统一 404 文案）、SUBMIT_TOKEN_INVALID B0406、ORDER_ITEMS_EMPTY/INVALID B0410、PRODUCT_NOT_SALABLE B0402、SKU_INVALID B0403、INSUFFICIENT_STOCK B0404、ADDRESS_INVALID B0405、STATUS_NOT_ALLOWED B0407、DEPENDENCY_UNAVAILABLE B0409/503。

- Migration Impact: mall_order 新建库表（环境库需已创建 mall_order schema——本地 compose 检查，若未建则 Flyway 前补 schema 创建脚本或授权；dev 阶段确认 docker-compose mysql 是否含 mall_order 库）。
- 跨仓时序: member 地址端点 + order 骨架/建表先行 → preview/create → pay/cancel（含 inventory CAS）→ 查询/履约 → 补偿 → 前端按 DU 依赖并行 → Integration Gate。

## 5. Story 设计分派（Story Design Assignments）

| Story ID | 技术要点 | 仓库 | 公共契约归属 |
| -------- | -------- | ---- | ------------ |
| STORY-004-01-01-01 订单预览 | order 工程骨架（pom/yml/安全/Flyway/通用枚举错误码）、product/inventory/address/cart 四端口与 Rest 客户端、Preview 聚合、submitToken Redis 签发、member 内部地址端点、CheckoutView | repo-1、repo-2 | 全套公共底座（包结构/客户端/安全/错误码/金额值对象）在本 Story 落 |
| STORY-004-01-01-02 订单创建与锁定 | Order/OrderItem/ReceiverSnapshot/Money/history 聚合与 PO/Mapper/V1 DDL、OrderNoGenerator、create 编排、双层幂等、逐行锁与锁失败释放、网关路由、前端提交与清购物车 | repo-1、repo-2 | 订单表与聚合 SSOT |
| STORY-004-02-01-01 支付与取消 | 状态迁移表与 CAS SQL、Payment/Cancel 服务、inventory releaseStock/deductStock/casStatus 加固与服务重写、history、前端操作 | repo-1、repo-2 | CAS Mapper 被后续 ship/receipt 复用 |
| STORY-004-03-01-01 会员列表详情 | QueryService 分页/详情/归属、OrderList/DetailView、OrderListView/OrderDetailView 页面初版 | repo-1、repo-2 | 订单读模型 SSOT |
| STORY-004-03-01-02 确认收货 | ReceiptService CAS COMPLETED、前端详情按钮 | repo-1、repo-2 | — |
| STORY-004-03-02-01 后台发货 | AdminQuery/ShipmentService、权限码、mall-admin 两页面+菜单种子 | repo-1、repo-2 | admin DTO SSOT |
| STORY-004-04-01-01 补偿与幂等 | compensation 表/聚合/服务/调度/管理端点、锁后单失败与 pay/cancel 后置失败接线、审计日志、十场景中的 A/B/E 验证 | repo-1 | compensation 表与服务 |

## 6. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-901 | repo-1 | mall-order 工程骨架（pom/yml/安全链/Redis/Flyway 基建/通用枚举错误码/Money）+ 四出站端口与 Rest 客户端 + member 内部地址端点 + Preview 聚合与 submitToken 签发 | AC-101~105 后端 | — |
| DU-BE-902 | repo-1 | create 全链路（Order/OrderItem/快照/history 聚合与 PO/Mapper/V1 建表/orderNo/双层幂等/逐行锁/锁失败释放/history CREATE）+ 网关路由 | AC-106~111 后端 | DU-BE-901 |
| DU-BE-903 | repo-1 | pay/cancel + 状态机 CAS + inventory 条件 SQL 加固 + 并发测试 | AC-112~118,124 | DU-BE-902 |
| DU-BE-904 | repo-1 | 会员订单列表/详情/归属 404 读模型与查询 API | AC-119 | DU-BE-902 |
| DU-BE-905 | repo-1 | 确认收货 CAS COMPLETED + admin 订单查询/详情/发货 + 权限码 | AC-120~122 | DU-BE-903、DU-BE-904 |
| DU-BE-906 | repo-1 | compensation_task + 同步补偿接线 + 有界退避调度 + admin 补偿管理端点 + 审计 | AC-123~126,128 | DU-BE-903 |
| DU-FE-901 | repo-2 | mall-web CheckoutView + api/order + store 预览模型 + 两入口接线 + 提交与成功后清购物车 | AC-101~111 前端 | DU-BE-902 |
| DU-FE-902 | repo-2 | mall-web 订单列表/详情（状态 Tab/历史/物流）+ 支付/取消/确认收货交互 | AC-119,122,127,129 | DU-FE-901、DU-BE-905 |
| DU-FE-903 | repo-2 | mall-admin 订单列表/详情/发货 + 菜单权限接入 | AC-120,121,127,129 | DU-BE-905 |

> 全局依赖：CHG-0015（@StringId/UnifyResult/内部凭证/网关）、CHG-0016（MEMBER 身份/地址归属）、CHG-0017（product sku/batch、inventory availability）、CHG-0018（cart selected-items/batch-delete、RestClient 样板）。

## 7. 风险

- **锁与单跨库**：锁全部成功后落库失败概率低但存在；以同步 release + 补偿任务双层兜底，场景十专项验证（含故障注入）。
- **支付后 confirm 失败语义**：保持 PAID + 补偿，需要前端/后台把"已支付待扣减"视为正常 PAID；补偿 SUCCESS 后无人工感知，靠日志/任务表对账。
- **inventory CAS 改造回归**：release/confirm 是既有 M2 交付能力，重写必须保持响应契约与既有测试通过；新增并发重复请求测试，旧全量测试必须保持绿。
- **H2/MySQL DDL 兼容**：避免 JSON 专有类型；CAS SQL 与 now() 函数双库兼容（H2 MODE=MySQL 支持）。
- **循环内部调用延迟**：最坏 100 行 × (lock) 串行，P95 目标 800ms 可能吃紧；M4 接受 ≤100 条目（preview 限制），实测若超阈值再评估并行化（并行锁会增加补偿复杂度，默认串行）。
- **submitToken 与换地址**：令牌载荷绑定 addressId 与行指纹；用户在确认页换地址/改数量必须重新 preview 取新 token，前端交互需明确（重新拉取不跳页）。
- **admin 菜单种子位置**：需在 dev 实施时确认菜单/权限码的初始化迁移归属（admin 服务库的 Flyway 或既有 bootstrap 机制），避免发货权限不可用。
- **调度重复执行**：M4 单实例；任务执行采用 status+next_retry_at 条件拾取与幂等 handler，未来多实例升级为抢占锁（M7）。

## 8. 待澄清问题

- 无阻断项。exploration §5 的十项决策已定稿并落入本设计；以下实施期确认项不改变契约：
  - 本地 MySQL 是否已建 mall_order schema（dev 启动前核实，缺则补建库命令到本地脚本，不入 Flyway）。
  - admin 菜单/权限码种子数据的迁移位置（随对应 admin 服务既有机制）。
  - 前端金额展示统一走已有 fen 格式化工具（若无需新增，复用 cart 的 formatFen）。
