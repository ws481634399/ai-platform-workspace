# Convergence — CHG-0022 M5 系统配置

## 0. 元信息

- Change ID：CHG-0022
- 标题：M5 系统配置（功能开关与参数管理、配置缓存与动态生效）
- 完成时间：2026-09-19
- 生命周期：当前 testing；本文件仅作收敛判断与知识登记，不触发 Change 状态推进（completed 由流程审批推进）
- 产出 Artifact 数：27 篇
  - Change 级 9 篇：exploration.md、requirement.md、requirement-spec.md、requirement-design.md、test-design.md、implementation.md、evidence/test-report.md、review-report.md、convergence.md
  - Story 级 18 篇：3 个 Story × 6（story-spec.md、story-design.md、test-design.md、implementation.md、evidence/test-report.md、review-report.md）
  - 另：metadata.yaml、4 份 evidence.yaml、3 份 story-metadata.yaml 为载体/索引，不计入 Artifact 数
- standards-need-update：yes
- product-need-update：yes（Spec 晋升候选 1 篇 product/specs/系统配置.md，待人工评审后落库）
- featuretree-need-update：yes（3 个 Story 节点 planned → delivered）
- glossary-need-update：no
- 参与仓库：repo-1（ai-platform-backend）、repo-2（ai-platform-frontend）
- review 结论：0 blocker / 0 major / 6 条 Change 级 minor（EV-007~EV-012）+ 22 条 Story 级 minor（Story1 9、Story2 6、Story3 7），全部登记去向，无开放 blocker/major

## 1. 知识变化总结

本 Change 首次在平台引入"系统配置中心 + 动态生效"能力，沉淀 6 项可跨 Change 复用的工程知识（review §1.5）：

1. **配置中心唯一写者边界**：mall-system（8108）是 `system_config_feature`/`system_config_parameter`/`system_config_history` 的唯一写者；mall-search、mall-cart 等消费端对 Redis 只读、对配置中心仅经内部 HTTP 只读，回填责任在配置中心单侧，禁止跨服务直库或回写。
2. **fail-open 的 FeatureGate 分层语义**：前端 UI 显隐 fail-open（拉取失败默认放行，避免误隐藏入口）；服务端只在"显式取到 enabled=false"时拦截（B0606 功能未开启，403）；Provider/Redis/HTTP 全链路故障时默认放行并打 WARN，绝不因配置基础设施故障阻断主交易。
3. **Redis 键命名与 TTL 分层**：单键 `aimall:{env}:system:feature:{key}`、`aimall:{env}:system:parameter:{key}`，聚合键 `aimall:{env}:system:feature:public-features`；Redis 值 TTL 600s、missing 负缓存 60s；消费端本地缓存 TTL 60s。键名分段固定，禁止业务侧拼键。
4. **AFTER_COMMIT 精确删键作为 M5 轻量分发方案**：管理端变更提交后（事务提交后）精确删除受影响单键，并恒删 `public-features` 聚合键；跨服务新读立即取 Redis 新值，旧持有者最迟经本地缓存 60s TTL 到期收敛（有界生效 ≤60s，无额外传播时延）。M5 明确不做 Redis Pub/Sub，留待 M7 评估。
5. **内部批量查询契约**：`/api/internal/config/features|parameters/batch` 走 X-Internal-Token 共享密钥头；请求 `keys` 必填、去重、数量 ≤100，为空或超限直接 HTTP 400 + A 段参数校验码（A0001，framework-standard §13.4，经 IllegalArgumentException → GlobalExceptionHandler 映射），不分批、不用 B06 业务码；响应包络冻结为 `{values:{key:{...}},missingKeys:[...]}`。
6. **播种与并发变更模式**：内置配置仅由 Flyway 版本化 DML（V1）唯一播种（`built_in=true`），内置项禁删、key 结构性不可改（路径参数 + 更新体无 key 字段）；并发更新采用版本号乐观锁"预检 + DB CAS"双保险，冲突抛 B0604 并由前端引导刷新；全部管理操作落审计（含操作人、traceId、前后值）。

## 2. 更新判断

### 2.1 Standards（新建，待 sdd-knowledge 统一写回）

**项 1：动态配置标准**

- 文件：standards/engineering/backend/dynamic-config-standard.md（新建）
- 操作：新增（主流程统一写入；本文件记录判断、概要与理由）
- 内容概要（映射 §1 六项增量）：
  1. 唯一写者与消费端只读边界，禁跨服务直库；
  2. 内置数据唯一播种路径 = Flyway 版本化 DML，禁止内置数据 Java seeder 双保险；
  3. Redis 键命名/TTL 分层（值 600s / 负缓存 60s / 本地 60s）与聚合键恒删规则；
  4. AFTER_COMMIT 精确删键 + 本地短 TTL 的有界收敛方案，Pub/Sub 为后续阶段选项而非默认；
  5. FeatureGate fail-open 三层语义（UI、服务端显式 false、全故障放行 + WARN）；
  6. 内部批量查询契约（X-Internal-Token、keys 必填去重 ≤100、`{values,missingKeys}` 包络、A 段校验码）；
  7. 版本号乐观锁"预检 + DB CAS"与 B0604 冲突刷新引导、审计留痕。
- 理由：配置中心是后续 M6/M7 多个模块（限流、灰度、活动）的共性基础设施，本 Change 冻结的边界、键规、契约与一致性模式具备跨 Change 复用价值。
- 复用场景：后续一切动态开关/参数类能力、跨服务只读缓存、内部批量取数端点设计。

### 2.2 Product（Spec 晋升候选，人工评审后落 product/specs/）

**项 1：系统配置产品规则**

- 文件：product/specs/系统配置.md（评审通过后创建）
- 操作：新增
- 草稿要点：
  - 配置分两类：功能开关（BOOLEAN，enabled）与系统参数（STRING/INTEGER/DECIMAL/BOOLEAN/DATETYPE/JSON，含 min/max 约束）；
  - 4 个内置种子键：`search.enabled`（开关，公开）、`mall.guest-cart.enabled`（开关，公开）、`search.default-page-size`=20（INTEGER，[1,100]）、`cart.max-item-quantity`=99（INTEGER，[1,999]）；
  - 错误码：B0601（参数校验失败/内置保护）、B0602（键重复，409）、B0603（配置不存在）、B0604（版本冲突，引导前端刷新）、B0606（功能未开启，服务端 403）；
  - 公开端点只返回公开标记（publicFlag=ON）的开关：非公开键与全部参数不出域；禁用的公开项以 `enabled=false` 返回（前端据此隐藏入口），响应字段冻结为 `{key,enabled}`；
  - 管理面位于 mall-system（端口 8108），仅 ADMIN，全量变更审计；
  - 开关消费策略 fail-open；M5 不提供 Pub/Sub 实时推送，动态生效有界 ≤60s。
- 理由：PRD 已确立开关/参数两类模型、种子键与管理/消费规则，作为后续运营配置类需求的产品依据。
- 来源：requirement-spec.md 业务规则、requirement-design.md 冻结契约。
- 状态：候选草稿，待人工评审；本阶段不写入 product/。

### 2.3 Feature Tree（3 节点，planned → delivered）

- STORY-006-01-01-01（配置模型、后台管理与变更审计）：planned → delivered
- STORY-006-02-01-01（Redis 配置缓存与统一访问边界）：planned → delivered
- STORY-006-02-01-02（功能开关动态生效与前端公开配置）：planned → delivered
- 方式：`openspec feature update <ID> --status delivered`（由 feature-tree/sdd-knowledge 流程统一执行；本阶段仅登记，未直接改写 Feature Tree）

### 2.4 Glossary

- no update：FeatureGate、fail-open、负缓存等术语在本 Change 文档内自洽，无需新增术语库条目。

### 2.5 No Update

- 实体 JSON 字段级明细、DTO/VO 字段名：属实现细节，契约已冻结在 requirement-design 与 Spec 候选中。
- Caffeine 选型、Spring Cache 装配、`@Cacheable` 等技术用法：属实现选择，标准只沉淀 TTL 分层结论。
- 测试以 H2(MODE=MySQL) 替代 MySQL 容器的具体连接参数：属测试工程细节。

## 3. 知识沉淀过程

### 3.1 沉淀流程

1. 通读 Change 级 9 篇与 3 个 Story 各 6 篇 Artifact，提取知识项并分类（1 standards + 1 spec 候选 + 3 feature-tree + glossary no + 3 no-update）。
2. 对照 review-report 全部 finding 核实闭环状态与去向。
3. 执行 EV-010 文档措辞回修（见 3.2），消除"文档说一套、代码做一套"的契约漂移。
4. 登记 EV-011/EV-012 等非本阶段落地项（见 3.3），并声明历史记录类文档保留原则（见 3.4）。
5. 逐条对照 17 条全局 AC 与真实证据形成 §4。
6. standards/product/feature-tree 本阶段仅作判断登记，实际写回由 sdd-knowledge/feature-tree 流程统一执行；未修改 standards/、product/ 任何文件。

### 3.2 EV-010 文档回修清单（①-⑧、⑩共 10 项已改；⑨登记不改）

| 项 | 回修内容 | 文件与位置 |
| --- | --- | --- |
| ① | mall-identity 种子版本 V9 → V10（V9 为 CHG-0021 搜索权限 + SearchIndex 菜单版本） | requirement-spec.md §0（L13）、§3.1（L42）；Story1 story-spec.md §2.1（L31） |
| ② | 内部批量端点响应包络 `{features:[...]}/{parameters:[...]}` → `{values:{key:{...}},missingKeys:[...]}`，并补 keys 必填/去重/≤100 | requirement-design.md §2.3（L89-90）、§4 跨仓契约（L150）；Story2 story-spec.md §4（L49-50） |
| ③ | keys 为空或 >100 的返回由 B0601 400 改为 HTTP 400 + A 段参数校验码 A0001（framework-standard §13.4）；"超出分批"改为硬上限直接 400（DEV-3） | Story2 story-design.md §1（L31、L39）、§2（L51） |
| ④ | 公开特性响应字段 `{configKey,enabled}` → `{key,enabled}`（与实现冻结契约一致） | Story3 story-spec.md §2.1（L28） |
| ⑤ | DYNAMIC 生效时延"≤66s（本地 60+传播）"→"有界生效 ≤60s"：AFTER_COMMIT 删键后跨服务新读立即取 Redis 新值，仅本地 60s TTL 收敛，无额外传播时延 | Story3 story-design.md §4（L52） |
| ⑥ | 列表/历史查询参数与冻结实现对齐：开关列表 `?group=&enabled=`、参数列表 group/type；历史查询参数名冻结为 `key`（configType=&key=，响应视图字段仍名 configKey）；keyword 关键词搜索标注本期未实现、待后续评估 | Story1 story-spec.md §3（L46）、§4（L50-52）；Story1 story-design.md §1（L36） |
| ⑦ | 内置项保护措辞：禁删、禁改 key（路径参数 + 更新体无 key 字段，结构性不可改）；enabled/value 等其余字段可由 ADMIN 修改 | Story1 story-spec.md §3（L43） |
| ⑧ | requirement 技术约束删除"（可选）Redis Pub/Sub 轻量通知"，明确 M5 不做 Pub/Sub；机制 = AFTER_COMMIT 删 Redis 单键并恒删 public-features 聚合键 + 本地 60s TTL 有界收敛；Pub/Sub 留 M7 | requirement.md L162 |
| ⑩ | 游客开关切点措辞：关闭态拦截点为游客 merge-token/merge 两端点（M4 游客数据进入服务端的唯一写入口）403；会员 /cart/items 不经开关；匿名直接加购无独立服务端点，关闭态由前端禁用按钮 + 登录引导拦截 | Story3 test-design.md TC-004 行（L22）；Change 级 test-design.md S3-TC-004 行（L46） |
| ⑨ | **未改，登记"下次触达随改"**：(a) repo-1 mall-system V1 SQL 注释称与 BuiltInConfigSeeder"双保险"（实际不存在该类，唯一播种 = Flyway V1 DML）；(b) InternalConfigController javadoc 对 keys 校验标注 B0601（实际为 A 段码）。二者位于 implementation/ 代码仓，converge 阶段无权修改 | 代码仓文件，仅登记：V1 Flyway 脚本注释、InternalConfigController javadoc |

### 3.3 其他 finding 去向

- **EV-011（安全硬化）**：管理端 configKey 入参 `[a-z0-9.-]+` 正则白名单（DEV-4）由后续 Change 在领域层补（当前依赖 JPA 参数化与管理端 ADMIN 权限，无注入面）；内部共享密钥 `MALL_INTERNAL_SHARED_SECRET` / `mall.config.internal-token` 属生产部署必注入配置（禁沿用 dev-internal-secret 默认值），已列入上线部署清单，M5 Integration Gate 联调环境核验。
- **EV-012（metadata 回填）**：metadata.yaml 的 repository-result 已由 converge 回填为 repo-1 commit `0715aefabc846cf198676150a3747fadd4b6c59c`、repo-2 commit `66b90214a61e546888725fd82ce30b7aae426bad`，供 submodule-pointer-aligned 机检消费；该 SHA 为 DU 回填时点仓指针，与 evidence 记录的代码提交 SHA（repo-1 82ccf6e、repo-2 af19b9e/404eb77）口径不同，均真实可溯。
- **EV-007/EV-008/EV-009 测试缺口**：场景六/七真实翻转、网关 8080 联调、多副本删键、浏览器三配置页交互等统一延后 M5 Integration Gate（见 §4、§5 登记），不阻断本 Change 收敛。

### 3.4 历史记录保留说明

- exploration.md L24/L29/L53/L83/L87 存在探索时点的 V9 与"Pub/Sub 可选"原文：探索文档是时点真实快照，不在 EV-010 回修目标列表内，版本演进已由 requirement-design.md §1 完整记录，故保留原文不改。
- review-report.md、3 份 Story review-report.md、各 evidence.yaml 中出现的 V9/V10、≤66s、features/parameters、B0601 等字样，是 finding 对"残留措辞"的历史引述，属审查/证据记录，按不可回修原则保留。
- requirement-design.md L110 公开端点示例 `{features:[{key,enabled}]}` 是 UnifyResult.data 的数组包装（公开端点真实形态），与内部批量端点的 values 包络无关，不改。

## 4. 全局验收标准对照

证据口径：后端全 reactor 482/482 全绿（本 Change 35 例：mall-system 19、common-config 12、search 2、cart 2，EV-004）；mall-admin 47/47 全绿（config.spec 12，EV-005）；mall-web 102/102 全绿（features.spec 3、ProductDetailView.spec 6，EV-006）。代码提交：repo-1 82ccf6e、repo-2 af19b9e（FE-504）/404eb77（FE-503）。

| # | 验收点 | 覆盖 Story | 证据引用 | 结论 |
| --- | --- | --- | --- | --- |
| AC-001 | 三表模型与 4 个内置种子键随 V1 迁移落库（builtIn=true） | S1 | ConfigAdminApiTest#pageSeededFeatures、#pageSeededParameters（分页读到种子并断言内置/类型/边界）；MallSystemApplicationSmokeTest#contextLoads（Flyway V1 DDL+DML 经 Flyway 真实执行，H2 MODE=MySQL 替代 MySQL，EV-008⑥） | 通过（自动化；MySQL 8 方言首启确认随联调，EV-008） |
| AC-002 | 开关管理 CRUD + 键唯一约束（重复 409 B0602） | S1 | ConfigAdminApiTest#createFeatureAndDuplicate（重复键 409/B0602）、#createFeatureInvalidName、#pageSeededFeatures、#authenticationAndAuthorization | 通过 |
| AC-003 | 参数管理与类型/边界校验（越界、非法 JSON、未知类型 400 B0601） | S1 | ConfigAdminApiTest#createParameterValidation（越界、非法 JSON、DATETIME 传 "x" 精确断言 400/B0601）；INTEGER 传 abc、BOOLEAN 传 yes 指名用例与读回断言列入 backlog（EV-008①） | 通过（自动化核心断言；指名用例补强随 EV-008） |
| AC-004 | 参数/开关并发更新乐观锁（版本冲突 B0604 + 前端刷新引导） | S1 | ConfigAdminApiTest#updateFeatureCas（预检 + DB CAS 双保险，版本冲突 B0604） | 通过 |
| AC-005 | 内置项禁删/禁改 key，非内置删除留审计（DELETED 历史） | S1 | ConfigAdminApiTest#deleteFeature、#updateAndDeleteParameter（内置操作 B0601 拒绝；非内置删除后历史留痕）；traceId/前后值逐例断言补强随 EV-008② | 通过 |
| AC-006 | 变更历史查询（configType/key 过滤）与 ADMIN 权限、审计 | S1 | ConfigAdminApiTest#historyFilterAndAuth、#authenticationAndAuthorization（401/403 自动化覆盖）；V10 权限/菜单种子经 SQL 静态核实（迁移断言补强 EV-008④） | 通过 |
| AC-007 | 管理后台配置三页面（列表/编辑/历史）可用，四门门禁全绿 | S1 | mall-admin config.spec.ts 12 例 + lint/typecheck/unit/build 四门门禁；三配置页面浏览器人工交互未执行，延后 M5 Integration Gate 场景六（EV-009） | 通过（组件/门禁自动化；浏览器交互延后，EV-009） |
| AC-008 | Redis 缓存读写：首读回填（TTL≈600s）、二读命中、更新删键 | S2 | ConfigCacheIntegrationTest#fetchWritesRedis（断言 TTL ∈ [500,600]s）、#secondReadHitsCache、#updateEvictsCache（AFTER_COMMIT 删键） | 通过 |
| AC-009 | 内部批量端点：X-Internal-Token 强制、keys 校验、负缓存、快照契约 | S2 | ConfigCacheIntegrationTest#internalRequiresToken（无/错令牌 401）、#keysValidation（空/超 100 → 400 + A 段码）、#missingKeyNegativeCache（负缓存 60s）、#parameterSnapshotContract（values/missingKeys 包络与全字段）；网关侧 CHG0015GatewaySecurityChainTest#internalAnonymousReturns404/#internalWithAdminTokenStill404（/api/internal/** 前缀级同构回归），config 子路径 8080 专项随联调（EV-007） | 通过（前缀级网关证据；8080 config 专项延后，EV-007） |
| AC-010 | 统一访问边界 SystemConfigClient：缓存/负缓存/回源/全故障 fail-open | S2 | SystemConfigClientTest 7 例（#redisHitThenLocalCache、#redisNegativeMarkerCached、#redisMissFallbackToHttp、#httpParameterFullFieldNames、#redisFailureAndHttpMissing、#allLayersDown、#providerFallbacks）；ConfigFacadesTest 5 例（#gateRejectsExplicitDisabled、#gateAllowsExplicitEnabled、#gateDefaults、#providerFallbacks、#errorCodeFrozen）；WARN 日志逐例断言随 EV-008⑤ | 通过 |
| AC-011 | search/cart 不直库，只依赖 common-config | S2 | 代码 grep：search/cart 对 system_config 表/JdbcTemplate/Repository 0 命中；两仓 pom 仅依赖 common-config；contextLoads 装配通过；ArchUnit 架构门禁自动化列入 backlog（Story2 EV-007） | 通过（静态审计；架构测试 backlog） |
| AC-012 | search.enabled 服务端显式 false 拦截 403 B0606，开启放行 | S3 | SearchFeatureGateTest#searchDisabledReturns403（B0606）、#searchEnabledPasses（两态切片 + ConfigFacadesTest 缓存分段）；单运行内真实翻转未串联，延后 M5 Integration Gate 场景六（EV-007/EV-008 Story3） | 通过（两态切片；真实翻转延后，EV-007） |
| AC-013 | mall.guest-cart.enabled 关闭拦截游客 merge-token/merge，会员不受影响 | S3 | GuestCartFeatureGateTest#guestCartDisabledRejectsMergeEndpoints（merge-token/merge 切点 403）、#guestCartEnabledAndMemberUnaffected（开启放行 + 会员 /cart/items 不经开关）；真实翻转联调随 EV-007 | 通过（切点冻结为 merge 两端点） |
| AC-014 | 公开配置端点只返公开开关 `{key,enabled}`（禁用公开项带 false），网关 8080 可达 | S3 | ConfigCacheIntegrationTest#publicFeatures（公开键含禁用项 enabled=false；非公开键与参数不出域）；stores/features.spec.ts 3 例；网关 8080 端到端链路延后 M5 Integration Gate 场景六（EV-007/EV-011 Story3） | 通过（契约自动化；8080 链路延后，EV-007） |
| AC-015 | 前端按公开配置 fail-open 显隐（搜索框、游客加购、登录引导） | S3 | stores/features.spec.ts 3 例；ProductDetailView.spec.ts 6 例（含关闭态禁用加购 + 登录引导）；MallLayout/SearchView 浏览器显隐与管理三页面组件测试延后场景六（EV-009） | 通过（单测；浏览器/组件显隐延后，EV-009） |
| AC-016 | effectType=api 运行时拉取，STATIC/DYNAMIC 语义与 ≤60s 有界生效 | S3 | SystemConfigClientTest#localCacheExpires（1s 注入）与 60s 生产常量链路、effectType api 透传链路均有分段自动化；页面 tag 静态展示组件断言随 EV-009 | 通过（分段链路；页面 tag 断言随 EV-009） |
| AC-017 | 全量回归与跨 Story 集成（真实翻转、网关、多副本、浏览器三配置页） | ALL | 482/482 + 47/47 + 102/102 全绿（EV-004/005/006）+ 上述缓存/删键/两态开关分段证据；场景六/七真实端到端翻转、网关 8080 联调、多副本删键、浏览器三配置页未在本阶段执行 | 自动化全绿；场景六/七延后 M5 Integration Gate（EV-007/EV-009），已在 §5 登记 |

**汇总结论**：17 条 AC 全部有自动化或静态审计证据支撑；AC-001/003/005/006/010 含 EV-008 测试深度补强 backlog（不影响当前结论），AC-007/009/012/013/014/015/016/017 的真实端到端/浏览器/网关 8080/多副本环节统一延后 M5 Integration Gate 场景六/七（EV-007/EV-009），无阻断收敛的开放项。

## 5. 完成确认

- [x] 代码变更已完成（repo-1 82ccf6e；repo-2 af19b9e/404eb77；metadata DU 指针已由 converge 回填，EV-012）
- [x] 测试已完成（自动化 482/482 + 47/47 + 102/102 全绿，EV-004/005/006；场景六/七真实端到端、网关 8080、多副本、浏览器三配置页延后登记至 M5 Integration Gate，EV-007/EV-009；测试深度补强登记 EV-008）
- [x] 证据已收集（4 份 evidence.yaml + 4 份 test-report；commits、命令、日志均可溯）
- [x] 全局验收标准已逐条对照（§4 共 17 条，证据引用真实测试类/EV 编号，无裸用例占位）
- [x] 知识更新已评估（standards 新建 1 篇；product Spec 候选 1 篇待人工评审；feature-tree 3 节点 planned → delivered；glossary no；no-update 3 项已列）
- [x] EV-010 文档措辞回修已完成（①-⑧、⑩共 10 项落到 8 个交付文档 11 处编辑；⑨代码仓 V1 SQL 注释与 InternalConfigController javadoc 登记"下次触达随改"，未改代码）
- [x] 安全硬化项已登记去向（configKey 正则 DEV-4 后续 Change；内部密钥生产必注入，EV-011）
- [x] 无未解决的 blocker/major（28 条 minor 全部登记去向）；本文件不直接写回 standards/product/feature-tree，写回由 sdd-knowledge/feature-tree 流程统一执行
