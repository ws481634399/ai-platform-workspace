# Test Report — STORY-006-02-01-02 功能开关动态生效与前端公开配置

> 阶段：sdd-test 产物。

## 0. 元信息

- Change ID：CHG-0022（M5 系统配置）
- Story ID：STORY-006-02-01-02
- 执行时间：2026-09-19（后端全 reactor 与 mall-web 四门均在本日实跑）
- 覆盖：AC-001~AC-007；test-design.md TC-001~TC-008
- 实施来源：repo-1 DU-BE-509（82ccf6e）、repo-2 DU-FE-504（af19b9e）
- 直接相关测试：SearchFeatureGateTest **2/2**、GuestCartFeatureGateTest **2/2**；mall-web features.spec.ts **3/3**、ProductDetailView.spec.ts **6/6**（其中 FE-504 新增 2 例），共 **13/13 全过**
- 关键语义：B0606 FEATURE_DISABLED 统一 403；fail-open 仅显式 false 拦截（缺键/故障默认放行）；前端 hasFeature 未知键默认 true；生效上限 60s（本地 TTL + AFTER_COMMIT 删键）

## 1. 测试范围

TC 编号与本 Story `test-design.md` §1 逐字一致；证据列映射真实测试类#方法名与 spec 文件#用例名（已逐一核对源码，无编造）。

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| TC-001 | API：匿名 GET /api/mall/public-features → 200，仅 publicFlag=1 的 [{key,enabled}]；非公开键（参数/私有开关）不出现 | Testcontainers Redis + MockMvc 匿名请求 | passed | ConfigCacheIntegrationTest#publicFeatures（匿名 200；search.enabled enabled=true、mall.guest-cart.enabled 出现；非公开 internal.flag 不出现；用例 displayName 同时覆盖禁用公开项以 enabled=false 返回）——该类物理归属 Story2 缓存 IT，作为本 TC 的后端端点证据交叉引用 |
| TC-002 | 集成：search.enabled=true 搜索 200；置 false（短 TTL/手动清缓存后 ≤60s）GET /api/mall/search/products → 403 B0606 FEATURE_DISABLED 统一结构；重开恢复 200 | MockMvc 切片（@MockitoBean FeatureGate 两态）+ ES Testcontainers | passed（两态切片；真实翻转端到端未自动化，见 §4-1） | SearchFeatureGateTest#searchDisabledReturns403（ensureEnabled 抛 FeatureDisabledException → 403、$.code=B0606，不进入 ES 查询）、#searchEnabledPasses（放行 → 200、$.success=true）；≤60s 生效链路由 ConfigCacheIntegrationTest#updateEvictsCache（提交即删键）+ SystemConfigClientTest#localCacheExpires（本地 TTL 到期重取）支撑。对应 Integration Gate 场景六 |
| TC-003 | 前端组件：features store 加载后搜索入口 v-if 显隐；false 态访问 /search 显示功能未开放空态；重开恢复 | Vitest（pinia store）+ 源码静态核实 | partial（store 三例全过；入口/空态无组件 DOM 测试，见 §4-2） | mall-web stores/features.spec.ts 3 例：①未加载时 hasFeature 返回 fallback（默认 true，fail-open；显式 fallback=false 可关）；②load 成功：数组映射为 key→enabled（search.enabled=false / guest-cart=true），缺键仍走 fallback；③load 失败静默吞错：loaded 置位、映射为空、hasFeature fail-open。入口/空态实现静态核实：MallLayout.vue 搜索链接 v-if="features.hasFeature('search.enabled', true)"（data-testid=mall-search-link）、SearchView.vue searchEnabled 计算属性 + search-closed 空态不发请求 |
| TC-004 | 集成：mall.guest-cart.enabled=false → 游客加购/改量 403 B0606；会员加购 200、读购物车 200；重开游客恢复 | MockMvc 切片 + Vitest jsdom | passed（服务端切点落在 merge-token/merge，见 §4-3） | GuestCartFeatureGateTest#guestCartDisabledRejectsMergeEndpoints（关闭态 POST /api/mall/cart/merge-token 与 /merge 均 403 $.code=B0606）、#guestCartEnabledAndMemberUnaffected（开启态 merge-token 200 签发；会员 POST /api/mall/cart/items 200，不经游客开关）；ProductDetailView.spec.ts#「FE-504 游客且游客车开关关闭：加购按钮禁用并展示登录引导，不触发加购」（add-cart-btn disabled、guest-cart-blocked-hint 文案含「游客购物车暂未开放」「请登录后加购」、addItem 0 调用） |
| TC-005 | API/前端：effectType 字段在管理页明示标识（无 RESTART 种子时机制可造一条验证展示）；开关切换到后端拒绝时延 ≤60s（测试用可注入 TTL） | Vitest（api 层）+ 缓存 IT/客户端单测 | partial（effectType 传输有断言、页面 tag 无组件测试，见 §4-4） | mall-admin api/config.spec.ts#「systemParameterApi page 与 create 序列化参数」（effectType:'DYNAMIC' 下发）、#「update 携带乐观锁 version 与 changeReason」（effectType:'RESTART_REQUIRED' 透传）；SystemParametersView 动态/重启生效 tag 为页面实现静态核实；时延：ConfigCacheIntegrationTest#updateEvictsCache（提交后删键）+ SystemConfigClientTest#localCacheExpires（注入 TTL=1s 到期读到新值），生产 localTtlSeconds=60 为上限 |
| TC-006 | 韧性：mock public-features 503/断网 → mall-web 不白屏、入口默认可见（fail-open）；服务端 Redis+system 全失时 FeatureGate 按代码默认（启用）决策 | Vitest + Mockito/HttpServer 桩 | passed | features.spec.ts#「load 失败静默吞错」（getPublicFeatures reject 503 → load resolve undefined、loaded=true、hasFeature 默认 true）、#「未加载时 hasFeature 返回 fallback」；服务端：SystemConfigClientTest#allLayersDown（Redis 异常 + HTTP 不可达 → empty 不抛）、ConfigFacadesTest#gateDefaults（缺键 isEnabled 默认 true、ensureEnabled 放行，可传保守 false） |
| TC-007 | 构建门禁：mall-search/mall-cart mvn test 绿；mall-web vitest（入口显隐/403 提示）+ type-check/lint/build 绿 | mvn + pnpm 四门 | passed | mall-search **32/32**、mall-cart **55/55**（全 reactor 482 全绿）；mall-web vitest **21 files 102/102**（含 features.spec.ts 3、ProductDetailView.spec.ts 6）、type-check 0 error、lint 0 error（65 warnings）、build SUCCESS |
| TC-008 | 网关：匿名经 8080 访问 public-features 200；/api/admin/system-parameters 等未登录 401 | 配置静态核实 + 直连服务 401 自动化 | partial（网关层无自动化请求用例，见 §4-5） | mall-gateway application.yml 路由 `Path=/api/mall/public-features/**`、GatewaySecurityConfiguration 白名单 `/api/mall/public-features/**`（静态核实）；未登录 401 直连服务断言：ConfigAdminApiTest#authenticationAndAuthorization（无 token GET /api/admin/feature-configs → 401，system-parameters 走同一安全链） |

ProductDetailView.spec.ts 6 例明细（FE-504 直接相关为第 5、6 例，前 4 例为详情页回归保护，确保引入 features mock 后页面既有行为不回归）：①加载成功渲染名称/品牌/面包屑并查询可售状态；②富文本经净化（script 被剥离）；③404 渲染不存在态且无加购入口；④未选齐 SKU 时加购按钮禁用；⑤FE-504 游客且游客车开关关闭：加购按钮禁用并展示登录引导，不触发加购（新增）；⑥FE-504 开关缺省（fail-open）游客仍可见加购入口且无拦截提示（新增）。

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-search | 全 reactor `mvn test -B -ntp` | SearchFeatureGateTest **2/2**；mall-search 合计 **32/32** |
| mall-cart | 同上（TESTCONTAINERS_RYUK_DISABLED=true） | GuestCartFeatureGateTest **2/2**；mall-cart 合计 **55/55** |
| mall-web | `pnpm vitest run` / `vue-tsc --noEmit` / `eslint` / `pnpm build` | **102/102**（21 files，含 features.spec 3、ProductDetailView.spec 6）；type-check 0 error；lint 0 error（65 warnings）；build SUCCESS |
| 日志 | 后端与 mall-web 均跨 Change 引用：`../../../../../../CHG-0020/evidence/logs/backend-full-test.log`、`mall-web-vitest.log`、`mall-web-type-check.log`、`mall-web-lint.log`、`mall-web-build.log` | 完整输出 |

## 3. AC 覆盖

| AC | 验收标准（摘自 story-spec §5） | 覆盖 TC | 结论 |
|----|--------------------------------|---------|------|
| AC-001 | 未登录访问 /api/mall/public-features 返回 200，仅含 publicFlag=true 开关键与 enabled；非公开键不出现 | TC-001、TC-008 | passed（端点行为 IT 断言）；网关 8080 匿名链路仅配置核实 |
| AC-002 | search.enabled=true 搜索正常；置 false 后（≤60s）搜索直接返回 FEATURE_DISABLED，错误结构统一 | TC-002 | passed（两态切片 B0606/403 与 200；≤60s 删键+TTL 链路在 Story2 IT/单测证明；真实翻转联调补） |
| AC-003 | search.enabled=false 时 mall-web 顶部搜索入口隐藏；重新开启恢复显示与搜索 | TC-003 | partial：store 两态/缺省/失败语义 3 例 passed；MallLayout 入口 v-if 与 SearchView 空态有实现无组件测试 |
| AC-004 | guest-cart=false：游客加购/改量被后端拒绝 FEATURE_DISABLED；会员不受影响；重开恢复 | TC-004 | passed（切点为 merge-token/merge 两端点 + 前端游客加购禁用；会员加购 200） |
| AC-005 | 管理页可见 effectType 标识；修改开关到后端拒绝生效时延不超过 60s | TC-005 | partial：effectType api 层透传 2 例 + 页面 tag 实现；时延链路 passed；tag 渲染无组件测试 |
| AC-006 | 公开端点异常时 mall-web 不白屏（UI fail-open）；服务端 FeatureGate 缓存全失时按代码默认决策 | TC-006 | passed（前端 store 静默 fail-open + 后端 allLayersDown/gateDefaults） |
| AC-007 | 前后端测试全绿（含关闭态后端拒绝集成测试与前端入口显隐组件测试） | TC-007 | passed（后端 4/4、前端 9/9 直接相关全绿；前端"入口显隐"为 store 级而非布局组件级，差异见 §4-2） |

## 4. 缺口备注

1. **TC-002 无真实开关翻转端到端 IT**：两条搜索用例以 @MockitoBean 替换 FeatureGate 断言切点两态（关闭抛 FeatureDisabledException → 403 B0606，不触达 ES；放行 200），未在同一运行内真实执行"管理端 PUT OFF → 缓存失效 → ≤60s 后搜索 403 → 重开 200"全链翻转；该链路的缓存段由 Story2 的 ConfigCacheIntegrationTest#updateEvictsCache 与 SystemConfigClientTest#localCacheExpires 覆盖，浏览器/多服务翻转留 Integration Gate 场景六联调。
2. **TC-003 / AC-003 入口显隐与 /search 空态无组件测试**：无 MallLayout.spec / SearchView.spec；features.spec.ts 仅验证 store 的 hasFeature 映射与 fail-open 语义，v-if 显隐（data-testid=mall-search-link）与 search-closed 空态经源码静态核实，浏览器端验证列入联调。
3. **TC-004 服务端切点位置与 test-design 措辞差异**：test-design 表述为"游客加购/改量"拒绝；实现（CartController）将开关切点置于 POST /api/mall/cart/merge-token 与 /api/mall/cart/merge——M4 游客车数据服务端唯一入口（登录后合并游客车）；匿名直接加购在服务端无独立端点，关闭态以 ProductDetailView 前端禁用按钮 + 登录引导拦截，addToCart() 内二次兜底。会员写操作与所有读操作不经开关（会员 /cart/items 200 已断言）。
4. **TC-005 effectType 展示无组件断言**：admin 侧仅 api/config.ts 序列化用例（DYNAMIC/RESTART_REQUIRED 透传），SystemParametersView 的生效方式 tag 无组件测试；M5 四粒种子均 DYNAMIC，RESTART_REQUIRED 仅机制标识、无重启钩子（story-spec §2.2 不包含）。
5. **TC-008 网关层未自动化**：public-features 匿名白名单与路由为 application.yml/GatewaySecurityConfiguration 静态配置核实，未经真实 8080 端口发请求断言 200；/api/admin/system-parameters 未登录 401 仅有直连 mall-system 的同链断言（feature-configs 路径）。网关端到端留联调。
6. **跨 Story 证据说明**：TC-001/TC-002/TC-005/TC-006 的后端证据物理位于 STORY-006-02-01-01 的 ConfigCacheIntegrationTest（8 例计数归入该 Story 报告）与 mall-common-config 单测（12 例归入该 Story 报告），本报告不重复计数，仅做 AC 映射交叉引用。
