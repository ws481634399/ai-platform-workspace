---
affected-repositories: [repo-1]
story-id: "STORY-003-03-01-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0018
- Story ID: STORY-003-03-01-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed
- 需要 Migration: no
- 数据变更概要: 无 MySQL DDL；新增 Redis key 空间 cart:* 与 4 个 Lua 脚本

## 1. 模块改动（Module Changes）

### repo-1 mall-cart（从骨架建成服务）

- pom 增加 mall-common-redis、mall-common-security；application.yml 增加 Redis（host/port/password 沿用 infra）、mall.security.internal.shared-secret、mall.cart.product-uri(8103)/inventory-uri(8106)。
- `domain.cart.CartItem`：record(skuId,quantity,selected,priceFenAtAdded,createdAt,updatedAt)；`CartConstants`（TTL_DAYS=90、MAX_ITEMS=100、MAX_QTY=999）；错误码枚举 CART_QUANTITY_LIMIT/CART_ITEMS_LIMIT/SKU_NOT_SALABLE/CART_STORAGE_UNAVAILABLE。
- `application.cart.CartApplicationService`：add/updateQuantity/remove/batchRemove/select/unselect/selectAll/unselectAll/getRaw；memberId 取自 SecurityContextFacade。
- `infrastructure.redis.CartRedisRepository`：StringRedisTemplate + DefaultRedisScript；scripts：
  - `cart_add.lua`：HLEN 判条目上限；HMGET 判合并后数量（>999 返回 QTY_LIMIT）；HSET（新条目 selected=true、写 createdAt；已有更新 quantity/updatedAt）；EXPIRE 90d；返回状态码。
  - `cart_update.lua`：HEXIST 校验（不存在 NOT_FOUND）；quantity 1..999（调用侧校验，脚本兜底）；HSET+EXPIRE。
  - `cart_remove.lua`：HDEL（单/批，幂等）+ 仅 key 仍存在时 EXPIRE 续期。
  - `cart_select.lua`：单条目或全条目改 selected + EXPIRE。
- `infrastructure.client.ProductSkuClient`：RestClient 直连 8103 + X-Internal-Token，POST /api/internal/products/skus/batch；加购前校验 productStatus=ON_SALE 且 skuStatus=ENABLED，并写 priceFenAtAdded。
- `interfaces.rest.mall.CartController`：/api/mall/cart 写接口全集（本 Story GET 返回原始条目视图供测试，读模型下一 Story 替换）；类级 @PreAuthorize ROLE_MEMBER。
- `interfaces.rest.internal.InternalCartController`：GET /api/internal/carts/members/{memberId}/selected-items（凭证保护；返 selected 的 skuId/quantity，M4 消费）。
- `infrastructure.config.CartSecurityConfiguration`：JWT 资源服务器（JwtSubjectConverter）+ InternalIdentityFilter。

### repo-1 mall-product

- `interfaces.rest.internal.InternalProductController` 新增 POST /skus/batch；application 新增按 skuId 集合批量装配（含 product ON_SALE 状态、sku status、价、图、规格、productId/name）；≤100；无库存调用。

### repo-1 mall-gateway

- 路由 `mall-cart`：/api/mall/cart/** → 8104；授权 `.pathMatchers("/api/mall/cart/**").hasRole("MEMBER")`（merge-token 同属认证）。

## 2. 接口契约细化

| 方法 | 路径 | 请求 | 响应/错误 |
| --- | --- | --- | --- |
| POST | /api/mall/cart/items | {skuId:string,quantity:int} | 200 原始车视图；400 SKU_NOT_SALABLE/CART_QUANTITY_LIMIT/CART_ITEMS_LIMIT |
| PUT | /api/mall/cart/items/{skuId} | {quantity:int 1..999} | 200；404 条目不存在 |
| DELETE | /api/mall/cart/items/{skuId} | — | 204（幂等） |
| POST | /api/mall/cart/items/batch-delete | {skuIds:string[]} | 200；不存在项忽略 |
| POST | /api/mall/cart/items/{skuId}/select · /unselect | — | 200 |
| POST | /api/mall/cart/select-all · /unselect-all | — | 200 |
| GET | /api/internal/carts/members/{memberId}/selected-items | SERVICE 凭证 | {items:[{skuId,quantity}]} |
- 任何写后 TTL=90 天；未认证 401；memberId 不出现在任何请求。

## 3. 数据变更

- 无 RDBMS 变更。Redis：cart:member:* Hash、（合并 key 在 Story3）；脚本随服务发布。

## 4. 错误处理

- product client 故障/返回非可售：加购 400 SKU_NOT_SALABLE（含 client 异常归一，避免阻塞式误判可区分 NOT_SALABLE 与 503——client 异常 → 503 DEPENDENCY_UNAVAILABLE）。
- Redis 异常：503 CART_STORAGE_UNAVAILABLE。
- 脚本返回码映射集中在 repository 层（0=OK,1=QTY_LIMIT,2=ITEMS_LIMIT,3=NOT_FOUND）。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-801 | repo-1 | cart Redis 写模型全套 + Lua + product sku/batch + 网关 + M4 端点 | AC-001,002,003,004,005,006,007,014 | — |

> 跨 Change 依赖：CHG-0015 DU-BE-501（@StringId/InternalIdentityFilter/网关机制）、CHG-0016 DU-BE-602（MEMBER 鉴权链路）。

## 6. 测试策略

- Lua 脚本测试（嵌入式/Testcontainers Redis 或 redis-server 集成）：加购合并、>999 各路径、100 条目边界、TTL 续期断言（TTL≈7776000±误差）、删除幂等、全选语义。
- 应用层：加购可售校验（mock client 四态：可售/下架/禁用/故障 503）；SecurityContext 归属（无 memberId 入参）。
- 网关：401/会员 200/ADMIN 403；internal selected-items 无凭证 401。
- inventory lock 零调用：全测试范围断言 cart 不依赖 inventory 锁定端点（本 Story 根本不引入 inventory client 依赖）。
