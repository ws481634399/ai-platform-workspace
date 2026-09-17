---
story-id: "STORY-004-01-01-02"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S2]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3/§4.2 + requirement-design.md §2
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-01-01-02 订单创建与库存锁定
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`（S2）
- 状态流转: specified → specified（本文件细化）

## 1. Story 目标

交付正式下单：消费一次性 submitToken，服务端二次重查商品/价格/库存并校验地址归属，生成全局唯一 orderNo，逐行锁定库存（任一失败整体失败并释放已锁行），在 mall_order 库持久化订单/订单项商品快照/地址快照/金额快照与 CREATE 状态历史，订单进入 PENDING_PAYMENT；双击/重试双层幂等只产生一单一锁；成功后由 mall-web 清理购物车选中项。

## 2. Scope（范围）

### 2.1 包含

- [S2] Flyway V1 建表 orders / order_item / order_status_history（compensation_task 在 STORY-004-04-01-01 追加 V2）。
- [S2] Order 聚合 + OrderItem + ReceiverSnapshot + OrderStatusHistory 领域模型；OrderNoGenerator（ORD+时间序+雪花尾数）；OrderRepository（insert + CAS 迁移方法一次备齐，本 Story 用 insert）。
- [S2] OrderCreateService 编排：令牌 GETDEL 消费 → 载荷校验（addressId/行指纹）→ 二次重查重算 → availability 预检 → 生成 orderNo → 逐行 lock（reservationId=`orderNo:skuId`）→ 失败释放已锁 → 同事务落库 + CREATE history → 返回。
- [S2] 创建幂等：Redis 令牌第一层 + DB `(member_id,submit_token)` 唯一索引第二层，唯一键冲突查回首单同响应。
- [S2] `POST /api/mall/orders`；网关 mall-order 会员/admin 路由 + MEMBER 安全匹配。
- [S2] mall-web DU-FE-901：CheckoutView 结算确认页（preview 展示/地址选择/提交）、购物车"去结算"与商品详情"立即购买"接线、创建成功 CART 来源调 cart batch-delete 后跳详情。

### 2.2 不包含

- pay/cancel/ship/confirmReceipt（后续 Story）；compensation_task 落表（本 Story 锁后单失败先做同步 best-effort release；release 失败仅 ERROR 日志，STORY-004-04-01-01 补任务落表与重试）；我的订单/详情页（STORY-004-03-01-01）。

## 3. 业务规则

- 令牌：GETDEL 不存在/不属当前会员 → B0406；载荷 addressId 与请求一致、items 指纹与请求一致（防换货改量）；不一致 → B0406（前端重新 preview）。
- 二次重查：商品不可售/SKU 失效/不存在 → B0402/B0403；库存 available<quantity → B0404；地址非归属 → B0405；任一失败不锁任何库存（availability 预检在 lock 前）。
- 金额完全以本次 product 重查 salePriceInCents 计算；请求体任何金额字段忽略；M4 payAmount=goodsAmount。
- 锁定：逐行 POST /internal/inventory/lock；任一行失败（B0404 不足或 503）→ 对已锁行逐行 release（幂等 best-effort），整体返回失败，无订单。
- 落库：同事务 insert orders(PENDING_PAYMENT,version=0)、order_item 全快照、history(null→PENDING_PAYMENT,CREATE)；落库异常 → catch 全量 release 后抛出创建失败。
- 幂等：同 submitToken 并发越过 Redis 时 uk_member_submit_token 冲突 → 按 token 查订单返回 200 同视图；第二单不产生、第二次锁定不发生（reservationId 与 orderNo 绑定，首单复用）。
- orderNo：ORD+yyyyMMddHHmmssSSS+4 位序列，唯一索引保障；不为自增主键、不含 memberId。
- 购物车清理：仅创建成功后前端发起；BUY_NOW 不清理；清理失败不改变订单成功结果。

## 4. 接口与字段规格

- `POST /api/mall/orders`（MEMBER）：`{submitToken, addressId:string, source:"CART"|"BUY_NOW", items?:[{skuId:string,quantity:int}]}` → 200 OrderDetailView（形状同 requirement-design §4 OrderView/Detail）。
- 错误：400 行/数量非法；404 地址（B0405 地址无效按 400/404 映射，design 定 400 ADDRESS_INVALID）；409/400 库存不足 B0404、不可售 B0402；409 令牌 B0406；503 依赖。
- 网关：/api/mall/orders/** → 8105 MEMBER；/api/admin/orders/** → 8105 ADMIN（本 Story 仅配置，admin 端点后 Story 实现）。
- 消费内部端点：inventory /lock /release；product skus/batch；member 地址；cart 不经后端（前端直连 cart API 清理）。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 无 token/伪造/他人 token/重复使用 token → B0406；同 token 双提交仅 1 单、库存仅锁定一次，两次响应同 orderNo |
| AC-002 | 请求 addressId 或 items 与令牌载荷不一致 → B0406 |
| AC-003 | 请求携带 price=0.01/totalAmount/payAmount → 全部忽略，订单金额按 product 重查价 |
| AC-004 | 地址非本人/不存在 → 创建失败且无锁定 |
| AC-005 | 库存充足：订单 PENDING_PAYMENT、order_item 快照完整、地址快照完整、金额不变量成立、history 有 CREATE、reservation 全 LOCKED、orderNo 唯一且非主键暴露 |
| AC-006 | available=1 quantity=2 → B0404，无订单、库存不为负、无 reservation 悬挂 |
| AC-007 | 多行中第 N 行锁失败 → 前 N-1 行最终 RELEASED，整体失败无订单 |
| AC-008 | 全部锁定后模拟落库失败 → 已锁 reservation 被同步 release，接口返回创建失败 |
| AC-009 | CART 单成功后前端调用 batch-delete 清除已购选中项；BUY_NOW 单不动购物车；创建失败购物车不变 |
| AC-010 | 网关：MEMBER 经 8080 可访问 /api/mall/orders；未认证 401；/api/internal/** 经网关 404 |
| AC-011 | mall-web CheckoutView：preview 展示/选地址/不可下单阻断/提交防双击/成功跳详情，两入口可达；type-check/lint/test/build 通过 |
