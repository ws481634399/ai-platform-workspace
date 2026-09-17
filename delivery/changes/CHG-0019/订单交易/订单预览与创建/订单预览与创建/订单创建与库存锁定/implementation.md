# Implementation（跨仓实施汇总）— 订单创建与库存锁定 STORY-004-01-01-02

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0019（M4 订单交易闭环）
- Story：STORY-004-01-01-02 订单创建与库存锁定
- 实施日期：2026-09-17

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-902 | repo-1 | 服务端二次核价/行指纹校验/逐行锁库/订单聚合落库/锁后失败同步释放/CART 购物车清理；OrderApiTest 17/17 |
| DU-FE-901 | repo-2 | mall-web 结算页与双入口（购物车去结算/商品详情立即购买）；test 90/90、build 成功 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| a06ed4c | DU-BE-902 | repo-1 | feat(order): M4 订单交易闭环（建单/锁库/购物车清理内部端点） |
| 22ad40f | DU-FE-901 | repo-2 | feat(order): M4 前台结算/订单中心与后台履约（结算页与双入口） |

## 3. 各仓实施引用

- repo-1（DU-BE-901 已交付的 mall-order 骨架之上）：
  - `OrderCreateService`：消费 submitToken（Redis 原子 DEL 单消费）→ 令牌载荷 source/addressId/行指纹与请求逐行比对（quantity/SKU 集合）→ product batch 二次核价（请求中任何金额一律不采信）→ member 地址归属再校验 → inventory 逐行 lock（顺序锁定，任一行失败即对已锁行同步 release；release 再失败登记补偿，见 STORY-004-04）
  - 订单聚合：`Order`/`OrderItem`/`ReceiverSnapshot`/`OrderStatusHistory`，金额不变量 goods=Σsubtotal、pay=goods+freight-discount；雪花 ID 经 @StringId 序列化为字符串；`SnowflakeOrderNoGenerator` 生成对外 orderNo（不暴露主键）
  - 持久化：order/order_item/order_status_history V1 落库（金额分 BIGINT、快照列 NOT NULL）；orderNo 在构造 OrderItem 时由聚合透传
  - 成功后置：CART 源调 mall-cart 内部 batch-delete 清除已购选中项；BUY_NOW 不动购物车；建单失败购物车不变
  - 错误码：B0406 submitToken（无/伪造/他人/载荷漂移/重复使用）、B0404 库存不足（409）、B0401 订单/地址（404）
- repo-2：
  - CheckoutView：预览行红显 issueCodes、地址单选（默认 defaultId）、availableToSubmit 阻断提交、提交按钮防双击、成功 router.replace 到 `/orders/{orderNo}`、失败重新预览重签 token
  - 入口：CartView「去结算」（勾选数 0 禁用）→ `/checkout?source=CART`；ProductDetailView「立即购买」→ `/checkout?source=BUY_NOW`（未登录跳登录带回跳）
  - checkout store（source/buyNowItems）、order 类型/API 契约（preview/create）

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | submitToken 缺失/伪造/复用 B0406；同 token 双提交仅 1 单、锁 1 次、同 orderNo | passed（tamperedFingerprintRejected/duplicateSubmitRejected + Redis DEL 原子消费） |
| AC-002 | addressId/items 与令牌载荷漂移 B0406 | passed（tamperedFingerprintRejected） |
| AC-003 | 请求携带 price/totalAmount/payAmount 全部忽略，服务端重算 | passed（priceChangedBetweenPreviewAndCreate：预览后调价按下单价取最新） |
| AC-004 | 地址非本人/不存在失败且无锁定 | passed（previewAddressNotOwned 覆盖归属；create 前再次校验） |
| AC-005 | 成功：PENDING_PAYMENT、item/address 快照、金额不变量、history(CREATE)、reservation LOCKED、orderNo | passed（fullHappyPath 全链路断言） |
| AC-006 | available=1 quantity=2 → 409 B0404，无订单/无负库存/无悬挂预留 | passed（insufficientStockOnCreate） |
| AC-007 | 第 N 行锁失败 → 前 N-1 行最终 RELEASED，整体失败无订单 | passed（lockMidwayFailureReleasesAndCompensates 前半） |
| AC-008 | 全锁后落库失败 → 同步 release，接口失败 | passed（同用例 release 断言 reservation RELEASED） |
| AC-009 | CART 成功清购物车选中项；BUY_NOW 不清；失败车不变 | passed（cartSourceClearsPurchasedItems + checkout store 仅 CART loadMemberCart） |
| AC-010 | 网关 MEMBER 8080 可访问 /api/mall/orders；未认证 401；/api/internal 404 | passed（authBoundaries + gateway 路由回归） |
| AC-011 | CheckoutView 预览/选地址/阻断/防双击/跳详情、双入口可达、前端四门全绿 | passed（pnpm test 90/90、type-check/lint/build 0 error） |
