---
affected-repositories: [repo-1, repo-2]
---

# Requirement Design（需求级方案设计）

> 层级：Requirement 级产物——本次 Change 的技术方案骨架
> 业界锚点：ADR（Context → Decision → Alternatives → Consequences）+ 跨仓影响面
> 输入：requirement-spec.md + exploration.md + product/11 细案 + CHG-0013 RBAC/CHG-0018 购物车/CHG-0020 搜索
> 产出状态：designed
> 分层关系：本文是 Requirement 级；各 Story 详细设计见 Story 目录 story-design.md。

## 0. 元信息

- Change ID: CHG-0022
- spec 来源: CHG-0022/requirement-spec.md（REQ-M5-003 系统功能与参数配置）
- 相关仓库: repo-1（ai-platform-backend：mall-system 新服务、mall-common-config 新模块、mall-gateway、mall-identity、mall-search、mall-cart 消费接线）、repo-2（ai-platform-frontend：mall-admin 三页面、mall-web 公开开关）
- 受影响仓库数: 2
- 需要 Migration: yes（mall_system 库 Flyway V1：feature_config/system_parameter/system_config_history + 种子；mall-identity V10：system:* 五权限码 + 菜单）

## 1. 当前状态

- mall-services/mall-system（8108，mall_system 库）：纯空骨架（Application + ContextLoadsTest + yml 数据源占位 flyway=false + 空 migration）；pom 同骨架基线，**无 redis/security 业务配置**；无分层包。
- mall-common：mall-common-core（UnifyResult 等）、web、security、redis、log、test、mq、openfeign 模块；Redis 在 cart/order/identity 已用（RedisTemplate/StringRedisTemplate 自动配置基线存在于 mall-common-redis）。
- mall-identity：Flyway 种子到 V8；V9 将由 CHG-0021 使用（search:index:*）；本 Change 使用 V10（system:feature:list/update、system:parameter:list/update、system:config-history:list + 系统管理菜单）。
- mall-gateway：无 8108 路由；/api/internal/** denyAll；公开端点模式可仿（public 路由 + 服务内 permitAll）。
- mall-search：CHG-0020 搜索接口；mall.guest-cart 能力：mall-cart（8104）游客购物车 CHG-0018 已交付（游客识别与合并链路），目前无开关校验。
- mall-admin：动态菜单/按钮权限体系、stores 模式成熟；mall-web：布局与 store 模式成熟，无全局功能开关加载。

## 2. 提议方案

### 2.0 总体架构

```
ADMIN → gateway(/api/admin/feature-configs|system-parameters|config-history/**, ADMIN+权限码) → mall-system:8108
                                                                      ↓ MySQL mall_system（仅本服务直连）
                                          写成功 AFTER_COMMIT → ConfigCacheEvictor 删 Redis 键
业务服务(mall-search/mall-cart) → mall-common-config:
   FeatureGate/SystemParameterProvider → 本地缓存(60s) → Redis(aimall:{env}:system:*) → HTTP /api/internal/config/** → mall-system → DB
   全失败 → 代码传入安全默认值(WARN)
GUEST → gateway(/api/mall/public-features, permitAll) → mall-system（Redis 聚合键 public-features → DB）
```

### 2.1 mall-system 分层（DDD 同构）

```
com.ai.mall.system
├── domain/config/
│   ├── FeatureConfig.java          # 聚合：enable()/disable()/updateGuard(version)，builtIn 保护
│   ├── SystemParameter.java        # 聚合：typed update + 范围校验 + version
│   ├── ConfigType.java             # STRING/INTEGER/LONG/DECIMAL/BOOLEAN/JSON
│   ├── ConfigHistory.java
│   ├── repositories（FeatureConfigRepository/SystemParameterRepository/ConfigHistoryRepository）
│   └── ConfigException + SystemErrorCode  # B0601 NOT_FOUND/B0602 TYPE_INVALID/B0603 OUT_OF_RANGE
│                                            B0604 VERSION_CONFLICT/B0605 BUILTIN_PROTECTED/B0606 FEATURE_DISABLED
├── application/config/
│   ├── FeatureConfigAppService.java    # 分页/分组/创建/启停/更新/删除；写历史；发 ConfigChangedEvent
│   ├── SystemParameterAppService.java
│   ├── ConfigHistoryAppService.java
│   └── ConfigChangedApplicationEvent.java(configType,key,changeKind)
├── infrastructure/
│   ├── persistence/config/ Po×3 + Mapper×3 + RepositoryImpl
│   ├── cache/ConfigCacheService.java（Redis 读写/回填/失效/聚合键）+ CacheEvictionListener(AFTER_COMMIT)
│   ├── seed/BuiltInConfigSeeder.java（ApplicationRunner 幂等播种，防重复：INSERT IGNORE/存在即跳过）
│   └── config/SystemSecurityConfiguration.java
└── interfaces/rest/
    ├── admin/FeatureConfigAdminController/SystemParameterAdminController/ConfigHistoryAdminController + dto
    ├── internal/InternalConfigController + dto（features/parameters 批量）
    └── mall/PublicFeaturesController + dto
```

### 2.2 数据模型（MySQL，整数 version 乐观锁）

- feature_config：id、config_key UK、feature_name、config_group、enabled TINYINT、public_flag TINYINT、built_in TINYINT、version INT DEFAULT 0、description VARCHAR、created_at/updated_at。
- system_parameter：id、config_key UK、parameter_name、parameter_type VARCHAR(16)、config_value VARCHAR(1000)、default_value VARCHAR(1000)、min_value VARCHAR(64) 可空、max_value VARCHAR(64) 可空、config_group、public_flag、built_in、effect_type VARCHAR(16) DEFAULT 'DYNAMIC'、version、description、created_at/updated_at。
- system_config_history：id、config_type VARCHAR(16)（FEATURE/PARAMETER）、config_key、old_value VARCHAR(1000)、new_value VARCHAR(1000)、change_kind（UPDATED/DELETED）、changed_by VARCHAR(64)、change_reason VARCHAR(255) 可空、trace_id VARCHAR(64)、created_at；KEY(config_type,config_key,created_at)。
- 更新：`UPDATE ... SET config_value=?,version=version+1 WHERE config_key=? AND version=?`；影响行 0 → B0604 409；历史与更新同事务。
- 种子（BuiltInConfigSeeder + V1 初始 DML 双保险，以迁移 DML 为准）：
  - FEATURE：search.enabled(enabled=1,public=1)、mall.guest-cart.enabled(1,public=1)
  - PARAMETER：search.default-page-size(INTEGER,value=20,default=20,min=1,max=100,public=0)、cart.max-item-quantity(INTEGER,99,99,1,999,public=0)
  - 全部 built_in=1、effect_type=DYNAMIC。

### 2.3 缓存与内部端点

- Redis key：`aimall:{env}:system:feature:{key}` → JSON {key,enabled,version}；`...:parameter:{key}` → {key,value,type,version}；`aimall:{env}:system:public-features` → [{key,enabled}]；TTL 600s。
- ConfigCacheService：getFeature/getParameter（Redis 未命中→读库→回填；键不存在不缓存负向? 决策：缓存空标记 TTL 60s，防穿透，M5 键集小可接受）；getPublicFeatures（聚合键未命中→查全部 public_flag=1 启用/禁用均返回→回填）。
- CacheEvictionListener：AFTER_COMMIT 删对应单键 + 恒删 public-features 聚合键（任何键变更都可能影响公开列表——简化且正确）。
- InternalConfigController（SERVICE，X-Internal-Token）：
  - `GET /api/internal/config/features?keys=a,b` → {values:{key:{key,enabled,publicFlag}}, missingKeys:[...]}
  - `GET /api/internal/config/parameters?keys=` → {values:{key:{key,configValue,parameterType,minValue,maxValue}}, missingKeys:[...]}
  - 内部端点读缓存（不要求强一致，受 TTL 保护），批量 keys ≤100。

### 2.4 mall-common-config 新模块

- Maven 模块 mall-common/mall-common-config（注册进 common 聚合 pom；依赖 common-core + common-redis + spring-web）；AutoConfiguration（META-INF/spring/...AutoConfiguration.imports）注册 Bean，配置属性 `mall.config.system-base-uri=http://localhost:8108`、`mall.config.internal-token`、`mall.config.local-ttl-seconds=60`、`mall.config.env`。
- SystemConfigClient：
  1. Caffeine 不引依赖——用 ConcurrentHashMap + volatile expireAt 实现 60s 本地 TTL（避免新依赖）；
  2. StringRedisTemplate 直读 Redis 缓存值（反序列化 JSON）；
  3. Redis 缺失/异常 → RestClient 调内部端点（成功后不负责回填，由 system 侧回填；客户端可直接使用返回值）；
  4. 全链路失败 → 返回 empty，调用方走默认值；WARN 日志含 key。
- FeatureGate：isEnabled(key) 默认值由调用点传入；ensureEnabled(key, defaultIfAbsent=true) 关闭时抛 FeatureDisabledException（common-core 定义或本模块定义，rest advice 由各服务全局处理映射 B0606/403）。
- SystemParameterProvider：getString(key,default)、getInt/getLong/getDecimal/getBoolean；解析失败（类型不符/数值非法）→ 默认值 + WARN。
- 各消费服务引入依赖 + yml 配置；禁止在业务服务配置 mall_system 数据源。

### 2.5 动态生效与公开配置

- FeatureDisabledException 经各服务全局异常处理映射统一 UnifyResult{code:"B0606"/"FEATURE_DISABLED"}——错误码冻结为 B0606 FEATURE_DISABLED，HTTP 403。
- mall-search：MallSearchController 入口（或 AppService 首行）featureGate.ensureEnabled("search.enabled", true)；关闭→403 B0606。
- mall-cart：游客写端点（游客加购/改量/游客券等游客身份写操作）featureGate.ensureEnabled("mall.guest-cart.enabled", true)；会员路径不检查（具体切入点在 story-design 对照 cart 现有控制器列明）。
- PublicFeaturesController：permitAll；GET /api/mall/public-features → {features:[{key,enabled}]}，只含 public_flag=1。
- 网关：/api/admin/feature-configs/**、/api/admin/system-parameters/**、/api/admin/config-history/** → 8108 ADMIN；/api/mall/public-features → 8108 permitAll。
- mall-web：stores/features.ts（应用启动/布局挂载拉取公开开关，失败默认空+UI fail-open）；搜索入口 v-if features['search.enabled'] !== false。
- mall-admin：三页面（FeatureConfigsView/SystemParametersView/ConfigHistoryView）+ api/system.ts + store；按钮 v-permission（既有指令）；菜单由 V10 种子驱动。

### 2.6 权限种子（mall-identity V10）

- 权限操作码：system:feature:list、system:feature:update、system:parameter:list、system:parameter:update、system:config-history:list。
- 菜单：系统配置目录下"功能开关/系统参数/变更历史"；参照 V8 订单种子的菜单/权限/超管角色关联写法（超管角色全量授予）。

## 2.1 备选方案对比（Alternatives Considered）

| 决策 | 采纳 | 备选与理由 |
| --- | --- | --- |
| 模型 | 双表 FeatureConfig/SystemParameter + 统一历史表 | 需求原文单一 config 表：布尔开关与类型化参数字段诉求不同（publicFlag/范围/默认值），product/11 已细案双模型且路由对应；统一历史降低审计复杂度 |
| 缓存读取 | 客户端 Redis→HTTP→默认值 | 每次走 HTTP：延迟与依赖大；发布订阅强推：M5 不引 MQ，本地 60s TTL + 更新删键已满足 |
| 本地缓存 | JDK ConcurrentHashMap+TTL | Caffeine：新增依赖管理成本，键集小、读多写少，JDK 足够 |
| 生效时延 | 60s 有界 + 删 Redis 立即对跨服务新读生效 | Pub/Sub：额外故障面；M5 验收接受有界时延 |
| 错误码 | B06xx 段，FEATURE_DISABLED=B0606/403 | 各服务自定义：跨服务语义不一致 |
| 负向缓存 | 空标记 60s | 不缓存：键集小，风险可控但防穿透更稳 |
| 种子方式 | Flyway DML + Seeder 双保险 | 仅代码播种：迁移历史不完整；两者键集以 DML 为准、Seeder 兜底 |

## 3. 仓库影响（Repository Impact）

### 3.1 repo-1（ai-platform-backend）

- mall-system：从空骨架建全分层；Flyway V1（三表+种子 DML）；Redis 接入；安全配置；admin/internal/mall 三类控制器；调度不需要。
- mall-common/mall-common-config：新模块 + 聚合 pom 注册 + 自动配置。
- mall-identity：V10 权限菜单种子。
- mall-gateway：8108 admin/mall 路由。
- mall-search、mall-cart：引入 common-config + 开关校验切点（最小增量）。

### 3.2 repo-2（ai-platform-frontend）

- mall-admin：api/store/三页面 + 路由（动态菜单驱动）。
- mall-web：features store + 启动加载 + 搜索入口受控（CHG-0020 搜索框接线开关）。

## 4. 跨仓协作

- API Contract：
  - 业务服务→mall-system：GET /api/internal/config/features|parameters?keys=（SERVICE，keys 必填/去重/≤100）→ {values:{key:view},missingKeys}（实现冻结的 values 键值映射包络）；UnifyResult；503 归一由客户端默认值消化。
  - 公网：GET /api/mall/public-features（PUBLIC）。
  - 管理：/api/admin/feature-configs、/api/admin/system-parameters、/api/admin/config-history（ADMIN+五权限码）；409 版本冲突。
- Data Contract：Redis 缓存 JSON 形状为跨进程契约（key 规范冻结 §2.3）；mall_system 库仅 mall-system 可访问。
- Repository Dependencies：common-config 先行 → mall-system 可独立于消费方交付 → search/cart 接线最后；前端依赖 public-features。
- Integration Boundary：内部端点 8108 直连 + X-Internal-Token，网关 denyAll；Redis 共享实例但 key 前缀隔离 env。
- Cross-Repository Sequence：V1/V10 迁移 + mall-system → common-config → 消费接线 → 前端；search.enabled 闭环依赖 CHG-0020 已交付的搜索端点。

## 5. Story 设计分派（Story Design Assignments）

| Story ID | domain（L3） | 技术要点 | 仓库 |
| -------- | ------------ | -------- | ---- |
| STORY-006-01-01-01 配置模型、后台管理与变更审计 | FEAT-006-01-01 配置管理与审计 | V1 三表+种子 DML、聚合/校验/乐观锁、三类 admin 控制器、SystemSecurity、V10 权限种子、网关 admin 路由、mall-admin 三页面（BE-507、FE-503） | repo-1、repo-2 |
| STORY-006-02-01-01 Redis 配置缓存与统一访问边界 | FEAT-006-02-01 缓存分发与生效 | ConfigCacheService/失效监听/内部端点、mall-common-config 模块/FeatureGate/Provider/本地 TTL、search/cart 引依赖（BE-508） | repo-1 |
| STORY-006-02-01-02 功能开关动态生效与前端公开配置 | FEAT-006-02-01 缓存分发与生效 | B0606 拒绝映射、search/cart 切点、public-features、网关公开路由、mall-web features store+搜索入口受控、mall-admin 细节（BE-509、FE-504） | repo-1、repo-2 |

## 6. DU 划分总览（跨 Story 依赖）

| DU id | repository | goal | 关联 Story | depends on |
| ----- | ---------- | ---- | ---------- | ---------- |
| DU-BE-507 | repo-1 | mall-system 配置管理全垂直（V1/聚合/校验/历史/admin 端点/安全/V10 种子/网关） | STORY-006-01-01-01 | — |
| DU-FE-503 | repo-2 | mall-admin 三页面 | STORY-006-01-01-01 | DU-BE-507 |
| DU-BE-508 | repo-1 | Redis 缓存/失效/内部端点 + mall-common-config 模块 + 两消费服务引依赖 | STORY-006-02-01-01 | DU-BE-507 |
| DU-BE-509 | repo-1 | 开关切点（search/cart）B0606 拒绝 + public-features 端点与网关路由 | STORY-006-02-01-02 | DU-BE-508 |
| DU-FE-504 | repo-2 | mall-web features store/搜索入口受控（+admin 必要联动） | STORY-006-02-01-02 | DU-BE-509、CHG-0020 DU-FE-501 |

## 7. 数据变更

```sql
-- mall_system V1__system_config_init.sql
CREATE TABLE feature_config (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  config_key VARCHAR(128) NOT NULL UNIQUE,
  feature_name VARCHAR(128) NOT NULL,
  config_group VARCHAR(64) NOT NULL DEFAULT 'default',
  enabled TINYINT NOT NULL DEFAULT 0,
  public_flag TINYINT NOT NULL DEFAULT 0,
  built_in TINYINT NOT NULL DEFAULT 0,
  version INT NOT NULL DEFAULT 0,
  description VARCHAR(512) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
);
CREATE TABLE system_parameter (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  config_key VARCHAR(128) NOT NULL UNIQUE,
  parameter_name VARCHAR(128) NOT NULL,
  parameter_type VARCHAR(16) NOT NULL,
  config_value VARCHAR(1000) NOT NULL,
  default_value VARCHAR(1000) NOT NULL,
  min_value VARCHAR(64) NULL, max_value VARCHAR(64) NULL,
  config_group VARCHAR(64) NOT NULL DEFAULT 'default',
  public_flag TINYINT NOT NULL DEFAULT 0,
  built_in TINYINT NOT NULL DEFAULT 0,
  effect_type VARCHAR(24) NOT NULL DEFAULT 'DYNAMIC',
  version INT NOT NULL DEFAULT 0,
  description VARCHAR(512) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
);
CREATE TABLE system_config_history (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  config_type VARCHAR(16) NOT NULL, config_key VARCHAR(128) NOT NULL,
  old_value VARCHAR(1000) NULL, new_value VARCHAR(1000) NULL,
  change_kind VARCHAR(16) NOT NULL,
  changed_by VARCHAR(64) NOT NULL, change_reason VARCHAR(255) NULL, trace_id VARCHAR(64) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  KEY idx_config_key (config_type, config_key, created_at)
);
-- 种子 DML：search.enabled / mall.guest-cart.enabled（public）；search.default-page-size / cart.max-item-quantity
-- mall-identity V10__system_config_permissions.sql：5 权限码 + 3 菜单 + 超管角色关联
```

## 8. 风险

| 风险项 | 级别 | 缓解措施 |
| --- | --- | --- |
| common-config 被多服务引入产生自动配置冲突 | 中 | 纯客户端 Bean，条件注解 @ConditionalOnProperty(mall.config.enabled)；无数据源/无服务端 Bean |
| Redis 缓存与 DB 双写不一致 | 中 | 只在 AFTER_COMMIT 删键（不写缓存），回源回填天然收敛；聚合键恒删 |
| 开关关闭误伤已登录会员流程 | 中 | guest-cart 切点仅针对游客身份；集成测试覆盖会员不受影响 |
| FEATURE_DISABLED 错误码跨服务不统一 | 中 | B0606 定义在 common-config，异常 + advice 统一映射 |
| V10 与 CHG-0021 V9 顺序 | 低 | 版本冻结；开发合并时检查 identity migration 目录 |
| 管理端误改参数致服务异常 | 低 | 范围校验 + 乐观锁 + 审计 + builtIn 保护；默认值兜底 |

## 9. 待澄清问题

- 无阻断项；双表收敛、错误码、缓存 key/TTL、种子集在本文冻结。
