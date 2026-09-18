# Requirement Spec（需求级产品规格）

> 层级：Requirement 级产物——针对本次需求/Change（多 Story 统一一份）
> 业界锚点：PRD（Problem → Goals/Metrics → Scope → Requirements → AC）
> 输入：exploration.md + requirement.md + references/M5.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0020
- Requirement: REQ-M5-001 Elasticsearch 商品搜索
- 状态流转: exploring → specified
- 主要服务: mall-search（从空骨架交付，8107，库 mall_search，repo-1）、mall-gateway（路由增量，repo-1）
- 前端: mall-web（搜索框 + 搜索结果页，repo-2）
- 基础设施: Elasticsearch 8.x 单节点（repo-4 docker-compose 新增）
- target-user: GUEST/MEMBER（商城商品搜索，游客可访问，点击详情仍走既有 mall-product 页面）
- pain-points: M2 的数据库 LIKE/筛选在商品量增长后无法支撑高性能关键词检索；商城缺少独立搜索入口；没有搜索异常口径会直接暴露不可理解的 500
- expected-value: 商城用户能用关键词快速找到真实上架商品，并按分类/品牌/价格/排序精确定位；平台获得可演进的搜索投影链路（为 M6 AI 商品检索铺路），且 Product 权威边界不被破坏
- scope-in: Elasticsearch 基础设施、mall-search 接入 ES、关键词多字段搜索、分类/品牌/价格组合筛选、四种排序、标准分页、Search DTO 精简读模型、四类搜索异常统一响应、mall-web 搜索框与结果页全状态
- scope-out: 索引 Mapping 生命周期与全量/增量同步（CHG-0021）、数据库降级搜索（本期不做）、库存强实时入索引、推荐/综合热度排序、AI 语义检索/向量搜索（M6）、搜索运营后台

## 1. 背景

M2 交付了商品权威数据（SPU/SKU/品牌/分类/上下架），M3 交付了商城分类浏览与商品详情。商城目前的"找商品"只有分类浏览一条路径，且列表检索是 mall-product 内的数据库筛选。M5 按 product/08 的既定架构把"检索"从 Product Context 拆出：新建 mall-search（8107）+ Elasticsearch 投影，Product DB 保持唯一 Source of Truth，ES 只是 Search Projection。本 Change 只交付"查询侧"（环境 + 检索 + 前端），索引数据的灌入与同步由 CHG-0021 紧接交付；两个 Change 在 M5 Integration Gate 统一联调。金额沿用整数分 Long；跨服务只走 Internal API，mall-search 不直连任何商品库。

## 2. 用户价值

- 商城用户（GUEST/MEMBER）：在任意页面通过搜索框输入关键词即可检索上架商品，用分类/品牌/价格区间与排序快速缩小范围，分页浏览，点击进入熟悉的商品详情页。
- 平台：商品检索能力从数据库筛选升级为独立搜索引擎，为后续搜索增强（销量/综合排序）与 M6 AI 商品检索建立可复用投影；搜索与商品主数据解耦，搜索故障不影响商品详情与交易主链路。

JTBD：

- 角色：商城用户；场景：When 我明确想买某类商品（如"机械键盘"）, I want 在搜索框输入关键词并按品牌/价格筛选排序；价值：So that 我不必逐级浏览分类就能快速找到可购买的上架商品。
- 角色：商城用户；场景：When 搜索没有命中或搜索服务暂时故障, I want 看到明确的空结果或错误提示；价值：So that 我知道是"没有商品"还是"稍后重试"，并仍可走分类浏览。
- 角色：平台；场景：When 未来需要 AI 导购检索商品或增强排序, I want 已有独立搜索服务与索引投影；价值：So that 新能力不必再拆商品主数据。

## 3. 功能范围

### 3.1 包含

- [S1 ES 基础设施与服务接入] repo-4 docker-compose 新增 Elasticsearch 8.x 单节点（健康检查、数据卷、内网、安全简化配置、.env 样例）；mall-bom 统一 ES 版本；mall-search 引入官方 elasticsearch-java Client 与连接配置（localhost:9200/环境变量覆盖）、ES 连通性健康检查；Testcontainers ES 集成测试基线。
- [S2 关键词搜索] 多字段匹配（productName/keywords/brandName/categoryName）；硬过滤 status=ON_SALE；返回精简 SearchProductDTO（productId/name/image/priceFen/brandName/categoryName）；标准分页（默认 20、最大 100）与统一 UnifyResult；网关新增 `/api/mall/search/**` → 8107 游客可访问路由。
- [S3 筛选与排序] categoryId（按索引字段单值过滤，子孙分类展开由 mall-product 既有口径在查询侧以 categoryId 精确匹配实现 M5 最小集）、brandId、minPrice/maxPrice 组合 bool 过滤；sort=default|price_asc|price_desc|newest（发布时间倒序）；筛选/排序/分页可自由组合。
- [S4 搜索异常口径] ES 不可用、查询超时、索引不存在三类底层异常统一捕获为 B05xx 业务错误（可定位日志含 traceId）；搜索结果为空是正常 200 空分页；M5 不做数据库降级搜索。
- [S5 mall-web 搜索体验] 全局搜索框；/search 搜索结果页（关键词回显、分类/品牌/价格筛选、排序控件、分页、商品卡片复用）；空结果/Loading/Error 三态；点击商品跳转既有 ProductDetailView；search.enabled 开关关闭时隐藏入口（接线在 CHG-0022，本 Change 仅保证无开关时默认展示）。

### 3.2 不包含

- 索引 Mapping 代码化管理、全量/增量同步、重建、失败重试（CHG-0021）；本 Change 集成测试用 Testcontainers 临时 Mapping，本地联调依赖 CHG-0021 灌入数据。
- 数据库降级搜索；库存/可售状态入索引展示；销量/综合热度排序；搜索联想/热词/拼写纠错；聚合筛选面板（facet 计数）；AI/向量搜索；搜索运营后台。
- 商品详情改造（详情始终由 mall-product 提供）。

### 3.3 Story 拆分总表

| Story ID | 标题 | Scope 摘要 | 依赖 | 优先级 |
| --- | --- | --- | --- | --- |
| STORY-005-01-01-01 | 建立 mall-search 与 Elasticsearch 基础环境 | S1：compose ES、mall-bom 版本、ES Client/健康检查、Testcontainers 基线 | REQ-M2-003 | P0 |
| STORY-005-01-01-02 | 搜索异常响应与降级 | S4：三类 ES 异常归一 B05xx、空结果正常态、不做 DB 降级 | S1 | P0 |
| STORY-005-01-02-01 | 商品关键词搜索 | S2：多字段检索+ON_SALE 过滤+SearchDTO+分页+网关公开路由 | S1 | P0 |
| STORY-005-01-02-02 | 搜索筛选与排序 | S3：分类/品牌/价格组合过滤、四种排序、与分页组合 | S2 | P0 |
| STORY-005-01-02-03 | mall-web 商品搜索体验 | S5：搜索框、SearchView、三态、跳转详情 | S2、S3 | P0 |

## 4. 业务规则总纲

- [数据边界] mall-search 只提供读接口（+CHG-0021 的内部写投影接口）；不提供任何修改 Product/SKU/Brand/Category 的能力；不直连 mall_product 库；搜索结果不返回 Product 聚合。
- [可售过滤] 查询硬条件 status=ON_SALE；任何排序/筛选下下架商品都不出现。
- [金额] 价格字段 minPrice/maxPrice 为整数分 long（ES long）；入参价格区间以元为单位时前端转换，API 入参直接收整数分（与既有商品列表契约口径一致，design 定稿）。
- [分页] page 从 1 起；size 默认 20、上限 100；响应含 total/page/size/items，形状与既有分页响应一致。
- [排序枚举] 全平台唯一：default / price_asc / price_desc / newest；非法 sort 参数回退 default（不报错）。
- [游客可访问] `/api/mall/search/**` 网关 permitAll；不返回任何会员专属信息；`/api/internal/**` 继续 denyAll。
- [异常] ES 连接失败/超时/索引不存在 → 统一 B05xx（SEARCH_UNAVAILABLE）+ 可定位日志；不向上抛出 ES 原生堆栈；空结果 = 200 + items=[]。
- [降级] M5 不提供降级搜索：搜索故障时 mall-web 展示 Error 态并保留分类浏览入口；禁止在 mall-search 直查商品库实现降级。

## 5. 全局验收标准

| ID | 验收标准（可测试） | 覆盖 Story |
| --- | --- | --- |
| AC-001 | docker-compose up 后 Elasticsearch 健康检查通过；mall-search 启动日志显示 ES 连通成功，健康检查端点 UP | STORY-005-01-01-01 |
| AC-002 | mall-search 存在官方 elasticsearch-java 依赖（版本由 mall-bom/Spring Boot BOM 管理），无废弃 RestHighLevelClient | STORY-005-01-01-01 |
| AC-003 | Testcontainers ES 集成测试可运行：建临时索引/写样例文档/检索通过 | STORY-005-01-01-01 |
| AC-004 | ES 不可用/查询超时/索引不存在 → 返回统一错误码 B05xx（SEARCH_UNAVAILABLE）与友好文案，响应体为 UnifyResult 错误结构，无 ES 原生堆栈泄漏 | STORY-005-01-01-02 |
| AC-005 | 无命中时返回 200 + 空 items 分页（不是错误） | STORY-005-01-01-02 |
| AC-006 | 关键词命中 productName/keywords/brandName/categoryName 任一字段即可检索到（如"机械键盘"命中名称） | STORY-005-01-02-01 |
| AC-007 | 结果仅含 ON_SALE 商品；下架商品在任何查询下均不出现 | STORY-005-01-02-01 |
| AC-008 | 结果项仅含 productId/name/image/priceFen/brandName/categoryName 等搜索摘要字段，不含 SKU 列表/聚合全字段 | STORY-005-01-02-01 |
| AC-009 | 分页参数生效（page/size 正确切片，total 准确）；size>100 被限制为 100；响应为统一分页结构 | STORY-005-01-02-01 |
| AC-010 | 网关：游客经 8080 可访问 GET /api/mall/search/products；未携带 token 不返回 401；/api/internal/** 经网关 404 | STORY-005-01-02-01 |
| AC-011 | categoryId 过滤仅返回该分类商品；brandId 过滤仅返回该品牌商品；minPrice/maxPrice 按整数分闭区间过滤 | STORY-005-01-02-02 |
| AC-012 | 关键词+品牌+价格区间组合查询结果同时满足全部条件 | STORY-005-01-02-02 |
| AC-013 | sort=price_asc/price_desc 价格严格升降；newest 按发布时间倒序；default 稳定排序；非法 sort 回退 default | STORY-005-01-02-02 |
| AC-014 | mall-web 顶部搜索框输入关键词回车 → 进入 /search 结果页并回显关键词，展示结果卡片（图/名/价/品牌） | STORY-005-01-02-03 |
| AC-015 | 结果页可使用分类/品牌/价格筛选与四种排序、分页，URL query 与页面状态一致，刷新保持 | STORY-005-01-02-03 |
| AC-016 | 空结果/加载中/搜索失败三态有明确 UI；失败态提供"返回首页/分类浏览"出口 | STORY-005-01-02-03 |
| AC-017 | 点击结果卡片进入既有商品详情页（mall-product 提供），数据正常展示 | STORY-005-01-02-03 |
| AC-018 | mall-web type-check/lint/test/build 全部通过 | STORY-005-01-02-03 |

## 6. 业务规则补充

- 搜索读索引别名（由 CHG-0021 建立 `mall_products` 别名）；本 Change 查询一律对别名查询，别名/索引不存在时按 AC-004 返回搜索不可用。
- 关键词最小长度：空白关键词等同不带关键词（返回按 default 排序的上架商品，与"搜索页浏览"一致）；单字符也可查询（不强制最小长度）。
- 价格区间边界：minPrice/maxPrice 均为闭区间；min>max → 返回 400 参数错误。

## 7. 成功指标

- 功能指标：M5 Integration Gate 场景一（关键词搜索/筛选/排序/分页/下架不可见）E2E 通过；场景五（ES 故障）错误口径符合预期。
- 性能指标（本地开发环境，记录但不作为发布门槛）：万级文档下关键词查询 P95 < 300ms；本期不建设压测体系。
- 质量指标：mall-search 单元 + Testcontainers 集成测试全绿；mall-web 搜索页测试全绿；不出现跨服务数据库访问（架构评审 0 违规）。
