---
story-id: "STORY-004-01-01-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S1]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3/§4.2 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-01-01-01 订单预览
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`（S1）
- 状态流转: pending → specified

## 1. Story 目标

从零建成 mall-order 服务工程骨架（安全/配置/分层/通用领域基础），交付 Checkout Preview：会员从购物车选中项或立即购买进入确认页时，服务端重新聚合商品可售状态、当前整数分价格、库存可用量与收货地址，逐项标注不可下单原因、服务端重算金额；预览不锁库存、不建单；可下单时签发一次性 submitToken。同步交付 mall-member 内部地址查询端点。

## 2. Scope（范围）

### 2.1 包含

- [S1] mall-order 骨架：pom 补 security/oauth2/redis；application.yml（MySQL mall_order/Redis/JWT/internal/四下游 URI）；OrderSecurityConfiguration（internal SERVICE、/api/mall MEMBER、/api/admin ADMIN）；通用 OrderErrorCode(B04xx)、Money 值对象、@StringId DTO 基类约定；Flyway 目录就位（本 Story 不建订单表，仅校验服务启动）。
- [S1] 四出站端口 + Rest 实现：ProductSkuPort（skus/batch）、InventoryPort（availability；lock/release/confirm 接口本 Story 定义、下 Story 接线使用）、MemberAddressPort（地址内部端点）、CartSelectionPort（selected-items）；统一 UnifyResult 解包、503 归一。
- [S1] mall-member 新增 `GET /api/internal/members/{memberId}/addresses/{addressId}`（SERVICE），复用 findByIdForMember 归属双条件。
- [S1] `POST /api/mall/orders/preview`：source=CART|BUY_NOW 两入参形态；服务端重查重算；响应 PreviewView（items 行状态 + 金额 + availableToSubmit + submitToken）。
- [S1] RedisSubmitTokenStore：可下单 preview 签发 UUID 令牌（TTL 10 分钟，载荷 source/addressId/行指纹），消费（GETDEL）方法供下 Story 使用。

### 2.2 不包含

- 订单创建/锁库存/订单表/orderNo（STORY-004-01-01-02）；支付取消/发货/收货（后续 Story）；补偿任务（STORY-004-04-01-01）；结算确认页前端（DU-FE-901 随创建 Story 交付，本 Story 用 API 测试验证）。

## 3. 业务规则

- 预览是只读操作：不锁库存、不建单、不生成 orderNo、不产生任何库存 reservation 调用（仅 availability 查询）。
- CART 来源：忽略 body items，经 cart 内部端点取选中项；选中项为空 → items=[]、availableToSubmit=false。
- BUY_NOW：items=[{skuId,quantity}]，quantity 1–999、条目 ≤100；非法 → 400。
- 每 SKU 经 product batch 重查：salable=false（含不存在占位、商品下架、SKU 禁用）→ issueCode PRODUCT_NOT_SALABLE/SKU_INVALID/NOT_FOUND；inventory availability：available<quantity → OUT_OF_STOCK（不可下单），1≤available<10 → LOW_STOCK（可下单仅提示）。
- 金额：unitPriceFen=salePriceInCents；subtotal=单价×数量；goodsAmount=Σ 可售行 subtotal（不可售行金额仍展示但不计入？——统一：所有有有效单价的行参与合计，availableToSubmit 独立表达能否下单；payAmount=goodsAmount，discount/freight=0）。
- addressId 非空：member 端点查地址；不存在/非本人 → 地址项标记 invalid + issueCode ADDRESS_INVALID，availableToSubmit=false；addressId 为空 → address=null、availableToSubmit=false。
- availableToSubmit = 条目非空 且 每一行无 issue 且地址有效。
- product/inventory/cart/member 依赖 5xx/超时 → 503 DEPENDENCY_UNAVAILABLE（不猜测、不降级为可下单）。
- memberId 只取自 SecurityContext；内部端点用路径 memberId + token 鉴权。

## 4. 接口与字段规格

- `POST /api/mall/orders/preview`（MEMBER）
  - req：`{source:"CART"|"BUY_NOW", addressId?:string, items?:[{skuId:string,quantity:int}]}`
  - resp PreviewView：`{submitToken:string|null, address:{id,receiverName,receiverPhone,province,city,district,detailAddress,postalCode,isDefault}|null, items:[{skuId,productId,productName,skuCode,specifications:Record<string,string>,mainImageUrl,quantity,unitPriceFen,subtotalFen,stockStatus:"OK"|"LOW"|"OUT_OF_STOCK"|"UNKNOWN", issueCodes:string[]}], goodsAmountFen:long, discountAmountFen:0, freightAmountFen:0, payAmountFen:long, availableToSubmit:boolean}`
  - 错误：401 未认证；400 入参非法（source/items）；503 依赖不可用。
- `GET /api/internal/members/{memberId}/addresses/{addressId}`（SERVICE，新增于 mall-member）→ AddressInternalView 全字段；不命中 → UnifyResult 失败 ADDRESS_NOT_FOUND（404）。
- 既有消费：POST /api/internal/products/skus/batch；POST /api/internal/inventory/availability；GET /api/internal/carts/members/{memberId}/selected-items。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | CART 预览：选中项被服务端拉取并逐行返回当前快照价/库存状态；body 伪造 items 被忽略；无锁库存调用、无订单产生 |
| AC-002 | BUY_NOW 预览：只含传入 SKU；quantity 0/负/非整数/≥1000 → 400；条目 101 → 400 |
| AC-003 | 下架商品/SKU 失效/不存在 → issueCodes 明确，availableToSubmit=false |
| AC-004 | available=1 quantity=2 → OUT_OF_STOCK 不可下单；available 1–9 → LOW_STOCK 但可下单；available≥10 → OK |
| AC-005 | 后台改价后预览按最新价计算小计与总额；篡改无影响（请求无金额字段，响应金额来自服务端） |
| AC-006 | addressId 非本人/不存在 → 地址 invalid 且不可下单；addressId 为空 → address=null 不可下单；有效地址返回完整快照 |
| AC-007 | availableToSubmit=true 时返回 submitToken（Redis 可查 TTL≤600s 且载荷含 source/addressId/行指纹）；不可下单时 submitToken=null |
| AC-008 | product/inventory/cart/member 任一依赖故障 → 503 ORDER_DEPENDENCY_UNAVAILABLE，不返回可下单 |
| AC-009 | 未认证 401；MEMBER 才能访问；member 内部地址端点无 token 401/有 token 非归属 404 |
| AC-010 | mall-order 工程骨架可启动（安全链/MyBatis-Plus/Flyway/Redis 配置就绪），common-test 下 smoke + preview API 测试通过 |
