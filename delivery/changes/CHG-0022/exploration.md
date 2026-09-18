# Exploration（需求探索报告）

> 阶段：sdd-explore 产物
> 业界锚点：Discovery（Problem → Evidence → Conflict → Recommendation）
> 输入：requirement.md（原文沉淀；本文件不复述原文，只做改写分析）
> 产出状态：exploring（推进 Change 状态）

## 1. 需求要点

- 做什么：把"平台功能是否启用、运行参数是多少"从代码硬编码中抽离，由新服务 **mall-system**（8108，空骨架）统一承载——两类配置（Feature Config 开关 / System Parameter 参数）的类型化模型、CRUD、mall-admin 管理页、M1 RBAC 管控、变更审计、Redis 缓存与精确失效、跨服务统一读取边界（Config Client/FeatureGate）、动态生效语义与前端公开配置 API。
- 给谁：ADMIN（后台维护，受细粒度权限码约束）、各 Java 业务服务（类型安全读取开关/参数）、mall-web/mall-admin（按公开开关显隐入口）、未来 AI 服务（通过同一配置边界消费）。
- 解决什么问题：M6 AI 导购/RAG、游客购物车、搜索开关、订单超时等都需要"不改代码即可启停/调参"的统一机制；同时防止配置体系退化为"各服务直查 config 表 + Secret 数据库仓库 + 改了不生效"。
- 核心语义（需求硬约束）：
  1. **configKey 稳定唯一**，是跨服务契约，不可随代码重构随意改名；
  2. **类型化**：按声明类型解析（STRING/INTEGER/DECIMAL/BOOLEAN/JSON），业务代码不各自 parse String；
  3. **安全默认值**：配置缺失不能拖垮服务启动；高风险写能力默认关闭；DB/Redis/JWT/LLM/MinIO 等 Secret **永不进入**动态配置表；
  4. **缓存必须可失效**：DB 改 → Redis 失效/刷新 → 后续读到新值，杜绝永久旧值；
  5. **前端隐藏 ≠ 安全控制**：开关关闭必须 Frontend Hide + Backend Reject 双生效；
  6. **可审计**：谁、把哪个 key、从什么值改为什么值、何时改，有据可查。
- 隐含需求（设计必须回答）：
  - **模型取舍（需求与产品文档存在粒度差异）**：M5.md 给的是统一模型（configKey/configValue/configType/category/enabled/version... 一表承载），product/11-权限与功能配置.md 给的是**双模型**（FeatureConfig：configKey/featureName/configGroup/enabled/publicFlag/builtIn/version；SystemParameter：configKey/parameterName/parameterType/configValue/defaultValue/minValue/maxValue/configGroup/publicFlag/builtIn/version + 校验范围）。建议 PRD 按产品文档 11 落**双表双模型**（开关只有布尔语义且需 publicFlag/内置保护，参数有类型/范围/默认值），需求 §三 的字段是两个模型字段的并集，语义无冲突；JSON 类型作为 parameterType 扩展补充（产品文档列了 STRING/INTEGER/LONG/DECIMAL/BOOLEAN/DURATION，M5 至少实现需求点名的五类，DURATION/LONG 可同批支持，成本极低）；
  - **内置配置保护**：builtIn=true 的种子键不可删除、key 不可改，只可改 enabled/value；首次启动 Flyway/初始化器写入种子（search.enabled、mall.guest-cart.enabled 等 M5 实际消费项 + 产品文档 23/24 节中当前阶段需要的少量键），不一次性灌入 AI/退款等未来配置（避免假能力）；
  - **乐观锁与并发**：配置表 version 乐观锁，更新冲突返回 CONFIG_VERSION_CONFLICT，前端提示重新加载（产品文档 §29.4）；
  - **缓存拓扑**：业务服务不直查 mall_system 库，也不各自实现 DAO——mall-system 暴露内部批量配置查询端点（SERVICE/X-Internal-Token）；mall-common 提供 Config Client（Redis 为一级远端缓存，key 规范 `aimall:{env}:system:feature:{key}` / `...:parameter:{key}` / public-features 聚合键，Redis TTL 10 分钟）+ 可选本地短 TTL 缓存（1~5 分钟）；更新路径：DB 更新成功 → 删除 Redis 键 →（M5 可选 Redis Pub/Sub 通知各服务清本地缓存，或仅靠本地短 TTL 自然收敛）→ 后续读取回源；M5 不引入 RocketMQ 配置变更事件（产品文档 §28 的 IntegrationEvent 留给 M7）；
  - **动态 vs 重启生效**：配置元数据增加生效方式标记（dynamic/restart_required，可放 configGroup 约定或显式字段）；M5 所有种子配置均为可热生效（开关、页大小、数量上限等），重启类只有未来技术参数；管理页展示该标记；
  - **审计模型**：`system_config_history`（或分 feature/parameter 两张历史表，建议统一一张带 configType 区分）：configType/configKey/oldValue/newValue/changedBy/changeReason/traceId/changedAt；历史只追加不改写；回滚=基于历史值发起一次新修改（产品文档 §30），M5 交付历史列表与审计记录，**一键回滚 UI 可列为非必须**（需求只要求审计）；
  - **后端强制开关**：mall-common 提供 FeatureGate（isEnabled/ensureEnabled，关闭抛 FEATURE_DISABLED 业务错误）+ SystemParameterProvider（getInt/getLong/getBoolean/getString + 安全默认值）；M5 必须有一个**真实消费示范**：search.enabled 控制 mall-search 搜索接口（与 CHG-0020 联动）、mall.guest-cart.enabled 控制游客购物车（与 CHG-0018 已交付能力联动，关闭即后端拒绝游客合并）——至少落地 search.enabled 消费链证明闭环；
  - **公开配置 API**：`GET /api/mall/public-features` 无需登录，仅返回 publicFlag=true 的开关（不含内部参数），供 mall-web 显隐；非公开配置绝不通过该端点泄露；
  - **权限码**（产品文档 §11.9 已定）：system:feature:list、system:feature:update、system:parameter:list、system:parameter:update、system:config-history:list；经 identity 权限种子 SQL + 后台菜单初始化（沿用 CHG-0019 V8 订单权限种子模式，下一版本 V9）；
  - **Secret 边界**：表结构/管理页不提供任何 secret 类配置录入；DB 密码等仍走环境变量/yml/Nacos；在 PRD 显式声明该禁令；
  - **mall-admin 页面**：功能开关列表（分组/公开标记/内置标记/启停开关）、系统参数列表（分组/类型/当前值/默认值/范围校验/编辑）、配置变更历史（按 key 筛选）。

知识检索结果（引用来源）：

- M5.md 全文：REQ-M5-003 十七章 + 15 条验收、Integration Gate 场景六（功能开关）/场景七（缓存一致性）、DoD REQ-M5-003 十项与阶段验收（Feature Flag 动态生效、Config Cache 一致性）。
- product/11-权限与功能配置.md：§22 双模型字段、§23/24 配置清单（商城/AI/后台开关 + 订单/购物车/商品/AI/文件参数及类型范围）、§25 生效原则（FEATURE_DISABLED 错误码、前端隐藏+后端拒绝）、§27 缓存（key 规范/层级/TTL 10min/失效流程）、§28 变更事件（M7 形态参考）、§29 类型范围校验与 version 乐观锁（CONFIG_VERSION_CONFLICT）、§30 历史与回滚、§31 安全默认值表、§32 FeatureGate/SystemParameterProvider 接口草案；§11.9 权限码。
- product/08-系统与微服务架构.md：mall-system 8108，职责"功能配置、系统参数、操作日志 | MySQL + Redis"；路由 `/api/admin/feature-configs/**`、`/api/admin/system-parameters/**`、`/api/admin/operation-logs/**`、`/api/mall/public-features`。
- standards/engineering/backend/database-access-standard.md §7.2/§8：跨服务不直库、缓存不能作唯一数据来源——支撑 Config Client + 回源模式。
- 代码调研结论（本 Change explore 实测）：
  - `mall-services/mall-system`：纯空骨架（Application + smoke test + yml 含 mall_system 数据源/8108 + 空 migration），pom 与 mall-search 同构，无 Redis/安全依赖；
  - MySQL 初始化脚本已预建 mall_system 库；Redis 7.4 已在运（cart/order/rbac 缓存均在用，权限缓存失效模式 CHG-0013 期已验证）；
  - mall-identity 权限种子：V1~V8 migration（V8 为订单权限），配置权限为下一种子版本；
  - mall-gateway：无 8108 路由；
  - mall-admin：已有 Workbench/商品/库存/订单/补偿台页面与动态菜单/按钮权限体系，配置管理为新菜单组；
  - 消费方现状：游客购物车（CHG-0018）目前为代码常开，mall.guest-cart.enabled 接入后是首个被开关约束的既有能力；mall-search 与本 Change 同期建设，search.enabled 可直接按开关闭环设计。
- 历史 Change：CHG-0013（RBAC + Redis 权限缓存精确失效）提供缓存失效与权限码种子范式；CHG-0019（后台菜单/权限初始化）提供 admin 接线范式；无已交付配置能力。

## 2. Story 归属判定

- Feature ID: FEAT-006（新建 L1 业务域：系统配置）。
- Story 节点（feature-tree.yaml 已新建，本 Change 含 3 个，均为 planned）：
  - STORY-006-01-01-01 **配置模型、后台管理与变更审计**（L2 FEAT-006-01 → L3 FEAT-006-01-01；本 Change 锚点 Story）：Flyway 建 feature_config/system_parameter/system_config_history 表 + 内置种子初始化；双模型领域服务、类型与范围校验、version 乐观锁、builtIn 保护、安全默认值、Secret 禁入；admin CRUD/历史端点 + 五权限码 + identity 权限种子 + 网关 admin 路由；mall-admin 三页面；
  - STORY-006-02-01-01 **Redis 配置缓存与统一访问边界**（L2 FEAT-006-02 → L3 FEAT-006-02-01）：Redis 分级缓存（key 规范/10min TTL/聚合键）、更新后精确失效、内部配置查询端点（SERVICE）、mall-common Config Client（FeatureGate/SystemParameterProvider 类型安全读取 + 本地短 TTL 可选 + Pub/Sub 失效可选）、业务服务接入示范；
  - STORY-006-02-01-02 **功能开关动态生效与前端公开配置**：dynamic/restart_required 语义、ensureEnabled 后端拒绝（FEATURE_DISABLED）、GET /api/mall/public-features 公开端点、mall-web/mall-admin 按公开开关显隐；落地 search.enabled（mall-search）真实消费闭环。
- 是否新建 candidate: 否。
- Feature 路径: 系统配置 → 功能开关与参数管理/配置缓存与动态生效 → 对应 Story。
- Integration Gate 场景六/场景七不单独建 Story，作为 change 级 test-design/converge 验收场景。

## 3. 证据评估

- 业务依据：M5.md REQ-M5-003 15 条验收 + 2 个 Integration Gate 场景，管理/缓存/生效/审计/安全五类行为齐全。
- 产品依据：product/11 已有字段级、权限码级、缓存 key 级、接口级细案，是所有 M5 需求中产品知识最充分的一个，PRD 主要做"需求统一模型 vs 文档双模型"的收敛声明。
- 工程依据：mall-system 骨架/独立库/Redis/RBAC 种子机制/后台动态菜单全部齐备；跨服务内部调用样板（RestClient + X-Internal-Token + UnifyResult 解包/503 归一）在 cart/order 已验证；配置读取是典型读多写少场景，Redis 缓存方案无技术风险。
- 结论: **充分**。无阻断性未知。

## 4. 冲突点检测

- 与 specs 冲突: 无。与 database-access-standard §8"缓存不能作为唯一数据来源"一致（Redis 未命中回源 mall_system，且有安全默认值兜底）。
- 需求 vs 产品文档粒度差异: M5.md 统一配置模型 vs product/11 双模型——**处理决策：按产品文档 11 落双表双模型**，需求字段作为并集全部覆盖，JSON 补充进参数类型；在 PRD 显式说明该收敛（产品文档更细且与路由 `/feature-configs`、`/system-parameters` 完全对应）。
- 与既有 Change 重叠或沿用:
  - RBAC/菜单/权限缓存沿用 CHG-0013 成果，本 Change 只新增权限码种子与菜单数据，不改权限框架；
  - mall.guest-cart.enabled 会约束 CHG-0018 已交付的游客购物车：属新增开关对既有能力的治理性接线，在 STORY-006-02-01-02 做最小接入（后端开关校验），不重写购物车；
  - 操作日志（/api/admin/operation-logs）在 product/08 归属 mall-system，但 M5 REQ 未要求通用操作日志平台（需求只要求配置审计），本 Change **不建**通用 operation-log，仅交付 system_config_history；操作日志留待后续里程碑。
- 与已规划 Story 重复: 无（FEAT-006 全新分支）。
- 其他处理决策:
  - 1 个 REQ 拆 3 个 Story：管理侧（表/CRUD/审计/admin 页面，一个完整垂直切片）与分发侧（缓存/客户端/动态生效/前端公开）分离——前者 mall-system 自闭环，后者跨 mall-common + 多服务 + 双前端；分发侧再按"缓存与访问边界 / 生效与前端"拆 2 个，因消费者后端与公开 API/前端是两类验收；
  - 配置历史"一键回滚"不纳入 M5（需求未要求，历史记录+审计已满足），后续增强。

## 5. 待澄清问题

- 建议 PRD/Design 直接定稿：
  1. 双表双模型（feature_config / system_parameter）+ 统一历史表 system_config_history（configType 区分）；参数类型 STRING/INTEGER/LONG/DECIMAL/BOOLEAN/JSON（DURATION 随 LONG/字符串约定支持，M5 不消费）；
  2. 缓存 key 与 TTL 按产品文档 §27（Redis 10min）；本地缓存 1~5min Caffeine（mall-common 可选启用）；M5 失效以"更新即删 Redis + 本地 TTL 自然收敛"为准，Redis Pub/Sub 主动失效列为设计可选项（不做也满足"合理时间内生效"验收）；
  3. 内部端点：`GET /api/internal/config/features?keys=`、`GET /api/internal/config/parameters?keys=`（或批量聚合端点），SERVICE 身份；网关 denyAll；
  4. 错误码：FEATURE_DISABLED（开关关闭业务拒绝）、CONFIG_VERSION_CONFLICT（乐观锁冲突）；mall-system 自身错误码段取 B06xx；
  5. 生效方式字段：effect_type=DYNAMIC/RESTART_REQUIRED（M5 种子全部 DYNAMIC）；
  6. 权限码五件套按产品文档 §11.9；identity 新增 V9 种子迁移；
  7. M5 种子配置最小集：Feature：`search.enabled`(true,公开)、`mall.guest-cart.enabled`(true,公开)；Parameter：`search.default-page-size`(20,INTEGER，非公开) 等——以实际有消费方的键为准，PRD 列表定稿，宁少勿滥；
  8. 真实消费闭环：search.enabled 控制 `/api/mall/search/**`（CHG-0020 联动，关闭时返回 FEATURE_DISABLED，mall-web 隐藏搜索入口）；
  9. 审计历史不做物理删除/修改；builtIn 键禁止删除；Secret 禁令写入 PRD 与管理页校验。
- 无需要用户额外澄清的业务问题；需求与产品文档的唯一差异（单表/双表）按上述决策收敛，PRD 评审时请用户重点确认此项。
