# Review Report（Story 级）— STORY-006-02-01-02 功能开关动态生效与前端公开配置

## 0. 元信息

- Change ID：CHG-0022（M5 系统配置）
- Story ID：STORY-006-02-01-02 功能开关动态生效与前端公开配置
- 审查时间：2026-09-19
- 审查者：sdd-review 独立评审 Agent（只读分析，未修改业务代码/测试/既有文档，未写 evidence.yaml）
- 审查输入：story-spec.md、story-design.md、test-design.md、implementation.md、evidence/test-report.md、evidence/evidence.yaml（EV-001~EV-004）；DU-BE-509、DU-FE-504 仓内 implementation.md；repo-1 提交 82ccf6e、repo-2 提交 af19b9e 源码抽查（mall-search、mall-cart、mall-gateway、mall-web）
- 关联需求 AC：requirement-spec.md AC-012~AC-016（并交叉支撑 AC-017）

## 1. 检查结论

**通过（PASS）。** Story 7 条验收标准中 4 条 passed、3 条核心功能断言通过但验证形态为切片/静态核实（AC-003/AC-005）或链路分段组合（AC-002 真实翻转端到端 IT 缺），均为 minor 且去向明确（Integration Gate 场景六联调/组件测试 backlog/文档回修）。**无 blocker、无 major。**

### 1.1 需求一致性

| Story AC | 结论 | 证据与说明 |
| --- | --- | --- |
| AC-001 匿名公开端点仅返公开开关 {key,enabled} | passed（网关 8080 链路见建议 EV-011） | ConfigCacheIntegrationTest#publicFeatures：匿名 200，search.enabled、mall.guest-cart.enabled 出现（含禁用公开项以 enabled=false 返回），非公开 internal.flag 不出现，不返回系统参数与分组元信息；findAllPublic 数据源含禁用公开项，最小化泄露要求满足 |
| AC-002 搜索开关两态 403 B0606 / 200，≤60s 生效 | passed（切片+缓存段组合，见建议 EV-008） | SearchFeatureGateTest#searchDisabledReturns403（FeatureDisabledException → 403 $.code=B0606，不触达 ES）、#searchEnabledPasses（200）；切点为 ProductSearchService.search() 首行 featureGate.ensureEnabled("search.enabled")；≤60s 链路由 ConfigCacheIntegrationTest#updateEvictsCache + SystemConfigClientTest#localCacheExpires 分段证明 |
| AC-003 mall-web 搜索入口随开关显隐并可恢复 | partial（store 断言通过、布局组件未测） | features.spec.ts 3 例：未加载 fallback（默认 true fail-open）、加载成功映射（search.enabled=false/guest-cart=true）、加载失败静默 fail-open；MallLayout.vue 搜索链接 v-if（data-testid=mall-search-link）与 SearchView.vue searchEnabled/search-closed 空态（不发请求）为源码静态核实。见建议 EV-009 |
| AC-004 游客车关闭拒绝游客写、会员不受影响 | passed（切点位置措辞差异见建议 EV-010） | GuestCartFeatureGateTest#guestCartDisabledRejectsMergeEndpoints（POST /api/mall/cart/merge-token 与 /merge 关闭态均 403 $.code=B0606）、#guestCartEnabledAndMemberUnaffected（开启态 merge-token 200；会员 POST /api/mall/cart/items 200 不经开关）；ProductDetailView.spec.ts 新增两例（游客关态按钮 disabled + guest-cart-blocked-hint + addItem 零调用；缺省 fail-open 可见入口）；CartController 类级 @PreAuthorize MEMBER 与游客切点组合正确 |
| AC-005 effectType 标识 + 生效时延 ≤60s | partial（机制/链路通过、页面 tag 未测） | api/config.spec.ts 透传 DYNAMIC/RESTART_REQUIRED 两例；SystemParametersView 生效方式 tag 静态核实；M5 四种子均 DYNAMIC，RESTART_REQUIRED 仅元数据标识、无重启钩子（story-spec §2.2 明示不做，DU-BE-509 DEV-3 已记录，合理）；时延链路同 AC-002 证据，上限为生产 localTtlSeconds=60 常量 |
| AC-006 mall-web 加载失败不白屏；服务端按代码默认决策 | passed | 前端：features.spec.ts 加载失败用例（getPublicFeatures reject 503 → load 不抛、loaded=true、hasFeature 默认 true）、main.ts mount 后 void load() 不阻塞渲染；后端：SystemConfigClientTest#allLayersDown + ConfigFacadesTest#gateDefaults（缺键/全故障默认 true 放行并 WARN） |
| AC-007 前后端测试全绿 | passed（前端"入口显隐"为 store 级，差异见建议 EV-009） | 后端 SearchFeatureGateTest 2 + GuestCartFeatureGateTest 2 全绿（全 reactor 482/482）；mall-web 102/102（features.spec 3、ProductDetailView.spec 6），type-check/lint 0 error、build SUCCESS |

### 1.2 设计一致性

- DU-BE-509 三条 Deviation 复核：
  - DEV-1（游客车切点仅 merge-token/merge）：**实现合理**。匿名直接加购在 M4 服务端无独立端点（游客车存浏览器本地，登录后经 merge-token/merge 并入会员车），此两端点即游客数据进入服务端的唯一写入口；关闭态前端按钮禁用 + hint + addToCart() 二次兜底构成体验层拦截，会员一切操作不受影响。test-design "游客加购/改量"措辞未精确描述切点，见建议 EV-010。
  - DEV-2（无真实翻转端到端 IT）：见建议 EV-008。
  - DEV-3（effectType 仅展示元数据、无重启钩子）：**合理**，与 story-spec §2.2 不包含项一致。
- DU-FE-504 两条 Deviation 复核：
  - DEV-1（前端拦截器无 B0606 专项处理）：**合理**。B0606→403 的转换在服务端由 mall-common-config 自动配置 advice 统一完成；前端按通用错误体展示与入口隐藏即可，无需特殊码分支。
  - DEV-2（MallLayout/SearchView 无组件测试）：见建议 EV-009。
- fail-open 安全性独立核实（本 Story 核心安全决策）：
  - 服务端权威：FeatureGate.ensureEnabled 仅对显式 false 拦截；缺键、Redis/HTTP 全故障默认 true 放行并 WARN——适用于"搜索/游客车为存量能力、避免配置面故障造成回归"的冻结决策，与产品文档"高风险写能力默认关闭"不冲突（两键在种子中显式 true；保守默认可通过 ensureEnabled(key,false) 传入，gateDefaults 已证明）。
  - 前端 fail-open 仅作用于 UI 显隐（stores/features.ts hasFeature fallback=true、load catch 静默），不是安全控制；真正拒绝发生在服务端切点，AC-002/AC-004 已断言，符合 story-spec §3 [后端权威]。
- 错误码/契约核实：B0606 FEATURE_DISABLED → HTTP 403，错误结构为统一 UnifyResult（$.success/$.code/$.message）；public-features 字段为 {key,enabled}（story-spec §2.1 残留 {configKey,enabled} 措辞，见建议 EV-005）；story-design §4 曾出现"≤66s（本地 60+传播）"措辞，冻结上限为 60s（AFTER_COMMIT 删键后跨服务新读立即取 Redis 新值，最迟 60s），见建议 EV-006。
- Pub/Sub：story-spec §2.2 明示不做；但 Change 早期输入 requirement.md 技术约束行仍残留"（可选）Redis Pub/Sub 轻量通知"措辞，见建议 EV-007。

### 1.3 跨仓一致性

两条跨仓链路逐环节源码核实，闭环一致：

1. 公开配置链：mall-system PublicFeaturesController（/api/mall/public-features，permitAll，读聚合键）→ mall-gateway 路由 Path=/api/mall/public-features/** 转 8108 且 GatewaySecurityConfiguration 白名单含该路径（/api/internal/** 仍 denyAll）→ mall-web api/features.ts（data 数组直接解包）→ stores/features.ts → MallLayout/SearchView/ProductDetailView 消费。
2. 开关保护链：mall-system 写开关 → AFTER_COMMIT 删 Redis 键（STORY-006-02-01-01 已核实）→ mall-search ProductSearchService.search() 与 mall-cart CartController merge-token/merge 首行 ensureEnabled → B0606 经 common-config advice 统一 403 → mall-web 入口隐藏 + 关闭空态/禁用引导。
3. 配置一致：mall-search/mall-cart yml 未显式覆写 mall.config.*，走自动配置默认（8108、dev token、60s 本地 TTL），与 mall-system 服务端默认成对；mall-web 经网关同源访问公开端点。

### 1.4 代码质量

- 正向项（依据 standards/）：
  - 切点位于业务方法/端点首行、在触达 ES 与合并逻辑之前抛出，测试断言"不进入 ES 查询"，防御位置正确，符合 security-guidelines.md"前端隐藏不是安全控制"的后端权威原则。
  - 前端守卫分层完整：入口 v-if、关闭空态不发请求、按钮 disabled + 文案引导、addToCart() 二次兜底，四层无单点绕过体验。
  - 公开端点最小化：匿名可读但仅返回公开布尔键，禁用项以 false 显式返回（供前端正确隐藏），无参数/分组/元信息泄露。
  - 测试真实：GuestCartFeatureGateTest 验证真实 MockMvc 安全链下的 403/200 与会员旁路，ProductDetailView.spec 断言回调零调用而非仅样式。
- 负面项：组件级测试与网关端到端自动化缺口（建议 EV-009/EV-011）；文档措辞三项（建议 EV-005/EV-006/EV-007）。

### 1.5 知识同步候选（仅候选，沉淀由 sdd-converge 执行）

1. fail-open FeatureGate 分层语义：UI 显隐 fail-open（缺省可见）与服务端"仅显式 false 拦截、故障默认放行+WARN"的决策边界，以及存量能力与高风险写能力默认值的逐键评估方法。
2. 公开开关端点最小化契约：只返 publicFlag=true 的布尔键（含禁用项 false），经网关白名单暴露，内部端点 denyAll 不变。
3. 存量能力接入开关的切点选取原则：游客车取服务端唯一数据入口（merge-token/merge），会员路径零影响。

## 2. 发现清单

> review 阶段不写 evidence.yaml；下列 EV 编号为**建议登记号**（本 Story evidence.yaml 当前至 EV-004），供 converge/后续流程登记。minor 允许开放，均给出处理去向。

| 建议 EV | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-005 | story-spec.md §2.1 | minor | public-features 返回字段写 `{configKey,enabled}`，与冻结契约及实现 `{key,enabled}` 不一致（同篇 §4 已正确写 key） | sdd-converge 回修 §2.1 字段名 |
| EV-006 | story-design.md §4 | minor | 生效时延写"实时生效 ≤66s（本地 60+传播）"，冻结决策与代码常量为 60s 上限（提交后删键使跨服务新读立即取 Redis 新值，本地缓存最迟 60s 收敛） | 回修为"≤60s 有界时延，删键后新读立即生效" |
| EV-007 | requirement.md 技术约束行 | minor | 早期需求输入残留"缓存失效 + TTL +（可选）Redis Pub/Sub 轻量通知"措辞；requirement-design 备选方案表已明确 M5 不引 Pub/Sub，story-spec §2.2 明示不做，全仓无 MessageListener/convertAndSend，动态生效真实机制为 AFTER_COMMIT 删键 + 本地 60s TTL | converge 阶段回修 requirement.md 措辞，避免 M7 前误读为已承诺项 |
| EV-008 | story-spec.md#AC-002；DU-BE-509 DEV-2；evidence/test-report.md §4-1 | minor | 无真实"管理端 PUT OFF → 缓存失效 → ≤60s 搜索 403 → 重开 200"单运行端到端 IT；现状为搜索两态切片（@MockitoBean FeatureGate）+ 缓存段 IT + 本地 TTL 单测的分段组合，各段均真但未串联 | Integration Gate 场景六多服务联调执行完整翻转并回填证据；后续可补 testcontainers 级翻转 IT |
| EV-009 | story-spec.md#AC-003、#AC-005、#AC-007；DU-FE-504 DEV-2、DU-FE-503 DEV-3；MallLayout.vue、SearchView.vue、SystemParametersView.vue | minor | MallLayout 搜索入口 v-if、SearchView 关闭空态、SystemParametersView 生效方式 tag 均无组件级 vitest（store 3 例、api 透传 2 例通过；DOM 行为源码静态核实） | Integration Gate 场景六/七浏览器验收显隐/空态/tag；后续补 MallLayout/SearchView 组件测试 |
| EV-010 | test-design 游客车用例措辞；DU-BE-509 DEV-1；CartController | minor | test-design 表述"游客加购/改量拒绝"，实现切点为 POST /merge-token、POST /merge（M4 游客车服务端唯一入口）；匿名无独立加购端点，关闭态由前端禁用+引导+二次兜底承接。实现合理但规格/设计读者易误解切点 | 回修 test-design/story 相关措辞明确切点为 merge-token/merge；联调时按真实链路走查游客加购→登录合并 |
| EV-011 | story-spec.md#AC-001；mall-gateway application.yml、GatewaySecurityConfiguration | minor | 网关层 public-features 匿名 200 与 /api/admin/** 未登录 401 未做经 8080 真实端口的自动化请求：路由+白名单为配置静态核实，401 仅有直连 mall-system 同链断言（feature-configs 路径） | 联调环境经网关 8080 端到端断言：公开端点匿名 200、admin 端点未登录 401、/api/internal/** 404 |

无 blocker / 无 major。

## 3. 完成确认

- [x] §1.1 Story 7 条 AC 逐条给出对照结论与可定位测试证据（SearchFeatureGateTest 2、GuestCartFeatureGateTest 2、features.spec 3、ProductDetailView.spec 6、ConfigCacheIntegrationTest 交叉证据）
- [x] §1.2 DU-BE-509/DU-FE-504 共 5 条 Deviations 全部复核且均有记录、结论合理；fail-open 前后端边界与 B0606/403 契约源码核实
- [x] §1.3 两条跨仓链路（公开端点→网关白名单→mall-web；开关写→缓存失效→search/cart 切点）逐环节闭环核实
- [x] §1.4 代码质量发现均有 standards/ 依据（security-guidelines.md 后端权威与内部端点隔离、最小化返回原则）
- [x] §1.5 知识同步候选已列出（3 项）
- [x] §2 发现清单 target 均可定位，minor 全部给出 resolution 去向
- [x] 无 blocker / 无 major；无未记录的实现偏离
- [x] 报告无残留占位符
