---
affected-repositories: [repo-1, repo-2]
---

# Requirement Design（需求级方案设计）

> 层级：Requirement 级产物——本次 Change 的技术方案骨架
> 业界锚点：ADR（Context → Decision → Alternatives → Consequences）+ 跨仓影响面
> 输入：requirement-spec.md + CHG-0015/0016/0017 设计契约
> 产出状态：designed
> 分层关系：本文是 Requirement 级；Story 内部的详细设计见各 Story 目录 story-design.md。

## 0. 元信息

- Change ID: CHG-0018
- spec 来源: requirement-spec.md（REQ-M3-003 购物车）
- 相关仓库: repo-1（ai-platform-backend）、repo-2（ai-platform-frontend）
- 受影响仓库数: 2
- 需要 Migration: no（购物车纯 Redis 临时态；无 MySQL DDL；Redis AOF 已在 infra 仓启用）

## 1. 当前状态

- mall-cart 仅 `MallCartApplication` 骨架；pom 含 mybatis-plus/flyway/mysql/mall-common-web，**未引入 redis 依赖**；application.yml 端口 8104、无 Redis 配置；无安全配置。
- `mall-common-redis` 已存在（spring-boot-starter-data-redis，StringRedisTemplate 使用先例在 mall-common-security 的权限快照）。
- infra `deploy/docker-compose.infra.yml` 的 redis:7.4.11 已配置 `--appendonly --appendfsync everysec` 与持久化卷——**AC-022 的 AOF 要求已满足，本 Change 不改 repo-4，仅做配置验证留证**。
- CHG-0017 已交付：product 内部 availability 客户端模式（InventoryAvailabilityClient + X-Internal-Token）、公开三态 POST /api/mall/skus/availability（阈值 10）；product 内部现有 SKU 能力仅单条 snapshot `/api/internal/products/{productId}/skus/{skuId}` 与存在性 `GET /skus/{skuId}`，**无按 skuId 批量快照**。
- CHG-0016 已交付：ROLE_MEMBER 网关授权模式、SecurityContextFacade、mall-web 登录态（member store/http 拦截器/刷新协调）。
- 商品侧 SkuPo 字段齐备（salePrice、specification_data、mainImageUrl、status）；商品状态 ON_SALE 判定在 product 域内。

## 2. 提议方案

- 方案概要:
  1. **Redis 模型（纯临时态，滑动 TTL）**：Key `cart:member:{memberId}`，类型 Hash，field=skuId，value=JSON `{quantity,selected,priceFenAtAdded,createdAt,updatedAt}`（priceFenAtAdded 仅作调价提示基准，永不作结算价）；所有写操作经 **Lua 脚本原子完成业务校验+写入+EXPIRE 90 天**；上限：HLEN ≤100 条目、quantity 1–999、加购累加超 999 返回 400 不静默截断。
  2. **加购可售校验（product 批量内部快照新端点）**：product 新增 `POST /api/internal/products/skus/batch`（≤100，X-Internal-Token），返回 skuId→{productId,productName,skuName,specs,priceFen,imageUrl,productStatus,skuStatus}；cart 加购前一次批量调用确认 productStatus=ON_SALE 且 skuStatus=ENABLED（不校验库存、不锁库存）。
  3. **读车实时聚合**：GET /api/mall/cart 一次拉取 Hash 全量 → 一次 product sku/batch + 一次 inventory availability（复用 CHG-0017 内部端点）→ 组装条目状态：VALID/PRODUCT_OFF_SHELF/SKU_INVALID/NOT_FOUND/PRICE_CHANGED（对比 priceFenAtAdded）/库存三态/UNKNOWN；依赖故障条目级降级，整车恒 200；校验只读不改 Redis。
  4. **mergeToken 幂等合并**：`POST /api/mall/cart/merge-token`（MEMBER）签发 UUID，`SET cart:merge:{token} memberId EX 300`；`POST /api/mall/cart/merge` 在**单个 Lua 脚本**内完成 token 校验（GET 等于当前 memberId）→ 逐 SKU 相加（>999 截断 999 记 truncated）→ 条目超 100 时会员已有条目优先、游客多余记 dropped → EXPIRE → DEL token；token 不匹配/过期 401/400；重放同 token 不再累加。
  5. **M4 预留**：`GET /api/internal/carts/members/{memberId}/selected-items`（SERVICE 凭证）只读返选中条目，M3 实现不联调。
  6. **网关/前端**：/api/mall/cart/** 路由到 8104 并要求 ROLE_MEMBER；product 另增**公开** `POST /api/mall/skus/items`（≤100，游客车展示用快照，字段同内部批量但仅可售商品）与公开三态配合；mall-web 新增 useGuestCart（LocalStorage）、购物车页（会员/游客双模）、详情页加购接线、登录后自动合并与清理、去结算置灰占位。
- 关键组件:
  - mall-cart：`domain.cart.{CartItem,CartItemStatus,StockStatus,CartConstants}`；`application.cart.{CartApplicationService,CartMergeService}`；`interfaces.rest.mall.CartController`、`interfaces.rest.internal.InternalCartController`、dto；`infrastructure.redis.{CartRedisRepository,LuaScripts}`（classpath 脚本 + DefaultRedisScript）；`infrastructure.client.{ProductSkuClient,InventoryAvailabilityClient}`；`infrastructure.config.{CartSecurityConfiguration,RedisConfiguration,MybatisPlusConfig(如复用mysql依赖)}`；resources/lua/*.lua。
  - mall-product：internal sku/batch；public mall sku/items（assembler 复用，仅 ON_SALE+ENABLED）；网关白名单。
  - mall-gateway：cart 路由 + ROLE_MEMBER；skus/items 白名单。
  - mall-web：composables/useGuestCart、stores/cart、api/cart.ts、views/cart/CartView.vue、components/{CartItemRow,CartSummaryBar,GuestCartBanner}、详情页加购接线、登录合并编排。
- 关键不变量:
  - memberId 只来自 SecurityContext；接口路径/请求体永远不含 memberId（internal 端点除外）。
  - 不锁库存、不信任浏览器价格、购物车不生成订单号/成交价。
  - 每次写滑动 TTL；合并 token 一次性、与合并原子。
  - 无 MySQL 持久化；Redis 故障语义=空/失败（产品已接受丢车）。

## 2.1 备选方案对比（Alternatives Considered）

| 方案 | 描述 | 优点 | 缺点 | 是否采纳 |
| ---- | ---- | ---- | ---- | -------- |
| A（选中）Redis Hash + Lua 原子写 + mergeToken 单脚本 | 原子、上限/TTL/幂等可证；无 DB | 仅 Redis 依赖；丢车风险 AOF 兜底（已接受） | Lua 维护成本 | 是 |
| B MySQL 购物车表 | 可靠持久 | 违背"临时态、接受丢失"决策；高频写打 DB | 否 |
| C Redis 但 Java 侧读改写（WATCH/事务） | 不写 Lua | 并发上限竞争、合并原子性难保证 | 否 |
| D 游客车也存服务端（GUEST 主体车） | 跨设备游客车 | 需要游客身份签发链路与清理成本，M3 无必要 | 否 |
| E 合并依赖登录响应直接带 token（identity 签发） | 少一次请求 | identity 需感知 cart Redis，越界耦合 | 否（cart 自签） |

## 3. 仓库影响（Repository Impact）

- 受影响仓库数: 2（repo-4 经核查零改动：AOF 已配置）

### 3.1 repo-1（ai-platform-backend）

- `mall-services/mall-cart`：pom 增 mall-common-redis/mall-common-security；Cart 域全套；Lua 脚本；两个 client；安全配置（JWT 资源服务器 ROLE_MEMBER + InternalIdentityFilter）；application.yml（Redis 连接、internal secret、product/inventory uri）。
- `mall-services/mall-product`：internal sku/batch + public skus/items；网关白名单。
- `mall-gateway`：cart 路由（→8104）+ /api/mall/cart/** ROLE_MEMBER；/api/mall/skus/items 白名单（并入 product-mall 路由）。

### 3.2 repo-2（ai-platform-frontend）

- mall-web：游客车 LocalStorage 模块、会员 cart store/api、购物车页面与组件、详情页加购、登录合并编排、去结算占位。

## 4. 跨仓协作（Cross-Repository Contract）

- 会员接口（ROLE_MEMBER，UnifyResult，ID 字符串）：
  - GET /api/mall/cart → {items:CartLine[], selectedTotalFen:number, selectedCount:number}
  - POST /api/mall/cart/items {skuId,quantity(1..999)}；PUT /api/mall/cart/items/{skuId} {quantity}；DELETE /api/mall/cart/items/{skuId}；POST /api/mall/cart/items/batch-delete {skuIds:[]}
  - POST /api/mall/cart/items/{skuId}/select|/unselect；POST /api/mall/cart/select-all|/unselect-all
  - POST /api/mall/cart/merge-token → {mergeToken}；POST /api/mall/cart/merge {mergeToken,items:[{skuId,quantity,selected}]} → {merged,truncated,dropped,cart}
  - 错误码：CART_QUANTITY_LIMIT(400)、CART_ITEMS_LIMIT(400)、SKU_NOT_SALABLE(400)、MERGE_TOKEN_INVALID(401)、MERGE_TOKEN_EXPIRED(400)
- CartLine：{skuId,quantity,selected,productId,productName,skuName,specs,imageUrl,priceFen,priceFenAtAdded,itemStatus,stockStatus,createdAt,updatedAt}
- 内部契约（X-Internal-Token）：
  - POST /api/internal/products/skus/batch {skuIds:long[](≤100)} → {items:SkuSnapshotItem[]}（含 product/sku 双状态）
  - GET /api/internal/carts/members/{memberId}/selected-items（M4 预留，SERVICE 凭证）
- 公开契约（匿名，游客车展示）：
  - POST /api/mall/skus/items {skuIds:string[](≤100)} → 仅含 ON_SALE+ENABLED 的可售快照；不可售条目省略（前端按缺失标 NOT_FOUND/失效）。
- 仓库依赖: repo-2 → repo-1；cart 运行期直连 product 8103 / inventory 8106。
- Migration Impact: 无；Redis 仅新增 key 命名空间 cart:* 与 Lua，无配置迁移；AOF 已启用（验证项）。
- 跨仓时序: product 批量端点先行（加购校验依赖）→ cart 读写 → 前端合并联调。

## 5. Story 设计分派（Story Design Assignments）

| Story ID | 技术要点摘要 | 涉及仓库 | 公共组件/契约归属 |
| -------- | ------------ | -------- | ----------------- |
| STORY-003-03-01-01 | Redis Hash+Lua 写模型（加购合并/改量/删除/选择/TTL/上限）；product internal sku/batch；网关 cart 路由；M4 选中项内部端点 | repo-1 | CartConstants/Redis key/Lua 仓库为后续两 Story 公共底座 |
| STORY-003-03-01-02 | 读车聚合（product batch + availability）、双状态映射、priceFenAtAdded 调价检测、条目级 UNKNOWN 降级、selectedTotal | repo-1 | CartLine 读模型 SSOT |
| STORY-003-03-02-01 | mergeToken 签发与单 Lua 原子合并；public skus/items；游客 LocalStorage、购物车双模页、详情加购、登录合并清理、结算占位、AOF 验证 | repo-1、repo-2 | useGuestCart 本地规则 SSOT |

### 5.1 公共组件与共享契约

- Key SSOT：`cart:member:{memberId}`（TTL 90 天）、`cart:merge:{token}`（TTL 300s）。
- 上限 SSOT：100 条目 / 999 件 / 合并批 ≤100。
- 状态枚举：itemStatus VALID/PRODUCT_OFF_SHELF/SKU_INVALID/NOT_FOUND/PRICE_CHANGED/UNKNOWN；stockStatus IN_STOCK/LOW_STOCK/OUT_OF_STOCK/UNKNOWN（阈值沿用 CHG-0017）。

## 6. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | -------- | ---- | ------ | ---------- |
| DU-BE-801 | repo-1 | cart 服务骨架接入 Redis/安全；Lua 写模型全套；product internal sku/batch；网关路由；M4 选中项端点 | AC-001~007,014 | — |
| DU-BE-802 | repo-1 | 读车聚合/双状态/调价检测/降级/金额合计；跨服务边界审计 | AC-008~013,021 | DU-BE-801 |
| DU-BE-803 | repo-1 | mergeToken 签发与单 Lua 原子合并（截断/dropped）；public skus/items | AC-015,016,017,018 | — |
| DU-FE-801 | repo-2 | useGuestCart + cart store/api + 购物车双模页/组件/详情加购/登录合并清理/结算占位 | AC-015~022 | DU-BE-803 |

> 全局依赖（跨 Change）：全部 DU 依赖 CHG-0015 DU-BE-501（@StringId/内部凭证/网关）；DU-BE-801 依赖 CHG-0016 DU-BE-602（MEMBER 鉴权）；读车聚合依赖 CHG-0017 DU-BE-705（availability 内部端点与阈值）。

## 7. 风险

- Lua 脚本复杂度：合并脚本承载截断/dropped 语义；以 lua 单测（eval 构造多场景）+ 集成测试覆盖；脚本加载用 DefaultRedisScript 启动期校验语法。
- Redis 故障：读写异常统一 503 CART_STORAGE_UNAVAILABLE（不静默造数据）；前端提示稍后重试；接受语义已评审。
- 价格基准陈旧：priceFenAtAdded 仅用于提示；结算价 M4 重算，任何链路不得据此计价——代码 review 清单与命名强调 AtAdded。
- 合并 token 与并发：单 Lua 保证原子；会员在合并期间并发写车的极端时序（Lua 原子隔离，最终值确定）。
- 依赖降级误展示：UNKNOWN 条目禁止进入"去结算"可点状态与金额合计。
- 大 key：单 key ≤100 字段、每值 JSON <1KB，总量受控；TTL 保证冷车自清理。

## 8. 待澄清问题

- 去结算控件 M3 默认置灰 + tooltip"结算将在后续阶段开放"；M4 替换。
- 游客车 LocalStorage 不设主动过期（与会员车 90 天语义对齐：前端可记录 addedAt，超 90 天条目惰性清理，作为体验优化不阻塞 AC）。
- repo-4 AOF 已为 everysec，本 Change 仅在测试证据中验证配置存在（AC-022），不产生 infra 提交。
