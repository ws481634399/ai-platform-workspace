---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-003-03-02-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0018
- Story ID: STORY-003-03-02-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed
- 需要 Migration: no
- 数据变更概要: 新增 Redis key cart:merge:{token}（TTL 300s）与 cart_merge.lua；无 RDBMS/infra 变更（AOF 已启用仅验证）

## 1. 模块改动（Module Changes）

### repo-1 mall-cart

- `CartMergeService`：issueMergeToken(memberId)（UUID，SET NX EX 300）；merge(memberId, token, guestItems) 单 Lua：
  1. GET cart:merge:{token}，不等于 memberId/无此键 → 返回 TOKEN_INVALID（脚本前置校验，写操作之前）；
  2. HGETALL 会员车；逐游客 SKU 合并：会员已有→相加（>999 截断并 truncated）；新 SKU→加入（HLEN 达 100 后记 dropped）；selected 取游客值（新条目）；priceFenAtAdded 由服务端在合并前经 product sku/batch 批量补快照（合并请求处理先做商品校验补价：失效游客条目 dropped 并返回原因 SKU_NOT_SALABLE，不进车）；
  3. HSET 全量变更 + EXPIRE 90d + DEL token；返回 {merged,truncated,dropped,cart}。
- `CartController`：POST /api/mall/cart/merge-token、POST /api/mall/cart/merge（ROLE_MEMBER）。
- `cart_merge.lua`（classpath）；入参为预校验后的 JSON 数组（价格快照在 Java 侧补齐，脚本只做合并算术）。

### repo-1 mall-product

- `interfaces.rest.mall.MallSkuItemController`：POST /api/mall/skus/items（匿名公开，白名单）；assembler 复用 internal sku/batch 但**仅输出 ON_SALE+ENABLED 条目**（不可售条目省略），≤100；供游客车展示。
- 网关：白名单增 /api/mall/skus/items（product-mall 路由已覆盖 /api/mall/skus/**）。

### repo-2 mall-web

- `src/composables/useGuestCart.ts`：LocalStorage key `mall:guest-cart:v1`；条目 {skuId,quantity,selected,addedAt}；上限同服务端（100/999，超限本地提示）；惰性清理 addedAt >90 天条目。
- `src/stores/cart.ts`：双模（游客走本地、会员走 API）；会员车 CRUD/选择/刷新；游客→会员合并编排（登录成功/恢复会话且本地有车时：merge-token → merge → 按 truncated/dropped 提示 → 清本地与 pending 标记；任何失败保留本地可重试）。
- `src/api/cart.ts`。
- views `cart/CartView.vue`：游客/会员双模列表（图/名/规格/价格/数量步进/库存徽标/有效状态/单选全选/删除/行内改量）、CartSummaryBar（选中合计、selectedCount、去结算置灰+tooltip）、GuestCartBanner（游客提示登录合并）；游客行展示数据来自 /api/mall/skus/items + /api/mall/skus/availability，缺失标失效。
- 详情页（CHG-0017 ProductDetailView）加购接线：游客写本地、会员调 API，按钮态与三态联动；成功轻提示并更新角标。
- 布局头部购物车角标（数量=有效条目数）。
- infra 验证：读取 docker-compose.infra.yml 记录 appendonly/everysec 证据（无 repo-4 代码变更）。

## 2. 接口契约细化

| 方法 | 路径 | 鉴权 | 请求 | 响应/错误 |
| --- | --- | --- | --- | --- |
| POST | /api/mall/cart/merge-token | MEMBER | — | {mergeToken,expiresIn:300} |
| POST | /api/mall/cart/merge | MEMBER | {mergeToken,items:[{skuId,quantity,selected}](≤100)} | {merged:[{skuId,quantity}],truncated:[{skuId,finalQuantity}],dropped:[{skuId,reason}],cart:CartView}；401 MERGE_TOKEN_INVALID；400 MERGE_TOKEN_EXPIRED/批次非法 |
| POST | /api/mall/skus/items | 匿名 | {skuIds:string[](≤100)} | {items:PublicSkuItem[]}（仅可售；缺失即省略） |
- 幂等：同 token 二次调用 → token 已 DEL，返回 401 MERGE_TOKEN_INVALID（前端据此不再重试且不报错——HTTP 语义上前端把"重复消费"当成功跳转）；服务端保证未二次累加（单脚本原子）。

## 3. 数据变更

- Redis：新增 cart:merge:* 短 TTL key 与 cart_merge.lua；无持久化变更。
- repo-4：无改动（AOF=everysec 现状满足，AC-022 以配置验证为证）。

## 4. 错误处理

- 合并商品校验失败条目：dropped(reason=SKU_NOT_SALABLE)，不阻断其他条目。
- token 过期：400 MERGE_TOKEN_EXPIRED，前端重新取 token 重提（游客车保留）。
- 游客公开快照批量缺失：前端行标"商品已失效"并禁止选中。
- 会员合并后读车失败：合并已成功（toast 成功），列表区域 Error 态可重试，本地已清空。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-803 | repo-1 | mergeToken 签发 + 单 Lua 原子合并（相加/截断/dropped/幂等）+ public skus/items | AC-015,016,017,018 | — |
| DU-FE-801 | repo-2 | useGuestCart/双模 store/购物车页/详情加购/合并编排/结算占位/AOF 验证留证 | AC-015,016,017,018,019,020,022 | DU-BE-803 |

> 跨 Story/Change 依赖：读车 CartView 与写 API 由 DU-BE-801/802 交付；CHG-0016 DU-FE-601（登录态）、CHG-0017 DU-FE-704（详情页加购接线点）、CHG-0015 DU-BE-501（凭证/白名单）。

## 6. 测试策略

- 后端 Lua/服务：2+1=3 合并；超 999 截断与响应告知；超 100 dropped 优先级（会员条目保留）；失效游客条目 dropped；同 token 二次请求不累加（数量前后快照）；过期/伪造 token；合并后 TTL 续期。
- public skus/items：仅可售条目、≤100、匿名 200。
- 前端：useGuestCart 规则单测；合并成功清本地、失败保留、刷新不重复合并（pending 标记）；CartView 双模渲染与置灰结算；详情加购分流；vue-tsc/eslint/build。
- 证据：infra AOF 配置摘录归档 test evidence（无代码 diff）。
