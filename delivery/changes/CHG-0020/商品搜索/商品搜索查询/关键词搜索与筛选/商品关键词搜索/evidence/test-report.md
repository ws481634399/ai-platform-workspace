# Test Report — STORY-005-01-02-01 商品关键词搜索

> 阶段：sdd-test 产物（Story 级）。

## 0. 元信息

- Change ID：CHG-0020（M5 商品搜索）
- Story ID：STORY-005-01-02-01
- 执行时间：2026-09-19
- 覆盖 AC 范围：AC-001 ~ AC-008（逐条见 §3）
- 覆盖 TC 范围：TC-001 ~ TC-010（逐条对齐本 Story `test-design.md` §1）
- 实施来源：DU-BE-502（repo-1 ai-platform-backend，含 mall-gateway 路由放行），commit `82ccf6e`

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| TC-001 | bulk 文档关键词分布在 name/keywords/brandName/categoryName，各自可检出；name boost 体现为名称命中排序靠前 | MockMvc + Testcontainers ES 8.17.4（bulk 6 精选 + 100 种子，refresh 立查） | passed | `ProductSearchApiTest#keyword_relevance_andOnSaleOnly`（「keyboard」命中名称 id1 与 keywords id2 且 id1 置顶（productName^3）；「机械」命中 id3） |
| TC-002 | 含 OFF_SALE 数据集，任意查询不返回下架文档（显式 status term 兜底） | MockMvc + Testcontainers ES（id4 为 OFF_SALE 同名商品） | passed | `ProductSearchApiTest#keyword_relevance_andOnSaleOnly`（「机械」total=1 仅 id3，OFF_SALE id4 被滤）；`#pagination`（无差别浏览 total=105 亦不含 id4） |
| TC-003 | 响应 JSON 字段白名单：仅 productId/productName/mainImage/minPrice/maxPrice/brandName/categoryName，无 status/keywords/publishedAt 等 | MockMvc，响应体正反 contains 断言 | passed | `ProductSearchApiTest#responseWhitelist`（正断言 7 字段存在，反断言 keywords/status/publishedAt/updatedAt 不存在） |
| TC-004 | 105 条文档：page=1/size=20 默认；size=500（用例取 999）切片为 100 且 total=105；page=0/-1 回退第 1 页 | MockMvc + Testcontainers ES | passed | `ProductSearchApiTest#pagination`（默认 total=105/page=1/size=20/items 20；size=999→100、page=2 items=5；page=0→page=1） |
| TC-005 | 无 keyword 请求返回 ON_SALE 文档（default 排序浏览态），结构与关键词查询一致 | MockMvc + Testcontainers ES | passed | `ProductSearchApiTest#pagination`（无参请求 total=105 在售、分页结构完整） |
| TC-006 | 网关 8080 无 token GET /api/mall/search/products → 200（路由 + 白名单） | 网关/E2E —— Integration Gate 联测项（test-design 已标注「联测」，无网关自动化 @Test） | 待联测 | 配置物证据：mall-gateway 路由 id mall-search-mall（Path=/api/mall/search/** → 8107）+ 白名单 permitAll（commit 82ccf6e）；本 Story `implementation.md` §4 AC-006 如实标注证据类型为配置落地 |
| TC-007 | 经网关访问 /api/internal/search/products/sync → 404；mall-search 无经网关可达写端点 | 网关/E2E —— Integration Gate 联测项（无网关自动化 @Test） | 待联测 | 配置物证据：网关无 internal 搜索路由、/api/internal/** denyAll→404；`MallSearchController` 仅一个 GET 端点（源码核对，commit 82ccf6e） |
| TC-008 | ES 故障场景搜索 → 503 B0501（复用 STORY-005-01-01-02 Advice，回归断言） | MockMvc 切片（cause 链异常注入） | passed（切片级） | `SearchExceptionAdviceTest#connectRefused_returns503`、`#socketTimeout_returns503`、`#indexMissing_returns503`；`ProductSearchApiTest#missingIndex_throws` |
| TC-009 | keyword 长度 65、size=0、page=abc 绑定失败 → 400 B0502 统一结构 | MockMvc + Testcontainers ES（参数真实过服务层校验） | passed（部分边界） | `ProductSearchApiTest#invalidParams`（min>max 400 B0502、minPriceFen=-1 400、keyword 65 字符 400）；`SearchExceptionAdviceTest#illegalArgument_returns400`（IAE → 400 B0502 文案） |
| TC-010 | ProductSearchService 参数归一（trim/null/默认值/上限）与 mapper 映射 | 集成链路间接覆盖（无独立 Service/Mapper 单测类） | passed（间接覆盖） | `ProductSearchApiTest#pagination`（默认 20/上限 100/page<1 回退 1）、`#responseWhitelist`（hits→SearchProductItem 7 字段映射）、`#keyword_relevance_andOnSaleOnly` |

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
| --- | --- | --- |
| mall-search（本 Story 相关） | 全 reactor `mvn test -B -ntp`（`TESTCONTAINERS_RYUK_DISABLED=true`，ES Testcontainers 8.17.4） | `ProductSearchApiTest` **9/9**（25.50s，真实 ES）；异常口径回归 `SearchExceptionAdviceTest` **4/4**，0 失败 0 跳过 |
| mall-search 模块整体 | 同上（2026-09-19） | **32/32**（7 classes），BUILD SUCCESS |
| 全 reactor 回归 | 同上 | 14 模块 **482/482**，0 失败 0 跳过，BUILD SUCCESS |
| 日志 | `delivery/changes/CHG-0020/evidence/logs/backend-full-test.log` | ProductSearchApiTest Tests run: 9（行 19400）、模块 Results 32（行 21348）、Reactor mall-search SUCCESS（39.939s） |

通过率：本 Story 自动化用例 **9/9 = 100%**；TC 维度 8 项 passed、TC-006/TC-007 两项网关 E2E 按 test-design 既定标注待 Integration Gate 联测（服务层与网关配置均已落地）。

## 3. AC 覆盖

| AC | 覆盖 TC |
| --- | --- |
| AC-001 | TC-001 |
| AC-002 | TC-002 |
| AC-003 | TC-003、TC-010 |
| AC-004 | TC-004、TC-009 |
| AC-005 | TC-005、TC-010 |
| AC-006 | TC-006 |
| AC-007 | TC-007 |
| AC-008 | TC-008 |

## 4. 备注 / 缺口

- **网关两 AC（AC-006/AC-007 → TC-006/TC-007）无自动化测试**：test-design §3 已标注「网关 AC 单测覆盖薄弱，以 Integration Gate E2E + 手工 curl evidence 替代」。路由/白名单配置已在 commit 82ccf6e 落地，匿名 200 与 internal 404 的运行时契约留待 M5 联调（含场景一 mall-web→8080→mall-search 全链路）。
- TC-009 设计列举的 `size=0`、`page=abc` 两个绑定失败分支未单独构造请求；实现口径为静默归一（size<1→20、page<1→1，见 DU-BE-502 DEV-1），非数字绑定走框架类型异常，后续如需冻结该行为可在联调补 curl 证据。
- TC-010 无独立 `ProductSearchServiceTest`/Mapper 单测：归一与映射行为全部经 ProductSearchApiTest 真实 ES 链路断言（DU-BE-502 DEV-2 测试布局说明），断言强度等价但故障定位粒度粗于纯单测。
- TC-001 数据集对 brandName/categoryName 的命中为 multi_match 同机制覆盖（查询 DSL 含四字段 productName^3/keywords/brandName/categoryName），未构造「纯品牌词/纯类目词」独立断言项。
