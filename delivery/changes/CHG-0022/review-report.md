# Review Report（Change 级聚合）— CHG-0022 M5 系统功能与参数配置

> 各 Story 审查明细见对应 Story 目录下的 review-report.md：
> - Story 1（STORY-006-01-01-01 配置模型、后台管理与变更审计）
> - Story 2（STORY-006-02-01-01 Redis 配置缓存与统一访问边界）
> - Story 3（STORY-006-02-01-02 功能开关动态生效与前端公开配置）

## 0. 元信息

- Change ID：CHG-0022（REQ-M5-003 系统功能与参数配置）
- 审查时间：2026-09-19
- 审查者：sdd-review 独立评审 Agent（只读分析，未修改业务代码/测试/既有文档，未写 evidence.yaml）
- 审查范围：requirement-spec.md（17 条 AC）、requirement-design.md、implementation.md（9 条关键技术决策）、evidence/test-report.md、evidence/evidence.yaml（EV-001~EV-006）、3 个 Story 全套产物、5 个仓内 DU implementation.md（共 19 条 Deviations）
- 代码基线：repo-1 提交 82ccf6e（DU-BE-507/508/509）、repo-2 提交 af19b9e（DU-FE-504）、404eb77（DU-FE-503）；metadata.yaml baseline repo-1 2342a26 / repo-2 daef5c0
- 测试总览：后端全 reactor **482/482**（本 Change 直接相关 35 例）、mall-admin **47/47**（config 12）、mall-web **102/102**（features 3、ProductDetailView 6），四门门禁全绿

## 1. 检查结论

**通过（PASS）。** 17 条 Change AC 中 10 条 passed、7 条核心功能断言全部通过但存在覆盖深度/端到端形态缺口（AC-003/AC-006/AC-007/AC-015/AC-016/AC-017，AC-005 含字段断言深度说明），所有缺口均为 **minor** 且去向明确（Integration Gate 场景六/七联调、测试增强 backlog、sdd-converge 文档回修）。冻结契约（错误码、Redis 键与 TTL、8108 端口、内部端点鉴权、4 种子键、fail-open 语义）逐项源码核实一致。**无 blocker、无 major。**

### 1.1 需求一致性

| AC | 验收标准（摘） | 结论 | 主要证据 |
| --- | --- | --- | --- |
| AC-001 | V1 三表与内置种子、builtIn=true | passed（环境替代） | V1 SQL 与冻结值逐字一致；ConfigAdminApiTest#pageSeededFeatures/#pageSeededParameters、SmokeTest contextLoads；H2(MODE=MySQL) 替代 MySQL 容器，联调首启确认（Story1 建议 EV-009） |
| AC-002 | 分页/分组/增改启停 + key 唯一拒绝 | passed | ConfigAdminApiTest 全流程方法；重复键 409 B0602 |
| AC-003 | 四类非法参数值 400 不更新 | partial（功能通过、指名覆盖缺） | 越界/非法 JSON 精确、DATETIME "x" 等价、跨层坏值回退；INTEGER "abc"/BOOLEAN "yes" 无逐字用例、无读回断言（Story1 建议 EV-008） |
| AC-004 | 版本冲突 B0604 + 最新版可改 | passed | #updateFeatureCas（v0 成功 0→1、重提 409）；版本预检 + DB CAS 双保险 |
| AC-005 | 变更历史完整、可按 key 查、只追加 | passed（traceId 深度不足） | CREATED/UPDATED/DELETED 三类历史断言 + 过滤分页；HistoryView 九字段源码核实，traceId 未逐例断言（Story1 建议 EV-008） |
| AC-006 | 五权限码与菜单；无权限 403 | partial（接口断言通过、种子静态） | 401/403/跨资源 403 真实 JWT 断言；identity V10 五码 + /system 目录 + 三 PAGE 菜单 + 超管授权仅 SQL 静态核实（Story1 建议 EV-008） |
| AC-007 | mall-admin 三页面可用、四门通过 | partial（门禁全绿、组件未测） | config.spec 12 例 + type-check/lint/build 全绿；三页无组件 vitest（Story1 建议 EV-010） |
| AC-008 | Redis 缓存回填、TTL≈10min、更新删键后读新值 | passed | ConfigCacheIntegrationTest#fetchWritesRedis（TTL ∈[500,600]）、#secondReadHitsCache、#updateEvictsCache（单键+聚合键双删后读新值） |
| AC-009 | 内部端点 SERVICE、网关 404、最小返回、回源回填 | passed（网关前缀级同构） | #internalRequiresToken、#keysValidation（空/101 键 400）、#missingKeyNegativeCache、#parameterSnapshotContract；网关 /api/internal/** denyAll 由 CHG0015 既有用例同构覆盖 |
| AC-010 | 类型安全读取；坏值默认+WARN；服务不可用不抛 | passed（WARN 未断言） | ConfigFacadesTest 5 + SystemConfigClientTest 7；每键每分钟 WARN 限频无日志断言（Story2 建议 EV-005） |
| AC-011 | 业务服务无直库/自建 DAO | passed（人工静态审计） | mall-search/mall-cart grep 0 命中 + pom 仅依赖 mall-common-config + contextLoads；无 ArchUnit（Story2 建议 EV-007） |
| AC-012 | search.enabled=false 后端 FEATURE_DISABLED、重开恢复 | passed（真实翻转未串联） | SearchFeatureGateTest 两态（403 B0606 不触 ES / 200）；生效链路由缓存 IT + 本地 TTL 单测分段支撑（Story3 建议 EV-008） |
| AC-013 | guest-cart=false 拒绝游客写、会员不受影响 | passed（切点措辞差异） | GuestCartFeatureGateTest（merge-token/merge 403；会员 /cart/items 200）+ ProductDetailView 新增两例；切点即 M4 游客车服务端唯一入口，实现合理（Story3 建议 EV-010） |
| AC-014 | public-features 匿名仅公开 {key,enabled} | passed（网关链路留联调） | #publicFeatures（含禁用公开项 false、非公开/参数不出现）；经 8080 的链路为配置静态核实（Story3 建议 EV-011） |
| AC-015 | mall-web 入口随开关显隐；admin 按权限隐控件 | partial（store/api 级、组件静态） | features.spec 3 例 fail-open/映射/静默；MallLayout v-if、SearchView 空态、v-permission 按钮源码静态核实（Story3 建议 EV-009、Story1 建议 EV-010） |
| AC-016 | effectType 标识；热生效 ≤60s | partial（tag 静态、时延链路通过） | api 层 DYNAMIC/RESTART_REQUIRED 透传；60s 上限为代码常量且 1s 注入等价证明；页面 tag 无组件断言；无重启钩子符合 §3.2 不包含项 |
| AC-017 | Integration Gate 场景六/七 E2E；测试全绿 | partial（全绿达成、端到端联调待执行） | 482/47/102 全绿且关键链路分段自动化齐备；真实多服务翻转、网关 8080、多副本收敛未在单机执行（建议 EV-007） |

### 1.2 设计一致性

- implementation.md 9 条关键技术决策与实现核对：双模型收敛（FeatureConfig/SystemParameter 字段并集真实落地）；identity 权限种子版本 V10（代码一致，需求级文档残留 V9 措辞）；错误码 B0601~B0604/B0606 冻结（mall-system 与 mall-common-config 两处定义一致）；fail-open 仅显式 false 拦截（FeatureGate/前端 store 双侧核实）；M5 不做 Redis Pub/Sub，动态生效=AFTER_COMMIT 删单键+聚合键 + 本地 60s TTL 兜底（无 MessageListener/convertAndSend）；Flyway DML 唯一播种（无 Seeder 类）；mall-system 为缓存唯一写者；TTL 600/60/60 分层；Secret 不入库（两表无任何密钥类字段，管理端无入口）。
- 19 条 DU Deviations（DU-BE-507 6 条、DU-BE-508 5 条、DU-BE-509 3 条、DU-FE-503 3 条、DU-FE-504 2 条）**全部有记录**，逐条复核结论为合理或影响可控；未发现未登记的实现偏离。关键偏离：B0605 并入 B0601、H2 测试替代、无 keyword 过滤、键字符正则未落（DEV-4，安全 minor 独立登记）、历史参数名 `key`、客户端不回写 Redis、evict 失败仅 warn、游客车切点 merge-token/merge、前端无独立 store、无组件测试。
- 安全专项核实：内部端点 X-Internal-Token 常量时间比较 + 无凭证 401 + SERVICE 角色 + 网关 denyAll，符合 security-guidelines.md 内部端点隔离全部要点；共享密钥默认值 dev-internal-secret 仅本地开发用途，由 MALL_INTERNAL_SHARED_SECRET / mall.config.internal-token 环境覆写（CHG-0015 起既有约定），生产注入列入建议 EV-011 上线检查；admin 端点 hasRole("ADMIN") + 方法级五权限码；公开端点最小化返回。
- 契约差异均为文档侧陈旧措辞、代码侧自洽且唯一消费端同提交适配：内部端点包络 values 与 features/parameters 之差异、keys 校验错误码（实现返回 A 段参数码，符合 framework-standard §13.4）、V9/V10、configKey/{key,enabled}、≤66s/60s 等，统一归集建议 EV-010。

### 1.3 跨仓一致性

requirement-design §4 跨仓契约由各仓证据共同满足，三条链路逐环节源码核实闭环：

1. **配置写→缓存→消费读链**：mall-system AppService 写库 + history 同事务 → ConfigChangedEvent → AFTER_COMMIT CacheEvictionListener 删 Redis 单键 + public-features 聚合键（失败仅 warn，TTL 兜底）→ mall-common-config（本地 60s → Redis 600s/负 60s → 8108 内部端点 X-Internal-Token → 默认值）→ mall-search ProductSearchService 与 mall-cart CartController 真实注入并切点生效。消费服务无 mall_system 数据源/DAO。
2. **公开配置链**：mall-system PublicFeaturesController（permitAll）→ mall-gateway 路由 + 白名单 /api/mall/public-features/**（/api/internal/** denyAll 不变）→ mall-web features api/store（fail-open）→ MallLayout/SearchView/ProductDetailView。
3. **管理与权限链**：identity V10 五权限码/三菜单/超管授权 → mall-system 三 admin Controller @PreAuthorize → 网关 mall-system-admin 三组路由 8108 → mall-admin 三页 v-permission + api/config.ts 契约（分页形状、HistoryView 九字段、B0602/B0604/403 归一化）。
- 仓库基线：metadata.yaml repository-baseline 已登记（repo-1 2342a26、repo-2 daef5c0），实际交付提交见 EV-001~EV-003；repository-result 未回填（{}），列为流程观察（建议 EV-012），不影响代码一致性结论。

### 1.4 代码质量

- 正向项（依据 standards/）：DDD 分层清晰（interfaces/application/domain/infrastructure，符合 architecture-principles.md）；错误响应统一 UnifyResult、错误码分段与全局异常处理符合 framework-standard.md §13；Bean Validation + 领域类型/范围双层校验符合 api-design-standard.md；内部端点鉴权与网关隔离符合 security-guidelines.md；测试证据真实（Testcontainers Redis 7.4.11 TTL/删键断言、真实 JWT 安全链、ES Testcontainers 下验证不触达查询、非全 mock 假证）。
- 负面项：configKey 字符白名单缺失（ADMIN-only 受信面，minor）；CacheEvictionListener 一处未使用 import；前端仅 api/store 层测试无组件测试；后端指名非法值/traceId/迁移断言等深度缺口；不直库约束无自动化架构门禁；多实例与网关端到端留联调。全部为 minor，详见 §2 及各 Story 报告。

### 1.5 知识同步候选（仅候选，沉淀由 sdd-converge 执行）

1. 配置中心边界模式：唯一写者（mall-system）回填 Redis，消费端只读 Redis/HTTP + 本地短 TTL，禁止跨服务直库。
2. fail-open FeatureGate 模式：UI 显隐 fail-open 与服务端"仅显式 false 拦截、全故障默认放行 + WARN"的分层决策，以及存量能力/高风险能力逐键默认值评估。
3. Redis 键命名与 TTL 分层：aimall:{env}:system:feature|parameter:{key} 与 :public-features；值 600s / 负缓存 60s / 本地 60s 的数值依据。
4. AFTER_COMMIT 精确删键（单键 + 恒删聚合键）+ 本地 TTL 有界收敛，作为 M5 阶段替代 Pub/Sub 的轻量方案（含多实例收敛代价与联调验证点）。
5. 内部批量查询端点契约：X-Internal-Token SERVICE 身份、keys 必填去重 ≤100、{values,missingKeys} 最小返回。
6. 内置配置 Flyway 版本化 DML 唯一播种 + 乐观锁"预检 + DB CAS"双保险 + B0604 前端刷新引导的前后端协作约定。

## 2. 发现清单

> review 阶段不写 evidence.yaml；下列 EV 编号为**建议登记号**（Change evidence.yaml 当前至 EV-006），供 converge/后续流程登记。各 Story 明细 finding 编号（建议 EV-005 起）见对应 Story 报告。minor 允许开放，均给出处理去向。

| 建议 EV | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-007 | requirement-spec.md#AC-017；evidence/test-report.md §5 缺口① | minor | Integration Gate 场景六（开关动态生效）、场景七（缓存一致性）未执行真实端到端：无单运行"管理端 PUT OFF → 删键 → ≤60s 搜索/游客车 403 → 重开恢复"翻转，无经网关 8080 的 public-features 200/admin 401 自动化，无多消费副本跨节点收敛编排验证。自动化分段证据（缓存 IT、TTL 单测、两态切片、安全链、网关前缀回归）齐备且全绿 | 联调/部署环境按场景六/七执行多服务浏览器 + 多副本验收并回填 Gate 证据；后续可补 testcontainers 级翻转 IT |
| EV-008 | requirement-spec.md#AC-003、#AC-005、#AC-006；Story1 建议 EV-008/EV-009、Story2 建议 EV-005 | minor | 后端测试覆盖深度合集：①INTEGER "abc"、BOOLEAN "yes" 两指名非法值无逐字用例且无"值不变"读回断言；②历史 traceId 字段存在未逐例断言；③删不存在键无专门用例；④identity V10 种子仅 SQL 静态核实无迁移断言；⑤参数键失效无独立 IT、Provider WARN 限频无日志断言、全故障为桩级注入；⑥H2(MODE=MySQL) 替代 testcontainers MySQL | 测试增强 backlog：参数化非法值 + 读回、traceId、DELETE 缺失键、mall-identity V10 断言、参数删键 IT、WARN 捕获；联调/部署首启确认 MySQL 8 方言 |
| EV-009 | requirement-spec.md#AC-007、#AC-015、#AC-016；Story1 建议 EV-010、Story3 建议 EV-009 | minor | 前端组件测试缺口：mall-admin 三管理页（渲染/启停/类型表单矩阵/范围提示/内置禁用/v-permission/B0604 引导）与 mall-web MallLayout 入口显隐、SearchView 关闭空态、SystemParametersView effectType tag 均无组件级 vitest（api/store 层 12+3 例通过、DOM 行为静态核实） | Integration Gate 场景六浏览器验收；后续建立管理页/布局组件 vitest 基线 |
| EV-010 | requirement-spec.md §0/§3.1、requirement.md 技术约束、requirement-design.md §2.1/§2.3/§4；三 Story story-spec/story-design 相关小节；V1 SQL 注释；InternalConfigController javadoc | minor | 文档措辞/契约漂移合集（代码侧自洽、无功能影响）：①权限种子 V9 残留（实际 V10）；②内部端点包络文档写 features/parameters 数组、实现为 values 键值映射（story-design 已冻结 values、唯一消费端同提交适配）；③keys 校验标注 B0601、实现返回 A 段参数码（符合 framework-standard §13.4，建议以标准为准）；④public-features §2.1 写 {configKey,enabled}（实际 {key,enabled}）；⑤生效时延"≤66s"（冻结 60s）；⑥历史查询参数 configKey（实际 key）、列表 keyword 未实现；⑦内置保护"禁改分组"与设计/实现（仅禁删/禁改 key）不一致；⑧requirement.md 残留"可选 Pub/Sub"；⑨V1 注释提不存在的 BuiltInConfigSeeder；⑩游客车 test-design 措辞与 merge-token/merge 切点差异 | sdd-converge 统一回修需求/设计/规格/注释措辞（review 只读不代改）；keyword 搜索与内置键分组收紧按运营/安全评估决定是否开后续 Change |
| EV-011 | Story1 建议 EV-007（FeatureConfigAppService#validateKeyName、DU-BE-507 DEV-4）；SystemConfigProperties/application.yml | minor | 安全硬化两项：①configKey 未落 `[a-z0-9.-]+` 白名单（仅 @NotBlank+≤100），键拼入 Redis 键路径段，非预期字符可致键空间/日志混淆——创建面 ADMIN-only、内网受信，风险可控；②内部共享密钥代码默认 dev-internal-secret，虽经环境变量覆写且为 CHG-0015 起既有基线，生产环境必须显式注入（mall-system MALL_INTERNAL_SHARED_SECRET、消费端 mall.config.internal-token） | 后续 Change 领域层补键正则（DEV-4 已预留建议）；上线部署清单显式核验各服务密钥环境注入且不沿用默认值 |
| EV-012 | metadata.yaml repository-result | minor | repository-result 仍为空（{}）：5 个 DU 均 completed、实际结果提交已在 EV-001~EV-003 登记（82ccf6e/af19b9e/404eb77），但 metadata 结果位未由流程回填 | sdd-converge 阶段补回填或确认由 submodule-pointer-aligned 机检统一处理 |

无 blocker / 无 major。

## 3. 完成确认

- [x] §1.1 Change 17 条 AC 逐条给出对照结论与可定位证据，每条 AC 均被 EV-004/EV-005/EV-006 三个 test-run 的 covers 覆盖
- [x] §1.2 requirement-design 关键声明与 9 条关键技术决策、5 个 DU 共 19 条 Deviations 全部复核，无未登记偏离；fail-open/TTL/鉴权/Pub-Sub 边界源码核实
- [x] §1.3 requirement-design §4 跨仓契约三条链路（写→缓存→消费、公开端点→网关→mall-web、admin→API→identity V10）逐环节闭环
- [x] §1.4 代码质量发现均有 standards/ 依据（architecture-principles.md、framework-standard.md §13、api-design-standard.md、security-guidelines.md）
- [x] §1.5 知识同步候选已列出（6 项）
- [x] §2 发现清单 target 均可定位，全部 minor 且 resolution 非空（联调/测试 backlog/文档回修/部署检查/流程回填）
- [x] 无 blocker / 无 major
- [x] 报告无残留占位符
