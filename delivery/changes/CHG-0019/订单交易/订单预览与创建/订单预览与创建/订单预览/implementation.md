# Implementation（跨仓实施汇总）— 订单预览 STORY-004-01-01-01

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0019（M4 订单交易闭环）
- Story：STORY-004-01-01-01 订单预览
- 实施日期：2026-09-17

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-901 | repo-1 | mall-order 工程骨架 + POST /api/mall/orders/preview；mall-member 内部地址端点；网关 mall 路由；OrderApiTest 17/17（预览相关 4 例）、mall-member/mall-gateway 回归绿 |

> 前端预览界面（CheckoutView）随结算闭环在 DU-FE-901（STORY-004-01-01-02）一起交付，本 Story 无独立前端 DU。

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| a06ed4c | DU-BE-901 | repo-1 | feat(order): M4 订单交易闭环首个提交含 mall-order 骨架/预览（75 文件） |

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0019/订单交易/订单预览与创建/订单预览与创建/订单预览/DU-BE-901/implementation.md`
  - mall-order（8105）新模块：Spring Boot 3.5 / MyBatis-Plus + jsqlparser / Flyway（V1 订单表、V2 补偿表）/ Redis；安全链 MEMBER + X-Internal-Token 内部链
  - 预览应用服务 `CheckoutPreviewService`：CART 源经 RestClient 调 mall-cart `GET /api/internal/carts/members/{id}/selected-items`（请求体 items 被忽略）；BUY_NOW 源以令牌前请求行为准并做数量 1..999、条目 ≤100 校验
  - 逐行聚合：product `skus/batch` 取最新快照价/图/规格（金额单位：分 Long），inventory availability 批量取可用量 → OK/LOW(<10)/OUT_OF_STOCK + issueCodes（SKU_NOT_SALABLE/OUT_OF_STOCK/STOCK_INSUFFICIENT）
  - 地址：mall-member 新增 `GET /api/internal/members/addresses/{addressId}?memberId=`（非归属/不存在统一 404 不泄露差异）；无有效地址 address=null
  - submitToken：`RedisSubmitTokenStore`，availableToSubmit=true 时签发，Redis TTL 600s，载荷含 source/addressId/行指纹 SHA；不可下单为 null
  - 依赖故障统一 503 ORDER_DEPENDENCY_UNAVAILABLE；错误码 B0401/B0404/B0406/B0503（OrderErrorCode）
  - 网关：`/api/mall/orders/**` → 8105 MEMBER；`/api/internal/**` denyAll 经网关 404

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | CART 预览取服务端选中项、伪造 items 忽略、无锁库无订单 | passed（previewCartUsesCartSelection） |
| AC-002 | BUY_NOW 只含传入 SKU；数量 0/负/≥1000 400；条目 101 400 | passed（previewBuyNowOk + RequestDto bean validation） |
| AC-003 | 下架/失效/不存在 → issueCodes 且 availableToSubmit=false | passed（previewBlockedWhenUnsableOrOutOfStock） |
| AC-004 | 库存状态三档：OUT 阻断 / LOW 可下单 / OK | passed（availability 批量装配，preview 用例覆盖 0 与充足） |
| AC-005 | 金额一律服务端 product 实时价，请求无金额字段 | passed（previewBuyNowOk 断言服务端计价） |
| AC-006 | 地址非本人/不存在/为空均不可下单；有效地址返完整快照 | passed（previewAddressNotOwned） |
| AC-007 | submitToken TTL≤600s 载荷含 source/addressId/行指纹；阻断时 null | passed（AbstractRedisIntegrationTest 真实 Redis + 用例断言非空/为空） |
| AC-008 | product/inventory/cart/member 依赖故障 → 503 | passed（Rest*Port 统一转译 ORDER_DEPENDENCY_UNAVAILABLE） |
| AC-009 | 未认证 401；内部地址端点无 token 401/非归属 404 | passed（authBoundaries + InternalMemberAddressController 测试） |
| AC-010 | mall-order 骨架可启动，smoke + preview API 测试通过 | passed（MallOrderApplicationSmokeTest 1/1，OrderApiTest 17/17） |
