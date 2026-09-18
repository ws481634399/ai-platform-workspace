# Test Report — STORY-006-02-01-01 Redis 配置缓存与统一访问边界

> 阶段：sdd-test 产物。

## 0. 元信息

- Change ID：CHG-0022（M5 系统配置）
- Story ID：STORY-006-02-01-01
- 执行时间：2026-09-19（后端全 reactor 实跑；Redis 集成测试经 Testcontainers 真实拉起容器）
- 覆盖：AC-001~AC-007；test-design.md TC-001~TC-008
- 实施来源：repo-1 DU-BE-508（82ccf6e）
- 直接相关测试：ConfigCacheIntegrationTest **8/8**（redis:7.4.11-alpine Testcontainers + H2）、SystemConfigClientTest **7/7**、ConfigFacadesTest **5/5**，共 **20/20 全过**
- 契约核实：Redis 键 `aimall:{env}:system:feature:{key}` / `:parameter:{key}` / `:public-features`；值 TTL 600s、负标记 `{"missing":true}` TTL 60s；消费端本地缓存 60s；内部端点 X-Internal-Token（SERVICE）；fail-open（仅显式 false 拦截）；错误码 B0601~B0606

## 1. 测试范围

TC 编号与本 Story `test-design.md` §1 逐字一致；证据列映射真实测试类#方法名（已逐一核对源码，无编造）。

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| TC-001 | 集成（testcontainers Redis）：首次 getFeature → 回源并写入 `aimall:{env}:system:feature:{key}`，TTL 断言 ≈600s；第二次读取 DB/HTTP 零回源（计数断言） | Testcontainers Redis 7.4.11 + MockMvc；客户端 JDK HttpServer 桩 | passed | ConfigCacheIntegrationTest#fetchWritesRedis（回源 200、键名 aimall:test:system:feature:search.enabled、TTL ∈[500,600]）、#secondReadHitsCache（旁路直改库后二次读仍为缓存旧值，证明零回源）；SystemConfigClientTest#redisHitThenLocalCache（首次读 Redis 后二次读仅访问 1 次 Redis，verify times(1)） |
| TC-002 | 集成：后台更新开关/参数提交后断言 Redis 单键与 public-features 聚合键被删除；再读得到新值且 TTL 重建 | Testcontainers Redis + MockMvc（AFTER_COMMIT 同步监听） | passed（参数键路径共用监听器但无独立 IT，见 §4-5） | ConfigCacheIntegrationTest#updateEvictsCache（预热单键+聚合键 → PUT search.enabled=false 200 → awaitGone 两键均删除 → 再读回源得 enabled=false）；回填 TTL 重建逻辑同 #fetchWritesRedis。对应 Integration Gate 场景七 |
| TC-003 | API：内部 features/parameters 端点无 SERVICE 令牌 401/403、经网关 404；只返回请求键；含不存在键 → missingKeys；keys>100 → 400 | MockMvc + 网关回归 | passed（网关为前缀级既有用例，见 §4-1） | ConfigCacheIntegrationTest#internalRequiresToken（无 X-Internal-Token → 4xx）、#keysValidation（keys 空白 400；101 键 400）、#missingKeyNegativeCache（missingKeys 含 not.exist.key）、#parameterSnapshotContract（只返请求键；未播种的 cart.max-item-quantity 进 missingKeys）、#fetchWritesRedis（存在键 missingKeys 不存在）；网关：CHG0015GatewaySecurityChainTest#internalAnonymousReturns404、#internalWithAdminTokenStill404（/api/internal/** 前缀规则，匿名/ADMIN 均 404，全 reactor 19 例网关回归内） |
| TC-004 | 单测/集成：在消费服务测试中注入 FeatureGate/Provider，getString/getInt/getLong/getDecimal/getBoolean 正确；错误类型值 → default + WARN | Mockito 单测 + HTTP 桩 | passed（WARN 限频未断言，见 §4-2） | ConfigFacadesTest#providerFallbacks（getInt " 25 "→25、非法 "abc"→默认 20、缺键→20、getString 默认、getLong、getDecimal 19.90、getBoolean "1"→true）、#gateAllowsExplicitEnabled（显式 true 放行）、#gateRejectsExplicitDisabled（显式 false 抛 FeatureDisabledException 带 featureKey）、#errorCodeFrozen（B0601/B0602/B0603/B0604/B0606 冻结）；SystemConfigClientTest#httpParameterFullFieldNames（configValue/parameterType/minValue/maxValue 全名契约解析）、#redisMissFallbackToHttp（携带 X-Internal-Token=dev-internal-secret） |
| TC-005 | 韧性：停 Redis 且 HTTP 端点 503 → 读取返回代码默认不抛、业务请求 200；ensureEnabled 缺键默认放行 WARN | Mockito + 不可达 HTTP 端口单测 | passed（桩级故障注入，非真实停容器，见 §4-3） | SystemConfigClientTest#allLayersDown（Redis 抛异常 + HTTP 指向 127.0.0.1:1 不可达 → getFeature/getParameter 返回 empty 不抛）、#redisFailureAndHttpMissing（Redis 异常 + HTTP 回 missingKeys → empty）；ConfigFacadesTest#gateDefaults（缺键 isEnabled 默认 true、ensureEnabled 不抛；显式保守默认 false 可拦截） |
| TC-006 | 集成：本地短 TTL（测试覆盖置 60s 逻辑用可配置 TTL 注入 100ms）更新后消费端尽快拿到新值，最长不超过本地 TTL；负缓存（missing key 60s）生效 | 可注入 localTtlSeconds 单测 + Testcontainers | passed（实际注入 1s 非 100ms，逻辑等价，见 §4-4） | SystemConfigClientTest#localCacheExpires（localTtlSeconds=1 + sleep 1100ms 后重新回源，version1 true→version2 false，Redis 访问 2 次）；ConfigCacheIntegrationTest#missingKeyNegativeCache（负标记 {"missing":true}，TTL ∈[1,60]）；SystemConfigClientTest#redisNegativeMarkerCached（负结论入本地缓存，不穿透 HTTP） |
| TC-007 | 静态：mall-search/mall-cart pom 与源码无 mall_system 数据源/DAO/Mapper；仅依赖 mall-common-config | 静态审计（grep/pom）+ 上下文加载佐证 | passed（人工静态门禁，无 ArchUnit 自动化，见 §4-6） | mall-search/mall-cart 仅 pom 引入 mall-common-config、src 内无 mall_system 数据源/DAO/Mapper（grep 0 命中）；切点接线见 CartController（featureGate.ensureEnabled）、ProductSearchService；AutoConfiguration 生效由 MallSearchApplicationSmokeTest#contextLoads、MallCartApplicationSmokeTest#contextLoads 上下文加载佐证（在 search 32 例、cart 55 例内） |
| TC-008 | 构建门禁：mvn test（mall-system + common-config + 消费服务）全绿；AutoConfiguration.imports 生效的上下文加载测试 | mvn 全 reactor | passed | 全 reactor `mvn test -B -ntp` BUILD SUCCESS 14 模块 482 例：mall-system 19/19（本 IT 8）、mall-common-config 12/12、mall-search 32/32（含 SearchFeatureGateTest 2，归属 Story3）、mall-cart 55/55（含 GuestCartFeatureGateTest 2，归属 Story3）；MallSystemApplicationSmokeTest#contextLoads 与消费服务两 SmokeTest 验证 ConfigClientAutoConfiguration（AutoConfiguration.imports）可装配 |

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-system | 全 reactor `mvn test -B -ntp`（TESTCONTAINERS_RYUK_DISABLED=true，Redis 7.4.11 Testcontainers） | ConfigCacheIntegrationTest **8/8**；mall-system 合计 19/19 |
| mall-common-config | 同上 | **12/12**（SystemConfigClientTest 7 + ConfigFacadesTest 5） |
| 消费服务佐证 | 同上 | mall-search **32/32**、mall-cart **55/55**（开关切点 2+2 的 AC 归属见 Story3 报告；此处取上下文加载与不直库佐证） |
| 全 reactor | 同上 | **482/482**，0 Failures / 0 Errors，BUILD SUCCESS（2026-09-19 01:42） |
| 日志 | `../../../../../../CHG-0020/evidence/logs/backend-full-test.log`（跨 Change 引用；含 ConfigFacadesTest 5、SystemConfigClientTest 7、ConfigCacheIntegrationTest 8 的 Tests run 行） | 完整输出 |

## 3. AC 覆盖

| AC | 验收标准（摘自 story-spec §5） | 覆盖 TC | 结论 |
|----|--------------------------------|---------|------|
| AC-001 | 首次读取后 Redis 出现规范 key 且 TTL≈600s；第二次读取不回源 DB | TC-001 | passed（服务端 TTL ∈[500,600] + 旁路改库证明命中；客户端 times(1) 计数） |
| AC-002 | 后台更新提交后，对应 Redis 单键与 public-features 聚合键被删除；下次读取得到新值 | TC-002 | passed（AFTER_COMMIT 删双键 + 再读新值；参数键路径见 §4-5） |
| AC-003 | 内部端点无令牌 401/403、经网关 404；只返回请求键；含不存在键时 missingKeys 正确 | TC-003 | passed（网关断言为 /api/internal/** 前缀级回归） |
| AC-004 | FeatureGate/SystemParameterProvider 可注入；类型读取正确；错误类型值返回默认且 WARN | TC-004、TC-008 | passed（五类型读取与坏值回退均断言；WARN 日志本身未断言） |
| AC-005 | Redis 与 mall-system 均不可用时，读取返回安全默认值，不抛异常、不中断业务请求 | TC-005 | passed（客户端/门面级全链路 down 不抛；消费服务真实 HTTP 200 未做停容器 IT） |
| AC-006 | 更新后消费端最长 60s 读到新值；测试可通过设短 TTL/手动失效验证 | TC-006 | passed（1s 注入 TTL 等价验证；负缓存 TTL ∈[1,60]） |
| AC-007 | mall-search/mall-cart 工程中无 mall_system 数据源/DAO 代码；mvn test 全绿 | TC-007、TC-008 | passed（静态 grep 审计 + 482 全绿 + 上下文加载） |

## 4. 缺口备注

1. **TC-003 网关 404 非 config 专属用例**：CHG0015GatewaySecurityChainTest 的两条 404 用例请求路径为 `/api/internal/inventory/lock`，以 `/api/internal/**` 前缀 denyAll 规则同构覆盖 config 内部端点；未对 `/api/internal/config/features|parameters` 单独经 8080 发请求。
2. **TC-004 WARN 日志未断言**：Provider 坏值/缺键回退默认的"每键每分钟限一条 WARN"为实现层逻辑，测试只断言返回值，未做日志捕获断言。
3. **TC-005 故障为桩级注入**：Redis 层以 Mockito 抛 RuntimeException、HTTP 层指向不可达端口模拟"Redis+system 全失"，未真实停止 Redis 容器/停 8108 服务后在消费服务发 MockMvc 请求断言 200；fail-open 不抛、返回 empty/默认值的核心语义已在单测闭环。
4. **TC-006 短 TTL 取值差异**：test-design 示例注入 100ms，实际用例注入 1s 并 sleep 1100ms，验证逻辑等价（到期重取、读到新值）；真实墙钟 60s/600s 不等待，与 test-design §3「TC-NOT-TESTABLE: 真实墙钟 60s」标注一致，TTL 以区间断言替代。
5. **TC-002 参数键失效无独立 IT**：updateEvictsCache 的删键断言对象为 feature 单键 + public-features 聚合键；参数（parameter 单键）失效共用同一 CacheEvictionListener（ConfigChangedEvent.parameter 发布点已在 SystemParameterAppService 核实），未单独构造参数更新 IT。
6. **TC-007 静态审计非自动化门禁**：消费服务不直库以 grep/pom 人工审计确认，仓库无 ArchUnit/架构测试自动断言；自动化佐证为两消费服务 contextLoads（FeatureGate Bean 经 AutoConfiguration 成功注入）。
7. **Redis Pub/Sub 不在 M5 范围**：story-spec §2.2 与 story-design 明确「Redis Pub/Sub 主动失效列为后续增强，不做」，全仓 grep 无 MessageListener/convertAndSend 等发布订阅代码；跨节点一致性机制为「AFTER_COMMIT 删 Redis 单键+聚合键 + 消费端本地 60s TTL 收敛」。真实多实例（多个消费副本各持本地缓存）容器编排级验证未在单机自动化执行，留联调/部署环境（与 Change 报告 §5 缺口①一致）。
