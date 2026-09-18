---
story-id: "STORY-006-02-01-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S2]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.1 [S2]/§4/§5
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0022
- Story ID: STORY-006-02-01-01 Redis 配置缓存与统一访问边界
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`（S2）

## 1. Story 目标

建立跨服务配置分发与消费的唯一通道：mall-system 配置更新后精确失效 Redis 缓存（key 规范 + TTL 10min + public-features 聚合键），提供 SERVICE 身份的内部批量查询端点（Redis→DB 回源回填）；mall-common 新增 mall-common-config 模块，提供 FeatureGate/SystemParameterProvider 类型安全读取（Redis→内部端点→代码安全默认值 + 60s 本地短缓存）。

## 2. Scope（范围）

### 2.1 包含

- [S2] mall-system ConfigCacheService：读 getFeature/getParameter（Redis→DB→回填，TTL 10min）、getPublicFeatures（聚合键）；ConfigChangedApplicationEvent 监听（AFTER_COMMIT）删除对应单键与聚合键。
- [S2] InternalConfigController：GET /api/internal/config/features?keys=a,b 与 /api/internal/config/parameters?keys=（SERVICE，X-Internal-Token），返回键值视图（不存在的键不返回或显式 missing，由 design 定）。
- [S2] mall-common/mall-common-config 新模块：RedisConfigReader（直连 Redis 读缓存值——仅读 Redis 缓存，不读 mall_system 库）、SystemConfigClient（缓存未命中调 mall-system 内部端点 RestClient + 令牌，经 mall-gateway? 否：直连服务 8108）、本地 Caffeine/ConcurrentHashMap 60s TTL 缓存。
- [S2] FeatureGate（isEnabled(key,defaultIfAbsent)、ensureEnabled(key) 抛 FeatureDisabledException）；SystemParameterProvider（getString/getInt/getLong/getDecimal/getBoolean(key,default)，类型解析失败返回默认+WARN）。
- [S2] mall-system pom 接入 mall-common-redis；application.yml 增加 Redis 配置（复用基础设施 Redis/db 序号约定）；自动配置 spring.factories/AutoConfiguration（参照其他 common 模块接入方式）。
- [S2] 消费方接线（仅依赖接入，不实现业务关闭语义）：mall-search、mall-cart pom 引入 mall-common-config 并配置 mall-system 地址。

### 2.2 不包含

- 开关关闭的业务拒绝与 public-features 端点（STORY-006-02-01-02）。
- Redis Pub/Sub 主动失效（M5 用更新删键 + 本地 60s TTL 收敛；Pub/Sub 列为后续增强，不做）。

## 3. 业务规则

- [读路径] 本地缓存(60s)→Redis(10min)→内部端点→DB 回源回填；全部失败 → 调用方传入的安全默认值 + WARN 日志（键名/异常）。
- [写后失效] DB 更新事务提交后：删 Redis 单键 + public-features 聚合键；其他服务最多经 60s 本地 TTL 收敛（Integration Gate 场景七允许"立即/有界时延"，search 等消费端可在管理操作后手动刷新，design 以 60s 为上限）。
- [不直库] 除 mall-system 外，任何服务不得配置 mall_system 数据源或 Config Mapper/DAO。
- [最小授权] 内部端点只返回请求的键；不提供写能力。
- [环境前缀] Redis key 统一 aimall:{env}:system:feature:{key} / parameter:{key} / public-features，env 取自 spring.profiles/既有约定。

## 4. 接口与字段规格

- GET /api/internal/config/features?keys=search.enabled,mall.guest-cart.enabled（SERVICE）→ {features:[{key,enabled}], missingKeys:[]}
- GET /api/internal/config/parameters?keys=...（SERVICE）→ {parameters:[{key,value,type}], missingKeys:[]}
- Redis 值：JSON 视图（含类型/版本），TTL 600s。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 首次读取后 Redis 出现规范 key 且 TTL≈600s；第二次读取不回源 DB（用日志/埋点或测试验证回源次数） |
| AC-002 | 后台更新开关/参数提交后，对应 Redis 单键与 public-features 聚合键被删除；下次读取得到新值 |
| AC-003 | 内部端点无令牌 401/403、经网关 404；只返回请求键；含不存在键时 missingKeys 正确 |
| AC-004 | mall-common-config：FeatureGate/SystemParameterProvider 在消费服务中可注入；类型读取正确；错误类型值返回默认且 WARN |
| AC-005 | Redis 与 mall-system 均不可用时，读取调用返回安全默认值，不抛异常、不中断业务请求 |
| AC-006 | 更新后消费端最长 60s 读到新值（本地 TTL 过期后经 Redis 读到新值）；测试可通过设短 TTL/手动失效验证 |
| AC-007 | mall-search/mall-cart 工程中无 mall_system 数据源/DAO 代码；mvn test 全绿 |
