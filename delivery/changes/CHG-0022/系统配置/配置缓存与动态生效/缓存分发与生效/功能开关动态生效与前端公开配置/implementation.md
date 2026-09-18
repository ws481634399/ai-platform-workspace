# Implementation（跨仓实施汇总）— 功能开关动态生效与前端公开配置 STORY-006-02-01-02

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0022（M5 系统功能与参数配置）
- Story：STORY-006-02-01-02 功能开关动态生效与前端公开配置
- 实施日期：2026-09-18

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-509 | repo-1 | PublicFeaturesController（GET /api/mall/public-features，data 为数组，白名单 key/enabled）+ 网关 mall 路由白名单；ProductSearchService search 首行 Gate（search.enabled）；CartController 仅 merge-token/merge 两端点 Gate（mall.guest-cart.enabled）；SearchFeatureGateTest 2、GuestCartFeatureGateTest 2（源码清点） |
| DU-FE-504 | repo-2 | mall-web features API（数组解包）+ pinia features store fail-open + main.ts fire-and-forget；MallLayout 搜索入口 v-if、SearchView 关闭空态、ProductDetailView 游客加购禁用+登录引导+方法兜底；features.spec.ts 3、ProductDetailView.spec.ts 新增 2（共 6；源码清点，node_modules 未安装未实跑） |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 82ccf6e | DU-BE-509 | repo-1 | M5 三 Change 合并提交，含 public-features 公开端点与网关路由、search/cart 切点、切点切片测试 4 例 |
| af19b9e | DU-FE-504 | repo-2 | mall-web 公开开关接线：features API/store、搜索入口与空态、游客加购守卫、前端测试 3+2 例 |

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0022/系统配置/配置缓存与动态生效/缓存分发与生效/功能开关动态生效与前端公开配置/DU-BE-509/implementation.md`
  - `/api/mall/public-features` permitAll 无鉴权，UnifyResult.data 直接为 `List<PublicFeatureView>` 数组，聚合键读缓存（含禁用公开项），字段仅 key/enabled
  - 搜索切点在 ProductSearchService.search 首行 ensureEnabled("search.enabled")，关闭 → FeatureDisabledException 经 common-config advice 转 403/UnifyResult B0606「功能暂未开放」
  - 游客车切点仅 merge-token / merge（M4 游客数据服务端唯一入口）；会员 /cart/items 等不受影响
  - effectType 作为参数元数据经 admin View 返回（4 种子均 DYNAMIC），M5 不做重启钩子
- repo-2：`implementation/ai-platform-frontend/delivery/CHG-0022/系统配置/配置缓存与动态生效/缓存分发与生效/功能开关动态生效与前端公开配置/DU-FE-504/implementation.md`
  - stores/features.ts：hasFeature(key, fallback=true)，未加载/缺键/加载失败均 fail-open；main.ts mount 后 void load() 不阻塞首屏
  - MallLayout 搜索 router-link data-testid="mall-search-link" v-if 受控；SearchView 关闭态「搜索功能暂未开放」空态（search-closed）不发请求
  - ProductDetailView guestCartBlocked 仅约束未登录游客；add-cart-btn disabled + guest-cart-blocked-hint 登录引导；addToCart() 二次兜底

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | 无鉴权 GET /api/mall/public-features 返回 200，data 为数组且元素仅 key/enabled；非公开键不出现（findAllPublic public_flag=1，含禁用项） | passed（ConfigCacheIntegrationTest.publicFeatures；网关白名单 /api/mall/public-features/**） |
| AC-002 | search.enabled=true 搜索 200；false 时切点在业务逻辑前拒绝，$.code=B0606 结构统一；≤60s 生效由本地 TTL + AFTER_COMMIT 删键保证（见 STORY-006-02-01-01 AC-002/AC-006） | passed（SearchFeatureGateTest.searchDisabledReturns403、searchEnabledPasses；updateEvictsCache） |
| AC-003 | store 公开开关刷新后 hasFeature 两态控制 MallLayout 搜索入口显隐，SearchView false 显示空态不发请求，重开恢复 | passed（features.spec.ts 3 例覆盖两态/缺省/失败语义；MallLayout v-if 与 SearchView search-closed 接线已核实，组件级测试缺口见 DU-FE-504 DEV-2，联调列入场景六） |
| AC-004 | 游客车 false：merge-token 与 merge 均 403 B0606；会员 /cart/items 加购 200 不受影响；前端游客加购按钮禁用 + 登录引导且不触发加购，重开 fail-open 恢复 | passed（GuestCartFeatureGateTest.guestCartDisabledRejectsMergeEndpoints、guestCartEnabledAndMemberUnaffected；ProductDetailView.spec.ts 新增 2 例） |
| AC-005 | 参数 admin View 带 effectType（DYNAMIC/RESTART_REQUIRED），mall-admin 参数页动态/重启生效 tag；生效时延上限 60s 由 mall.config.localTtlSeconds=60 + localCacheExpires 短 TTL 测试与删键链路证明；4 种子均 DYNAMIC | passed（ConfigCacheIntegrationTest.updateEvictsCache、SystemConfigClientTest.localCacheExpires；SystemParametersView effectType tag） |
| AC-006 | 公开端点异常时 store load() catch 静默、finally loaded、hasFeature 默认 true，首屏不白屏；服务端缓存全失时 Gate 走代码默认值放行 | passed（features.spec.ts「load 失败静默 fail-open」、SystemConfigClientTest.allLayersDown、ConfigFacadesTest.gateDefaults） |
| AC-007 | 后端切点两态测试 4 例 + 缓存/客户端 20 例（DU-BE-508）口径通过；前端 store 3 例与商品详情新增 2 例通过口径；前端环境 node_modules 未安装，计数为源码清点非实跑，端到端翻转联调移至 Integration Gate 场景六 | passed（SearchFeatureGateTest 2、GuestCartFeatureGateTest 2、features.spec.ts 3、ProductDetailView.spec.ts 新增 2；限制见 DU-FE-504/DU-BE-509 Deviations） |
