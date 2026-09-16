# Implementation（跨仓实施汇总）— 购物车核心操作 STORY-003-03-01-01

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0018（购物车）
- Story：STORY-003-03-01-01 购物车核心操作
- 实施日期：2026-09-16

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-801 | repo-1 | mall-cart 23/23（新增）、mall-product 95/95（基线 93 + 新增 2）、mall-gateway 19/19，三仓 package 成功 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| ebfbeb2 | DU-BE-801 | repo-1 | 会员购物车 Redis 写模型：4 Lua + 可售校验 + product sku/batch + 网关路由 + M4 端点（34 files +1965/-41） |

（另有 docs(sdd) 提交 082b… 仅回填 DU implementation/metadata，非代码提交，按机检规则不计入 code-change Evidence。）

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0018/商城前台/购物车/会员购物车/购物车核心操作/DU-BE-801/implementation.md`
  - mall-cart（8104，无 RDBMS）：`cart_add/update/remove/select.lua` 原子写 + EXPIRE 滑动 TTL 90 天；条目数/单量上限脚本判定；加购前 RestClient 调 product `POST /api/internal/products/skus/batch`（X-Internal-Token）做 product ON_SALE + sku ENABLED 双状态校验并写 priceFenAtAdded；memberId 仅取 SecurityContext；错误码 B0301~B0304/S0301/S0302；M4 `GET /api/internal/carts/members/{id}/selected-items`
  - mall-product：`findBySkuIds` 批量装配（3 轮 IN 查询无 N+1）、`SkuBatchApplicationService`（缺失占位、双状态、价/图/规格）、内部 batch 端点
  - mall-gateway：`/api/mall/cart/**` → 8104 路由 + MEMBER 鉴权；`/api/internal/**` denyAll→404 不变
  - 测试：Testcontainers 真实 Redis（Lua 9 例，TTL≈90 天、999/100 边界、幂等、全选、隔离）+ MockMvc 全链路 13 例（401/403/归属/错误码矩阵/M4 凭证）+ product batch 2 例

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | 加购成功默认勾选、写快照价、写后 TTL 90 天（Lua EXPIRE） | passed（addNewItemSetsDefaultsAndTtl；真实环境 TTL 与九千万秒常量相差 <1 分钟） |
| AC-002 | 同 SKU 合并一条；>999 → 400 且保持原值 | passed（addMergesSameSku/addOverQuantityLimitKeepsOriginal/mergeAndQuantityLimit） |
| AC-003 | 下架/失效/不存在 SKU 与非法数量 → 400，车不变；依赖故障 503 区分 | passed（addUnsalableRejected/invalidRequestRejected/addDependencyFailure503；E2E DRAFT SKU 实测 B0303） |
| AC-004 | 第 101 个不同 SKU → 400，车保持 100 | passed（addRejects101stDistinctSku/itemsLimit） |
| AC-005 | 改量（不存在 404）、单删 204、批删不存在幂等 | passed（updateQuantityLifecycle/removeIsIdempotent/updateAndRemove） |
| AC-006 | 单选/全选生效，selected 随 Hash 跨设备保持 | passed（selectSemantics/selectionLifecycle） |
| AC-007 | 无 Token 401、ADMIN 403、memberId 无入参入口、会员车隔离 | passed（noTokenUnauthorized/adminForbidden/cartIsolation；网关实测 401） |
| AC-014 | 加购链路零库存锁定调用 | passed（mall-cart pom 无 inventory 依赖；product batch 不查库存） |

## 5. 真实环境验证（2026-09-16）

Docker infra（MySQL 13306/Redis 6379）+ 真实 jar：identity 8101、product 8103、cart 8104、gateway 8080、inventory 8106。
注册登录会员（memberId=1）→ 经网关加购真实在售 SKU（快照价 399900 分，默认勾选）→ 再购 2 合并为 3 → DRAFT 商品 SKU 加购 400 B0303 → 无 Token GET 401 → 网关访问 internal 404 → 直连 cart 8104 以 X-Internal-Token 调 selected-items：unselect 后 0 项、select-all 后 1 项（skuId 字符串/quantity=3）→ Redis HLEN=1、TTL≈90 天常量、value 为约定 JSON。测后已清理该会员购物车 key。
