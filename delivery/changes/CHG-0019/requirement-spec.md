# Requirement Spec（需求级产品规格）

> 层级：Requirement 级产物——针对本次需求/Change（多 Story 统一一份）
> 业界锚点：PRD（Problem → Goals/Metrics → Scope → Requirements → AC）
> 输入：CHG Context（exploration.md + requirement.md + references/M4.md）
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0019
- Requirement: REQ-M4-001~004 M4 订单交易闭环
- 状态流转: exploring → specified
- 主要服务: mall-order（新建，8105，库 mall_order，repo-1）；mall-member（内部地址端点增量）、mall-inventory（release/confirm CAS 加固）、mall-product（纯消费）、mall-cart（纯消费）、mall-gateway（路由增量）
- 前端: mall-web（结算确认页/我的订单/订单详情，repo-2）、mall-admin（订单管理/发货，repo-2）
- target-user: MEMBER（下单/支付/取消/查询/收货，仅本人资源）、ADMIN（后台订单查询/发货，RBAC）
- pain-points: 没有订单则商城不构成交易；篡改前端价格低价下单、重复提交重复锁库存、支付取消并发导致订单与库存状态撕裂、锁成功单失败导致库存泄漏、越权查看他人订单，都是高风险点
- expected-value: 平台第一条端到端核心交易闭环，订单/价格/库存/履约在同步链路内业务一致，失败可补偿、可重试、可审计
- scope-in: Checkout Preview、订单创建与锁库存、Mock 支付与取消、会员/admin 订单查询、发货、确认收货、集中状态机、状态历史、CompensationTask 有界重试、库存幂等加固、审计日志、十场景联调
- scope-out: 真实支付网关/回调、退款售后、超时自动关单、真实物流、自动确认收货、评价发票、RocketMQ/Outbox/延迟消息/死信/Seata/分布式强事务/监控平台（M7+）

## 1. 背景

M1 交付了可信身份（MEMBER/ADMIN/SERVICE 三类主体与网关 RS256 验签），M2 交付了商品/价格权威与库存锁定/释放/确认扣减能力（reservationId 幂等、防超卖），M3 交付了会员、收货地址与购物车（含选中项查询）。M4 把这些能力编排为一条真正的交易事实链路。新建 mall-order 作为订单权威数据 + 交易状态 + 订单金额 + 订单快照 + 交易流程编排的唯一归属，坚持四条红线：Order ≠ Product/Inventory/Payment（不跨库直查、不直接改他服务数据，跨服务一律 RestClient + X-Internal-Token 内部 API）；价格只信服务端重查（浏览器价格字段一律忽略）；订单状态只能经 Order 聚合的领域行为迁移（CAS 条件更新 + 状态历史，禁止散落 setStatus）；M4 只做同步可靠（幂等 + 补偿任务 + 有界重试），不提前实现 MQ 架构。金额单位沿用项目全局约定：整数分 Long（精确金额，禁 float/double），M4 无优惠无运费 payAmount=goodsAmount，模型预留扩展位。

## 2. 用户价值

- 会员：从购物车或商品详情一键进入结算，看到的就是当前真实价格与库存；下单后可支付、可在待支付时反悔取消、可跟踪发货并确认收货；我的订单随时可查，历史商品与地址永不被后续修改污染。
- 运营（ADMIN）：在 mall-admin 按订单号/会员/状态/时间检索订单，查看详情与状态轨迹，对已支付订单录入物流信息发货。
- 平台：库存始终 ≥0、不泄漏（锁了必能扣或释放）、同一笔交易任何重复请求结果一致、并发竞争只产生一个合法结果、失败有补偿任务兜底且可人工追溯（orderNo + traceId）。

JTBD：

- 角色：MEMBER；场景：When 我在购物车勾选多个 SKU（或商品详情立即购买）进入确认页, I want 看到服务端最新价格/库存/我的地址并直接提交；价值：So that 我支付的金额就是系统认定的金额，不会因页面陈旧数据或他人篡改变价。
- 角色：MEMBER；场景：When 我网络卡顿双击提交或重复收到支付响应, I want 系统只认同一笔单、只锁/扣一次库存；价值：So that 不会被重复扣款（模拟）或重复占库存。
- 角色：MEMBER；场景：When 我下单后不想买了且尚未支付, I want 取消订单并立即释放库存；价值：So that 库存可被其他人购买，我也不会被催支付。
- 角色：运营；场景：When 会员支付完成, I want 录入快递公司与运单号发货；价值：So that 订单进入待收货，会员确认后闭环完成。
- 角色：平台/运维；场景：When 锁库存成功但订单库暂时异常, I want 库存被自动释放或形成可重试的补偿任务；价值：So that 没有永久悬挂库存与无法解释的脏数据。

## 3. 功能范围

### 3.1 包含

- [S1 订单预览] 两入口 Preview（source=CART 拉选中项 / source=BUY_NOW 带 items）；服务端批量重查商品可售状态与当前价、库存可用量、地址详情；逐项输出不可下单原因与整车可下单标志；金额整数分服务端重算；不锁库存不建单；preview 成功签发一次性 submitToken；mall-web 结算确认页（地址列表选择/新增入口、商品行、单价/小计/总额、缺货下架标识、提交）；mall-member 新增内部地址查询端点。
- [S2 订单创建与库存锁定] POST /api/mall/orders；地址归属校验；服务端二次重查重算；生成 orderNo；逐行 inventory lock（reservationId=`orderNo:skuId`），任一行失败则已锁行全部释放并整体失败；orders/order_item/order_status_history 落库（商品快照+地址快照+金额快照）；submitToken 双层幂等（Redis 一次性消费 + DB 唯一索引），重复请求返回首单；PENDING_PAYMENT；mall-gateway 新增 8105 会员/admin 路由；mall-web 创建成功后按已购 skuId 调 cart batch-delete 清理选中项。
- [S3 模拟支付与订单取消] 集中状态机；pay：本人+PENDING_PAYMENT 校验，CAS 迁移 PAID 后逐行 inventory confirm 幂等扣减；cancel：本人+PENDING_PAYMENT，CAS 迁移 CANCELLED 后逐行 release 幂等释放；并发竞争只允许一个迁移生效（CAS 影响行=0 方重读订单做幂等/冲突解读）；库存后置调用失败落 compensation_task，订单状态不回滚；每次迁移写 order_status_history；mall-inventory release/confirm 补原子条件更新；mall-web 按状态显示支付/取消按钮与结果提示。
- [S4 会员订单列表与详情] /api/mall/orders 分页 + 状态 Tab（全部/待支付/待发货/待收货/已完成/已取消）+ 时间范围；详情聚合订单/商品行/地址/金额/关键时间/物流/状态历史；所有访问强制 memberId 归属，越权 404；mall-web 我的订单列表页与详情页。
- [S5 确认收货] POST /api/mall/orders/{orderNo}/confirm-receipt；本人 + SHIPPED 校验；CAS 迁移 COMPLETED + completedAt；重复确认幂等解读，未发货/他人单拒绝；mall-web 详情页操作按钮。
- [S6 后台订单查询与发货] /api/admin/orders 分页/orderNo/会员/状态/时间范围检索与详情；POST /api/admin/orders/{orderNo}/ship，仅 PAID→SHIPPED，记录 deliveryCompany/trackingNo/shippedAt/操作人；重复发货幂等解读，非法状态 409/业务错误；RBAC 权限码 order:list/order:view/order:ship；mall-admin 订单列表页、详情（含状态轨迹）、发货弹窗，接入动态菜单。
- [S7 交易异常补偿与幂等加固] compensation_task 表与 CompensationService；锁后建单失败同步 release + 失败落任务；支付/取消后库存 confirm/release 失败落任务；@Scheduled 有界指数退避重试（30s/1m/2m/5m/10m，最多 5 次）→ SUCCESS/FAILED_DEAD；内部/admin 查询失败任务与人工重试端点；关键异常结构化日志（orderNo/reservationId/operation/traceId/error，不记录敏感信息）。

### 3.2 不包含

- 真实第三方支付、支付回调签名安全、退款/退货/售后；自动超时未支付关单（M7 延迟消息）；真实物流平台对接与物流轨迹查询；自动确认收货；订单评价、发票；库存与订单的消息驱动最终一致性（Outbox/RocketMQ/死信）；分布式定时调度与补偿运维平台；优惠券/营销/运费计价（仅预留字段）。

### 3.3 Story 拆分总表

| Story ID | 标题 | Scope 摘要 | 依赖 | 优先级 |
| --- | --- | --- | --- | --- |
| STORY-004-01-01-01 | 订单预览 | S1：Preview 聚合、服务端重算、submitToken 签发、member 内部地址端点、结算确认页 | CHG-0015/17/18、REQ-M3-001 | P0 |
| STORY-004-01-01-02 | 订单创建与库存锁定 | S2：订单建模/建表/orderNo/快照/逐行锁定与失败释放/创建幂等/网关路由/清购物车 | S1、库存锁契约 | P0 |
| STORY-004-02-01-01 | 模拟支付与订单取消 | S3：状态机 CAS、pay/cancel、confirm/release 与库存 CAS 加固、并发竞争、状态历史 | S2 | P0 |
| STORY-004-03-01-01 | 会员订单列表与详情 | S4：会员查询/筛选/详情聚合/归属 404/我的订单页面 | S2（数据来源） | P0 |
| STORY-004-03-01-02 | 确认收货 | S5：SHIPPED→COMPLETED、本人校验、completedAt、前端按钮 | S3（状态机） | P0 |
| STORY-004-03-02-01 | 后台订单查询与发货 | S6：admin 检索/详情/发货与 RBAC、mall-admin 页面与菜单 | S3 | P0 |
| STORY-004-04-01-01 | 交易异常补偿与幂等加固 | S7：CompensationTask、同步补偿、有界重试、人工重试、审计日志 | S2、S3 | P0 |

## 4. 业务规则总纲

### 4.1 通用规则

- [身份与归属] memberId 只取自 SecurityContext（X-Subject-Id 经网关可信传播），请求体/路径中的 memberId 一律忽略；会员订单资源（预览/创建/查询/支付/取消/收货）全部校验 Order.memberId=当前会员，不匹配统一返回 404（不泄露资源存在性）；admin 接口需 ADMIN 角色 + 权限码。
- [内部调用] 服务间走 RestClient 直连服务端口（不经网关），默认头 X-Internal-Token=`${mall.security.internal.shared-secret}`，对端 `/api/internal/**` 需 SERVICE 角色；解包 UnifyResult 校验 success，非成功/超时/连接失败归一为 503 依赖异常并触发补偿或友好失败；禁止跨服务 SQL。
- [ID 与编号] 订单/订单项主键雪花 ID（MyBatis-Plus ASSIGN_ID），API 经 @StringId 以字符串传输；orderNo 全局唯一业务编号（ORD+时间序列，不复用自增主键、不暴露内部 ID），作为跨服务 Reference 与日志检索键。
- [金额] 一律整数分 Long；goodsAmount=Σ(unitPriceInCents×quantity)；M4：discountAmount=0、freightAmount=0、payAmount=goodsAmount；金额只在服务端计算；任何入参金额字段忽略；金额不变量：goodsAmount≥0、payAmount≥0、payAmount=goodsAmount-discountAmount+freightAmount、每行 subtotal=unitPrice×quantity。
- [状态枚举] 全平台唯一：PENDING_PAYMENT / PAID / SHIPPED / COMPLETED / CANCELLED；不得出现 WAIT_PAY/PAYING/UNPAID 等等价异名；状态机集中在 Order 聚合，迁移表唯一权威：CREATE→PENDING_PAYMENT；PENDING_PAYMENT→PAID(pay)；PENDING_PAYMENT→CANCELLED(cancel)；PAID→SHIPPED(ship)；SHIPPED→COMPLETED(confirmReceipt)；其余迁移全部非法。
- [并发原语] 所有状态迁移用条件更新：`UPDATE orders SET status=:toStatus, version=version+1, <时间字段> WHERE id=:id AND status=:fromStatus AND version=:version`；影响行 0 视为竞争失败，重新加载聚合后按"首次/重复/非法"三种语义解读。
- [幂等语义总则] 首次执行→产生迁移与副作用；重复执行（当前状态=目标状态）→返回当前资源的成功结果且不重复副作用；非法执行（当前状态既非来源也非目标）→业务错误（409/域错误码）。
- [时间与审计] createdAt 落单时间；paidAt/cancelledAt/shippedAt/completedAt 随迁移写入；每次迁移追加 order_status_history（from/to/operation/operator/reason/occurredAt）；关键日志含 orderNo + traceId + operation。
- [错误码] order 域使用 B04xx 段：如 B0401 订单不存在/越权（404 对外统一文案）、B0402 商品不可售/已下架、B0403 SKU 失效、B0404 库存不足、B0405 地址不存在/不属于本人、B0406 提交令牌无效或已使用、B0407 订单状态不允许该操作、B0408 重复提交幂等命中（正常返回首单，非错误）、B0409 依赖服务暂时不可用（503）、B0410 订单项为空/数量非法；最终命名与 HTTP 映射以 design 为准。

### 4.2 REQ-M4-001 预览与创建规则

- [Preview 入参] `POST /api/mall/orders/preview`，body：`source=CART|BUY_NOW`、addressId（可空，表示未选地址）、items（仅 BUY_NOW：[{skuId, quantity}]，CART 时服务端经 cart 内部端点取选中项，忽略 body items）；quantity 1–999 整数；总条目 ≤100。
- [Preview 聚合] product `POST /internal/products/skus/batch` 取每 SKU 快照（含 salable/price/spec/image/productName/status）；inventory `POST /internal/inventory/availability` 取可用量；addressId 非空时 member 内部端点取地址（不存在/非本人→地址项标记 invalid，不阻断预览本身）；逐项计算 status：OK / PRODUCT_OFF_SHELF / SKU_INVALID / NOT_FOUND / OUT_OF_STOCK / STOCK_LOW（available<quantity 即不可下单；available 1–9 标记低库存但不阻断）与 unitPriceInCents、subtotal、goodsAmount；响应 `availableToSubmit`（全部 OK 且地址有效且条目非空）。
- [Preview 边界] 不锁库存、不建单、不生成 orderNo；预览结果不持久化（或仅短 TTL 缓存，design 定，默认不缓存）；preview 成功且可下单时签发 submitToken（UUID，Redis `order:submit-token:{memberId}:{token}` TTL 10 分钟，载荷：source、items 指纹（skuId+quantity 排序哈希）、addressId）。
- [创建入参] `POST /api/mall/orders`：`{submitToken, addressId, source, items?}`；服务端校验：token 存在且属于该会员（Lua GETDEL 原子消费）、addressId 与令牌载荷一致（允许同会话换地址？——以载荷 addressId 为准；换地址需重新 preview 签新 token）、商品行与令牌指纹一致（防 token 内换货改量）。
- [创建重算] 再次 product batch + inventory availability 全量重查重算（preview 到 submit 之间价格/状态可能变化）：任一不可售/失效/库存不足→4xx 失败（此时令牌已消费，前端需重新 preview 获取新 token，错误响应明确指示）；金额以本次重查价计算。
- [锁定顺序] 先由 OrderNoGenerator 生成 orderNo；按 items 逐行调用 lock（reservationId=`orderNo:skuId`）；任一行失败（库存不足/503）→对已锁定行逐行 best-effort release（幂等，失败落 compensation_task），订单不存在，返回 B0404/依赖错误；库存服务不提供批量端点，循环调用（≤100 行可接受）。
- [落库] orders + order_item（商品快照：productId/skuId/productName/skuCode/specifications(JSON)/mainImageUrl/unitPriceFen/quantity/subtotalFen）+ 地址快照列（receiverName/receiverPhone/province/city/district/detailAddress/postalCode）+ 金额列 + status=PENDING_PAYMENT + version=0；order_status_history 首条（null→PENDING_PAYMENT, CREATE, memberId）；同事务提交。
- [锁后单失败补偿] 落库抛异常（DB 故障等）→ catch 后对全部 reservationId release；release 失败→写 compensation_task（businessType=ORDER_CREATE, businessId=orderNo, operation=INVENTORY_RELEASE, payload=reservationId 列表 JSON）；异常向上返回创建失败（不返回订单）。
- [创建幂等] Redis token 消费为第一层；DB orders.submit_token 与 member_id 联合唯一索引为第二层：唯一键冲突时按 submit_token 查询已存在订单并返回 200 + 该订单视图（同请求同响应，B0408 仅用于日志/响应头提示幂等命中）；不得产生第二单、第二次锁定。
- [购物车清理] 仅在创建成功响应返回后，由 mall-web 对 CART 来源订单调用既有 `POST /api/mall/cart/items/batch-delete`（body 为已购 skuId 列表）；清理失败不影响订单（可提示用户手动删除/下次购物车视图自然处理）；BUY_NOW 不动购物车。

### 4.3 REQ-M4-002 支付与取消规则

- [支付] `POST /api/mall/orders/{orderNo}/pay`：加载订单→不存在/非本人 404；状态=PAID→幂等成功（直接返回订单视图，不调用 confirm）；状态≠PENDING_PAYMENT→B0407（CANCELLED 单不能支付）；状态=PENDING_PAYMENT→CAS 迁移（写 paidAt、history PAY/operator=memberId）→成功后逐行 confirm（reservationId=`orderNo:skuId`，幂等）；confirm 任一失败→compensation_task（ORDER_PAY / INVENTORY_CONFIRM / orderNo），订单保持 PAID（语义：支付已成功，库存扣减待补偿），接口仍返回支付成功但内部告警；补偿任务成功后库存 DEDUCTED。
- [取消] `POST /api/mall/orders/{orderNo}/cancel`，body 可带 reason：非本人/不存在 404；CANCELLED→幂等成功返回；非 PENDING_PAYMENT→B0407（PAID 及以后不能普通取消）；CAS 迁移 CANCELLED（cancelledAt、history CANCEL/reason）→逐行 release（幂等）；release 失败落补偿任务（ORDER_CANCEL/INVENTORY_RELEASE），订单保持 CANCELLED。
- [并发竞争] Pay 线程与 Cancel 线程同时 CAS，仅一个影响行=1：获胜方执行库存副作用；失败方重读订单——pay 失败方读到 CANCELLED→返回 B0407（订单已取消，不能支付）；cancel 失败方读到 PAID→返回 B0407（订单已支付，不能取消）；绝不会出现 PAID+released 或 CANCELLED+deducted。
- [库存侧加固] mall-inventory：release 仅在 reservation.status=LOCKED 时迁移 RELEASED 并归还 locked/total 可用量（条件更新，影响行 0 即已处理，返回当前状态幂等结果）；confirm 仅在 LOCKED 时迁移 DEDUCTED 并同减 total/locked；stock 行更新带 `locked_quantity >= ?` 条件；重复请求返回 reservation 当前 status，调用方按 status 判断是否首次。
- [前端体验] 详情/待支付列表仅在 PENDING_PAYMENT 显示"立即支付/取消订单"；PAID 显示待发货；操作后重查详情；按钮提交中防重复点击（前端防抖，后端幂等兜底）。

### 4.4 REQ-M4-003 查询与履约规则

- [会员列表] `GET /api/mall/orders?status=&page=&size=&startAt=&endAt=`：强制 memberId 过滤；status 不传=全部；按 createdAt 倒序分页；列表项含 orderNo/status/goodsAmount/payAmount/商品行摘要（首图/名称/数量/行数）/createdAt/keyTimes。
- [会员详情] `GET /api/mall/orders/{orderNo}`：非本人 404；返回完整订单：金额明细、全部 order_item 快照、地址快照、物流信息、paidAt/cancelledAt/shippedAt/completedAt、cancelReason、statusHistory 升序。
- [状态 Tab 映射] 全部=不传；待支付=PENDING_PAYMENT；待发货=PAID；待收货=SHIPPED；已完成=COMPLETED；已取消=CANCELLED。
- [后台列表] `GET /api/admin/orders?orderNo=&memberId=&status=&page=&size=&startAt=&endAt=`：ADMIN + order:list；无归属过滤；支持订单号模糊/精确（精确前缀匹配）、时间范围。
- [后台详情] `GET /api/admin/orders/{orderNo}`：ADMIN + order:view，字段同会员详情（含会员 memberId）。
- [发货] `POST /api/admin/orders/{orderNo}/ship` `{deliveryCompany, trackingNo}`：ADMIN + order:ship；两字段必填非空、长度上限校验；订单 SHIPPED→幂等成功返回（不重复写历史）；非 PAID→B0407；PAID→CAS 迁移 SHIPPED（shippedAt、物流列、history SHIP/operator=admin username）。
- [确认收货] `POST /api/mall/orders/{orderNo}/confirm-receipt`：非本人 404；COMPLETED→幂等成功；非 SHIPPED→B0407；SHIPPED→CAS 迁移 COMPLETED（completedAt、history CONFIRM_RECEIPT/operator=memberId）。

### 4.5 REQ-M4-004 补偿与可观测规则

- [任务模型] compensation_task：id、businessType（ORDER_CREATE/ORDER_PAY/ORDER_CANCEL）、businessId（orderNo）、operation（INVENTORY_RELEASE/INVENTORY_CONFIRM）、payload（reservationId 列表 JSON）、status（PENDING/SUCCESS/FAILED_DEAD）、retryCount（0–5）、maxRetries=5、lastError、nextRetryAt、createdAt、updatedAt；(businessType,businessId,operation) 唯一键保证同一补偿不重复落任务（并发时复用）。
- [同步补偿] 锁后单失败、支付/取消后库存调用失败的第一反应是同步 best-effort 执行一次 release/confirm；失败立即落/更新 PENDING 任务（nextRetryAt=now+30s）。
- [有界重试] @Scheduled 固定速率（如 30s）扫描 status=PENDING AND nextRetryAt<=now，逐任务执行（按 id limit 分批）：成功→SUCCESS；失败→retryCount+1、lastError 截断、nextRetryAt=now+退避（30s,1m,2m,5m,10m）；retryCount>=5→FAILED_DEAD（仅日志告警，不丢弃记录）；执行按 operation 幂等（库存侧 CAS 保证）；任务本身用条件更新防多实例重复拾取（M4 单实例，仍写 `WHERE status='PENDING'` 条件）。
- [人工处理] `GET /api/admin/compensations?status=FAILED_DEAD`（ADMIN 内部权限码 order:compensation）查询；`POST /api/admin/compensations/{id}/retry` 重置 retryCount/nextRetryAt 立即重试；不建运维平台 UI（端点 + curl/后台后续接入即可，design 可决定是否在 mall-admin 放极简页面，默认仅端点）。
- [审计] 每次补偿尝试记日志（taskId/orderNo/operation/retryCount/result/error）；订单每次状态迁移有 history；日志不出现 password/token/secret/完整手机号地址（手机号可脱敏）。
- [可观测] 依赖调用失败、补偿落任务、FAILED_DEAD 产生 WARN/ERROR 级结构化日志与 traceId。

## 5. 全局验收标准

| ID | 验收标准（可测试） | 覆盖 |
| --- | --- | --- |
| AC-101 | MEMBER 从购物车（有选中项）调 preview → 200，商品行/最新整数分单价/库存可用量/地址(已选时)/goodsAmount=payAmount 全部来自服务端重查，无锁库存调用、无订单产生 | S1 |
| AC-102 | 立即购买 preview（source=BUY_NOW + items）→ 200 且只含传入 SKU；CART 来源时 body items 被忽略，以服务端选中项为准 | S1 |
| AC-103 | preview 时某商品下架/SKU 失效/库存不足/不存在 → 该行明确状态标识，availableToSubmit=false；product 或 inventory 503 → 预览 503/行级降级（按 design，默认依赖不可用不可下单） | S1 |
| AC-104 | 后台改价 100→120 后 preview，单价与金额按 120 计算（Gate 场景三） | S1 |
| AC-105 | addressId 不属于当前会员 → preview 地址项 invalid/创建时 B0405；未选地址不可提交 | S1/S2 |
| AC-106 | preview 成功返回一次性 submitToken；不携带 token 创建 → B0406；同一 token 双提交只产生 1 单、库存只锁一次，第二次返回同一订单视图（Gate 场景五） | S2 |
| AC-107 | 创建请求体携带篡改 price=0.01/totalAmount/payAmount → 被忽略，订单金额按 product 当前真实价格（Gate 场景四） | S2 |
| AC-108 | 库存充足创建成功：orders/order_item 快照完整（名称/规格/图/单价/数量/小计）、地址快照完整、PENDING_PAYMENT、history 有 CREATE、inventory reservation 全 LOCKED、orderNo 全局唯一且非自增 ID | S2 |
| AC-109 | available=1 提交 quantity=2 → 创建失败 B0404、无订单残留、库存不为负（Gate 场景二）；多行中第 N 行锁失败 → 前 N-1 行 reservation 最终 RELEASED | S2 |
| AC-110 | 创建成功后 CART 来源订单的已购选中项被前端调 batch-delete 清理；创建失败时购物车不变 | S2 |
| AC-111 | BUY_NOW 下单不改变购物车 | S2 |
| AC-112 | 待支付订单 pay 成功：CAS PENDING_PAYMENT→PAID、paidAt、history(PAY)、reservation 全 DEDUCTED、库存 total 与 locked 同减 | S3 |
| AC-113 | 重复 pay 同一订单 2 次：订单保持 PAID、confirm 只生效一次、库存只扣一次（Gate 场景六） | S3 |
| AC-114 | CANCELLED 订单 pay → B0407；他人订单 pay → 404 | S3 |
| AC-115 | 待支付订单 cancel：CAS→CANCELLED、cancelledAt/reason、history、reservation RELEASED、可用库存归还 | S3 |
| AC-116 | 重复 cancel 2 次：幂等成功、库存只释放一次（Gate 场景七）；PAID/SHIPPED/COMPLETED 单 cancel → B0407；他人单 404 | S3 |
| AC-117 | Pay||Cancel 并发压测（同一单多线程）：最终仅 PAID 或 CANCELLED 之一；PAID 必库存 DEDUCTED、CANCELLED 必库存 RELEASED，无撕裂（Gate 场景八） | S3 |
| AC-118 | mall-inventory 对同一 reservationId 重复 release/confirm 返回当前状态且库存数量不重复变化（条件更新验证） | S3/S7 |
| AC-119 | 会员订单列表分页/状态 Tab/时间范围正确，仅返回本人订单；详情含快照/金额/时间/物流/history；Member A 查 Member B 订单 → 404（Gate 场景九） | S4 |
| AC-120 | admin 列表多条件检索 + 详情成功，受 RBAC 保护（无权限 403）；MEMBER 访问 /api/admin/** → 403 | S6 |
| AC-121 | PAID 订单 ship 成功 → SHIPPED、物流字段/shippedAt/history(SHIP, admin)；PENDING_PAYMENT/CANCELLED 发货 → B0407；重复 ship 幂等不重复写历史 | S6 |
| AC-122 | 本人 SHIPPED 单 confirm-receipt → COMPLETED + completedAt + history；未发货确认 → B0407；他人确认 → 404；重复确认幂等 | S5 |
| AC-123 | 模拟 Lock 成功 + 订单持久化失败：同步触发 release；若 release 也失败则生成 PENDING compensation_task，调度重试至 SUCCESS，reservation 最终 RELEASED（Gate 场景十/A） | S7 |
| AC-124 | 取消时 release 首次失败 → 落补偿任务，重试后释放成功（场景 B）；支付重复处理不重复扣减（场景 C）；取消重复不重复释放（场景 D） | S7/S3 |
| AC-125 | 补偿任务超 5 次 → FAILED_DEAD 可经 admin 端点查询并人工 retry 重置执行；重试有退避不无限循环 | S7 |
| AC-126 | 关键失败日志可用 orderNo+traceId 定位（场景 E），日志不含 token/secret/明文敏感信息；每次状态迁移均有 history | S7 |
| AC-127 | 完整成功交易 E2E：登录→加购→preview→选地址→下单→锁库存→pay→扣减→admin 发货→确认收货→COMPLETED 全链路通过（Gate 场景一） | 全量 |
| AC-128 | 全流程后任意 SKU 库存 available≥0；mall-order 代码审计无跨服务 SQL/直改他库表；internal 路径网关不可达（404） | 红线 |
| AC-129 | mall-web 结算页/订单列表/详情、mall-admin 订单管理/发货页面真实联调可用；type-check/lint/test/build 全绿 | 前端 |
| AC-130 | mall-order 单测（状态机/金额/orderNo/并发 CAS 解读）+ 集成测试（H2 + mock rest client / Testcontainers）通过，覆盖十场景 | 测试 |

## 6. 非功能需求

- 性能：preview/创建（≤100 行，顺序内部调用）P95 < 800ms；订单列表 P95 < 300ms；pay/cancel/ship/confirm P95 < 500ms。
- 可靠性：同步链路失败必有补偿或明确错误返回；库存零泄漏、不超卖；补偿任务有界且幂等；M4 接受单实例调度。
- 安全：MEMBER/ADMIN/SERVICE 三身份隔离；归属校验；internal token；价格零信任；越权 404；操作留痕。
- 可观测：traceId 贯通网关→order→内部调用；交易关键事件与补偿全生命周期结构化日志。
- 兼容：库存/商品/member 内部契约变更保持向后兼容（仅新增 member 端点、inventory 条件更新不改响应契约）。

## 7. 成功指标

- M4 Integration Gate 十场景全部 PASS 并形成 change 级 evidence（含并发场景压测记录与库存对账）。
- 重复下单/支付/取消造成的重复副作用为 0；联调期间库存永久悬挂为 0。
- mall-order 自动化测试与前端三检（type-check/lint/test + build）通过率 100%；核心交易链路浏览器 E2E 走通。
