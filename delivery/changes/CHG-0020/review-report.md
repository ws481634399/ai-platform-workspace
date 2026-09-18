# Review Report — CHG-0020 M5 商品搜索（Change 级评审）

## 0. 元信息

- Change ID：CHG-0020（M5 商品搜索）
- 评审范围：5 个 Story / 6 个 DU / 4 个仓库（repo-4 基础环境、repo-1 mall-search+mall-gateway、repo-2 mall-web；repo-3 无改动）
- Story 清单：STORY-005-01-01-01 基础环境、STORY-005-01-01-02 异常响应与降级、STORY-005-01-02-01 商品关键词搜索、STORY-005-01-02-02 搜索筛选与排序、STORY-005-01-02-03 mall-web 商品搜索体验
- DU 清单：DU-WS-501、DU-BE-501、DU-BE-510、DU-BE-502、DU-BE-511、DU-FE-501
- Test Report 来源：各 Story `evidence/test-report.md`（Change 汇总：`evidence/test-report.md`）
- Evidence 索引：`evidence/evidence.yaml`（EV-001~EV-019：5 code-change + 4 test-run + 10 review-finding，covers 覆盖 AC-001~018）
- Story 评审报告：5 份 `evidence/review-report.md`（本报告为聚合结论，Story 级证据细节以各 Story 报告为准）
- 检查时间：2026-09-19
- 状态：testing 检查点（Machine Gate 评审；报告不推进 Change 生命周期，converge 决策由评审结论与联测证据共同支撑）

## 1. 检查结论

**通过（PASS）。** 18 条 AC 中 14 条判定 passed、4 条 partial（AC-010/014/016/017 仅差 Gate 运行时联测证据）；无 blocker；**2 项 major 已在 review 阶段修复并回归闭环**——EV-006（业务 ID 未字符串化）由后端 d7dc2b0 加 `@StringId`、前端 5ab0979 改 string 联动修复（EV-016/EV-017），EV-007（/search 结果页缺分类/品牌筛选控件与入口）由 5ab0979 新增分类树/品牌下拉与 SearchView.spec 3 例修复（EV-017）；回归证据：EV-018 后端定向回归 26/26（ProductSearchApiTest 9、InternalSearchFailureApiTest 2、IndexSyncIntegrationTest 9、SyncFailureFlowTest 6）、EV-019 mall-web 全量 vitest 22 files/105 例全绿（type-check/lint/build 同绿）。9 项 minor 全部为已登记的覆盖深度缺口或联调待补项，允许开放。跨仓查询契约（八参数、sort 四值、七字段命名、SearchPage 形状、B05xx 错误段、网关匿名路由）经源码逐点抽查闭环；原唯一跨仓类型断裂 ID 线格式（EV-006）与"能力→UI"缺口（EV-007）均已修复对齐。

### 1.1 需求一致性（AC-001~018 总对照）

| AC | 需求要点 | 结论与主要证据 |
| --- | --- | --- |
| AC-001 | compose 起 ES 健康、命名卷持久化、重启数据不丢 | passed（静态/配置：docker-compose.infra.yml 8.17.4 single-node、wait_for_status=yellow、es-data→ai-platform-es-data；容器实跑复核见 EV-011） |
| AC-002 | 官方 elasticsearch-java、无 RHLC、版本随 BOM | passed（mall-search pom 坐标无 version，Boot 3.5.15 BOM 解析 8.18.8；全工程无 RestHighLevelClient） |
| AC-003 | Testcontainers 真实 ES 集成测试基线 | passed（ElasticsearchSmokeTest static 8.17.4 单例、@DynamicPropertySource 注入；mall-search 32/32、全 reactor 482/482） |
| AC-004 | ES 连接拒绝/超时/缺索引 → 503 B0501，无主机/堆栈泄漏 | passed（SearchExceptionAdviceTest 连接/超时/404 三例断言响应体无主机与 `at ` 堆栈；ProductSearchApiTest 缺索引真实抛错佐证） |
| AC-005 | 0 命中 → 200 空页、不打 ERROR | passed（真实 ES 空结果用例 + ListAppender 断言 com.ai.mall.search 无 ERROR） |
| AC-006 | keyword 命中名称/关键词/品牌/类目，名称加权 | passed（multi_match productName^3/keywords/brandName/categoryName，OR；相关性用例名称命中置顶） |
| AC-007 | 下架商品任何查询不返回 | passed（恒效 filter term status=ON_SALE；OFF_SALE 文档在相关性/分页用例均缺席） |
| AC-008 | 响应仅摘要白名单字段（含 ID 字符串线格式） | passed（ProductSearchItem 七字段白名单正反断言通过；productId 已由 d7dc2b0 加 @StringId 以字符串直出，EV-006 major 已闭环，EV-018 回归 26/26） |
| AC-009 | 分页切片、默认 20、越界收敛上限 100 | passed（默认 20/total=105、size=999→100、尾页 5、page=0→1，trackTotalHits） |
| AC-010 | 网关游客访问搜索 200、/api/internal/** 404 | partial（网关路由 mall-search-mall 与 permitAll/denyAll 配置落地、无 internal 搜索路由；运行时证据待 Gate，见 EV-009 minor） |
| AC-011 | 分类/品牌 term、价格区间相交过滤 | passed（categoryId 4 条、叠加 brandId 2 条交集；10000–30000 边界/单边/相交/非命中四分支断言） |
| AC-012 | keyword+筛选组合查询取交集 | passed（multi_match must 与 term/range filter 同一 BoolQuery，分机制均有真实 ES 断言；三合一单跳请求为同机制覆盖，见 EV-012 minor） |
| AC-013 | 四种排序严格序、非法 sort 回退默认 | passed（升序 2,6,1,3、降序首 3 尾 2、newest id1 前 null 排尾、sort=hacker/大写 →200 回退 DEFAULT） |
| AC-014 | 顶部搜索框 → /search 回显关键词与卡片 | partial（/search 页内框与 nav 入口实现且路由真实、回显与卡片字段实现核对通过；**Header 全局框实际跳 /products?keyword=**，DU-FE-501 DEV-1 已记录待产品确认；浏览器全链路待 Gate，见 EV-013/EV-008 minor） |
| AC-015 | 结果页分类/品牌/价格筛选 + 四排序 + 分页，URL 与状态一致 | passed（价格/排序/分页与 URL 双向同步；分类树/品牌下拉控件已由 5ab0979 补齐并写 URL 回第 1 页，SearchView.spec 3 例覆盖筛选渲染/URL 同步，EV-007 major 已闭环，EV-019 全绿；浏览器全链路操作待 Gate，见 EV-008 minor；对应 Story AC-002 同步闭环） |
| AC-016 | 空/加载/失败三态与出口 | partial（StateView 三态、resolveErrorMessage、retry、空态热门词出口均实现；SearchView.spec 已补视图行为 3 例，store 三态/竞态与浏览器行为证据待 Gate，见 EV-008 minor） |
| AC-017 | 点卡片进既有详情页 | partial（onCardClick→/products/:id，路由真实存在；SearchView.spec 含雪花大整数 ID 详情跳转断言（EV-007/EV-019），ID 精度风险随 EV-006 闭环消除；浏览器跳转仍待 Gate，见 EV-008 minor） |
| AC-018 | 前端 type-check/lint/test/build 通过 | passed（review 回归：type-check 0 error、lint 0 error/65 warnings、vitest 22 files/105 tests（含 search.spec.ts、新增 SearchView.spec.ts 3 例）、build SUCCESS，EV-019；后端定向回归 26/26，EV-018） |

汇总：passed 14 条（AC-001~009、011~013、015、018）；partial 4 条（AC-010、014、016、017）。判定口径：AC-010/014/016/017 的配置与实现物已落地，仅差 Gate 运行时联测证据（属既定 Gate 工作项）；原受 major 影响的 AC-008/AC-015 已随 EV-006/EV-007 修复回归转 passed（EV-016~EV-019）。

Story 判定汇总：

| Story | 判定 | major | minor |
| --- | --- | --- | --- |
| STORY-005-01-01-01（DU-WS-501+DU-BE-501） | PASS | 0 | 2（容器级启停复核、RepoDigest） |
| STORY-005-01-01-02（DU-BE-510） | PASS | 0 | 1（容器级故障注入） |
| STORY-005-01-02-01（DU-BE-502） | PASS | 0（EV-003 已修复闭环） | 2（网关联测、纯单测） |
| STORY-005-01-02-02（DU-BE-511） | PASS | 0 | 2（组合单跳/非数字绑定、纯单测） |
| STORY-005-01-02-03（DU-FE-501） | PASS | 0（EV-003/EV-004 已修复闭环） | 4（store 竞态待联测、浏览器链路、Header 入口、文件行数） |

### 1.2 设计一致性

- 冻结契约（requirement-design §4）与实现核对：端点 GET /api/mall/search/products（唯一 GET、无写端点）、八参数全部可选、SearchPage{items,total,page,size}、ProductSearchItem 七字段、sort=DEFAULT/price_asc/price_desc/newest、B0501/B0502——逐条一致；ID 序列化形态原偏差（EV-006）已由 d7dc2b0 @StringId + 5ab0979 string 修复对齐（EV-016/EV-017）。
- 设计偏差登记完整性：六个 DU 的 Deviations 逐条核对，DU-WS-501（1 条）、DU-BE-501（2 条）、DU-BE-510（2 条）、DU-BE-502（4 条）、DU-BE-511（2 条）、DU-FE-501（3 条）均"原设计/实际/原因/影响"要素齐全，外部契约保持不变（含白名单九字段→七字段收紧与 spec §4 一致、分页静默归一口径统一、8.18/8.17.4 版本组合、healthcheck 宽限参数、FeatureGate fail-open）。
- **评审发现未记录偏差一处，已闭环**：DU-FE-501 交付物曾缺分类/品牌筛选控件且未登记——为 EV-007 定 major 的依据；5ab0979 已补齐分类树/品牌下拉控件并新增 SearchView.spec 3 例（EV-017/EV-019），该偏差以功能补齐方式关闭。
- fail 安全设计落地：SearchHealthIndicator 异常仅 WARN 置 DOWN 不外抛、ES Client 构造期懒连接（无 ES 可 contextLoads）、异常 Advice 未匹配 rethrow 不盲吞、FeatureGate ensureEnabled fail-open（CHG-0022）、关闭态前端有额外出口。

### 1.3 跨仓一致性

repo-4 → repo-1 → repo-2 查询链路逐段抽查：

- repo-4：elasticsearch 8.17.4 固定 tag、外部网络 ai-platform-network/卷 ai-platform-es-data、ES_PORT 暴露；repo-1 mall-search 以 MALL_ES_URIS 消费（connect 2s/socket 5s、index-alias mall_products、关闭默认 ES 健康项），Testcontainers 同为 8.17.4。
- repo-1 内：mall-gateway 路由 `/api/mall/search/**`→8107（MALL_GATEWAY_SEARCH_URI 可覆盖）+ permitAll 白名单；mall-search 自身 /api/mall/** permitAll、/api/internal/** SERVICE、无 internal 搜索路由；网关 /api/internal/** denyAll 统一 404（entryPoint 与 accessDenied 双路径）。
- repo-1 → repo-2：前端 api/search.ts 路径/八参数/sort 四小写值/UnifyResult 解包/SearchPage 形状/七字段命名全部对齐；错误码经拦截器进 error 态。
- **断裂一处，已修复闭环**：业务 ID 线格式曾为 mall-search 裸 Long number vs. api-design-standard §5.3 字符串出参、mall-product 全公开 DTO @StringId、catalog.ts 全 id:string——EV-006；d7dc2b0 后端加 @StringId、5ab0979 前端改 string 后跨仓口径一致（EV-016/EV-017），雪花 ID 超 2^53 末位丢失/详情跳错风险消除，回归见 EV-018/EV-019。
- **能力闭环缺口一处，已修复闭环**：后端 categoryId/brandId 过滤已实现并有真实 ES 断言，repo-2 原无操作控件与携带入口——EV-007；5ab0979 已在 SearchView 落地分类树/品牌下拉并写 URL 回第 1 页（EV-017/EV-019），"能力→UI"最后一段接通。
- repo-3 本 Change 无改动，无跨仓影响。

### 1.4 代码质量

- 后端：domain（SortMode/SearchQuery/端口/白名单 record）/application（ProductSearchService 归一与校验）/infrastructure（ElasticsearchProductSearchAdapter 强类型 Builder DSL、无字符串拼接）/interfaces（Controller + SearchExceptionAdvice + 安全配置）分层清晰；价格全程整数分；DSL 恒效在售过滤、trackTotalHits、hits.total 空安全；日志 traceId 可串联。原 §5.3 违规（EV-006 major）已由 d7dc2b0 @StringId 闭环（EV-016）；归一逻辑纯单测缺位仍登记为 EV-012 minor。
- 前端：setup store 单一状态源 + requestSeq 竞态防护规范；URL 为查询条件唯一真相（watch fullPath immediate 覆盖前进后退/刷新）；元分 Math.round 换算与反向区间即时拦截；复用 StateView/PriceText。原 ID 类型违规（EV-006 前端段）与筛选控件缺失（EV-007）均已由 5ab0979 闭环（EV-017）；store 竞态纯单测仍缺（EV-008，视图部分已由 SearchView.spec 3 例闭环）、SearchView 829 行超组件规范评估线（EV-015）。
- 测试质量：后端 review 定向回归 26/26（ProductSearchApiTest 9、InternalSearchFailureApiTest 2、IndexSyncIntegrationTest 9、SyncFailureFlowTest 6，EV-018）全部真实依赖而非 mock 猜测；异常切片三例 + 空结果日志断言到位。前端 review 全量 22 files/105 例（含新增 SearchView.spec 3 例）、门禁四件全绿（EV-019）；store 竞态高交互风险仍无 store spec，已登记 EV-008。
- 基础设施：镜像固定明确 tag、健康检查打真实协议、命名卷、堆/内存限制齐全；缺 RepoDigest 记录（EV-014 minor）。

### 1.5 知识同步候选

1. ES 版本组合与深分页约束：客户端 8.18.8（Boot 3.5.15 BOM）与服务端 8.17.4 同 8.x 主版本互通可作基线；8.18 禁止对 `_id` 做 fielddata 排序，全量/深分页采用 PIT（openPointInTime+keepAlive）+ `_shard_doc` asc + search_after（本 Change 浅分页 from/size 不受影响；事实存于 DU-BE-501 DEV-1 与 CHG-0021 代码）。
2. B05xx 搜索域错误码与故障归一样式：B0501 SEARCH_UNAVAILABLE/503、B0502 SEARCH_BAD_REQUEST/400；cause 链遍历识别 ConnectException/SocketTimeoutException/404 ResponseException（只认状态码不依赖 reason 文本），未匹配 rethrow；WARN 带 traceId、响应体不含主机/堆栈——可复用为后续基础设施依赖故障归一模板。
3. SKU 价区筛选 DSL：商品文档 minPrice/maxPrice 表达启用 SKU 价区，筛选按区间相交（minPrice≤请求上限 ∧ maxPrice≥请求下限，单边开边界），可复用至后续商品列表增强。
4. 规范反例（建议 converge 时在标准宣贯中强调）：@StringId 字符串化规则对新服务公开 DTO 同样强制；新服务首次评审即应纳入检查单，避免"老服务全合规、新服务裸 Long"。

### Integration Gate 结论（场景一 / 场景五查询段）

- **场景一（端到端查询链路）**：后端自动化段 passed——真实 ES Testcontainers bulk 106 文档覆盖相关性加权、ON_SALE 恒效、七字段白名单（含 ID 字符串线）、分页、分类/品牌/价区过滤、四排序严格序；前端构建/单元段 passed（API 客户端 5 例、SearchView.spec 3 例、门禁四件，22 files/105 例）。**浏览器全链路段待联测**（mall-web→8080→mall-search→ES），在联测中实测分类/品牌筛选可操作、ID 为 string 的详情跳转（两项 major 已修复回归，EV-016~EV-019）；AC-014 Header 入口口径待产品确认（EV-013）。
- **场景五（Elasticsearch 故障）**：故障归一段 passed——连接拒绝/读超时/404 经 cause 链 503 B0501（无泄漏、traceId 串联）、空结果 200 无 ERROR、health DOWN 不外抛、Client 懒连接离线可启动，均有自动化或源码实证。**容器级注入段待联测**：实停 ES 容器复核 503/进程存活/X-Trace-Id/前端 Error 态，compose down-up 数据保留（EV-010/EV-011）。

## 2. 发现清单

| EV id | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-006 | mall-search `domain/search/ProductSearchItem.java#productId`；联动 repo-2 `src/api/search.ts`、SearchView 路由取参；依据 api-design-standard §5.3（Story 02-01 EV-003、02-03 EV-004） | major | 业务 ID 以裸 Long number 直出且前端声明为 number，违反业务 ID 字符串化强制规则，与 mall-product @StringId DTO/catalog.ts string 口径不一致；雪花 ID 超 2^53 末位丢失会导致搜索结果点详情 404（AC-008/AC-017 受影响） | **已闭环（review 阶段修复并回归）**：后端 d7dc2b0 为 ProductSearchItem.productId 加 common-web `@StringId`（入参保持 Long），ProductSearchApiTest/IndexSyncIntegrationTest 断言同步为字符串；repo-2 5ab0979 将 productId/categoryId/brandId 改 string 并更新 search.spec.ts；EV-016/EV-017 登记提交，EV-018 后端定向回归 26/26、EV-019 mall-web 105/105 全绿（type-check/lint/build 同绿） |
| EV-007 | repo-2 `src/views/search/SearchView.vue` 及全站 /search 入口；AC-015 / Story 02-03 AC-002（Story 02-03 EV-003） | major | 结果页无分类/品牌筛选控件（仅关键词/价格/排序/分页），且 HomeView 分类卡、详情面包屑等全站入口均跳 /products?categoryId=，无任何携带 categoryId/brandId 进入 /search 的路径，两维过滤 UI 不可达，且未记入 DU-FE-501 Deviations | **已闭环（review 阶段修复并回归）**：5ab0979 在 SearchView 新增分类树选择与品牌下拉控件，经 buildRouterQuery 写 URL 并重置 page=1，并新增 SearchView.spec 3 例（筛选渲染/URL 同步/雪花 ID 详情跳转）；EV-017 登记提交，EV-019 mall-web 22 files/105 例全绿；浏览器全链路操作留 Integration Gate 联测（EV-008 minor） |
| EV-008 | repo-2 `src/stores/search.ts`、`src/views/search/SearchView.vue`（缺 spec）；AC-014/016/017（Story 02-03 EV-005/EV-006） | minor | store 三态/requestSeq 竞态/URL 双向同步/重试与浏览器端到端链路原无自动化证据（test-design 既定浏览器验证放 Gate，DU-FE-501 DEV-2 已登记） | 视图部分已由 EV-017（5ab0979）新增 SearchView.spec 3 例闭环（筛选渲染/URL 同步/雪花 ID 跳转）；store 竞态/三态纯单测待补 stores/search.spec.ts，浏览器端到端链路由 Integration Gate 场景一补证闭合 |
| EV-009 | mall-gateway `application.yml`、GatewaySecurityConfiguration；AC-010（Story 02-01 EV-004） | minor | 游客 200 与 /api/internal/** 404 仅配置物/源码核对，无网关运行时自动化证据 | Integration Gate 以 curl/E2E 补 8080 无 token 200、internal 404 两证 |
| EV-010 | STORY-005-01-01-02 AC-001~003；SearchExceptionAdvice（Story 01-02 EV-003） | minor | 故障归一由 MockMvc cause 链切片 + 真实缺索引双层证明，未做实停 ES 容器的容器级注入与 mall-web Error 态联证 | Integration Gate 场景五实停 ES 容器验证 503 B0501/进程存活/X-Trace-Id/前端 Error 态 |
| EV-011 | STORY-005-01-01-01 AC-001/AC-003；compose/health（Story 01-01 EV-004） | minor | compose healthy、命名卷 down-up 数据保留、停 ES 后 health=DOWN 四项为设计既定手工/静态验证，无容器级实跑证据 | 联调阶段容器级启停复核并留证据（与场景五合并执行） |
| EV-012 | `application/search/ProductSearchService.java`、`domain/search/SortMode.java`、ElasticsearchProductSearchAdapter；AC-012（Story 02-01 EV-005、02-02 EV-003/EV-004） | minor | 归一/SortMode 映射无独立纯单测（9 例真实 ES 集成间接承载）；三合一组合、筛选+排序+第 2 页单请求、非数字类型绑定分支为分项/间接覆盖（非数字绑定未映 B0502 已记 DEV） | 维持集成覆盖或后续补 QueryNormalize 纯单测与类型绑定异常映射；联调 curl 补三合一/组合翻页单跳证据 |
| EV-013 | repo-2 `src/layouts/MallLayout.vue` submitSearch；AC-014（Story 02-03 EV-007） | minor | Header 全局搜索框回车跳 /products?keyword=（列表页）而非 /search，与设计描述有差异；DU-FE-501 DEV-1 已记录，功能可达但入口口径待确认 | Gate 联调由产品确认口径；需统一时改 submitSearch 跳转目标并回归 |
| EV-014 | DU-WS-501 实施记录；deploy/docker-compose.infra.yml（Story 01-01 EV-005） | minor | ES 镜像为首次引入，仅有 tag 无 RepoDigest，local-infrastructure-standard 的镜像内容追溯要求未落实 | 首次拉起后 docker image inspect 取 RepoDigests 摘要补录 DU/evidence |
| EV-015 | repo-2 `src/views/search/SearchView.vue`（829 行）（Story 02-03 EV-008） | minor | 单文件超 component-standard §9.1 的 300–500 行评估线（含约 280 行样式），工具条/价格表单/结果卡片可拆 | 后续迭代拆 SearchToolbar/SearchPriceForm/SearchCard 子组件并随组件归属样式，不阻断本 Change |

无 blocker。两项 major（EV-006/EV-007）已在 review 阶段修复并回归闭环（EV-016/EV-017 提交，EV-018 后端 26 例、EV-019 前端 105 例回归全绿）；9 项 minor 允许随 Gate 或后续迭代处置，去向已在 resolution 明确。

## 3. 完成确认

- [x] 四项检查全部执行（需求一致性 / 设计一致性 / 跨仓一致性 / 代码质量）
- [x] 已覆盖全部 18 条 AC 对照与 5 Story/6 DU 判定聚合
- [x] Integration Gate 场景一/场景五查询段结论已给（自动化段 passed，容器/浏览器段待联测）
- [x] 全部 blocker/major finding 已闭环（无 blocker；EV-006/EV-007 两项 major 已在 review 阶段修复，EV-018/EV-019 回归全绿）
- [x] minor finding 已记录（EV-008~EV-015，允许开放，处置去向明确）
- [x] 知识同步候选已写入 §1.5（4 项，含 1 条规范反例）
- [x] 跨仓一致性已核对（repo-4→repo-1→repo-2；原断裂两处 EV-006/EV-007 已修复闭环）
- [x] 5 份 Story 评审报告已产出并与本报告口径一致
