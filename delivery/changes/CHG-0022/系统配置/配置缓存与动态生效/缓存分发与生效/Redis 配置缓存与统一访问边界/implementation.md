# Implementation（跨仓实施汇总）— Redis 配置缓存与统一访问边界 STORY-006-02-01-01

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0022（M5 系统功能与参数配置）
- Story：STORY-006-02-01-01 Redis 配置缓存与统一访问边界
- 实施日期：2026-09-18

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-508 | repo-1 | mall-common-config 新模块（SystemConfigClient 三级读/FeatureGate/SystemParameterProvider/AutoConfiguration + B0606 advice）；mall-system ConfigCacheService（Redis 唯一读写者、槽位三态、负缓存、聚合键）、AFTER_COMMIT 同步失效监听、内部双端点（X-Internal-Token）；search/cart 仅 pom 接入不直库；SystemConfigClientTest 7、ConfigFacadesTest 5、ConfigCacheIntegrationTest 8（真实 Redis 7 容器，源码清点） |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 82ccf6e | DU-BE-508 | repo-1 | M5 三 Change 合并提交，含 mall-common-config 新模块、mall-system 缓存服务/槽位视图/失效监听/内部端点 |

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0022/系统配置/配置缓存与动态生效/缓存分发与生效/Redis 配置缓存与统一访问边界/DU-BE-508/implementation.md`
  - 冻结键：`aimall:{env}:system:feature:{key}`、`aimall:{env}:system:parameter:{key}`、`aimall:{env}:system:public-features`；值 TTL 600s、负标记 `{"missing":true}` TTL 60s；env 经 Environment.getActiveProfiles()[0] 解析，空则 dev
  - 消费侧三级读：本地 ConcurrentHashMap 60s（localTtlSeconds，无清理线程）→ Redis StringRedisTemplate（异常降级）→ RestClient 直连 http://localhost:8108（X-Internal-Token，1s/3s 超时）；HTTP 成功不回写 Redis，回填统一在 mall-system 侧
  - GET `/api/internal/config/features`、`/parameters?keys=`：keys 必填/去重/≤100 否则 400；响应 `{values:{key:view},missingKeys:[]}`；ParameterCacheView 全名 configValue/parameterType/minValue/maxValue（客户端同时兼容 value/type 短名）
  - CacheEvictionListener `@TransactionalEventListener(AFTER_COMMIT)` 同步删单键 + 恒删聚合键；evict 删 Redis 失败仅 warn 不阻断
  - FeatureGate fail-open（仅显式 false 抛 FeatureDisabledException B0606/403）；Provider 五类型必传默认值、解析失败回退 + 每键每分钟限一条 WARN
  - mall-search、mall-cart 仅在 pom 引 mall-common-config，src 内 grep `mall_system|mall-system` 0 命中

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | testcontainers 真实 Redis：首次内部读取回源 DB 并回填规范键，TTL 断言 ∈[500,600]；第二次读取命中缓存不回源；客户端侧 Redis 命中后本地缓存二次读零回源 | passed（fetchWritesRedis、secondReadHitsCache、SystemConfigClientTest.redisHitThenLocalCache） |
| AC-002 | 管理端 PUT 事务提交后 AFTER_COMMIT 监听器删除单键与 public-features 聚合键，再读回源得新值；消费侧本地 60s TTL 到期重新回源 | passed（updateEvictsCache、SystemConfigClientTest.localCacheExpires） |
| AC-003 | 内部端点无 X-Internal-Token 拒绝；keys 空白与 101 键 400；只返回请求键，缺键进 missingKeys；参数快照断言 configValue/parameterType/min/max；网关 `/api/internal/**` denyAll | passed（internalRequiresToken、keysValidation、parameterSnapshotContract、missingKeyNegativeCache） |
| AC-004 | FeatureGate/SystemParameterProvider 经 AutoConfiguration 在消费服务可注入；HTTP 视图全名字段解析正确；坏类型值（如非整数 INTEGER）回退默认且 WARN | passed（ConfigFacadesTest.gateAllowsExplicitEnabled、providerFallbacks、SystemConfigClientTest.httpParameterFullFieldNames） |
| AC-005 | Redis 异常、HTTP 缺键/不可达（全链路 down）均不外抛，Gate/Provider 返回调用方默认值（默认 true）继续业务 | passed（redisFailureAndHttpMissing、allLayersDown、gateDefaults） |
| AC-006 | 本地短 TTL 60s 到期重取（测试以 1s TTL + sleep 验证到期回源）；不存在键负标记 TTL ∈[1,60] 防透传；配合 AC-002 删键，最坏 60s 收敛 | passed（localCacheExpires、missingKeyNegativeCache） |
| AC-007 | 静态门禁：mall-search/mall-cart 无 mall_system 数据源/DAO/Mapper（grep 0 命中），仅声明 mall-common-config 依赖；测试计数 7+5+8=20 例（源码清点，缓存 IT 需 Docker，未在本次回填环境重跑） | passed（SystemConfigClientTest 7、ConfigFacadesTest 5、ConfigCacheIntegrationTest 8） |
