# Test Report — CHG-0022 M5 系统配置（功能开关 / 参数 / 缓存分发 / 动态生效）

> 阶段：sdd-test 产物（Change 级集成验收）。

## 0. 元信息

- Change ID：CHG-0022（M5 系统配置）
- 执行时间：2026-09-19
- 覆盖：3 个 Story 共 26 TC（S1 10 + S2 8 + S3 8）；M5 Integration Gate 场景六（功能开关动态生效）、场景七（缓存一致性），见 `docs/需求/M5/M5.md` L1395/L1415
- 实施来源：
  - repo-1：**82ccf6e**（DU-BE-507 配置模型/后台管理/审计 + identity V10 + 网关 admin 路由；DU-BE-508 mall-common-config 三级读客户端/内部端点/Redis 失效；DU-BE-509 public-features 端点 + search/cart 开关切点）
  - repo-2：**af19b9e**（DU-FE-504 mall-web features store fail-open/搜索入口/游客加购守卫）、**404eb77**（DU-FE-503 mall-admin 配置三页面）
- Evidence 索引：`evidence/evidence.yaml`（EV-001 repo-1 82ccf6e、EV-002 repo-2 af19b9e、EV-003 repo-2 404eb77）
- Story 级报告：3 份（路径见 §3 证据清单）

## 1. 测试范围（3 Story / 5 DU 分仓）

| Story | DU（仓库 / commit） | TC | 直接相关自动化用例（真实类#方法，已核对源码） |
| ----- | ------------------- | -- | --------------------------------------------- |
| STORY-006-01-01-01 配置模型、后台管理与变更审计 | DU-BE-507 repo-1 82ccf6e；DU-FE-503 repo-2 404eb77 | 10 | 后端 11：ConfigAdminApiTest 10（pageSeededFeatures、createFeatureAndDuplicate、createFeatureInvalidName、updateFeatureCas、deleteFeature、pageSeededParameters、createParameterValidation、updateAndDeleteParameter、historyFilterAndAuth、authenticationAndAuthorization）+ MallSystemApplicationSmokeTest#contextLoads 1；前端 12：mall-admin src/api/config.spec.ts 12 |
| STORY-006-02-01-01 Redis 配置缓存与统一访问边界 | DU-BE-508 repo-1 82ccf6e | 8 | 后端 20：ConfigCacheIntegrationTest 8（internalRequiresToken、fetchWritesRedis、secondReadHitsCache、missingKeyNegativeCache、keysValidation、parameterSnapshotContract、updateEvictsCache、publicFeatures，Redis 7.4.11 Testcontainers）+ SystemConfigClientTest 7（redisHitThenLocalCache、redisNegativeMarkerCached、redisMissFallbackToHttp、httpParameterFullFieldNames、redisFailureAndHttpMissing、allLayersDown、localCacheExpires）+ ConfigFacadesTest 5（gateRejectsExplicitDisabled、gateAllowsExplicitEnabled、gateDefaults、providerFallbacks、errorCodeFrozen） |
| STORY-006-02-01-02 功能开关动态生效与前端公开配置 | DU-BE-509 repo-1 82ccf6e；DU-FE-504 repo-2 af19b9e | 8 | 后端 4：SearchFeatureGateTest 2（searchDisabledReturns403、searchEnabledPasses）+ GuestCartFeatureGateTest 2（guestCartDisabledRejectsMergeEndpoints、guestCartEnabledAndMemberUnaffected）；前端 9：features.spec.ts 3 + ProductDetailView.spec.ts 6（含 FE-504 新增游客加购拦截 2 例） |

TC 编号与各 Story `test-design.md` 逐字一致；逐条 TC→用例/AC 映射与部分覆盖项见 3 份 Story 级报告。

## 2. 测试执行汇总

| 范围 | 命令 | 结果 |
| ---- | ---- | ---- |
| 后端全 reactor | `mvn test -B -ntp`（TESTCONTAINERS_RYUK_DISABLED=true；Redis Testcontainers redis:7.4.11-alpine） | **BUILD SUCCESS，14 个有测试模块 482/482，0 Failures / 0 Errors**（2026-09-19 01:42） |
| 后端·本 Change 直接相关 | 同上 | **35/35 全过**：mall-system **19/19**（ConfigAdminApiTest 10 + ConfigCacheIntegrationTest 8 + Smoke 1）、mall-common-config **12/12**（7+5）、mall-search SearchFeatureGateTest **2**（mall-search 总 32/32）、mall-cart GuestCartFeatureGateTest **2**（mall-cart 总 55/55） |
| mall-admin | vitest / vue-tsc / eslint / build | vitest **16 files 47/47**（含 config.spec.ts 12）；type-check 0 error；lint 0 error（221 warnings）；build SUCCESS |
| mall-web | vitest / vue-tsc / eslint / build | vitest **21 files 102/102**（含 features.spec.ts 3、ProductDetailView.spec.ts 6）；type-check 0 error；lint 0 error（65 warnings）；build SUCCESS |
| 前端·本 Change 直接相关 | 同上 | **21/21 全过**：config.spec 12 + features.spec 3 + ProductDetailView.spec 6 |

- 自动化用例通过率：**100%**（已执行用例无失败/错误/跳过）。
- 覆盖口径说明：3 个 Story 的 26 TC 中，S1 用例003/S1 用例007/S1 用例009 与 S3 用例003/S3 用例005/S3 用例008 标注 partial，含义为 TC 验证意图与对应用例间存在覆盖深度/执行环境差异（如四指名非法值仅 2 例逐字、页面无组件测试、网关链路静态核实），**不是执行失败**；明细与风险评估见各 Story 报告 §4 与本报告 §5。

## 3. 证据清单（真实路径）

| 证据 | 路径（相对 `delivery/changes/CHG-0022/evidence/`） | 关键内容 |
| ---- | ------------------------------------------------- | -------- |
| 后端全量日志 | `../CHG-0020/evidence/logs/backend-full-test.log`（跨 Change 引用） | 24 模块 Reactor Summary 全 SUCCESS；surefire 行：mall-system 19（ConfigAdminApiTest 10/ConfigCacheIntegrationTest 8/Smoke 1）、mall-common-config 12（5+7）、mall-search 32（SearchFeatureGateTest 2）、mall-cart 55（GuestCartFeatureGateTest 2）；14 个模块聚合行求和 482 |
| mall-admin vitest | `logs/mall-admin-vitest.log` | Test Files 16 passed (16)、Tests 47 passed (47)；config.spec.ts (12 tests) |
| mall-admin type-check | `logs/mall-admin-type-check.log` | vue-tsc 双 tsconfig，0 error |
| mall-admin lint | `logs/mall-admin-lint.log` | 0 errors，221 warnings |
| mall-admin build | `logs/mall-admin-build.log` | ✓ built（vite） |
| mall-web vitest | `../CHG-0020/evidence/logs/mall-web-vitest.log` | Test Files 21 passed (21)、Tests 102 passed (102)；features.spec.ts (3 tests)、ProductDetailView.spec.ts (6 tests) |
| mall-web type-check / lint / build | `../CHG-0020/evidence/logs/mall-web-type-check.log`、`mall-web-lint.log`（0 error，65 warnings）、`mall-web-build.log`（✓ built） | 全绿 |
| Evidence 索引 | `evidence/evidence.yaml` | EV-001/002/003 code-change 三 commit |
| Story 报告 1 | `../系统配置/功能开关与参数管理/配置管理与审计/配置模型、后台管理与变更审计/evidence/test-report.md` | 10 TC / 8 AC |
| Story 报告 2 | `../系统配置/配置缓存与动态生效/缓存分发与生效/Redis 配置缓存与统一访问边界/evidence/test-report.md` | 8 TC / 7 AC |
| Story 报告 3 | `../系统配置/配置缓存与动态生效/缓存分发与生效/功能开关动态生效与前端公开配置/evidence/test-report.md` | 8 TC / 7 AC |
| 需求依据 | `docs/需求/M5/M5.md` | 场景六 L1395、场景七 L1415 |

## 4. M5 Integration Gate 场景映射

### 场景六：功能开关动态生效（ON 正常 → 后台 OFF → Cache Refresh → 功能关闭）

| 环节 | 期望 | 自动化证据（真实方法名） | 结果 |
| ---- | ---- | ------------------------ | ---- |
| ON 正常 | 开关开启时业务可用 | SearchFeatureGateTest#searchEnabledPasses（mock 放行，GET /api/mall/search/products 200 $.success=true）；GuestCartFeatureGateTest#guestCartEnabledAndMemberUnaffected（开启态 merge-token 200、会员 /cart/items 200） | passed |
| 后台改 OFF | 管理端 PUT 提交成功、版本递增、留审计 | ConfigAdminApiTest#updateFeatureCas（enabled true→false，version 0→1，UPDATED 历史 old=true/new=false/changeReason；过期 version 409 B0604） | passed |
| Cache Refresh（失效分发） | 事务提交后 Redis 单键 + public-features 聚合键删除；消费端最迟本地 60s TTL 收敛 | ConfigCacheIntegrationTest#updateEvictsCache（预热 aimall:test:system:feature:search.enabled 与 aimall:test:system:public-features → PUT 200 → awaitGone 双键均删 → 再读回源 enabled=false）；SystemConfigClientTest#localCacheExpires（注入 localTtlSeconds=1 + sleep 1100ms → version1 true 变为 version2 false，Redis 访问 2 次） | passed（单节点容器） |
| 功能关闭（后端权威） | 绕过前端直调 API 返回 403 B0606 FEATURE_DISABLED 统一结构 | SearchFeatureGateTest#searchDisabledReturns403（doThrow FeatureDisabledException → 403 $.code=B0606，不进入 ES）；GuestCartFeatureGateTest#guestCartDisabledRejectsMergeEndpoints（merge-token、merge 均 403 B0606）；ConfigFacadesTest#gateRejectsExplicitDisabled（ensureEnabled 抛 FeatureDisabledException 且带 featureKey）、#errorCodeFrozen（B0606 冻结） | passed |
| fail-open 语义 | 仅显式 false 拦截；缺键/Redis+system 全失按代码默认（启用）放行并 WARN，业务不中断 | ConfigFacadesTest#gateDefaults（empty 缺键 isEnabled 默认 true、ensureEnabled 不抛；显式保守默认 false 时可拦截）；SystemConfigClientTest#allLayersDown（Redis 抛异常 + HTTP 不可达 → empty 不外抛）、#redisFailureAndHttpMissing | passed（桩级） |
| 前端联动 | store 两态；关闭态游客加购禁用+登录引导；端点异常不白屏 | features.spec.ts 3 例（未加载 fallback=true、load 成功 key→enabled 映射含 search.enabled=false、load 失败静默 fail-open）；ProductDetailView.spec.ts 新增 2 例（游客+关闭：add-cart-btn disabled + guest-cart-blocked-hint「游客购物车暂未开放/请登录后加购」+ addItem 0 调用；缺省 fail-open：无拦截提示） | passed（store/组件局部） |
| 公开开关来源 | 匿名 public-features 仅 publicFlag 键 | ConfigCacheIntegrationTest#publicFeatures（200；search.enabled、mall.guest-cart.enabled 出现；internal.flag 非公开不出现；禁用公开项 enabled=false 返回） | passed |
| 未覆盖段 | 浏览器中「管理端关闭 → mall-web 入口实时隐藏 → 重开恢复」整链；MallLayout.vue v-if（mall-search-link）、SearchView.vue search-closed 空态仅有实现无组件测试 | 列入联调（§5-②） | 联调 |

> 机制澄清：M5 设计（STORY-006-02-01-01 story-spec §2.2/story-design）**明确不实现 Redis Pub/Sub 主动失效**，全仓亦无 MessageListener/convertAndSend 代码；"Cache Refresh"环节的真实实现是 mall-system CacheEvictionListener 的 `@TransactionalEventListener(AFTER_COMMIT)` 删除 Redis 单键 + 恒删聚合键，消费服务靠本地 60s TTL 自然收敛。

### 场景七：缓存一致性（Config=10 读到 10 → 改 20 → 缓存失效 → 读到 20，不长期读旧值）

| 环节 | 期望 | 自动化证据（真实方法名） | 结果 |
| ---- | ---- | ------------------------ | ---- |
| 读到 10：回源回填 | 首次读回源 DB，写规范键 TTL≈600s | ConfigCacheIntegrationTest#fetchWritesRedis（aimall:test:system:feature:search.enabled 值含 "enabled":true，TTL ∈[500,600]，missingKeys 无）；客户端 SystemConfigClientTest#redisHitThenLocalCache（Redis 命中后二次读仅访问 1 次 Redis） | passed |
| 缓存读语义 | TTL 内走缓存、零回源 | ConfigCacheIntegrationTest#secondReadHitsCache（绕过应用直改库 enabled=0，600s 内二次读仍旧值 true，反证命中缓存）；SystemConfigClientTest#redisNegativeMarkerCached（负结论同样入本地缓存，不穿透 HTTP） | passed |
| 改为 20 | 管理端改值成功 + CAS + 参数同构 | ConfigAdminApiTest#updateFeatureCas（开关）、#updateAndDeleteParameter（search.default-page-size 20→50，version 0→1）、#createParameterValidation（越界/非法值 400 B0601 被拒、不写入数据库） | passed |
| 缓存失效 | 提交后单键 + 聚合键立即删除 | ConfigCacheIntegrationTest#updateEvictsCache（awaitGone 单键/聚合键；AFTER_COMMIT 同步监听，提交返回即删；evict 失败仅 warn 不阻断）；参数键共用同一监听器（ConfigChangedEvent.parameter，无独立 IT，见 Story2 报告 §4-5） | passed |
| 读到 20 | 下次读取回源得新值并重建 TTL | ConfigCacheIntegrationTest#updateEvictsCache（失效后再读 values.enabled=false）；SystemConfigClientTest#localCacheExpires（本地 TTL 到期重新回源，true→false） | passed |
| 不长期读旧值 | 上界 = 本地 60s TTL + 提交即失效；缺失键负缓存 60s 防穿透 | SystemConfigClientTest#localCacheExpires（1s 注入等价）；ConfigCacheIntegrationTest#missingKeyNegativeCache（{"missing":true}，TTL ∈[1,60]，missingKeys 正确）；parameterSnapshotContract（configValue/parameterType/minValue/maxValue 全名契约 + 缺键进 missingKeys）；keysValidation（空 keys/101 键 400） | passed（墙钟 60s/600s 不等待，区间断言） |
| 故障不破坏一致性 | Redis/system 全失不抛、按默认值服务 | SystemConfigClientTest#allLayersDown、#redisFailureAndHttpMissing；ConfigFacadesTest#gateDefaults、#providerFallbacks（坏类型值回退默认） | passed（桩级） |
| 边界约束 | 内部端点最小授权；消费服务不直库 | ConfigCacheIntegrationTest#internalRequiresToken（无 X-Internal-Token 4xx）；网关 CHG0015GatewaySecurityChainTest#internalAnonymousReturns404/#internalWithAdminTokenStill404（/api/internal/** 前缀 404 回归）；search/cart 无 mall_system 数据源/DAO（静态 grep） | passed |

## 5. 缺口与说明

1. **多实例跨节点缓存收敛未做容器编排级验证**：M5 按设计不引入 Redis Pub/Sub（story-spec §2.2 明确列为后续增强），跨节点一致性机制为「AFTER_COMMIT 删 Redis 单键 + public-features 聚合键，消费端本地 60s TTL 收敛」。单机自动化中，ConfigCacheIntegrationTest 以**单节点** redis:7.4.11-alpine Testcontainers 验证了提交后删键（updateEvictsCache）、TTL 600s（fetchWritesRedis，[500,600]）与负缓存 60s（missingKeyNegativeCache，[1,60]）；消费端本地 60s 兜底以 SystemConfigClientTest#localCacheExpires 注入 1s TTL 等价验证（真实墙钟 60s/600s 不等待，符合 S2 test-design §3 自标注不可测项）。真实多实例（多个消费服务副本同时持有本地缓存）经容器编排的跨节点生效验证未在本机执行，留联调/部署环境。
2. **三管理页浏览器端到端操作在联调阶段验证**：mall-admin 功能开关/系统参数/变更历史三页面的渲染、开关切换、类型表单（number/json/bool）校验与范围提示、历史筛选等交互无 Vitest 组件测试；自动化仅覆盖共享 api/config.ts 的 12 例（参数序列化、version 乐观锁、B0602/B0604/403 错误归一化）。同理 mall-web 的搜索入口 v-if 显隐（MallLayout）与 /search 关闭空态（SearchView）也仅有 store 级 3 例，无布局/页面组件测试。
3. **前端 config 历史页（及同域另两页）仅 api 层 12 例单测**：配置域前端组件交互无组件测试；config.spec.ts 12 例全部针对 src/api/config.ts（含 configHistoryApi page 透传 configType/key 与 B0604「请刷新后重试」引导），历史页变更前后对比渲染、操作人/原因/时间展示未做组件断言。
4. **其他部分覆盖项（明细见 Story 报告 §4）**：S1 用例001 迁移以 H2(MODE=MySQL) 替代 testcontainers MySQL；S1 用例003 四指名非法值中 INTEGER 写 "abc"、BOOLEAN 写 "yes" 无逐字用例（越界、非法 JSON 精确覆盖，类型非法以 DATETIME/"x" 等价）；S1 用例007 identity V10 权限/菜单种子仅 SQL 静态核实无迁移断言；S3 用例004 游客车服务端切点实际落在 merge-token/merge（M4 游客数据服务端唯一入口），匿名加购拦截以前端禁用+登录引导实现；S3 用例008 网关 public-features 200/admin 401 链路为配置静态核实 + 直连服务 401 自动化。以上均为覆盖深度/环境差异，已执行用例通过率仍为 100%，无失败项。
