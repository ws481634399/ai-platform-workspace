# Review Report（Story 级）— STORY-006-01-01-01 配置模型、后台管理与变更审计

## 0. 元信息

- Change ID：CHG-0022（M5 系统配置）
- Story ID：STORY-006-01-01-01 配置模型、后台管理与变更审计
- 审查时间：2026-09-19
- 审查者：sdd-review 独立评审 Agent（只读分析，未修改业务代码/测试/既有文档，未写 evidence.yaml）
- 审查输入：story-spec.md、story-design.md、test-design.md、implementation.md、evidence/test-report.md、evidence/evidence.yaml（EV-001~EV-004）；DU-BE-507、DU-FE-503 仓内 implementation.md；repo-1 提交 82ccf6e、repo-2 提交 404eb77 源码抽查
- 关联需求 AC：requirement-spec.md AC-001~AC-007

## 1. 检查结论

**通过（PASS）。** Story 8 条验收标准中 5 条 passed、3 条在核心功能断言全部通过的前提下存在覆盖深度缺口（AC-003/AC-007/AC-008），缺口均为 minor 且已有明确去向（测试增强/联调验收/文档回修）。**无 blocker、无 major。**

### 1.1 需求一致性

| Story AC | 结论 | 证据与说明 |
| --- | --- | --- |
| AC-001 V1 迁移与 4 种子键 | passed（环境替代） | ConfigAdminApiTest#pageSeededFeatures/#pageSeededParameters 断言两开关/两参数、builtIn=true、version=0、INTEGER 类型与 group；MallSystemApplicationSmokeTest#contextLoads 经 Flyway 真实执行 V1；V1 SQL 三表 DDL 与 4 种子（search.enabled、mall.guest-cart.enabled 公开；search.default-page-size=20[1,100]、cart.max-item-quantity=99[1,999]）与冻结值逐字一致。执行环境以 H2(MODE=MySQL) 替代 testcontainers MySQL，见建议 EV-009 |
| AC-002 分页/分组/启停/新建/删除 + 唯一约束 | passed | #pageSeededFeatures、#pageSeededParameters（group 过滤）、#createFeatureAndDuplicate（新建 200、重复键 409 B0602）、#updateFeatureCas（启停 200）、#deleteFeature（删非内置 200） |
| AC-003 四类非法值 400 且值不变 | partial（功能通过、深度不足） | 越界（INTEGER 999/[1,100]）、非法 JSON（"{not-json"）精确断言 400 B0601；类型非法以未知类型 DATETIME 写 "x" 等价覆盖，消费侧 ConfigFacadesTest#providerFallbacks 覆盖坏值回退；指名的 INTEGER 写 "abc"、BOOLEAN 写 "yes" 无逐字用例，"值不变"无读回断言。见建议 EV-008 |
| AC-004 乐观锁冲突 409 B0604 | passed | #updateFeatureCas：v0 更新成功 version 0→1，同体再提 409 B0604；源码核实 AppService 版本预检 + DB CAS 双保险 |
| AC-005 内置保护 + 删非内置留痕 | passed | #deleteFeature（内置 search.enabled 删除 400 B0601「内置配置不可删除」；tmp.feature 删 200 + DELETED 历史）、#updateAndDeleteParameter（内置值 20→50 成功、删除内置参数 400）；改 key 为路径参数 + 更新体无 key 字段的结构性禁止。story-spec §3 对"禁改分组"的更严措辞见建议 EV-006 |
| AC-006 变更历史完整且只追加 | passed（traceId 深度不足） | #updateFeatureCas（UPDATED、old=true/new=false、changeReason）、#createFeatureAndDuplicate（CREATED、changedBy="2001"）、#deleteFeature（DELETED）、#historyFilterAndAuth（configType+key 过滤、分页结构）；HistoryView 九字段（含 traceId、changedAt epoch millis）源码核实，历史 Controller 仅 GET；traceId 未逐例显式断言，见建议 EV-008 |
| AC-007 五权限码 403 反向 + 菜单/按钮 | partial（接口断言通过、种子与按钮深度不足） | #authenticationAndAuthorization（无 token 401、仅 list 权限写 403、跨资源读 403）、#historyFilterAndAuth（无 system:config-history:list 读历史 403）；identity V10__system_config_permissions.sql 五权限码 + /system 目录 + 三 PAGE 菜单（component_key=FeatureConfigs/SystemParameters/ConfigHistory）+ 超管幂等授权仅静态核实；mall-admin v-permission 按钮无组件测试。见建议 EV-008、建议 EV-010 |
| AC-008 三页面可用 + 四门门禁 | partial（门禁全绿、组件未测） | mall-admin 47/47（config.spec.ts 12 例全在 api 层）、type-check/lint 0 error、build SUCCESS；FeatureConfigsView/SystemParametersView/ConfigHistoryView 无组件渲染测试。见建议 EV-010 |

### 1.2 设计一致性

- DU-BE-507 六条 Deviation 逐条复核：
  - DEV-1（B0605 内置保护并入 B0601）：**合理**。冻结错误码仅 B0601~B0604/B0606，ConfigErrorCode/SystemErrorCode 与全局异常绑定（400/409/404/409）语义一致，无第五个业务码残留。
  - DEV-2（H2(MODE=MySQL) 替代 testcontainers MySQL）：可接受，测试环境差异留 minor，见建议 EV-009。
  - DEV-3（列表无 keyword 过滤，仅 group/enabled、group/type）：story-spec §3/§4 明确要求 group/keyword，属已登记偏离；前端亦未消费 keyword。影响可控但规格未回修，见建议 EV-012。
  - DEV-4（configKey 未落字符正则白名单）：与 story-spec §3「键只允许小写字母/数字/点/短横」不一致，已透明登记；安全影响独立评估为 minor，见建议 EV-007。
  - DEV-5（历史查询参数名为 `key` 而非 configKey）：全链路（前端 configHistoryApi 同步发 key）自洽，规格文本未回修，见建议 EV-012。
  - DEV-6（AppService 命名）：**合理**，三 AppService 位于 application 层，符合 DDD 分层与 architecture-principles.md 的 Controller/Service/Repository 职责约束。
- DU-FE-503 三条 Deviation 复核：
  - DEV-1（未建独立 store，页面直调 api 层）：**合理**，三页无跨页共享状态，避免冗余 store。
  - DEV-2（动态菜单仅注册 component-registry）：**合理**，与既有插件式路由注册约定一致；V10 菜单 component_key 与注册名对应。
  - DEV-3（仅 api 层 12 例无组件测试）：见建议 EV-010。
- 关键设计声明核对：六类型校验（ConfigType：BOOLEAN 仅 true/false、JSON 须 {/[ 开头且可解析、数值 BigDecimal 范围校验）真实存在；乐观锁"版本预检 + DB CAS"双保险真实存在；history 与业务变更同事务追加；OperatorContext 操作人取 SecurityContextFacade 主体、无主体回落 "system"，traceId 取 TraceContext；响应体统一 UnifyResult，符合 framework-standard.md §13.4。
- requirement-design §2.1 早期草图中的错误码排列（B0601 NOT_FOUND 等）与 B0605/B0606 设想，已被冻结决策与实现取代；同处提及的 BuiltInConfigSeeder 实际未落类（Change implementation.md 关键决策 6 已明确仅 Flyway DML 播种），V1 SQL 注释仍提"双保险"，见建议 EV-011。

### 1.3 跨仓一致性

权限与页面跨仓链路逐环节源码核实，闭环一致：

1. mall-identity V10 迁移：五权限码（system:feature:list/update、system:parameter:list/update、system:config-history:list）ON DUPLICATE KEY 幂等，三 PAGE 菜单 component_key 与 mall-admin component-registry 注册名一致，SUPER_ADMIN 角色权限/菜单幂等授权。
2. mall-system：SystemSecurityConfiguration（@Profile("!test")）`/api/admin/**` hasRole("ADMIN")，三 Controller 方法级 @PreAuthorize 权限码与 V10 种子逐一对齐；测试安全链 SystemApiTestSecurityConfig 与生产链等价。
3. mall-gateway：mall-system-admin 三组 /api/admin 路径转发 8108（requirement-spec 的网关路由要求落地）。
4. mall-admin（404eb77）：api/config.ts 三资源 API 与后端路径/分页形状/错误码（B0602 文案、B0604 刷新引导、403 兜底）一致；HistoryView 字段（configType/configKey/oldValue/newValue/changeKind/changedBy/changeReason/traceId/changedAt）与前端 ConfigHistoryItem 类型一致。
5. 端口 8108、库 mall_system 与 requirement-spec §0 一致。

### 1.4 代码质量

- 正向项（依据 standards/）：
  - 分层清晰：interfaces(rest/admin dto+controller) → application(AppService/事件/OperatorContext) → domain(ConfigType/ParameterValueValidator/模型) → infrastructure(mapper/po)，符合 architecture-principles.md 分层职责表。
  - 参数校验：DTO 上 jakarta Bean Validation（@NotBlank/@Size）+ 领域层 ConfigType 类型与范围校验双层，符合 api-design-standard.md §4.2/§6。
  - 异常与错误体：ConfigException 工厂绑定 HTTP 语义，GlobalExceptionHandler 统一 UnifyResult，符合 framework-standard.md §13.4；未预期异常不泄露内部信息。
  - 测试真实性：ConfigAdminApiTest 经 MockMvc + 真实 JWT 安全链断言 401/403/404/409/400 全矩阵，非浅层单测。
- 负面项：见建议 EV-007（键字符白名单）、建议 EV-013（前端未用 type 筛选）、建议 EV-011（SQL 注释陈旧）；均为 minor。

### 1.5 知识同步候选（仅候选，沉淀由 sdd-converge 执行）

1. 内置配置"Flyway 版本化 DML 唯一播种"模式（幂等、无运行时 Seeder）及与"双保险"设想的取舍。
2. 乐观锁"AppService 版本预检 + DB CAS"双保险写法。
3. admin 分页响应形状与 B0604 冲突"刷新重试引导"的前后端错误归一化约定。

## 2. 发现清单

> review 阶段不写 evidence.yaml；下列 EV 编号为**建议登记号**（本 Story evidence.yaml 当前至 EV-004），供 converge/后续流程登记。minor 允许开放，均给出处理去向。

| 建议 EV | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-005 | requirement-spec.md §0、§3.1；本 Story story-spec.md §2.1 | minor | 权限种子迁移版本残留 "V9" 字样；实际交付为 mall-identity V10__system_config_permissions.sql（requirement-design 已冻结 V10，代码/权限码/菜单全部一致） | sdd-converge 文档回修为 V10；无功能影响 |
| EV-006 | story-spec.md §3 [内置保护] vs story-design.md §1；FeatureConfigAppService/SystemParameterAppService | minor | 规格写内置键"禁改 key/type/分组"，设计与实现仅禁止删除与改 key（内置键 group/publicFlag/min/max/effectType 可由 ADMIN 修改）；冻结 AC（AC-005）与需求总纲只要求"删除仅限非内置、key 不可改"，实现满足 AC | 以设计/AC 为准回修 story-spec 措辞；若安全评估要求更严，后续 Change 在领域层冻结内置键分组（当前 ADMIN-only 且全量审计，风险可控） |
| EV-007 | DU-BE-507 DEV-4；FeatureConfigAppService#validateKeyName；story-spec.md §3 [唯一性] | minor | configKey 未落 `[a-z0-9.-]+` 字符白名单，仅 @NotBlank + @Size(max=100)；键会拼入 Redis 键路径段（aimall:{env}:system:feature:{key}），非预期字符可造成键空间/日志混淆。创建面仅 ADMIN、内网受信，无外部输入面，风险可控 | Deviation 已登记且自带补正则建议；列为后续安全硬化项（领域层 Pattern 校验），不阻断本 Change |
| EV-008 | story-spec.md#AC-003、#AC-006、#AC-007；evidence/test-report.md §4-2/§4-4/§4-5/§4-6 | minor | 覆盖深度缺口合集：①INTEGER 写 "abc"、BOOLEAN 写 "yes" 两指名非法值无逐字用例，非法值"值不变"无读回断言；②历史 traceId 字段存在但未逐例断言（OperatorContext#currentTraceId 已接 TraceContext）；③identity V10 菜单/权限种子无迁移自动化断言（仅 SQL 静态核实）；④删除不存在键无专门用例（更新不存在键 404 B0603 已断言） | 后续测试增强 backlog：参数化非法值 + 读回断言、traceId 断言、V10 迁移断言（mall-identity 测试套件）、DELETE 缺失键用例 |
| EV-009 | DU-BE-507 DEV-2；ConfigAdminApiTest | minor | 管理端持久层测试以 H2(MODE=MySQL) 替代 testcontainers MySQL，MySQL 方言级 DDL/DML 无容器验证；V1 经 Flyway 在 H2 真实执行、contextLoads 通过 | 联调/部署环境首次启动确认 MySQL 8 方言迁移与 4 种子播种 |
| EV-010 | DU-FE-503 DEV-3；story-spec.md#AC-007、#AC-008；mall-admin views/system/*.vue | minor | 三管理页无组件级 vitest：渲染、启停切换、类型表单校验矩阵、范围提示、内置键禁用、v-permission 按钮显隐、历史筛选交互均为源码静态核实；现有 12 例全在 api/config.ts 层 | Integration Gate 场景六浏览器验收三页交互；后续建立前端组件测试基线 |
| EV-011 | mall-system V1__system_config_seed.sql 注释；requirement-design.md §2.1 | minor | SQL 注释称"与 BuiltInConfigSeeder 双保险"、设计草图列 BuiltInConfigSeeder ApplicationRunner，实际无该类；内置键唯一播种途径为 Flyway V1 DML（Change implementation.md 关键决策 6 已说明） | 后续清理注释/设计草图措辞；功能无影响 |
| EV-012 | DU-BE-507 DEV-3/DEV-5；story-spec.md §3 [分页]、§4 | minor | ①历史查询参数实现为 `key`，规格文本写 configKey（前端同发 key，全链路自洽）；②规格要求列表支持 group/keyword 过滤，实现未提供 keyword（仅 group/enabled、group/type），前端未消费 | 回修规格：历史参数名改记 `key`；keyword 搜索按运营实际需要列入后续 Change 或从规格移除 |
| EV-013 | mall-admin src/api/config.ts#systemParameterApi.page | minor | 参数分页请求只发 group/enabled，未发后端已支持的 type 筛选参数（契约冗余未用），不影响功能 | 后续页面需要类型筛选时补传参数 |

无 blocker / 无 major。

## 3. 完成确认

- [x] §1.1 Story 8 条 AC 逐条给出对照结论与可定位测试证据（ConfigAdminApiTest 10 方法、config.spec.ts 12 例）
- [x] §1.2 story-design 关键声明与 DU-BE-507/DU-FE-503 共 9 条 Deviations 全部复核，均有记录、影响可控
- [x] §1.3 跨仓链路（identity V10 ↔ mall-system 权限码 ↔ 网关 admin 路由 ↔ mall-admin 页面/API 契约）逐环节源码核实闭环
- [x] §1.4 代码质量发现均有 standards/ 依据（architecture-principles.md、api-design-standard.md、framework-standard.md §13.4）
- [x] §1.5 知识同步候选已列出（3 项）
- [x] §2 发现清单 target 均可定位，minor 全部给出 resolution 去向
- [x] 无 blocker / 无 major；无未记录的实现偏离
- [x] 报告无残留占位符
