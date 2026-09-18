# Test Report — STORY-005-02-01-01 索引 Mapping 管理与首次全量构建

> 阶段：sdd-test 产物（Story 级）。

## 0. 元信息

- Change ID：CHG-0021
- Story ID：STORY-005-02-01-01
- 执行时间：2026-09-19
- 覆盖：AC-001~AC-007、TC-001~TC-009
- 实施来源：repo-1 DU-BE-503（commit 82ccf6e）
- 测试基线：真实 ES Testcontainers 8.17.4（镜像无 IK 插件，自动回退 standard 映射）+ H2（MySQL 兼容模式）Flyway + MockMvc 真实安全链。

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据（真实 类#方法） |
| --- | --- | --- | --- | --- |
| TC-001 | 空 ES 启动后 mall_products_v1 与查询别名 mall_products 存在；重复 ensureIndex 不抛错、别名仍唯一指向 v1 | ES Testcontainers 集成 | passed | IndexSyncIntegrationTest#ensureIndexIdempotentWithStandardFallback（@BeforeEach 清索引后 ensureIndex，断言 physicalIndicesOf("mall_products") 恰为 mall_products_v1，再连调两次 ensureIndex） |
| TC-002 | Mapping 代码化可评审；price long、productId 映射为 long（docId 使用字符串 _id）、mainImage index=false、日期 date | 静态评审 + 以该映射真实建索引 | passed | 资源文件 `mall-services/mall-search/src/main/resources/es/product-index.json`（IK 版）与 `product-index-standard.json`（回退版，字段类型完全一致：minPrice/maxPrice=long、productId 映射为 long（docId 使用字符串 _id）、mainImage=keyword 且 index=false、publishedAt/updatedAt=date）；建索引成功由 #ensureIndexIdempotentWithStandardFallback 实证 |
| TC-003 | 投影端点无内部令牌 401；持 SERVICE 凭据分页（page/size）返回投影与 total | MockMvc | passed（401/分页） | ProductSearchProjectionApiTest#projectionWithoutTokenUnauthorized（401）、#projectionPageOnSaleOnly（X-Internal-Token 分页，total=2、page/size 回显） |
| TC-004 | SQL EXISTS 口径：ON_SALE 无启用 SKU / OFF_SALE(DRAFT) 排除；minPrice/maxPrice=启用 SKU 极值 | MockMvc + H2 真实数据 | passed | ProductSearchProjectionApiTest#projectionPageOnSaleOnly（5001 启用 SKU 1000/3000 → min=1000、max=3000；5002 仅 DISABLED SKU 排除；5003 DRAFT 即使有启用 SKU 也排除） |
| TC-005 | 全量构建后 ES count=投影 total；抽样文档字段（名/分类品牌名/图/价格/时间）正确 | ES Testcontainers 集成 + 投影客户端 Mock | passed | IndexSyncIntegrationTest#fullRebuildSwitchesAliasAtomically（投影 3 条 → totalCount/indexedCount=3、别名 count=3、关键字"重建商品"可搜）；字段抽样另见 #syncUpsertAcceptedAndSearchable（brandName="索隐品牌" 经商城搜索返回） |
| TC-006 | 1001 条分批（≥3 批）构建成功；mock ES 第 2 批失败 → FAILED + error_message 含批次/productId | — | **未自动化** | 无对应用例（见 §4-G1） |
| TC-007 | Flyway V1 在 mall_search 库建 search_index_rebuild_task / search_sync_failure_record 两表 | SpringBoot 启动迁移 + JDBC 实证 | passed | IndexSyncIntegrationTest 与 SyncFailureFlowTest 的 @BeforeEach 均对两表执行 DELETE；#rebuildConflictWhenRunning 向 search_index_rebuild_task INSERT RUNNING 行成功；SyncFailureFlowTest 全部 6 例读写 search_sync_failure_record |
| TC-008 | ES 停机时启动不阻断（ensureIndex 捕获、日志 ERROR、health DOWN） | — | **未自动化**（代码评审支撑） | 无对应用例；`SearchIndexLifecycleManager` catch 后 log.error("搜索索引启动保障失败（不阻断启动）") 经静态评审（见 §4-G2） |
| TC-009 | 单条投影：下架/无启用 SKU 商品 data 语义；正常商品字段完整 | MockMvc + H2 | passed（契约差异见备注） | ProductSearchProjectionApiTest#singleProjectionAndNotFoundCases（5001 在架 200 且 minPriceFen=1000；5002 无启用 SKU / 5003 草稿 / 99999 不存在均 404）。**备注**：真实实现以 404 表达不可售/不存在，非 story-design §2 所写 data=null，测试按真实契约断言 |

## 2. 测试执行汇总
| 模块 | 命令 | 结果 |
| --- | --- | --- |
| mall-search | `mvn test -B -ntp`（全 reactor，TESTCONTAINERS_RYUK_DISABLED=true） | IndexSyncIntegrationTest **9/9**（本 Story 相关 4 例）；mall-search 模块合计 32/32，0 失败 |
| mall-product | 同上 | ProductSearchProjectionApiTest **4/4**；mall-product 模块合计 **101/101**，0 失败 |
| 全 reactor | 同上（2026-09-19 01:42 完成） | 14 个有测试模块合计 **482/482**，BUILD SUCCESS |
| 日志 | `delivery/changes/CHG-0020/evidence/logs/backend-full-test.log`（跨 Change 共享） | IndexSyncIntegrationTest 行 20469（9,0,0）；ProductSearchProjectionApiTest 行 11909（4,0,0）；mall-product 汇总行 17942（101）；BUILD SUCCESS 行 22991 |

通过率：已自动化 7/7 个可执行 TC passed；TC-006、TC-008 无自动化（见 §4）。

## 3. AC 覆盖

| AC | 验收标准（摘要） | 覆盖 TC | 结论 |
| --- | --- | --- | --- |
| AC-001 | 全新 ES 自动建 v1+别名；再启动不报错不改 Mapping | TC-001（TC-008 韧性侧未自动化） | passed |
| AC-002 | Mapping 可评审；价格 long、productId 可 term/docId、文本可检索 | TC-002 | passed（GET mapping 字段类型未做独立断言，依赖资源文件评审+建索引成功） |
| AC-003 | 投影端点无令牌 401/403、网关 404；持令牌分页正确 | TC-003、TC-009 | passed（401 实测；403/网关 404 留 Integration Gate） |
| AC-004 | 投影排除下架/无启用 SKU；价格极值正确 | TC-004、TC-009 | passed |
| AC-005 | 全量构建后 count=在售总数；抽样字段正确 | TC-005 | passed |
| AC-006 | >500 分批成功（1001 条）；中途批次失败 FAILED 且错误可定位 | TC-006 | **未自动化**（风险见 §4-G1） |
| AC-007 | Flyway V1 建两表 | TC-007 | passed（迁移成功执行并被读写实证；列/索引齐全性以 SQL 评审为主） |

## 4. 缺口 / 备注

- **G1（TC-006 / AC-006）**：1001 条分三批与"第 2 批失败 → FAILED+error_message"路径无专属自动化。分批 500 的稳定排序分页由 ProductSearchProjectionApiTest#paginationOrderAndSize（size=1 翻页，id 升序）间接支撑；建议联调/补测中以 Mock 投影客户端制造批次失败核对任务终态。
- **G2（TC-008）**：ES 停机启动场景未自动化；不阻断启动由 SearchIndexLifecycleManager 异常捕获代码评审保证，health DOWN 指标无断言。
- TC-002 未对 GET mapping 返回体逐字段断言类型；当前以"冻结映射资源文件 + 用该映射真实建索引/写入/查询成功"作为间接证据。
- TC-003 的 403 分支与"经网关访问内部路径 404"在本 Story 无网关层自动化，纳入 M5 Integration Gate 浏览器/网关联调。
- 单条投影端点真实语义为 404（test-design 写 data=null），与最终实现一致、与 story-design 早期表述不同，以实现为准。
