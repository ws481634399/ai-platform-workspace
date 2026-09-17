# Exploration（需求探索报告）

> 阶段：sdd-explore 产物
> 业界锚点：Discovery（Problem → Evidence → Conflict → Recommendation）
> 输入：requirement.md（原文沉淀；本文件不复述原文，只做分析）
> 产出状态：exploring（推进 Change 状态）

## 1. 需求要点

- 做什么：新建 **mall-order** 服务（8105 / 库 mall_order，当前为空骨架），交付平台第一条完整核心交易闭环——Checkout Preview → 服务端重算 → 锁库存建单 → Mock 支付/取消 → 后台发货 → 确认收货 → COMPLETED，并配套创建失败补偿、有界重试、全链路幂等、订单状态历史与审计可观测；mall-web 交付结算确认页/我的订单/订单详情，mall-admin 交付订单管理与发货。
- 给谁：MEMBER（预览/下单/支付/取消/查询/确认收货，只能操作本人订单）、ADMIN（后台查询/发货，受 RBAC 约束但不能绕过领域状态规则）、SERVICE（内部服务身份，X-Internal-Token）。
- 解决什么问题：把 M1（可信身份）、M2（商品/价格/库存权威与锁放扣）、M3（会员/地址/购物车）串成"真正买下商品"的交易事实，同时守住四条不可逾越的语义：
  1. **Order ≠ Product/Inventory/Payment Gateway**：订单服务不跨库直查、不直接改商品/库存表，一切跨服务交互走 Internal API（RestClient + X-Internal-Token）；
  2. **价格只信服务端**：前端任何 price/totalAmount/payAmount 字段一律忽略，成交价以创建瞬间 mall-product 重查的 salePriceInCents 为准并落快照；
  3. **状态集中管理**：唯一 Order 聚合状态机，禁止任何位置直接 setStatus；所有迁移 CAS 条件更新 + 状态历史；
  4. **M4 只做同步可靠**：幂等 + 补偿任务 + 有界重试，不引入 RocketMQ/Outbox/延迟消息/Seata（明确留给 M7）。
- 隐含需求（设计必须回答）：
  - **金额单位**：需求原文写 BigDecimal，但项目既有全局约定是**整数分 Long**（product/inventory/cart 全部 salePriceInCents），M4 采用整数分 Long（禁止用 float/double，语义等价于"精确金额"），goodsAmount/payAmount 均为分；M4 无优惠无运费，`payAmount = goodsAmount`，但表结构预留 discountAmount/freightAmount 字段（默认 0）；
  - **Preview 入参形态**：购物车入口传 `source=CART`（服务端拉选中项），立即购买传 `source=BUY_NOW + items[{skuId,quantity}]`；两种入口都必须服务端重查，不信任购物车缓存里的价格/名称；预览响应逐项带 salable/库存状态/最新价/小计与不可下单原因，整车可下单标志；
  - **Submit Token 方案**：进入确认页（preview 成功）时由服务端签发一次性下单令牌（Redis key `order:submit-token:{memberId}:{token}`，短 TTM 10 分钟，载荷=来源与商品行指纹），创建订单时校验并删除（Lua 原子消费）；DB orders 表再对 `(member_id, submit_token)` 建唯一索引兜底——双击时第二个请求唯一键冲突，查询并返回首单结果（同参数同响应）；
  - **reservationId 稳定性**：`orderNo + ":" + skuId` 在订单号生成后确定；但锁定发生在订单持久化之前，因此锁定时先生成 orderNo（OrderNoGenerator 时间序+雪花后缀，全局唯一），锁与单共用同一 orderNo；任何一行 lock 失败 → 已锁行全部 release 补偿，不产生订单；
  - **锁成功单失败**：同事务内保存失败理论上罕见（MySQL 单库），必须 catch 后对全部已锁 reservationId 同步 release；release 再失败 → 落 compensation_task 并由调度器有界重试；
  - **支付/取消并发的核心手法**：`UPDATE orders SET status=?, version=version+1 WHERE id=? AND status='PENDING_PAYMENT' AND version=?`（或仅 status 条件），影响行数=0 即竞争失败方，重新加载订单按当前状态做幂等解读（已 PAID 再 pay→幂等成功返回；已 CANCELLED 再 pay→业务错误）；**获胜方先做状态迁移，再做库存调用**——pay 获胜：迁移 PAID 后 confirm，confirm 失败则订单停留 PAID 并落补偿任务（库存仍 LOCKED，对账可恢复，绝不能回滚订单状态又让 cancel 重复释放）；cancel 获胜：迁移 CANCELLED 后 release，失败同理落补偿；
  - **库存侧加固**：mall-inventory 当前 release/confirm 用 updateById 无状态条件，M4 需补 `WHERE id=? AND locked_quantity>=?`（release）与 reservation 状态条件更新 LOCKED→RELEASED/DEDUCTED（CAS），从根上保证重复请求不重复加/扣库存；
  - **地址内部端点**：mall-member 现仅有 provision 内部端点，需新增 `GET /api/internal/members/{memberId}/addresses/{addressId}`（SERVICE 角色），复用 `findByIdForMember` 做归属校验，查不到返回 404 业务结果而非 500；
  - **购物车清理归属**：订单创建成功后由 mall-web 调既有 `POST /api/mall/cart/items/batch-delete`（按已购 skuId 列表）清理，创建失败不清理；不在 mall-order→mall-cart 新增反向依赖（M4 同步阶段最简且语义正确）；
  - **网关**：mall-gateway 需新增 mall-order 路由——`/api/mall/orders/**` 需 MEMBER、`/api/admin/orders/**` 需 ADMIN；`/api/internal/**` 一律 denyAll（404），内部调用走服务直连端口不经网关；
  - **越权响应码**：会员访问他人订单统一 404（不泄露存在性）；非本人支付/取消/确认收货同样 404；admin 侧不存在归属概念但受 RBAC；
  - **雪花 ID**：order/order_item 主键用 MyBatis-Plus ASSIGN_ID，API 经 @StringId 以字符串传输；orderNo 为独立业务编号（建议 `yyyyMMddHHmmss + 4位序列/雪花后缀`，纯数字字符串、全局唯一、可查）；
  - **可观测**：所有交易关键路径打 orderNo+reservationId+traceId；compensation_task 状态流转有日志与指标级日志（M4 不接监控平台）；不记录密码/令牌/密钥。

知识检索结果（引用来源）：

- M4.md 全文：REQ-M4-001 十六章 + 17 条验收、REQ-M4-002 十二章 + 14 条验收、REQ-M4-003 十二章 + 17 条验收、REQ-M4-004 十三章 + 场景 A~E、M4 Integration Gate 十场景、DoD 清单与阶段验收。
- 代码调研结论（本 Change explore 实测）：
  - `mall-services/mall-order`：纯空骨架（Application + smoke test + yml + 空 migration 目录），pom 缺 mall-common-security/oauth2-resource-server，yml 缺 JWT/internal/下游 URI；DDD 从零建模。
  - `mall-services/mall-inventory`：内部端点 `/api/internal/inventory` 的 lock/release/confirm/availability 已交付且按 reservationId 幂等；单 SKU 粒度无批量端点，多商品由 order 循环；release/confirm 回写无版本条件（本 Change 加固）。
  - `mall-services/mall-product`：`POST /api/internal/products/skus/batch` 每个入参必返回一项（含 salable/salePriceInCents/specifications/mainImageUrl），查不到占位 salable=false；另有单 SKU 快照端点。
  - `mall-services/mall-member`：仅 provision 内部端点；shipping_address 表主键为 AUTO_INCREMENT（非雪花），Repository 已有 findByIdForMember 可复用，需新增内部查询端点。
  - `mall-services/mall-cart`：已有 `GET /api/internal/carts/members/{memberId}/selected-items`；写接口 batch-delete 可供前端清理；跨服务 RestClient 样板（ProductSkuClient/RestInventoryAvailabilityClient、UnifyResult 解包、503 归一）可直接照搬到 mall-order。
  - `mall-gateway`：纯 yml 路由，无 8105 路由；internal 路径 denyAll。
  - common：UnifyResult/BusinessException/ErrorCode/GlobalExceptionHandler/SecurityContextFacade 齐备；错误码段位 order 取 B04xx（cart B03xx、product B21xx、inventory B22xx）。
- 历史 Change：CHG-0015（内部凭证/网关）、CHG-0017（商城批量商品/库存聚合）、CHG-0018（购物车选中项与 batch-delete）直接构成本 Change 前置。

## 2. Story 归属判定

- Feature ID: FEAT-004（新建 Module：订单交易），含 4 个 L2 功能组对应 4 个 REQ。
- Story 节点（feature-tree.yaml 已新建 6 个，全部纳入本 Change）：
  - STORY-004-01-01-01 **订单预览**（FEAT-004-01-01，对应 REQ-M4-001 前半）：两种入口的 Checkout Preview 聚合与服务端重算、不可下单标识；mall-web 结算确认页（地址选择/商品行/金额/提交令牌）；含 mall-member 内部地址端点。
  - STORY-004-01-01-02 **订单创建与库存锁定**（对应 REQ-M4-001 后半）：Order/OrderItem/快照/金额/orderNo、Flyway 建表、submit-token 幂等、逐行 lock 与锁失败释放、PENDING_PAYMENT 落单、状态历史首条、网关路由；mall-web 提交接线与成功后清购物车。
  - STORY-004-02-01-01 **模拟支付与订单取消**（FEAT-004-02-01，REQ-M4-002）：集中状态机、pay/cancel CAS 并发防护、inventory confirm/release 调用与库存侧原子条件加固、状态历史、幂等解读；mall-web 支付/取消操作。
  - STORY-004-03-01-01 **会员订单列表与详情**（FEAT-004-03-01，REQ-M4-003 查询侧）：会员分页/状态 Tab/时间筛选、详情聚合（快照+金额+历史）、归属 404；mall-web 我的订单列表/详情页。
  - STORY-004-03-01-02 **确认收货**（同域）：SHIPPED→COMPLETED 领域行为、本人校验、completedAt；mall-web 详情页按钮。
  - STORY-004-03-02-01 **后台订单查询与发货**（FEAT-004-03-02，REQ-M4-003 admin 侧）：admin 列表/搜索/详情、PAID→SHIPPED 发货与物流信息；mall-admin 订单管理页（含动态菜单/权限码接入既有 RBAC 体系）。
  - STORY-004-04-01-01 **交易异常补偿与幂等加固**（FEAT-004-04-01，REQ-M4-004）：compensation_task 表与领域服务、锁后单失败同步补偿、有界指数退避调度、FAILED_DEAD 人工查询/重试内部端点、审计日志；支付/取消后库存调用失败的补偿入口也在此 Story 接通。
- 是否新建 candidate: 否（6 个 Story 均为 REQ 明确范围，feature-tree 已 materialize）。
- Feature 路径: 订单交易 → 订单预览与创建/支付与取消/订单查询与履约/交易异常与补偿 → 对应 Story。
- Integration Gate 十场景不单独建 Story，作为 change 级 test-design/converge 的验收场景统一执行。

## 3. 证据评估

- 业务依据：M4.md 4 组验收（17+14+17+场景A~E）+ Integration Gate 十场景 + DoD 清单，行为边界完整无歧义。
- 领域依据：M2 已交付库存锁定/释放/确认扣减（reservationId 幂等、防超卖原子 SQL）与商品内部快照契约；M3 已交付地址归属校验模型与购物车选中项；M1 已交付 MEMBER/ADMIN/SERVICE 三类主体与网关 RS256 验签。
- 工程依据：mall-cart 已验证同一套技术形态（RestClient 内部调用 + JWT 资源服务器 + Redis + MyBatis-Plus + H2/Testcontainers 测试样板），mall-order 可同构复制；本地 MySQL/Redis/Nacos 基础设施在运（8102/8103/8104/8106 均已实跑）。
- 结论: 充分。无阻断性未知；两个已知技术债（inventory release/confirm 无 CAS、member 无地址内部端点）已纳入本 Change 范围。

## 4. 冲突点检测

- 与 specs 冲突: 无。需求原文"BigDecimal"与项目"整数分 Long"约定的差异按项目约定执行（整数分本身即为精确金额，满足禁止 float/double 的本意），在 PRD 显式声明。
- 与既有 Change 重叠或沿用:
  - 库存锁/放/扣能力已在 CHG-0013 交付，本 Change 只做**消费方 + 库存侧 CAS 加固**，不重写库存领域；
  - 商品批量查询契约沿用 CHG-0012/0017 的 internal SkuBatchItemView，不新建商品查询接口；
  - 地址内部端点是 mall-member 的增量（新增一个 controller 方法 + 无新表），归属 Story 1 但 DU 独立标注 mall-member 仓内改动；
  - 购物车不改后端（选中项查询与 batch-delete 均已存在），仅前端接线。
- 与已规划 Story 重复: 无（FEAT-004 为全新分支）。
- 处理决策:
  - 4 个 REQ 拆 6 个 Story（001 拆预览/创建、003 拆会员查询/确认收货/后台履约为 3 个 Story），理由：预览读模型与创建写模型验收点不同；履约三动作（列表/收货/发货）权限身份与前端应用不同（mall-web vs mall-admin）。
  - 004 不单列"库存加固"Story：CAS 加固随 STORY-004-02-01-01 一起改（支付取消竞争场景强依赖），补偿任务体系在 STORY-004-04-01-01。

## 5. 待澄清问题

- 以下决策基于需求授权（"具体由 Design 决定"）与项目既有约定，PRD/Design 直接定稿，不再人工澄清：
  1. 金额整数分 Long、表预留 freight_amount/discount_amount 默认 0；
  2. Submit Token = Redis 一次性令牌（10 分钟 TTL）+ DB (member_id, submit_token) 唯一索引双层幂等；
  3. orderNo = `ORD + yyyyMMddHHmmssSSS + 4位雪花尾数`（或时间序+雪花后缀），全局唯一纯数字/字母数字业务号；
  4. reservationId = `orderNo:skuId`；
  5. 并发：状态迁移 CAS 先行、库存调用后置，库存后置失败落 compensation_task，订单状态不回滚；
  6. 重试：固定退避基准 30s 起指数退避（30s/1m/2m/5m/10m），最多 5 次，其后 FAILED_DEAD；@Scheduled 调度（单实例足够，M7 再考虑分布式调度）；
  7. 越权统一 404；内部调用失败统一归一 503（沿用 cart 样板）；
  8. 错误码段 B04xx；
  9. 购物车清理由前端在创建成功后执行；
  10. mall-admin 订单菜单/权限码：order:list / order:view / order:ship，经后台菜单表配置（dev 阶段 SQL 初始化或 bootstrap 方式，design 定稿）。
