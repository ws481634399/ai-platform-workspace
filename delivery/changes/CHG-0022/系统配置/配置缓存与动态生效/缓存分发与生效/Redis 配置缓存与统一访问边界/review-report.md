# Review Report（Story 级）— STORY-006-02-01-01 Redis 配置缓存与统一访问边界

## 0. 元信息

- Change ID：CHG-0022（M5 系统配置）
- Story ID：STORY-006-02-01-01 Redis 配置缓存与统一访问边界
- 审查时间：2026-09-19
- 审查者：sdd-review 独立评审 Agent（只读分析，未修改业务代码/测试/既有文档，未写 evidence.yaml）
- 审查输入：story-spec.md、story-design.md、test-design.md、implementation.md、evidence/test-report.md、evidence/evidence.yaml（EV-001~EV-002）；DU-BE-508 仓内 implementation.md；repo-1 提交 82ccf6e 源码抽查（mall-system、mall-common-config、mall-search、mall-cart、mall-gateway）
- 关联需求 AC：requirement-spec.md AC-008~AC-011

## 1. 检查结论

**通过（PASS）。** Story 7 条验收标准全部 passed；其中 AC-003/AC-005/AC-006/AC-007 的个别验证手段为等价替代或人工静态审计，均为 minor 覆盖深度项并已有去向。**无 blocker、无 major。**

### 1.1 需求一致性

| Story AC | 结论 | 证据与说明 |
| --- | --- | --- |
| AC-001 首读回填规范键、TTL≈600s、次读零回源 | passed | ConfigCacheIntegrationTest#fetchWritesRedis（键名 aimall:test:system:feature:search.enabled、TTL ∈[500,600]）、#secondReadHitsCache（旁路改库后仍读缓存旧值）；SystemConfigClientTest#redisHitThenLocalCache（Redis 访问 times(1)）。VALUE_TTL=600 为代码常量 |
| AC-002 AFTER_COMMIT 删单键+聚合键，再读新值 | passed（参数键独立 IT 缺，见建议 EV-005） | #updateEvictsCache（预热两键 → PUT 200 → awaitGone 双删 → 再读 enabled=false）；CacheEvictionListener 为 @TransactionalEventListener(AFTER_COMMIT) 同步监听；ConfigChangedEvent.parameter 发布点在 SystemParameterAppService 已源码核实，参数路径共用同一监听器 |
| AC-003 内部端点鉴权/网关 404/最小返回/missingKeys/keys 上限 | passed（网关为前缀级同构覆盖；错误码标注差异见建议 EV-004） | #internalRequiresToken（无 X-Internal-Token 4xx）、#keysValidation（空 keys、101 keys 均 400，MAX_KEYS=100）、#missingKeyNegativeCache、#parameterSnapshotContract（只返请求键、未请求不返回、缺失进 missingKeys）；网关 404 由 CHG0015GatewaySecurityChainTest 对 /api/internal/** 前缀 denyAll 的既有用例同构覆盖（匿名/ADMIN JWT 均 404），未对 config 子路径单独发 8080 请求 |
| AC-004 类型安全读取 + 坏值默认+WARN | passed（WARN 日志未断言，见建议 EV-005） | ConfigFacadesTest#providerFallbacks（getString/getInt/getLong/getDecimal/getBoolean：" 25 "→25、非法 "abc"→默认 20、缺键→20、"1"→true）、#errorCodeFrozen（B0601/B0602/B0603/B0604/B0606）；SystemConfigClientTest#httpParameterFullFieldNames（configValue/parameterType/minValue/maxValue 全名契约） |
| AC-005 全故障安全默认不抛 | passed（桩级注入，见建议 EV-005） | SystemConfigClientTest#allLayersDown（Redis 抛异常 + HTTP 指向 127.0.0.1:1 → Optional.empty 不抛）、#redisFailureAndHttpMissing；ConfigFacadesTest#gateDefaults（缺键 isEnabled 默认 true、ensureEnabled 放行） |
| AC-006 更新后 ≤60s 收敛；负缓存 60s | passed（1s 注入等价；多实例验证见建议 EV-006） | SystemConfigClientTest#localCacheExpires（localTtlSeconds=1 + sleep 1100ms 读到 version2 新值）、#redisNegativeMarkerCached；ConfigCacheIntegrationTest#missingKeyNegativeCache（{"missing":true}，TTL ∈[1,60]）；生产本地 TTL=60s 为 SystemConfigClient 常量 |
| AC-007 消费服务不直库 + 全量测试绿 | passed（静态人工审计，见建议 EV-007） | mall-search/mall-cart 仅 pom 引入 mall-common-config，src 内无 mall_system 数据源/DAO/Mapper（grep 0 命中）；两服务 SmokeTest#contextLoads 证明 AutoConfiguration 可装配；全 reactor 482/482 |

### 1.2 设计一致性

- DU-BE-508 五条 Deviation 逐条复核：
  - DEV-1（env 取 Spring Environment API，空 profiles 回落 dev）：**合理**。ConfigCacheService 以 getActiveProfiles()[0] 生成键前缀，消费/服务两侧环境语义一致，无新约定。
  - DEV-2（客户端只读 Redis 不回写，mall-system 为唯一写者）：**合理且更优**。避免多写者键内容/TTL 口径分裂，回填责任集中；与"统一访问边界"Story 目标一致。
  - DEV-3（仅单键查询门面、无批量分批；keys>100 直接 400）：**合理**。story-design §1 曾出现"超出分批"措辞，实现改为硬上限拒绝，攻击面/复杂度更小；消费端实际批量极小（4 个种子键，门面按单键调用），建议回修设计措辞（并入建议 EV-003 文档对齐项）。
  - DEV-4（evict 失败仅 warn 不阻断提交）：**合理**。删键失败由 600s TTL 与消费端 60s 本地 TTL 有界收敛兜底，管理写操作不被缓存故障拖垮；ConfigCacheService#evict catch 全部异常。
  - DEV-5（mall-system 直依赖 spring-boot-starter-data-redis，不经 mall-common-redis）：**合理**，已登记；仅引入所需 RedisTemplate 能力，无功能分歧。
- 冻结契约数值核对全部一致：Redis 键 `aimall:{env}:system:feature:{key}` / `:parameter:{key}` / `:public-features`；值 TTL 600s、负缓存 60s、消费端本地 60s（代码常量 + yml 默认一致）；内部端点 X-Internal-Token、keys 必填去重且 ≤100。
- fail-open 决策核实：FeatureGate#isEnabled 缺省 true、#ensureEnabled 仅对显式 false 抛 FeatureDisabledException；SystemConfigClient 读序"本地 ConcurrentHashMap(TTL) → Redis → RestClient 直连 8108（1s/3s 超时、带 X-Internal-Token）→ Optional.empty"，全故障由 Provider 回落调用方默认值并每键每分钟限一条 WARN。与冻结决策"仅显式 false 拦截"一致，无静默关闭风险。
- M5 明确不做 Redis Pub/Sub：全仓无 MessageListener/convertAndSend；story-spec §2.2 已明示，动态生效 = AFTER_COMMIT 删单键+聚合键 + 本地 60s TTL 有界收敛。
- 包络差异：requirement-design §2.3/§4 与 story-spec §4 写内部端点返回 `{features|parameters:[...]}`，story-design §2 冻结与实现为 `{values:{key:view},missingKeys:[]}`，见建议 EV-003。
- 鉴权安全核实：SystemSecurityConfiguration（@Profile("!test")）`/api/internal/**` hasRole("SERVICE")、`/api/mall/**` permitAll；InternalIdentityFilter（CHG-0015 既有）对 X-Internal-Token 常量时间比较，无/错凭证 401，网关 /api/internal/** denyAll——符合 security-guidelines.md「服务间内部端点隔离」全部要点（凭证独立、身份不通用、网关外拒、常量时间比较、密钥环境变量注入且默认值仅限本地开发）。

### 1.3 跨仓一致性

缓存分发链路逐环节源码核实，闭环一致：

1. 写路径（唯一写者）：FeatureConfigAppService/SystemParameterAppService 写 mall_system 库 → 同事务追加 history → 发布 ConfigChangedEvent → AFTER_COMMIT CacheEvictionListener 删除 Redis 单键 + 恒删 public-features 聚合键。
2. 读路径（跨服务）：mall-search/mall-cart 经 mall-common-config 自动配置（ConfigClientAutoConfiguration，@ConditionalOnProperty matchIfMissing=true）注入 FeatureGate/SystemParameterProvider → 本地 60s → Redis（仅读缓存值，不接 mall_system 数据源）→ HTTP 直连 mall-system 8108 内部端点带 X-Internal-Token → 默认值。
3. 配置一致：三服务 yml 的 Redis 连接、内部 token 默认值（dev-internal-secret，可由 MALL_INTERNAL_SHARED_SECRET / mall.config.internal-token 环境覆写）、8108 地址对齐；测试安全链与生产安全链等价。
4. 错误语义一致：B06 段错误码在 mall-common-config 的 ConfigErrorCode 统一定义，消费服务自动 advice 把 FeatureDisabledException 映射为 403 B0606。

### 1.4 代码质量

- 正向项（依据 standards/）：
  - Redis 槽位三态（值视图/负标记/不存在）区分清楚，负缓存防穿透、TTL 分层防永久脏读，符合 [缓存] 业务规则与 api-design-standard 的防御性设计。
  - 内部端点输入约束（必填、去重、上限 100、只返请求键）落实最小授权与最小数据返回，符合 security-guidelines.md。
  - 测试真实性：ConfigCacheIntegrationTest 使用 redis:7.4.11-alpine Testcontainers，真实断言 TTL 区间与删键/回填；SystemConfigClientTest 以 JDK HttpServer 桩验证真实 HTTP 头与全名契约，非全 mock 假证。
  - 统一 UnifyResult 错误体与错误码分段，符合 framework-standard.md §13.2/§13.4。
- 负面项：CacheEvictionListener 存在未使用 import（org.springframework.scheduling.annotation.Async；实际为同步监听、无 @Async），见建议 EV-008；其余为测试深度与架构自动化项（建议 EV-005/EV-007）。

### 1.5 知识同步候选（仅候选，沉淀由 sdd-converge 执行）

1. 配置中心边界模式：配置服务为唯一缓存写者（回源回填），消费端只读 Redis/HTTP + 本地短 TTL，禁止跨库直读。
2. TTL 分层：值 600s / 负缓存 60s / 消费端本地 60s 的数值依据与收敛语义。
3. "AFTER_COMMIT 精确删键（单键+聚合键）+ 本地 TTL 有界收敛"作为 Pub/Sub 的 M5 替代方案（故障面更小，代价是 ≤60s 时延）。
4. 内部批量查询端点契约：keys 必填/去重/≤100、missingKeys 显式返回、最小字段授权。

## 2. 发现清单

> review 阶段不写 evidence.yaml；下列 EV 编号为**建议登记号**（本 Story evidence.yaml 当前至 EV-002），供 converge/后续流程登记。minor 允许开放，均给出处理去向。

| 建议 EV | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-003 | requirement-design.md §2.3、§4；本 Story story-spec.md §4；InternalConfigController | minor | 内部端点响应包络文档写 `{features:[...]}` / `{parameters:[...]}` + missingKeys；story-design §2 冻结与实际实现为 `{values:{key:view},missingKeys:[]}`。唯一消费端 SystemConfigClient 在同一提交按 values 适配，20 例端到端测试全绿，无外部消费者受损 | sdd-converge 回修 requirement-design/story-spec 包络措辞与实现对齐；同步把 story-design §1"超出分批"措辞改为"keys 上限 100、超出 400"（DEV-3） |
| EV-004 | story-design.md §2；InternalConfigController javadoc；framework-standard.md §13.4 | minor | 设计与控制器 javadoc 标注 keys 空/超 100 返回 B0601 400；实际 IllegalArgumentException → GlobalExceptionHandler 返回 A 段参数校验码 400。HTTP 语义（400）与上限（100）正确，客户端不分支错误码；且 framework-standard §13.4 明确"参数校验异常 → HTTP 400 + A 段码"，实现符合标准 | 以框架标准为准，回修设计/javadoc 的错误码标注，代码无需改动 |
| EV-005 | evidence/test-report.md §4-2/§4-3/§4-5；SystemParameterAppService；SystemParameterProvider | minor | 覆盖深度合集：①参数（parameter 单键）更新失效无独立 IT，仅源码核实发布点共用同一监听器；②Provider 坏值/缺键"每键每分钟一条 WARN"限频无日志捕获断言；③"Redis+system 全失"为 Mockito 抛错 + 不可达端口的桩级注入，未做真实停容器后消费服务 MockMvc 200 | 后续测试增强：参数更新删键 IT、WARN 日志捕获断言；联调环境做真实停依赖演练 |
| EV-006 | evidence/test-report.md §4-7；story-spec.md §3 [写后失效] | minor | 多实例（多个消费副本各持本地缓存）跨节点收敛无容器编排级验证；单机以 Testcontainers Redis + 1s 本地 TTL 注入等价证明收敛逻辑，真实墙钟 60s/600s 按 test-design 标注不等待 | 部署/联调环境多副本验证 Integration Gate 场景七（更新后各副本 ≤60s 读到新值） |
| EV-007 | story-spec.md#AC-007；mall-search/mall-cart 源码树 | minor | "业务服务不直查 mall_system 库/无自建 Config DAO"目前以 grep/pom 人工静态审计 + contextLoads 佐证，无 ArchUnit 等自动化架构门禁，结论依赖审计时点 | 后续在消费服务引入架构测试（禁止 mall_system 数据源/Mapper 包依赖）固化该约束 |
| EV-008 | mall-system infrastructure/cache/CacheEvictionListener.java:4 | minor | 未使用 import org.springframework.scheduling.annotation.Async；类实际为同步 AFTER_COMMIT 监听（无 @Async），不影响行为 | 后续顺手清理该 import |

无 blocker / 无 major。

## 3. 完成确认

- [x] §1.1 Story 7 条 AC 逐条给出对照结论与可定位测试证据（ConfigCacheIntegrationTest 8、SystemConfigClientTest 7、ConfigFacadesTest 5、网关回归 2）
- [x] §1.2 DU-BE-508 五条 Deviations 全部复核且均有记录、结论合理；TTL/键名/鉴权/fail-open/Pub/Sub 边界等冻结契约逐项源码核对
- [x] §1.3 跨仓缓存分发链路（mall-system 唯一写者 → Redis → mall-common-config → mall-search/mall-cart）逐环节闭环核实
- [x] §1.4 代码质量发现均有 standards/ 依据（security-guidelines.md 内部端点隔离、framework-standard.md §13.4）
- [x] §1.5 知识同步候选已列出（4 项）
- [x] §2 发现清单 target 均可定位，minor 全部给出 resolution 去向
- [x] 无 blocker / 无 major；无未记录的实现偏离
- [x] 报告无残留占位符
