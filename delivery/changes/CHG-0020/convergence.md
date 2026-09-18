# Convergence — CHG-0020 M5 商品搜索

> 阶段：sdd-converge 产物

## 0. 元信息

- Change ID：CHG-0020
- 完成时间：2026-09-19
- standards-need-update：yes（新建搜索引擎工程标准 1 篇：ES 8.x 版本基线、PIT 深分页、基础设施依赖故障归一样式、SKU 价区相交 DSL、新服务 DTO 评审检查单）
- product-need-update：yes（Spec 晋升候选 1 篇 product/specs/商品搜索.md，待人工评审，本报告不直接落盘）
- featuretree-need-update：yes（5 个 Story planned → delivered）
- glossary-need-update：no
- 产出 Artifact 数：39（Change 级 9 件 + Story 级 5×6=30 件；metadata.yaml、evidence.yaml 证据索引与 references/ 参考件不计入）

## 1. 知识变化总结

本 Change 交付搜索查询侧全部 5 个 Story、6 个 DU（repo-4 DU-WS-501；repo-1 DU-BE-501/510/502/511；repo-2 DU-FE-501），首次把 Elasticsearch 技术栈引入平台，确立 4 类可跨 Change 复用的知识：

1. **ES 8.x 版本基线与深分页约束（BE/infra）**：客户端 elasticsearch-java 8.18.8（随 Spring Boot 3.5.15 BOM 解析、pom 不写死版本）与服务端/Testcontainers 固定 8.17.4 同属 8.x 主版本，互通可作平台基线；禁止使用已废弃的 RestHighLevelClient。ES 8.18 起禁止对 `_id` 做 fielddata 排序，全量/深分页必须采用 PIT（openPointInTime + keepAlive）+ `_shard_doc` asc + search_after，本 Change 的 from/size 浅分页（默认 20、上限 100）不受影响。——适用于 CHG-0021 索引重建/批量导出及 M6 AI 检索。

2. **B05xx 搜索域错误码与基础设施依赖故障归一样式（BE）**：B0501 SEARCH_UNAVAILABLE/503、B0502 SEARCH_BAD_REQUEST/400；对 ES 抛出的包装异常遍历 cause 链识别 ConnectException / SocketTimeoutException / 404 ResponseException（只认状态码，不依赖 reason 文本），已识别归一为 503 B0501，未匹配则 rethrow 不盲吞；日志仅 WARN 且带 traceId（X-Trace-Id 响应头透传），响应体不含主机名与原生堆栈，固定友好文案。——可复用为后续所有"基础设施依赖故障归一"模板（Redis/MinIO/Nacos 不可用等）。

3. **SKU 价区区间相交筛选 DSL（BE）**：商品文档以 minPrice/maxPrice 表达启用 SKU 的价区，价格筛选按区间相交命中——`doc.minPrice ≤ 请求上限 ∧ doc.maxPrice ≥ 请求下限`，只传一侧按单边开边界过滤，边界等值命中（闭区间），全程整数分 long。——可复用至后续商品列表增强、营销活动价过滤。

4. **@StringId 对新服务公开 DTO 同样强制的评审检查单教训（BE/FE）**：本 Change 评审发现 mall-search 新服务首个公开 DTO 以裸 Long number 直出 productId、前端声明 number（EV-006 major），违反既有 api-design-standard §5.3 业务 ID 字符串化规则，雪花 ID 超 2^53 会末位丢失并导致搜索点详情 404；由 d7dc2b0 加 @StringId、5ab0979 前端改 string 闭环。教训：新服务首次评审必须把"全部公开 DTO 业务 ID @StringId + 前端 ID 一律 string"列为必检项，不能默认"老服务已合规、新服务自然合规"。——适用于后续每一个新微服务的首评检查单。

## 2. 更新判断

### Standards

- 是否需更新：yes
- 更新内容：新建 `standards/engineering/backend/search-engine-standard.md`（由主流程 sdd-knowledge 统一写入；本报告只记录判断与内容概要，不直接落盘）。内容概要：
  1. ES 8.x 版本基线：官方 elasticsearch-java、版本随 Spring Boot BOM、禁用 RestHighLevelClient；客户端与服务端保持同 8.x 主版本；compose/Testcontainers 固定明确 tag。
  2. 接入样式：Client 构造期懒连接（无 ES 可启动/contextLoads）、connect/socket 超时显式配置（2s/5s）、MALL_ES_URIS 环境化、自定义 HealthIndicator 异常仅 WARN 置 DOWN 不外抛、查询一律走别名（别名缺失按不可用归一）。
  3. 分页：浅分页 from/size（page 从 1、默认 20、上限 100、trackTotalHits）；深分页/全量遍历用 PIT + `_shard_doc` asc + search_after；禁止对 `_id` fielddata 排序。
  4. 查询 DSL：status=ON_SALE 恒效 filter 与任何排序/筛选共存；multi_match 多字段（productName 加权）；SKU 价区区间相交 range；强类型 Builder DSL，禁止字符串拼接。
  5. 故障归一：B0501/503、B0502/400 + cause 链识别（ConnectException/SocketTimeout/404，只认状态码）+ 未匹配 rethrow + WARN 带 traceId + 响应不泄漏主机/堆栈 + 空结果 200 不打 ERROR。
  6. 评审检查单：新服务首个公开 DTO 必查 @StringId 字符串化与前端 string 口径；镜像首次引入补 RepoDigest。
- 理由：ES 为本平台首次引入的独立搜索引擎技术栈，CHG-0021 索引同步/重建与 M6 AI 检索直接在其上迭代；故障归一样式亦适用于 Redis/MinIO 等其余基础设施依赖。现有 standards/engineering/backend 下仅 api-design/architecture/database-access/framework/service 五篇，无搜索引擎主题，不与既有标准冲突（@StringId 规则本就存在于 api-design-standard §5.3，本次是以反例强化执行而非改规则）。

### Product

- 是否需更新：yes
- 更新内容：Spec 晋升候选 `product/specs/商品搜索.md`（草稿要点，来源 requirement-spec §4/§5/§6 与 5 份 story-spec AC 汇总；人工评审通过后才落盘，本报告不直接写入 specs/）：
  - 查询入口：`GET /api/mall/search/products` 八参数全部可选（keyword、categoryId、brandId、minPriceFen、maxPriceFen、sort、page、size），统一 UnifyResult 包裹。
  - 出参：SearchPage{items,total,page,size}；结果项七字段（productId/name/image/price 区间/brandName/categoryName 摘要），**productId 以字符串直出**，不含 SKU 列表与 Product 聚合全字段。
  - 可售恒效：任意关键词/筛选/排序/分页下 status=ON_SALE 为硬过滤，下架商品任何查询不出现。
  - 排序：DEFAULT / price_asc / price_desc / newest 四值全平台唯一；非法 sort 不报错、200 静默回退 DEFAULT。
  - 过滤：categoryId/brandId 精确匹配（M5 不做子孙树展开）；价格按 SKU 价区区间相交、整数分闭区间、单边可传、min>max 返回 400。
  - 分页：page 从 1 起、size 默认 20 上限 100（超限静默收敛）、越界页码回退第 1 页。
  - 异常与空态：ES 连接失败/超时/索引别名不存在 → 503 B0501 友好文案；参数错误 → 400 B0502；0 命中为正常 200 空页；M5 不提供数据库降级搜索，前端展示 Error 态并保留分类浏览出口。
  - 访问控制：`/api/mall/search/**` 网关 permitAll，游客可搜且不返回任何会员专属信息；`/api/internal/**` 网关 denyAll 统一 404、服务侧 SERVICE 鉴权双层安全（内部写投影端点随 CHG-0021 上线）。
  - 能力边界：Product DB 是唯一 Source of Truth，ES 仅为 Search Projection；mall-search 只读、不修改商品主数据、不直连商品库、不承担商品详情（点击结果跳 mall-product 既有详情页）。
- 理由：商品搜索是商城常设用户能力与 M6 AI 检索的投影基线，后续索引同步、销量/综合排序增强均需稳定的产品行为依据。

### feature-tree.yaml

- 是否需更新：yes
- 更新内容：STORY-005-01-01-01、STORY-005-01-01-02、STORY-005-01-02-01、STORY-005-01-02-02、STORY-005-01-02-03 共 5 个节点 planned → delivered（5 个 Story 实体均已 completed、6 个 DU 均 completed、各 Story review gate 已过）。
- 理由：查询侧能力（基础环境、异常口径、关键词搜索、筛选排序、mall-web 体验）已全部交付并由自动化证据覆盖。
- 方式：由主流程执行 `openspec feature update <STORY-ID> --status delivered`（本报告不手写 yaml）。

### Glossary

- 是否需更新：no
- 更新内容：无。
- 理由：PIT、search_after、B05xx、Search Projection、价区等均为技术实现概念，由工程标准与设计文档承载；"上架商品/搜索结果页"为电商通用概念，已由 Feature Tree 与接口契约表达，无需统一新术语。

### No Update

- 八参数与七字段的具体 JSON 命名、SearchProductItem record 结构、SortMode 枚举类名、ElasticsearchProductSearchAdapter 包结构：实现细节。
- application.yml 配置键名（mall.elasticsearch.uris/index-alias、超时值）、compose 服务名/卷名/ES_PORT 变量、Testcontainers 镜像 8.17.4 tag：环境实现细节。
- 前端 buildRouterQuery 规则、requestSeq 竞态序号、SearchView 829 行拆分计划（EV-015）：组件实现与后续重构细节。
- 金额整数分 Long、雪花 ID、统一分页形状、UnifyResult：既有 Change 已确立的规则，本次仅验证复用。

## 3. 知识沉淀过程

- 通读产物清单：Change 级 requirement.md、requirement-spec.md（§5 全局验收 18 条）、requirement-design.md、review-report.md（§1.5 知识同步候选）、evidence/evidence.yaml（EV-001~EV-019）、evidence/test-report.md、metadata.yaml；5 个 Story 目录各读 story-spec.md、evidence/test-report.md、evidence/evidence.yaml，并抽查 5 份 story-metadata.yaml 确认 status=completed；另对照 convergence 模板与 CHG-0019 convergence 先例的结构与详略度。
- 分类过程：从 review-report §1.5 与各 Story 证据中提取技术候选 4 组（ES 版本/深分页、故障归一样式、价区相交 DSL、@StringId 检查单教训）→ 均可跨 Change 复用且既有 standards 无同主题文件 → 汇聚为 1 篇 standards 新建候选；提取业务规则候选 1 组（查询契约、恒效过滤、排序回退、错误码、游客口径、能力边界）→ 形成 1 篇 Spec 晋升候选草稿，仅记录于本报告 §2，待人工评审后落 product/specs/，本阶段不直接落盘；5 个 Story 交付对应 Feature Tree 5 节点状态变更；无需要统一的新术语。
- 冲突核对：4 类技术知识与既有 api-design-standard §5.3、architecture-standard 的 Product 权威边界一致，无矛盾；@StringId 事件是对既有规则的执行强化，不产生规则冲突；无 Conflict、无 Unresolved。
- 重大发现闭环复核：两项 major 均已在 review 阶段修复回归——EV-006（业务 ID 未字符串化）由后端 d7dc2b0 加 @StringId（EV-016）、前端 5ab0979 联动 string（EV-017）闭环，EV-018 后端定向回归 26/26、EV-019 mall-web 22 files/105 例全绿；EV-007（/search 缺分类/品牌筛选控件与入口）由 5ab0979 补分类树/品牌下拉与 SearchView.spec 3 例闭环（EV-017/EV-019）。9 项 minor（EV-008~EV-015）均为已登记的覆盖深度缺口或联调待补项，处置去向明确。
- 延后项登记：浏览器全链路（mall-web→8080→mall-search→ES）与容器级实停 ES 的证据按 test-design 既定分层留待 M5 Integration Gate 场景一/场景五联测，自动化段已先行 passed，本报告 §4 逐条注明。

## 4. 全局验收标准对照

| # | 验收点（摘自 requirement-spec §5，精炼） | 覆盖 Story | 证据引用 | 结论 |
| --- | --- | --- | --- | --- |
| 1 | AC-001 compose 起 ES 健康检查通过；mall-search 连通成功、健康端点 UP | STORY-005-01-01-01 | docker-compose.infra.yml elasticsearch 8.17.4（healthcheck wait_for_status=yellow、ai-platform-es-data 命名卷、内网，EV-001/7f05e11）；SearchHealthIndicator ping 异常置 DOWN 不外抛（Story 01-01 test-report §1 配置物核对项）；MallSearchApplicationSmokeTest#contextLoads 证明 Client 懒连接离线可启动；EV-004 全 reactor 482/482 | 通过（静态/配置+冒烟自动化；容器级实起实停段延后 M5 Integration Gate 场景五，EV-011） |
| 2 | AC-002 官方 elasticsearch-java 依赖、版本由 BOM 管理、无 RestHighLevelClient | STORY-005-01-01-01 | mall-search pom 中 co.elastic.clients 坐标无 version，Spring Boot 3.5.15 BOM 解析为 8.18.8；全工程检索无 RestHighLevelClient（Story 01-01 test-report §1 依赖静态检查项） | 通过（静态依赖核对） |
| 3 | AC-003 Testcontainers ES 集成测试可运行：建临时索引/写样例文档/检索通过 | STORY-005-01-01-01 | ElasticsearchSmokeTest#indexTwoDocumentsAndSearchHits（Testcontainers ES 8.17.4 static 单例 + @DynamicPropertySource，临时索引写「机械键盘/无线鼠标」match 命中、finally 清理）；mall-search 模块 32/32、EV-004 全 reactor 482/482 | 通过 |
| 4 | AC-004 ES 不可用/超时/索引不存在 → B05xx 统一错误与文案，UnifyResult 结构，无 ES 堆栈泄漏 | STORY-005-01-01-02 | SearchExceptionAdviceTest#connectRefused_returns503、#socketTimeout_returns503、#indexMissing_returns503（断言 503、$.success=false、$.code=B0501、body 不含主机 10.0.0.9 与 `at ` 堆栈、X-Trace-Id 存在）；ProductSearchApiTest#missingIndex_throws 真实 ES 查缺失别名必抛异常双层佐证（Story 01-02 test-report §1） | 通过（cause 链切片 + 真实 ES 双层；容器级实停 ES 段延后场景五，EV-010） |
| 5 | AC-005 无命中返回 200 + 空 items 分页（不是错误） | STORY-005-01-01-02 | ProductSearchApiTest#emptyResult_noErrorLog（关键词 qqqxzz：success=true、total=0、items=[]；Logback ListAppender 断言 com.ai.mall.search 无 ERROR 日志） | 通过 |
| 6 | AC-006 关键词命中 productName/keywords/brandName/categoryName 任一字段即可检索到 | STORY-005-01-02-01 | ProductSearchApiTest#keyword_relevance_andOnSaleOnly（真实 ES Testcontainers bulk 106 文档；multi_match productName^3/keywords/brandName/categoryName 取 OR；「keyboard」名称命中 id1 置顶、keywords 命中 id2，「机械」命中 id3）；EV-018 定向回归 26/26 | 通过 |
| 7 | AC-007 结果仅含 ON_SALE 商品，下架商品任何查询下均不出现 | STORY-005-01-02-01 | ProductSearchApiTest#keyword_relevance_andOnSaleOnly（OFF_SALE id4 在「机械」查询与无参浏览 total=105 中均缺席）与 #pagination 共证；DSL 恒效 filter term status=ON_SALE | 通过 |
| 8 | AC-008 结果项仅含七字段搜索摘要，不含 SKU 列表/聚合全字段 | STORY-005-01-02-01 | ProductSearchApiTest#responseWhitelist（七字段正断言存在、keywords/status/publishedAt/updatedAt 反断言不存在）；productId 经 d7dc2b0 加 @StringId 以字符串直出（EV-006 major 闭环、EV-016、EV-018 26/26） | 通过 |
| 9 | AC-009 page/size 正确切片、total 准确；size>100 限制为 100；统一分页结构 | STORY-005-01-02-01 | ProductSearchApiTest#pagination（默认 page=1/size=20、total=105、items=20；size=999 收敛为 100；尾页 items=5；page=0 回退第 1 页；trackTotalHits） | 通过 |
| 10 | AC-010 网关游客经 8080 访问 200、无 token 不 401；/api/internal/** 经网关 404 | STORY-005-01-02-01 | mall-gateway 路由 mall-search-mall（/api/mall/search/**→8107）+ permitAll 白名单；/api/internal/** denyAll 经 entryPoint 与 accessDenied 双路径统一 404；mall-search 侧 /api/mall/** permitAll、/api/internal/** SERVICE 且无 internal 搜索路由、Controller 仅一个 GET（82ccf6e 配置/源码核对，EV-009） | 通过（配置物/源码已落地；网关运行时 curl/E2E 段延后 M5 Integration Gate 场景一，EV-009） |
| 11 | AC-011 categoryId 仅返该分类、brandId 仅返该品牌；minPrice/maxPrice 按整数分闭区间过滤 | STORY-005-01-02-02 | ProductSearchApiTest#categoryAndBrandFilter（categoryId=10→total=4，叠加 brandId=100→total=2 取交集）；#priceRangeIntersection（10000–30000 命中 id1/id3，30000 上边界等值命中且不含 id2；仅传 maxPriceFen=5000 单边命中 id2/id6） | 通过 |
| 12 | AC-012 关键词+品牌+价格区间组合查询结果同时满足全部条件 | STORY-005-01-02-02 | #categoryAndBrandFilter 双 term 取交集、#priceRangeIntersection 证明 range 与其他 filter 同处一个 BoolQuery、#keyword_relevance_andOnSaleOnly 证明 multi_match must 与 term/range filter 同一适配器构建路径叠加（EV-018 26/26） | 通过（真实 ES 分机制断言；三合一单跳 curl 段延后场景一，EV-012） |
| 13 | AC-013 price_asc/price_desc 严格升降；newest 发布时间倒序；default 稳定；非法 sort 回退 default | STORY-005-01-02-02 | ProductSearchApiTest#sorts（升序价格序列 2,6,1,3；降序首 id3 尾 id2；newest id1 最先、publishedAt=null 的 id6 排尾）；#invalidParams（sort=hacker → 200 静默回退 DEFAULT，大写/未知值同口径） | 通过 |
| 14 | AC-014 顶部搜索框输入关键词回车 → 进入 /search 并回显关键词、展示结果卡片（图/名/价/品牌） | STORY-005-01-02-03 | src/api/search.spec.ts 5 例（端点命中、UnifyResult 解包、参数序列化）；SearchView.spec.ts 3 例（5ab0979 新增：筛选渲染/URL 同步/雪花 ID 详情跳转，EV-017、EV-019 22 files/105 例全绿）；/search 路由、页内搜索框与 nav 入口实现核对 | 通过（API/组件自动化 + 实现核对；浏览器全链路段延后场景一 EV-008；Header 全局框现跳 /products?keyword=，入口口径注 EV-013 待联调产品确认） |
| 15 | AC-015 结果页分类/品牌/价格筛选与四排序、分页可用，URL query 与页面状态一致、刷新保持 | STORY-005-01-02-03 | SearchView.spec.ts 3 例（5ab0979 新增分类树/品牌下拉控件，经 buildRouterQuery 写 URL 并重置 page=1，EV-007 major 闭环）；api/search.spec.ts「serializeSearchQuery 完整参数/空参数省略/三种排序值透传」3 例；watch fullPath immediate 覆盖刷新/前进后退（实现核对）；EV-019 105 例 + type-check/lint/build 全绿 | 通过（视图/API 自动化；浏览器操作段延后场景一，EV-008） |
| 16 | AC-016 空结果/加载中/搜索失败三态有明确 UI；失败态提供返回首页/分类浏览出口 | STORY-005-01-02-03 | StateView 三态、stores/search.ts resolveErrorMessage 与重试、空态热门词/分类浏览出口（ec0921b 实现物核对）；SearchView.spec.ts 视图行为 3 例；B0501 经拦截器进 error 态由 api/search.spec.ts 解包链路共证 | 通过（实现物 + 视图自动化；store 三态/requestSeq 竞态纯单测与浏览器行为段延后场景一，EV-008） |
| 17 | AC-017 点击结果卡片进入既有商品详情页（mall-product 提供）并正常展示 | STORY-005-01-02-03 | SearchView.spec.ts 含雪花大整数 ID 详情跳转断言（onCardClick→/products/:id，productId 为 string，EV-017）；products/:id → ProductDetailView 路由真实存在；ID 精度风险随 EV-006 经 d7dc2b0 @StringId 闭环消除（EV-016） | 通过（组件级 string ID 跳转断言；浏览器跳转段延后场景一，EV-008） |
| 18 | AC-018 mall-web type-check/lint/test/build 全部通过 | STORY-005-01-02-03 | 门禁四件（EV-019）：vitest 22 files/105 tests 全绿、vue-tsc 0 error、eslint 0 error（65 warnings 为既有风格告警）、vite build SUCCESS；后端定向回归 EV-018 26/26 | 通过 |

汇总：18 条全部判「通过」。其中 AC-001/004/010/012/014/015/016/017 的容器级、网关运行时或浏览器端证据按既定测试分层延后至 M5 Integration Gate 场景一/场景五联测补齐（自动化与实现物均已落地，缺口性质与 review-report §1.1 一致），不构成本收敛报告的未决阻断。

## 5. 完成确认

- [x] 代码变更已完成（6 个 DU 全部 completed：DU-WS-501、DU-BE-501、DU-BE-510、DU-BE-502、DU-BE-511、DU-FE-501；3 仓 5 个交付提交 EV-001/EV-002/EV-003 + 评审闭环 EV-016/EV-017）
- [x] 测试已完成（本 Change 功能自动化 20/20；后端全 reactor 482/482，其中 mall-search 32/32；mall-web 评审回归 22 files/105 例；EV-004/EV-005/EV-018/EV-019）
- [x] 证据已收集（Change evidence.yaml EV-001~EV-019：5 code-change、4 test-run、10 review-finding；5 个 Story evidence 索引与 test-report 齐全）
- [x] 全局验收标准已逐条对照（§4，18 条逐条一行，含跨 Story 集成点的自动化证据与延后说明）
- [x] 知识更新已评估（standards 新建候选 1 篇、Spec 晋升候选 1 篇待人工评审、Feature Tree 5 节点待主流程置 delivered、Glossary 无更新；本报告不直接写 standards/ 与 product/）
- [x] M5 Integration Gate 场景一/五浏览器与容器段已登记延后联测（场景一：网关 8080 匿名 200/internal 404、mall-web→8080→mall-search→ES 浏览器全链路、三合一组合单跳；场景五：实停 ES 容器复核 503 B0501/进程存活/X-Trace-Id/前端 Error 态、compose down-up 数据保留；EV-008~EV-013）
- [x] 全部 5 个 Story 已 completed、Story review gate 与 Change review Human Gate 均已 approved
- [x] 无未解决 Conflict / Unresolved 问题；无 blocker；两项 major（EV-006 @StringId、EV-007 筛选控件）已在 review 阶段修复并回归闭环，9 项 minor 处置去向明确
