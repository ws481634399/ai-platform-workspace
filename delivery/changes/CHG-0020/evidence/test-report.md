# Test Report — CHG-0020 M5 商品搜索

> 阶段：sdd-test 产物（Change 级测试汇总）。

## 0. 元信息

- Change ID：CHG-0020（M5 商品搜索 —— Elasticsearch 基础环境、关键词搜索、筛选排序、异常归一、mall-web 搜索体验）
- 执行时间：2026-09-19
- 覆盖：5 个 Story（STORY-005-01-01-01 / 01-01-02 / 01-02-01 / 01-02-02 / 01-02-03）的全部 TC 与 AC，各 Story 明细见其 `evidence/test-report.md`
- Implementation 来源：
  - repo-4（ai-platform-infrastructure）：commit `7f05e11`（DU-WS-501，Elasticsearch 8.17.4 compose 环境）
  - repo-1（ai-platform-backend）：commit `82ccf6e`（DU-BE-501 / DU-BE-502 / DU-BE-510 / DU-BE-511，mall-search 四单元）
  - repo-2（ai-platform-frontend）：commit `ec0921b`（DU-FE-501，mall-web 搜索体验）
- Evidence 索引：`evidence/evidence.yaml`（EV-001 repo-4 7f05e11、EV-002 repo-1 82ccf6e、EV-003 repo-2 ec0921b）
- 执行环境：JDK 21 / Maven 全 reactor；Testcontainers Elasticsearch 8.17.4（`TESTCONTAINERS_RYUK_DISABLED=true`）；mall-web pnpm + vitest / vue-tsc / eslint / vite build

## 1. 测试范围

分仓与 DU 覆盖清单（6 个 DU）：

| 仓库 | DU | 内容 | 主要自动化承载 |
| --- | --- | --- | --- |
| repo-4 | DU-WS-501 | docker-compose.infra.yml Elasticsearch 8.17.4 单节点、healthcheck、ai-platform-es-data 卷、ES_PORT | 手工/脚本 + 配置静态核对（冒烟由后端 Testcontainers 承载） |
| repo-1 | DU-BE-501 | 官方 elasticsearch-java Client、MALL_ES_URIS 配置、SearchHealthIndicator、Testcontainers 基线 | `ElasticsearchSmokeTest` 1、`MallSearchApplicationSmokeTest` 1 |
| repo-1 | DU-BE-510 | B0501/B0502 错误码、SearchExceptionAdvice 三类异常归一、traceId WARN、空结果 200 | `SearchExceptionAdviceTest` 4（+ ProductSearchApiTest 空结果/缺索引 2 例共证） |
| repo-1 | DU-BE-502 | GET /api/mall/search/products 关键词 multi_match、ON_SALE 硬过滤、白名单摘要、分页归一、网关匿名路由 | `ProductSearchApiTest` 9 |
| repo-1 | DU-BE-511 | categoryId/brandId term、价格区间相交、default/price_asc/price_desc/newest 四排序、参数 400 | `ProductSearchApiTest` 9（筛选排序 4 方法） |
| repo-2 | DU-FE-501 | api/search.ts、stores/search.ts、SearchView.vue、/search 路由、URL 状态同步、三态与竞态防护 | `src/api/search.spec.ts` 5（API 层）；store/视图无专属 vitest（见 §5） |

Story 级 TC/AC 规模：STORY-01-01-01 6 TC/5 AC、STORY-01-01-02 6 TC/5 AC、STORY-01-02-01 10 TC/8 AC、STORY-01-02-02 8 TC/7 AC、STORY-01-02-03 7 TC/6 AC，合计 **37 TC / 31 AC**。

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 后端 mall-search 本 Change（ElasticsearchSmokeTest 1 + MallSearchApplicationSmokeTest 1 + SearchExceptionAdviceTest 4 + ProductSearchApiTest 9） | 15 | 15 | 0 | 0 |
| 前端 mall-web 本 Change（src/api/search.spec.ts） | 5 | 5 | 0 | 0 |
| **本 Change 功能用例合计** | **20** | **20** | **0** | **0** |
| 后端全 reactor 回归（14 模块，2026-09-19 `mvn test -B -ntp`） | 482 | 482 | 0 | 0 |
| 　其中 mall-search 模块（7 classes） | 32 | 32 | 0 | 0 |
| 前端 mall-web 全量回归（vitest 21 files） | 102 | 102 | 0 | 0 |

- 本 Change 功能用例通过率：**20/20 = 100%**。
- 后端 mall-search 32 例的归属区分：本 Change 15 例（上表四类）；`IndexSyncIntegrationTest` 9 例、`SyncFailureFlowTest` 6 例服务于索引同步/失败恢复，功能归属 **CHG-0021**；`SearchFeatureGateTest` 2 例服务于功能开关，归属 **CHG-0022**。后 17 例本次执行一并全绿，仅作回归不计入本 Change 计数。
- 前端 mall-web 102 例中仅 src/api/search.spec.ts 5 例为本 Change 新增；其余 97 例为既有页面回归，全部通过。
- 门禁：mall-web type-check 0 error、lint 0 error（65 warnings 为既有风格告警）、build SUCCESS。

## 3. 证据清单

| 证据 | 路径 | 要点 |
| --- | --- | --- |
| 后端全 reactor 日志 | `delivery/changes/CHG-0020/evidence/logs/backend-full-test.log` | ProductSearchApiTest 9（行 19400）、ElasticsearchSmokeTest 1（行 19474）、IndexSyncIntegrationTest 9（行 20469）、SyncFailureFlowTest 6、SearchExceptionAdviceTest 4、MallSearchApplicationSmokeTest 1；mall-search Results 32（行 21348）；Reactor 14 模块 SUCCESS、BUILD SUCCESS（Finished 2026-09-19T01:42:13） |
| 前端单测日志 | `delivery/changes/CHG-0020/evidence/logs/mall-web-vitest.log` | Test Files 21 passed (21)、Tests 102 passed (102)、src/api/search.spec.ts (5 tests) |
| 前端类型检查日志 | `delivery/changes/CHG-0020/evidence/logs/mall-web-type-check.log` | vue-tsc 双 tsconfig，0 error |
| 前端 lint 日志 | `delivery/changes/CHG-0020/evidence/logs/mall-web-lint.log` | 0 errors，65 warnings |
| 前端构建日志 | `delivery/changes/CHG-0020/evidence/logs/mall-web-build.log` | ✓ built in 519ms，SUCCESS |
| Story 报告 ×5 | 各 Story 目录 `evidence/test-report.md` | TC↔@Test 逐条映射与 AC 覆盖、缺口标注 |
| Evidence 索引 | `delivery/changes/CHG-0020/evidence/evidence.yaml` | EV-001/EV-002/EV-003 三个 code-change 条目 |

## 4. M5 Integration Gate 场景映射

| # | 场景 | 验证内容 | 执行方式 | 结果 | 证据 |
| --- | --- | --- | --- | --- | --- |
| 一 | 商品搜索（查询段） | 商品已在 ES 前提下，mall-search 关键词查询返回真实商品：多字段命中 + 名称加权、ON_SALE 过滤、真实商品字段（productId/productName/mainImage/minPrice/maxPrice/brandName/categoryName）、分页 | MockMvc + Testcontainers ES 8.17.4（bulk 106 文档真实检索） | passed（查询段自动化） | `ProductSearchApiTest#keyword_relevance_andOnSaleOnly`、`#responseWhitelist`、`#pagination`、`#categoryAndBrandFilter`、`#priceRangeIntersection`、`#sorts` |
| 五 | Elasticsearch 故障（查询侧：无不可理解 500、错误可定位） | ES 连接拒绝/读超时/索引 404 三类故障 → HTTP 503 统一 UnifyResult{code:B0501}，不泄漏主机/堆栈；WARN 日志带 traceId 且 X-Trace-Id 透传；0 命中为正常 200 空页 | MockMvc 切片（cause 链异常注入 + Logback ListAppender）+ 真实 ES 缺失索引佐证 | passed（故障归一段） | `SearchExceptionAdviceTest#connectRefused_returns503`、`#socketTimeout_returns503`、`#indexMissing_returns503`、`#illegalArgument_returns400`；`ProductSearchApiTest#missingIndex_throws`、`#emptyResult_noErrorLog` |

其余场景归属（不在本 Change 验收口径，本次仅回归全绿）：

- 场景二「商品修改」、场景三「商品下架」、场景四「价格变化」（同步索引链路）→ **CHG-0021**，承载用例 `IndexSyncIntegrationTest` 9 例。
- 场景五中「同步失败可恢复」→ **CHG-0021**，承载用例 `SyncFailureFlowTest` 6 例。
- 场景六「功能开关」、场景七「缓存一致性」→ **CHG-0022**（开关承载用例 `SearchFeatureGateTest` 2 例）。
- 场景一中「mall-web 输入关键词 → 点击商品 → 进入 Product Detail」浏览器全链路，以及网关 8080 匿名 200 / internal 404 契约 → Integration Gate 阶段联调（本 Change 配置与前端实现均已落地，缺运行时 E2E 证据，见 §5）。

## 5. 缺口与说明

1. **前端 store/视图无专属 vitest**：`src/stores/search.ts`（成功/空/失败三态、requestSeq 竞态丢弃）与 `src/views/search/SearchView.vue`（URL query 双向同步、三态渲染、重试、元分换算拦截）均无对应 spec 文件；现有 5 例 vitest 仅覆盖 `src/api/search.ts` API 层。STORY-005-01-02-03 **AC-006 判定 partial**，浏览器 E2E 验证在 Integration Gate 联调阶段补齐（搜索→筛选→排序→详情→返回）。
2. **网关匿名 200 / internal 404 契约待集成联测**：STORY-01-02-01 S3 用例006/S3 用例007（AC-006/AC-007）无网关自动化测试，路由 mall-search-mall、白名单 permitAll、/api/internal/** denyAll 配置已在 82ccf6e 落地，运行时契约以联调 curl/E2E 证据闭合。
3. **ES 故障的容器级注入在联调处置**：当前故障归一以 cause 链 MockMvc 切片 + 真实 ES 缺失索引异常证明（覆盖连接拒绝/超时/404 三类与 traceId 可定位），未做「直接停止 ES 容器」的故障注入；Integration Gate 场景五执行容器级实停并验证 mall-search 503、进程存活、mall-web Error 态。
4. 基础环境 Story（STORY-01-01-01）S1 用例001~S1 用例004 为设计既定手工/静态项（compose 健康检查、依赖声明、health DOWN、MALL_ES_URIS），无自动化 @Test，结论依据配置物与实施记录，容器级启停复核随联调进行。
5. 用例布局如实说明：ProductSearchService 参数归一/mapper、SearchQuery 排序映射与区间校验无独立纯单测类，统一经 ProductSearchApiTest 真实 ES 集成链路断言（DU-BE-502/511 DEV 记录）；S4 三合一组合请求、「筛选+排序+第 2 页」单请求、非数字参数绑定分支为间接/分项覆盖，详见对应 Story 报告 §4。
6. 合并提交提示：82ccf6e 中同时包含 CHG-0021 安全链/internal 端点与 CHG-0022 FeatureGate 切点代码，其测试用例（17 例）已按功能归属排除在本 Change 计数外；ec0921b 同提交含 CHG-0022 搜索开关关闭态前端代码，非本 Change 验收物。
