---
affected-repositories: [repo-1]
story-id: "STORY-006-02-01-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §2.3/§2.4
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0022
- Story ID: STORY-006-02-01-01
- 状态流转: specified → designed
- 相关仓库: repo-1（mall-common/mall-common-config 新模块、mall-system）
- 需要 Migration: no
- 数据变更概要: 无 DDL；新增 Redis 键命名空间（运行期数据）

## 1. 模块改动（Module Changes）

### repo-1 mall-common/mall-common-config 新模块（DU-BE-508）

- mall-common/pom.xml modules 增 mall-common-config；新模块依赖 mall-common-web（或 core，按实际底座）+ mall-common-redis + openfeign（provided/optional 视既有 starter 约定）；版本随父 pom。
- src/main/resources/META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports 注册 ConfigClientAutoConfiguration。
- 客户端组件（对消费方暴露的稳定 API）：
  - FeatureGate：boolean isEnabled(key)、void ensureEnabled(key)（禁用→抛 B0606 FEATURE_DISABLED，HTTP 403）；isEnabled(key,defaultWhenMissing) 重载；
  - SystemParameterProvider：getString/getInt/getLong/getDecimal/getBoolean(key)，缺键回退代码默认值（调用方必传 default 参数，回退时 WARN 日志一次/键/分钟）；
  - ConfigClient（内部 RestClient 引擎）：GET {mall-system}/api/internal/config/features?keys=、/parameters?keys=，keys 必填、去重、≤100（超出直接 400，不分批），返回值含 missingKeys。
- 读路径三级：本地缓存（ConcurrentHashMap<CacheEntry>，volatile value + expireAt，TTL 60s）→ Redis（StringRedisTemplate/JSON，TTL 600s，空值负缓存 60s）→ HTTP 内部端点；逐级回填。
- Redis key 冻结：`aimall:{spring.profiles.active:dev}:system:feature:{key}`、`...:parameter:{key}`、聚合 `...:public-features`；值 JSON。
- 不引 Caffeine（显式约束）。

### repo-1 mall-system（DU-BE-508）

- interfaces.rest.internal.InternalConfigController（SERVICE 鉴权）：
  - GET /api/internal/config/features?keys=a,b（冻结：keys 必填、去重、≤100；空 keys 或 >100 → HTTP 400 + A 段参数校验码 A0001，依 framework-standard §13.4「参数校验异常 → HTTP 400 + A 段码」，非 B06 业务码）：{values:{key:{enabled,...}},missingKeys:[]}；
  - GET /api/internal/config/parameters?keys=...：{values:{key:{configValue,parameterType,...}},missingKeys:[]}。
- 缓存维护（mall-system 侧写后）：FeatureConfig/SystemParameter 任一 create/update/delete/commit 后 @TransactionalEventListener(AFTER_COMMIT)：删除对应单键；恒删除聚合键 public-features；负缓存随单键 TTL 自然过期（空标记同样存该键位）。
- 仅维护 Redis 这一份共享缓存；各消费服务本地层 60s 自过期（动态生效上限冻结为 60s 本地+Redis 实时）。

## 2. 接口契约细化

| 方法 | 路径 | 调用方 | 响应 |
| --- | --- | --- | --- |
| GET | /api/internal/config/features?keys=k1,k2 | 各微服务 SERVICE | {values:{k1:{key,enabled,publicFlag}},missingKeys:[...]} |
| GET | /api/internal/config/parameters?keys=k1 | 各微服务 SERVICE | {values:{k1:{key,configValue,parameterType,minValue,maxValue}},missingKeys:[...]} |

keys 为空或数量 >100 → HTTP 400 + A 段参数校验码（A0001，framework-standard §13.4；实现经 IllegalArgumentException → GlobalExceptionHandler 映射）；缺失键进 missingKeys 而非报错。

## 3. 数据变更

无 DDL。Redis 键见 §1；配置变更历史仍落 system_config_history（DU-BE-507）。

## 4. 错误处理

- HTTP 端点不可用：本次读返回 default + WARN（fail-open for isEnabled 显式默认值语义；ensureEnabled 对缺失键按 default=true 放行并 WARN——冻结：搜索/游客车缺配置按启用）；
- Redis 故障：跳过 Redis 层直连 HTTP，异常不抛给业务；
- 本地缓存 TTL 严格用 System.currentTimeMillis 判断，不主动清理线程。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-508 | repo-1 | mall-common-config 客户端(三级读/FeatureGate/Provider)+system 内部端点+Redis 失效 | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007 | 无 |

> 跨 Story 依赖（不入本表）：DU-BE-508 实际前置 DU-BE-507（STORY-006-01-01-01 配置模型/服务/V1）。

## 6. 测试策略

- 单测：三级读优先级与回填、60s 本地过期、负缓存、keys>100 分批、missingKeys、故障回退 default；
- IT（testcontainers redis + WireMock system）：写后删键导致下次读拿到新值（端到端缓存一致性）；Redis 停摆不影响读路径。
