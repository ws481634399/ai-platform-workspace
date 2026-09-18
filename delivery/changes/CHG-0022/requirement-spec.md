# Requirement Spec（需求级产品规格）

> 层级：Requirement 级产物——针对本次需求/Change（多 Story 统一一份）
> 业界锚点：PRD（Problem → Goals/Metrics → Scope → Requirements → AC）
> 输入：exploration.md + requirement.md + references/M5.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0022
- Requirement: REQ-M5-003 系统功能与参数配置
- 状态流转: exploring → specified
- 主要服务: mall-system（从空骨架交付，8108，库 mall_system，repo-1）、mall-common（统一配置客户端，repo-1）、mall-gateway（路由，repo-1）、mall-identity（V9 权限/菜单种子，repo-1）、消费接入：mall-search（search.enabled）、mall-cart（mall.guest-cart.enabled 最小后端校验）
- 前端: mall-admin（功能开关/系统参数/变更历史页，repo-2）、mall-web（公开开关显隐搜索入口，repo-2）
- target-user: ADMIN（配置维护，五权限码 RBAC）、业务服务（类型安全读取）、GUEST/MEMBER（公开开关影响入口显隐）
- pain-points: 功能启停/运行参数若硬编码，后续 AI、游客购物车、搜索等能力无法在线治理；各服务直查 config 表会造成耦合与口径分裂；配置改了缓存不失效、前端隐藏但后端不拒绝、Secret 进数据库都是高风险
- expected-value: 平台级开关/参数可后台维护、类型安全、可审计、缓存可失效、热生效；业务服务经统一 Config Client 消费；敏感功能后端真实拒绝
- scope-in: FeatureConfig/SystemParameter 双模型、类型与范围校验、乐观锁、内置保护、安全默认值、Secret 禁入、admin CRUD/历史、五权限码、Redis 分级缓存与精确失效、内部配置查询端点、mall-common FeatureGate/SystemParameterProvider、动态/重启生效语义、public-features 公开端点、search.enabled 真实消费闭环
- scope-out: Nacos 迁移、Secret Manager、灰度/A-B/多租户、通用操作日志平台、配置一键回滚 UI、RocketMQ 配置变更事件（M7）

## 1. 背景

M1 交付了 RBAC 与权限缓存，M3/M4 已出现游客购物车、订单参数等需要配置化的行为，M6 的 AI 导购/RAG 更依赖在线开关。product/11-权限与功能配置.md 已给出字段、权限码、缓存 key、接口级细案。本 Change 按该细案落**双模型**（需求原文 §三 的统一字段表为两模型字段并集，此为正式收敛决策）：FeatureConfig（布尔开关 + publicFlag/builtIn）与 SystemParameter（类型化参数 + 默认值/范围），由新服务 mall-system 承载管理、审计与缓存分发；mall-common 提供统一读取边界，业务服务不直查 mall_system 库、不各自实现 Config DAO。所有 Secret 继续走环境变量，禁止进入配置表。

## 2. 用户价值

- 运营/管理员：在 mall-admin 分组查看开关与参数、启停功能、修改带范围校验的参数值、按 key 查询变更历史（谁/何时/旧值→新值）。
- 业务服务/未来 AI 服务：用 FeatureGate.ensureEnabled("search.enabled") 与 SystemParameterProvider.getInt("search.default-page-size", 20) 类型安全消费；配置缺失有安全默认值，缓存自动失效，热生效无需重启。
- 商城用户：被关闭的功能入口不展示，且绕过前端直接调 API 也会被后端拒绝（FEATURE_DISABLED）。
- 平台：高风险写能力默认关闭、内置键不可删除、全部关键变更可审计。

JTBD：

- 角色：运营；场景：When 需要临时关闭商城搜索（如索引故障）, I want 在后台一键关闭 search.enabled；价值：So that 用户不再触发故障入口，后端也真实拒绝搜索请求。
- 角色：业务服务；场景：When 读取一个参数而 Redis 与数据库短暂不可用, I want 使用安全默认值继续服务；价值：So that 非关键配置缺失不拖垮业务。
- 角色：审计/管理员；场景：When 某开关状态引发疑问, I want 看到谁在何时把值从什么改为什么；价值：So that 配置变更可追溯。

## 3. 功能范围

### 3.1 包含

- [S1 配置模型/后台管理/审计] Flyway V1：feature_config（configKey 唯一/featureName/configGroup/enabled 布尔/publicFlag/builtIn/version/时间）、system_parameter（configKey 唯一/parameterName/parameterType(STRING/INTEGER/LONG/DECIMAL/BOOLEAN/JSON)/configValue/defaultValue/minValue/maxValue/configGroup/publicFlag/builtIn/effectType/version/时间）、system_config_history（configType/configKey/oldValue/newValue/changedBy/changeReason/traceId/changedAt）；种子写入内置配置；领域服务（类型校验、范围校验、version 乐观锁、builtIn 禁删/禁改 key）；admin CRUD/历史端点；五权限码 + identity V9 种子 + 菜单；mall-admin 三页面。
- [S2 Redis 缓存与统一访问边界] mall-system 配置缓存：Redis key 规范 aimall:{env}:system:feature:{key}、...:parameter:{key}、...:public-features；TTL 10 分钟；更新事务提交后精确删除相关键；内部批量查询端点 GET /api/internal/config/features|parameters?keys=（SERVICE，未命中回源 DB 并回填）；mall-common 新增 mall-common-config：FeatureGate（isEnabled/ensureEnabled 抛 FEATURE_DISABLED）与 SystemParameterProvider（类型安全 + 默认值），读路径 Redis→内部端点→安全默认值；本地短 TTL 缓存（60s）自然收敛。
- [S3 动态生效与公开配置] effectType=DYNAMIC/RESTART_REQUIRED 元数据与页面标识（M5 种子全部 DYNAMIC）；GET /api/mall/public-features 游客端点仅返回 publicFlag=true 开关；search.enabled 接入 mall-search（关闭时搜索接口 FEATURE_DISABLED，B05xx/B06xx 由 design 定错误码归属）；mall.guest-cart.enabled 接入 mall-cart 游客加购后端校验；mall-web 启动加载公开开关隐藏搜索入口；mall-admin 配置页按权限显隐。

### 3.2 不包含

- Nacos 配置中心；Secret 托管；按用户/比例灰度；多租户；通用操作日志（operation-log 表/端点留给后续里程碑）；历史一键回滚按钮（历史记录与审计必须，回滚以后续增强）；AI 相关配置键只在真实消费里程碑启用（本 Change 只放 M5 实际消费的最小种子集）。

### 3.3 Story 拆分总表

| Story ID | 标题 | Scope 摘要 | 依赖 | 优先级 |
| --- | --- | --- | --- | --- |
| STORY-006-01-01-01 | 配置模型、后台管理与变更审计 | S1：三表/种子/领域校验/乐观锁/admin 端点/权限/三页面 | REQ-M1-002/003 | P0 |
| STORY-006-02-01-01 | Redis 配置缓存与统一访问边界 | S2：Redis 缓存/失效/内部端点/mall-common-config 客户端 | S1 | P0 |
| STORY-006-02-01-02 | 功能开关动态生效与前端公开配置 | S3：生效语义/FeatureGate 拒绝/public-features/双端接入 | S2、CHG-0020 搜索接口 | P0 |

## 4. 业务规则总纲

- [键稳定] configKey 全局唯一、创建后不可修改（builtIn 与非内置均如此）；删除仅限非内置键；历史永久保留（不物理删历史）。
- [类型安全] 参数按 parameterType 解析与校验：INTEGER/LONG 整型、DECIMAL 小数、BOOLEAN true/false、JSON 合法 JSON、STRING 非空规则由 design 定；值必须落在 [minValue,maxValue]（声明时）；非法值 400，不写入。
- [乐观锁] 更新携带 version；不匹配返回 CONFIG_VERSION_CONFLICT（B06xx/409），前端引导重新加载。
- [审计] 每次 enabled/value 变更追加 system_config_history（旧值/新值/changedBy（管理员用户名/服务名）/traceId/可选 changeReason）；历史只追加。
- [安全默认值] 代码读取必传默认值或声明 required；DB/Redis/配置服务全部不可用时使用默认值并记 WARN；高风险写能力默认关闭。
- [Secret 禁入] 任何 password/secret/key（LLM API Key 等）不得录入两张配置表；管理端不提供此类入口；文档与 PRD 明示。
- [缓存] Redis TTL 10min；更新成功 AFTER_COMMIT 立即删除对应 key（含 public-features 聚合键）；客户端本地缓存 60s；任何路径不得永久脏读。
- [后端拒绝] 敏感功能必须 FeatureGate.ensureEnabled；关闭 → FEATURE_DISABLED 业务错误；前端隐藏只是体验层。
- [公开端点] /api/mall/public-features 无需登录，只返回 publicFlag=true 的 {key,enabled}；内部参数/非公开开关不泄露。
- [权限] system:feature:list/update、system:parameter:list/update、system:config-history:list；内部端点 SERVICE；网关 /api/internal/** denyAll。

## 5. 全局验收标准

| ID | 验收标准（可测试） | 覆盖 Story |
| --- | --- | --- |
| AC-001 | 三表 Flyway V1 在 mall_system 库创建成功；内置种子配置随启动/迁移写入且 builtIn=true | STORY-006-01-01-01 |
| AC-002 | 可分页/分组查询开关与参数；创建/修改/启停流程完整；configKey 唯一约束生效，重复 key 创建被拒 | STORY-006-01-01-01 |
| AC-003 | 参数按类型校验：写入非整型到 INTEGER、非法 JSON、越界 [min,max] 值均 400 且不更新 | STORY-006-01-01-01 |
| AC-004 | version 冲突更新返回 CONFIG_VERSION_CONFLICT；builtIn 键删除/改 key 被拒绝，值可改 | STORY-006-01-01-01 |
| AC-005 | 每次值/启停变更产生 history（旧值/新值/操作人/traceId/时间）；历史可按 key 查询且只追加 | STORY-006-01-01-01 |
| AC-006 | 五权限码种子与菜单生效：无 update 权限的管理员只读、写操作 403；历史需要 config-history:list | STORY-006-01-01-01 |
| AC-007 | mall-admin 功能开关/系统参数/变更历史三页面可用（列表/启停/编辑/范围提示/历史筛选），type-check/lint/build 通过 | STORY-006-01-01-01 |
| AC-008 | 读取配置经 Redis 缓存（首次回源后 Redis 存在键，TTL 约 10min）；更新后相关键立即被删除，随后读取得到新值 | STORY-006-02-01-01 |
| AC-009 | 内部配置端点需 SERVICE 身份，网关 404；非请求键不返回；未命中回源 DB 并回填 Redis | STORY-006-02-01-01 |
| AC-010 | mall-common-config：getInt/getBoolean 等类型读取正确；类型不匹配走默认值并 WARN；配置服务不可用时安全默认值生效不抛异常 | STORY-006-02-01-01 |
| AC-011 | 业务服务代码无直查 mall_system 库/无自建 Config DAO（架构评审） | STORY-006-02-01-01 |
| AC-012 | search.enabled=false：GET /api/mall/search/products 返回 FEATURE_DISABLED 错误（前端隐藏之外的后端拒绝）；重新开启后恢复 | STORY-006-02-01-02 |
| AC-013 | mall.guest-cart.enabled=false：游客加购/游客购物车相关写接口被后端拒绝；开启恢复 | STORY-006-02-01-02 |
| AC-014 | GET /api/mall/public-features 无需登录仅返回公开开关 {key,enabled}；非公开键不出现 | STORY-006-02-01-02 |
| AC-015 | mall-web 根据公开开关隐藏/显示搜索入口；mall-admin 按权限隐藏编辑控件 | STORY-006-02-01-02 |
| AC-016 | effectType=RESTART_REQUIRED 标识在页面明示（M5 无该类种子，机制存在）；改配置到热生效时延 ≤ 本地缓存 TTL（60s）或立即（清缓存路径） | STORY-006-02-01-02 |
| AC-017 | Integration Gate 场景六（开关动态生效）、场景七（缓存一致性）E2E 通过；后端/前端测试全绿 | ALL |

## 6. 补充约束

- 双模型为对需求原文"统一模型"的正式收敛（见 §1 背景），需求字段作为两模型字段并集全部覆盖。
- M5 种子配置最小集：只放当前里程碑存在真实消费方的键（search.enabled、mall.guest-cart.enabled、search.default-page-size、cart.max-item-quantity）；AI/退款等未来键在对应里程碑再播种。
- 所有种子键 effectType=DYNAMIC；RESTART_REQUIRED 仅提供机制标识。

## 7. 成功指标

- 治理：M5 消费的开关/参数 100% 经配置中心读取（硬编码点清零，以实际接入项为准）。
- 一致性：缓存一致性场景 0 失败（更新后读新值）；后端拒绝场景 0 绕过。
- 质量：mall-system 单元/集成测试（H2 + Redis Testcontainers）全绿；前端三页面测试全绿；审计记录完整率 100%。
