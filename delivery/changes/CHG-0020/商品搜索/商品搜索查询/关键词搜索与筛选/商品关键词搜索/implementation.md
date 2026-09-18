# Implementation（跨仓实施汇总）— 商品关键词搜索 STORY-005-01-02-01

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0020（Elasticsearch 商品搜索）
- Story：STORY-005-01-02-01 商品关键词搜索
- 实施日期：2026-09-18

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-502 | repo-1（ai-platform-backend） | mall-search 关键词查询全链路（multi_match/ON_SALE/白名单/分页）+ mall-gateway 匿名路由；ProductSearchApiTest 9 例、SearchExceptionAdviceTest 4 例（异常 Story 共证） |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 82ccf6e | DU-BE-502 | repo-1 | feat(search): GET /api/mall/search/products 关键词搜索、白名单摘要、分页归一；网关 mall-search-mall 匿名路由 |

## 3. 各仓实施引用

- repo-1（ai-platform-backend）：
  - 实施记录：`implementation/ai-platform-backend/delivery/CHG-0020/商品搜索/商品搜索查询/关键词搜索与筛选/商品关键词搜索/DU-BE-502/implementation.md`
  - 要点：
    - `MallSearchController` GET `/api/mall/search/products`（全部参数可选，UnifyResult 包裹，无写端点）。
    - `ElasticsearchProductSearchAdapter`：keyword 非空 must multi_match（productName^3/keywords/brandName/categoryName，Operator.OR）；恒 filter term status=ON_SALE；DEFAULT 排序 _score desc, updatedAt desc；trackTotalHits；from/size 分页。
    - `ProductSearchItem` 白名单摘要 7 字段（productId/productName/mainImage/minPrice/maxPrice/brandName/categoryName，金额分；无 categoryId/brandId，见 DU DEV-2）。
    - 参数归一：keyword trim/≤64、page<1→1、size<1→20 且上限 100。
    - mall-gateway：路由 id mall-search-mall（Path=/api/mall/search/** → http://localhost:8107），GatewaySecurityConfiguration 白名单 permitAll；无 internal 搜索路由，/api/internal/** denyAll→404。
    - 合并提交共存：FeatureGate search.enabled 切点（CHG-0022，fail-open）、安全链 internal/admin（CHG-0021），均非本 Story 交付物。

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | productName/keywords/brandName/categoryName 多字段命中，名称字段 ^3 加权置顶 | passed（ProductSearchApiTest.keyword_relevance_andOnSaleOnly：keyboard total=2 id1 置顶，「机械」total=1 id3） |
| AC-002 | OFF_SALE 商品任何查询不返回（恒 term status=ON_SALE） | passed（同用例 id4 被滤；105 条数据集） |
| AC-003 | 响应仅白名单字段（正反断言含/不含字段集） | passed（ProductSearchApiTest.responseWhitelist） |
| AC-004 | size=500/999 限制为 100、page=0/-1 回退第 1 页、默认 size=20 | passed（ProductSearchApiTest.pagination；静默归一而非 400，见 DU-BE-502 DEV-1） |
| AC-005 | 无 keyword 浏览全量在售商品（must 不加、filter 恒效） | passed（pagination：无参 total=105 在售） |
| AC-006 | 网关匿名 GET /api/mall/search/products 无 token 返回 200 | passed（配置落地：gateway application.yml 第 71–75 行 + 白名单第 49–50 行；匿名 200 联测归 Integration Gate，无网关单测，如实标注证据类型） |
| AC-007 | /api/internal/search 无路由、/api/internal/** denyAll→404；服务无写端点 | passed（网关配置核对 + MallSearchController 仅 GET；E2E 归 Integration Gate） |
| AC-008 | ES 故障/索引缺失统一 B05xx（503 B0501），不回传 ES 原始错误 | passed（ProductSearchApiTest.missingIndex_throws + SearchExceptionAdviceTest 连接/超时/404 三例） |
