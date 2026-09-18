# Implementation（跨仓实施汇总）— CHG-0020 Elasticsearch 商品搜索

> 阶段：sdd-dev 产物。本文件为 Change 级跨 Story 汇总，各 Story 实施正文见对应 Story 目录。

## 0. 元信息

- Change ID：CHG-0020（Elasticsearch 商品搜索）
- 实施日期：2026-09-18
- 范围：mall-search 服务与 Elasticsearch 基础环境（STORY-005-01-01-01/02）、商品关键词搜索与筛选排序（STORY-005-01-02-01/02）、mall-web 商品搜索体验（STORY-005-01-02-03）；涉及 repo-4（infrastructure）、repo-1（backend）、repo-2（frontend）三仓

## 1. Story 实施总览

| Story | DU | 仓库 | 状态 |
| --- | --- | --- | --- |
| STORY-005-01-01-01 建立 mall-search 与 Elasticsearch 基础环境 | DU-WS-501 / DU-BE-501 | repo-4 / repo-1 | completed |
| STORY-005-01-01-02 搜索异常响应与降级 | DU-BE-510 | repo-1 | completed |
| STORY-005-01-02-01 商品关键词搜索 | DU-BE-502 | repo-1 | completed（网关匿名/internal 行为联测归 Integration Gate） |
| STORY-005-01-02-02 搜索筛选与排序 | DU-BE-511 | repo-1 | completed |
| STORY-005-01-02-03 mall-web 商品搜索体验 | DU-FE-501 | repo-2 | partial（功能完成；store/视图单测缺，AC-006 未完全闭合） |

## 2. Commit 记录

| Commit | 仓库 | 说明 |
| --- | --- | --- |
| 7f05e11 | repo-4（ai-platform-infrastructure） | feat(infra): docker-compose.infra.yml 增加 Elasticsearch 8.17.4 单节点服务、es-data 命名卷、ES_PORT 与健康检查（DU-WS-501） |
| 82ccf6e | repo-1（ai-platform-backend） | feat(search): M5 三 Change 合并提交——CHG-0020 mall-search 关键词/筛选/排序/异常归一/网关匿名路由（DU-BE-501/502/510/511）；同提交共存 CHG-0021 索引同步（index 包/admin 路由）与 CHG-0022 FeatureGate（search.enabled）代码 |
| ec0921b | repo-2（ai-platform-frontend） | feat(web): mall-web 搜索 API 客户端/Pinia store/SearchView 结果页与 /search 路由（DU-FE-501；同提交含 CHG-0022 search.enabled 关闭态） |

## 3. 各 Story 实施引用

- 建立 mall-search 与 Elasticsearch 基础环境：`商品搜索/商品搜索查询/搜索服务基础/建立 mall-search 与 Elasticsearch 基础环境/implementation.md`
- 搜索异常响应与降级：`商品搜索/商品搜索查询/搜索服务基础/搜索异常响应与降级/implementation.md`
- 商品关键词搜索：`商品搜索/商品搜索查询/关键词搜索与筛选/商品关键词搜索/implementation.md`
- 搜索筛选与排序：`商品搜索/商品搜索查询/关键词搜索与筛选/搜索筛选与排序/implementation.md`
- mall-web 商品搜索体验：`商品搜索/商品搜索查询/关键词搜索与筛选/mall-web 商品搜索体验/implementation.md`

## 4. 关键技术决策

1. **客户端/服务端版本策略与 8.18 兼容**：官方 co.elastic.clients（无 RHLC），Spring Boot 3.5.15 BOM 解析客户端 8.18.8，服务端与 Testcontainers 固定 8.17.4（同 8.x 主版本兼容）；为规避 ES 8.18 禁止对 `_id` 排序，深分页全量 ID 拉取采用 PIT + `_shard_doc`（EsSearchIndexAdapter，属同合并提交的 CHG-0021 代码，本 Change 不交付但需知悉共存）。
2. **召回 DSL 口径**：keyword 非空时 bool.must 追加 multi_match（productName^3、keywords、brandName、categoryName，Operator.OR）；filter 恒带 term status=ON_SALE（下架商品任何条件不可见）；无 keyword 即浏览态（不加 must）；trackTotalHits 保证 total 准确。
3. **白名单摘要契约**：对外仅下发 ProductSearchItem 7 字段（productId/productName/mainImage/minPrice/maxPrice/brandName/categoryName，金额整数分），SearchProductDocument 读模型含全字段（含 categoryId/brandId 供 term 过滤），响应 SearchPage{items,total,page,size} 前后端冻结。
4. **故障不降级、统一 B05xx**：不做商品库 DB 回退（搜索域零商品库直连）；连接拒绝/读超时/索引 404 经 cause 链判定统一 503 B0501 且响应无主机/堆栈，WARN 带 traceId；非法参数 400 B0502；空结果正常 200 不打 ERROR；前端以 Error 态 + 重试承接。
5. **真实 ES 测试基线**：Testcontainers static 单例 Elasticsearch 8.17.4（关 xpack/enrollment、single-node、512m），ProductSearchApiTest 以 105 条固定数据集（6 精选 + 100 种子）对相关性/白名单/分页/过滤/区间/排序/异常逐条断言，归一逻辑不单建纯单测而在真实 DSL 结果上回归。
6. **宽松入参 + 相交区间**：价格按区间相交（minPrice.lte(max) ∧ maxPrice.gte(min)，单边开边界）；sort 仅认小写 price_asc/price_desc/newest，未知值（含大写）回退 DEFAULT 不报错；分页 size<1→20、上限 100 截断、page<1→1；仅负价格/min>max/keyword>64 抛 400。
7. **功能开关 fail-open（共存的 CHG-0022）**：ProductSearchService 首行 ensureEnabled("search.enabled")，缺键/故障默认放行，仅显式 false 返回 403 B0606；不影响本 Change 默认行为，前端已提前落地关闭态。
