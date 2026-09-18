# Review Report（Story 级）— STORY-005-02-01-01 索引 Mapping 管理与首次全量构建

> 阶段：sdd-review 产物（独立只读评审；本报告不改动业务代码/测试/既有文档，不写 evidence.yaml）。

## 0. 元信息

- Change ID：CHG-0021（REQ-M5-002 商品搜索索引同步）
- Story ID：STORY-005-02-01-01 索引 Mapping 管理与首次全量构建
- 关联 DU：DU-BE-503（repo-1，commit 82ccf6e，completed）
- Test Report 来源：`evidence/test-report.md`（2026-09-19；9 个验收项中 7 项自动化 passed，2 项经静态评审/留 Integration Gate）
- Evidence 索引：`evidence/evidence.yaml`（EV-001 code-change 82ccf6e；EV-002 test-run 全 reactor 482/482；EV-003~EV-005 review-finding minor）
- 状态流转：testing（检查点，状态不变）
- 检查时间：2026-09-19
- 审查者：sdd-review 独立评审 Agent（trae-agent）

## 1. 检查结论

**通过（PASS，有 minor 遗留）。** Story AC-001~AC-007 均有实现与证据支撑，无 blocker/major；3 项 minor 均为已登记的自动化覆盖深度缺口/证据描述勘误，联调阶段补齐。

### 1.1 需求一致性

| Story AC | 验收要点 | 证据（真实方法/资源） | 结论 |
| --- | --- | --- | --- |
| AC-001 | 全新 ES 自动建 mall_products_v1+别名；重启幂等不改 Mapping | IndexSyncIntegrationTest#ensureIndexIdempotentWithStandardFallback（连调两次 ensureIndex，别名唯一指向 v1）；SearchIndexLifecycleManager 源码幂等分支 | passed |
| AC-002 | Mapping 代码化；价格 long、productId 可 docId/term、文本可检索 | `resources/es/product-index.json`+`product-index-standard.json` 静态评审；以该映射真实建索引成功 | passed（证据文字有一处描述偏差，见 EV-003） |
| AC-003 | 投影端点无令牌 401、经网关 404；持令牌分页含 total | ProductSearchProjectionApiTest#projectionWithoutTokenUnauthorized、#projectionPageOnSaleOnly；gateway `/api/internal/**` denyAll→404 配置 | passed（网关 404 未 E2E，见 EV-005 关联项） |
| AC-004 | 排除下架/无启用 SKU；价区为启用 SKU 极值 | #projectionPageOnSaleOnly（1000/3000）、#singleProjectionAndNotFoundCases；ProductSearchProjectionMapper INNER JOIN ENABLED SKU 派生表 SQL 抽查 | passed |
| AC-005 | 全量后 ES count=在架总数；抽样字段正确 | #fullRebuildSwitchesAliasAtomically（count=3、别名指向、可搜）、IndexSyncIntegrationTest#syncUpsertAcceptedAndSearchable（brandName 字段抽样） | passed |
| AC-006 | >500 分批（1001 条）；批次失败 FAILED 可定位 | FullIndexBuildService（PAGE_SIZE=500、id 升序页号从 1）与 RebuildService#markFailed 代码具备；无 1001 条/批次失败注入 | 部分（EV-004） |
| AC-007 | Flyway V1 建两表 | `V1__create_search_sync_tables.sql` 抽查（列/注释/索引与设计一致）；全部 @SpringBootTest 经 H2 Flyway 建表后读写两表 | passed |

### 1.2 设计一致性

DU-BE-503 五项 Deviations 全部闭环且理由合理：

1. RestClient 替代 OpenFeign（DEV-1）——与仓内 SkuClient/SearchSyncClient 同范式，契约等价，已核实 ProductProjectionClient 超时 2s/5s、X-Internal-Token、404→null。
2. 不提供内部 full-build 端点、首次全量复用 admin 重建链路（DEV-2）——触发面收敛到 RBAC 端点，任务可观测性更完整；story-spec §4 的内部触发端点相应取消，属合理演进且已登记。
3. IK 缺失自动回退 standard（DEV-3）——已核实 EsSearchIndexAdapter.createProductIndex 先 IK 后回退，两份 JSON 字段类型完全一致（long/keyword/date/index:false），仅分析器不同。
4. 投影口径 INNER JOIN 替代 EXISTS、单条投影以 404 表达不可售（DEV-4）——requirement-design §2.1 本就写明"404 语义=已删除/不可见"；total 口径与极值一次查询得到，search 侧客户端 404→null 二分重放，口径演进闭环。
5. categoryName/brandName 不建 keyword 子字段（DEV-5）——M5 无名称精确匹配/聚合需求，精确筛选走 categoryId/brandId long，别名架构支持后续映射版本化。

### 1.3 跨仓一致性

- mall-search → mall-product 投影拉取契约一致：ProductProjectionClient 调用 `GET /api/internal/products/search-projection?page=&size=` 与 InternalProductController 实际路由、UnifyResult 解包、分页字段（items/total/page/size）对齐。
- 双端投影视图同构：mall-product `SearchProjectionView` 与 mall-search `ProductProjectionView` 均为 13 字段同名 record（productId String、价格 Long 分、时间 epoch millis），EsSearchIndexAdapter 直接消费，跨仓 JSON 契约无漂移。
- 安全边界一致：投影端点挂 `/api/internal/products/**`（mall-product 安全链 hasRole SERVICE），gateway 对 `/api/internal/**` denyAll 返 404；SearchSecurityConfiguration 角色链 `/api/mall permitAll`、internal SERVICE、admin ADMIN 与设计一致。
- 本 Story 为单 DU 单仓后端变更，repo-2 无触点。

### 1.4 代码质量

- 分层符合 standards/engineering/backend/architecture-standard：domain（SearchIndexPort/枚举）、application（FullIndexBuildService）、infrastructure（Es adapter/persistence/client）边界清晰，适配器实现端口、配置走 @Value。
- 测试规范（testing-standard §2 风险覆盖、§13.3 测试安全切片）：真实 ES Testcontainers 8.17.4 + H2 Flyway + 真实安全链，非 Mock 堆砌；投影口径用真实 H2 数据断言，命名表达行为。
- ES 8.18.8（本地依赖仓库核实版本）用法合规：全量 dump 以 PIT+`_shard_doc` search_after，未使用 8.x 禁止的 `_id` 排序；bulk 失败抛异常含首条 id:reason。
- 未发现有明确规范依据的违规；遗留为覆盖深度问题（EV-004/EV-005）。

### 1.5 知识同步候选

- ES 索引"代码化双映射资源 + 插件缺失自动回退（IK→standard，字段类型冻结一致）"启动幂等模式。
- 读模型投影端点"SQL INNER JOIN 启用 SKU 派生表同时完成全集过滤与价区 MIN/MAX"的分页 total 保真写法。
- ES Java Client 8.x 全量遍历 PIT + `_shard_doc` 游标（禁 `_id` 排序）模式，可晋升 backend 规范。

## 2. 发现清单

| EV id | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-003 | evidence/test-report.md §1 Mapping 评审证据项（第 2 行）；resources/es/product-index.json | minor | 测试报告证据文字称回退映射 productId=keyword，抽查两份 es JSON 实际均为 `long`；docId 走 ES `_id` 字符串、long 字段仍可 term，AC-002 满足，但证据描述与资源不符 | converge 时勘误该证据描述，并将"productId=long、_id 为字符串 docId"固化为映射冻结口径（story-spec §2.1 原文"keyword/long"兼容） |
| EV-004 | story-spec.md#AC-006；FullIndexBuildService | minor | 1001 条分三批与"某批失败→FAILED+error_message"无专属自动化；500/批稳定分页由 #paginationOrderAndSize 间接支撑，失败终态路径仅静态评审 | Integration Gate 造 1001 条数据 + 以 Mock 投影客户端注入批次失败，核对任务终态 FAILED 与错误信息 |
| EV-005 | story-spec.md#AC-001 韧性侧；SearchIndexLifecycleManager | minor | ES 停机时启动不阻断（catch 后 log.error）、health DOWN 无自动化用例，仅代码静态评审；网关对内部路径 404 亦未 E2E | Integration Gate 做真实 ES 停启启动验证与网关 404 联调，补 health 指标断言 |

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 无 blocker/major finding（3 项 minor 已记录，允许开放，联调/converge 处理）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（投影端点/视图同构/SERVICE 边界）
