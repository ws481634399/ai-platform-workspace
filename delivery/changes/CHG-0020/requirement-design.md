---
affected-repositories: [repo-4, repo-1, repo-2]
---

# Requirement Design（需求级方案设计）

> 层级：Requirement 级产物——本次 Change 的技术方案骨架
> 业界锚点：ADR（Context → Decision → Alternatives → Consequences）+ 跨仓影响面
> 输入：requirement-spec.md + exploration.md + CHG-0012/0017 已交付契约
> 产出状态：designed
> 分层关系：本文是 Requirement 级；各 Story 详细设计见 Story 目录 story-design.md。

## 0. 元信息

- Change ID: CHG-0020
- spec 来源: CHG-0020/requirement-spec.md（REQ-M5-001 Elasticsearch 商品搜索）
- 相关仓库: repo-4（ai-platform-infrastructure）、repo-1（ai-platform-backend）、repo-2（ai-platform-frontend）
- 受影响仓库数: 3
- 需要 Migration: no（本 Change 无业务表；mall_search 库既有，Flyway 表在 CHG-0021 V1）

## 1. 当前状态

- repo-4 `deploy/docker-compose.infra.yml`：mysql 8.2/redis 7.4/nacos 3.0.3/minio 四服务 + ai-platform 网络 + 命名卷；**无 Elasticsearch**；`.env.example` 已管理端口/密码变量。
- repo-1 `mall-services/mall-search`（8107，mall_search 库）：仅 MallSearchApplication + ContextLoadsTest + application.yml（MySQL 数据源占位、flyway enabled=false）+ 空 migration；pom 含 common-web/log/security?（仅 common-web/common-log/mybatis-plus/flyway/mysql/nacos/common-test），**无 ES 依赖、无分层包、无安全配置类**。
- mall-bom：Spring Boot 3.5.x BOM 已导入（其 dependency management 已包含 co.elastic.clients:elasticsearch-java 与 elasticsearch-rest-client 8.17.x 版本管理），无需在 bom 手写 ES 版本。
- mall-gateway：路径式路由 yml + GatewaySecurityConfiguration（MEMBER/ADMIN/permitAll/denyAll 规则）；无 8107 路由；`/api/internal/**` denyAll。
- mall-product 商城列表（CHG-0017）已验证筛选/排序口径与 ProductListView 卡片样式，mall-web 可复用分类树 API 与商品卡片组件。
- 本地 Docker 29.4 可用（Testcontainers 前提具备）。

## 2. 提议方案

### 2.0 总体链路

```
GUEST/MEMBER → mall-gateway(/api/mall/search/**, permitAll) → mall-search:8107
   → ElasticsearchClient(别名 mall_products) → SearchProductDTO(UnifyResult 分页)
mall-web: 顶部搜索框 → /search?keyword=&categoryId=&brandId=&minPriceFen=&maxPriceFen=&sort=&page=
ES 由 repo-4 compose 提供；索引导入/同步在 CHG-0021，本 Change 对别名查询，别名缺失=搜索不可用
```

### 2.1 mall-search 分层（DDD 同构既有服务）

```
com.ai.mall.search
├── MallSearchApplication（@MapperScan 预留；@EnableScheduling CHG-0021 用）
├── domain/search/
│   ├── SearchProductDocument.java      # 索引读模型（与 CHG-0021 写模型同字段集，本 Change 只读消费）
│   ├── SearchQuery.java                # keyword/categoryId/brandId/min/max/sort/page/size 值对象 + 规范化
│   ├── SearchSort.java                 # DEFAULT/PRICE_ASC/PRICE_DESC/NEWEST + from(String) 安全回退
│   ├── SearchProductSummary.java       # 精简结果 record（productId/name/imageUrl/priceFen/brandName/categoryName）
│   ├── SearchPage.java                 # items/total/page/size
│   ├── SearchRepository.java           # 端口
│   └── SearchErrorCode.java            # B0501 SEARCH_UNAVAILABLE / B0502 SEARCH_BAD_REQUEST
├── application/search/SearchApplicationService.java
├── infrastructure/
│   ├── elasticsearch/
│   │   ├── ElasticsearchConfiguration.java  # RestClient+JsonpMapper+ElasticsearchClient Bean
│     ├── ├── SearchIndexProperties.java     # mall.search.index-alias=mall_products、超时、uris
│   │   └── ElasticsearchSearchRepository.java
│   ├── config/SearchSecurityConfiguration.java  # permitAll /api/mall/search/**
│   └── health/ElasticsearchHealthIndicator.java
└── interfaces/rest/mall/
    ├── MallSearchController.java       # GET /api/mall/search/products
    └── dto/SearchDtos.java             # 请求参数 record + SearchProductView
```

- ES Client：官方 `co.elastic.clients:elasticsearch-java` + `elasticsearch-rest-client` + `jackson.json.databind`（JsonpMapper），版本均继承 Spring Boot BOM。
- 查询构造：bool 查询——filter 必含 term status=ON_SALE；keyword 非空时 must multi_match（productName^3, keywords, brandName, categoryName，operator or）；categoryId/brandId term filter；价格 range（minPriceFen ≤ doc.minPrice? 语义见 §2.3）。
- 排序：DEFAULT = _score desc + updatedAt desc；PRICE_ASC = minPrice asc；PRICE_DESC = maxPrice desc；NEWEST = publishedAt desc, updatedAt desc；from=0/size。
- 异常：ES 客户端异常（ElasticsearchException/TransportException 及原因链中的 Connect/SocketTimeout、ResponseException 404 index_not_found）由 SearchExceptionAdvice 归一 B0501/503；参数非法（min>max）B0502/400；空结果正常 200。
- 健康检查：自定义 HealthIndicator 调 client.ping；不因此影响进程存活。

### 2.2 SearchDocument 字段集（与 CHG-0021 契约冻结）

| ES 字段 | Java 类型 | mapping | 说明 |
| --- | --- | --- | --- |
| productId | long/string | keyword(docId) | _id=productId 字符串，term 可用 |
| productName | String | text(standard) + keyword 子字段 | 主检索，boost 3 |
| keywords | String | text | 可空，商品检索关键词（M5 可空串） |
| categoryId | Long | long | 精确过滤 |
| categoryName | String | text+keyword | 检索/展示 |
| brandId | Long | long | 精确过滤 |
| brandName | String | text+keyword | 检索/展示 |
| mainImage | String | keyword/index:false | 展示 |
| status | String | keyword | ON_SALE 硬过滤 |
| minPrice | long | long | 整数分；price_asc 排序；range |
| maxPrice | long | long | 整数分；price_desc 排序；range |
| publishedAt | date | date(epoch_millis/严格) | newest |
| updatedAt | date | date | 默认排序/版本（CHG-0021 external version 用毫秒） |

价格区间语义（冻结）：商品命中条件为 `minPrice <= maxPriceFen AND maxPrice >= minPriceFen`（区间相交），单侧只传一边。

### 2.3 网关与安全

- yml 新增路由 id mall-search-mall：Path=/api/mall/search/** → uri http://localhost:8107（与其他服务直连风格一致）。
- SearchSecurityConfiguration：/api/mall/search/** permitAll（资源服务器过滤链中公开）；其余默认认证；本 Change 无 internal/admin 端点（CHG-0021 增加）。
- 不返回任何会员/写能力；Controller 无身份依赖。

### 2.4 mall-web

- api/search.ts（SearchQuery/SearchProductView/PageResult 类型）、stores/search.ts（state: items/total/page/size/loading/error/keyword；action 按 query 请求，错误进入 error 态）。
- 布局组件加搜索框（Header/顶部导航，回车与按钮 → router.push({path:'/search', query})）。
- views/search/SearchView.vue：挂载与 query 变化均触发查询（watch route.query）；筛选区（分类用既有分类树接口渲染 select、品牌 select M5 先支持 brandId 输入隐藏域?——决策：品牌筛选提供文本输入 brandId（数字）+ 从首页品牌卡片跳转携带 brandId；价格两个输入框元→分）；排序条四个单选项；分页组件复用；三态；卡片点击 /product/:id。
- 公开开关 search.enabled 隐藏入口的接线在 CHG-0022；本 Story 搜索入口无条件渲染（默认值即展示）。

### 2.5 测试基线

- 单测：SearchQuery 规范化（分页/排序回退/min>max）、ES QueryBuilder 断言（bool 子句、排序值）——抽出 SearchRequestBuilder 纯 Java 可单测。
- 集成：AbstractElasticsearchIntegrationTest（Testcontainers `docker.elastic.co/elasticsearch/elasticsearch:8.17.x`，单节点、withSecurityDisabled）；测试内创建临时索引（直接 apply 本 Change 定义的 mapping JSON 常量，作为 CHG-0021 代码化 Mapping 的同源预览——Mapping 常量类放 mall-search 公共位置，CHG-0021 复用）；写样例文档→关键词/筛选/排序/分页/空结果/停服异常用例。
- Web 层：不依赖 ES 的参数错误用例（MockMvc + mock service）。
- ContextLoads 冒烟：ES 连接懒处理——ElasticsearchClient 不在启动期强连（仅 ping 健康检查），保证无 ES 时上下文测试仍可加载（Testcontainers 用例自带容器）。

## 2.1 备选方案对比（Alternatives Considered）

| 决策 | 采纳 | 备选与理由 |
| --- | --- | --- |
| ES 客户端 | 官方 elasticsearch-java（BOM 管版本） | Spring Data Elasticsearch：仓储魔法与项目显式 Repository/DDD 风格不一致；RestHighLevelClient 已废弃 |
| 中文分词 | ES 内置 standard + 多字段 match | IK 插件：需定制镜像/插件安装，M5 验收"名称可搜到"内置分词即可；列为后续增强 |
| 故障降级 | 不做 DB 降级，统一 B0501 + 前端 Error 态 | 降级需复刻筛选口径且有双状态一致性风险；mall-search 直查库违规；后续可经 product 公开列表 API 做受控降级 |
| 索引/别名 | 查询走别名 mall_products（CHG-0021 建） | 直写物理索引名会导致重建期中断；别名是重建切换的前提 |
| 品牌筛选交互 | brandId 精确参数（首页品牌卡/URL 携带） | M5 不做品牌联想/facet，避免范围蔓延 |
| ES 部署 | compose 单节点、安全关闭、内网 | 生产 TLS/鉴权方案后续里程碑；本地以最小可用为准 |

## 3. 仓库影响（Repository Impact）

### 3.1 repo-4（ai-platform-infrastructure）

- 技术职责：提供 Elasticsearch 8.17.x 单节点运行时。
- 修改概要：docker-compose.infra.yml 新增 elasticsearch 服务（image docker.elastic.co/elasticsearch/elasticsearch:8.17.x；environment discovery.type=single-node、xpack.security.enabled=false、ES_JAVA_OPTS=-Xms512m -Xmx512m；ulimits memlock；healthcheck curl http://localhost:9200/_cluster/health?wait_for_status=yellow；9200 端口经 .env 变量；volumes ai-platform-es-data:/usr/share/elasticsearch/data；networks ai-platform）；.env.example 补 ES_PORT。
- 涉及模块：deploy/。

### 3.2 repo-1（ai-platform-backend）

- 技术职责：mall-search ES 接入与查询 API、网关路由。
- 修改概要：mall-search pom 增 ES 依赖；新增分层包（§2.1）；application.yml 增 mall.elasticsearch.uris/超时/别名配置；mall-gateway yml + 安全规则增搜索公开路由。
- 涉及模块：mall-services/mall-search、mall-gateway；mall-bom 不改（版本继承 Boot BOM，若实际 BOM 未管理再补 property，dev 阶段验证）。

### 3.3 repo-2（ai-platform-frontend）

- 技术职责：mall-web 搜索入口与结果页。
- 修改概要：mall-web 新增 api/search.ts、stores/search.ts、views/search/SearchView.vue、布局搜索框、路由 /search。
- 涉及模块：mall-web/src。

## 4. 跨仓协作

- API Contract：浏览器 → gateway 8080 `GET /api/mall/search/products?keyword&categoryId&brandId&minPriceFen&maxPriceFen&sort&page&size` → 8107；出参 UnifyResult<SearchPage>；错误 B0501/503、B0502/400；版本策略：URL 无版本前缀（与既有 API 一致）。
- Data Contract：ES 索引文档结构（§2.2）是与 CHG-0021 的冻结契约；mall-search 只读；Product 权威在 mall-product。
- Repository Dependencies：repo-4 ES 先行 → repo-1 查询能力 → repo-2 页面；与 CHG-0021 的联调在 CHG-0021 dev 完成后（Integration Gate）。
- Integration Boundary：9200 仅内网/本机；服务间不经过 ES 互通；网关公开路由。
- Cross-Repository Sequence：compose up → mall-search 启动（别名不存在不阻断）→ CHG-0021 建索引灌数据 → 搜索可用。

## 5. Story 设计分派（Story Design Assignments）

| Story ID | domain（L3） | 技术要点 | 仓库 |
| -------- | ------------ | -------- | ---- |
| STORY-005-01-01-01 建立 mall-search 与 Elasticsearch 基础环境 | FEAT-005-01-01 搜索服务基础 | compose ES（WS-501）；ES Client Bean/配置/健康检查/Testcontainers 基类（BE-501 第一部分） | repo-4、repo-1 |
| STORY-005-01-01-02 搜索异常响应与降级 | FEAT-005-01-01 搜索服务基础 | 异常归一 Advice/错误码/可定位日志/空结果语义（BE-501 第二部分） | repo-1 |
| STORY-005-01-02-01 商品关键词搜索 | FEAT-005-01-02 关键词搜索与筛选 | SearchRequestBuilder 多字段+ON_SALE、分页、SearchDTO、Controller、网关公开路由（BE-502） | repo-1 |
| STORY-005-01-02-02 搜索筛选与排序 | FEAT-005-01-02 关键词搜索与筛选 | bool filter 组合、range 相交语义、四种排序、参数校验（BE-502 增量，同 DU 迭代） | repo-1 |
| STORY-005-01-02-03 mall-web 商品搜索体验 | FEAT-005-01-02 关键词搜索与筛选 | 搜索框/SearchView/筛选排序分页/三态/跳详情（FE-501） | repo-2 |

## 6. DU 划分总览（跨 Story 依赖）

| DU id | repository | goal | 关联 Story | depends on |
| ----- | ---------- | ---- | ---------- | ---------- |
| DU-WS-501 | repo-4 | compose Elasticsearch 服务/卷/健康检查/.env | STORY-005-01-01-01 | — |
| DU-BE-501 | repo-1 | ES Client 接入 + 健康检查 + Testcontainers 基线 | STORY-005-01-01-01 | DU-WS-501 |
| DU-BE-510 | repo-1 | B0501/B0502 错误码与异常归一 Advice、空结果语义 | STORY-005-01-01-02 | 无（实际前置 DU-BE-501） |
| DU-BE-502 | repo-1 | 关键词查询/分页/SearchDTO/网关路由 | STORY-005-01-02-01 | 无（实际前置 DU-BE-501/510） |
| DU-BE-511 | repo-1 | 三维过滤/价格区间相交/四排序/参数校验 | STORY-005-01-02-02 | 无（同模块增量，实际随 BE-502 发布） |
| DU-FE-501 | repo-2 | mall-web 搜索框与 SearchView 全态 | STORY-005-01-02-03 | 无（实际前置 BE-502/511 契约） |

## 7. 数据变更

- 无（本 Change 不建表；ES Mapping 由测试夹具与 CHG-0021 代码化管理；Mapping JSON 常量在本 Change 落于 mall-search 资源供测试与 CHG-0021 复用）。

## 8. 风险

| 风险项 | 级别 | 缓解措施 |
| --- | --- | --- |
| Spring Boot BOM 未管理 ES client 版本 | 低 | dev 首步验证 dependency:tree；缺则在 mall-bom 补 elasticsearch.version property 对齐 8.17.x |
| Testcontainers ES 内存/启动慢 | 中 | 固定 8.17.x 镜像、JVM 堆 512m、测试基类共享容器（static singleton） |
| ES 未启动时本地误报故障 | 低 | 启动不强连；健康检查 DOWN 不影响进程；README/启动脚本注明 up 顺序 |
| 与 CHG-0021 字段漂移 | 中 | §2.2 字段表冻结；Mapping 常量单一来源两 Change 共用 |
| 中文分词效果争议 | 低 | M5 以验收用例（机械键盘等）实测；不足则后续加 IK，不阻断 |

## 9. 待澄清问题

- 无阻断项；§2.1 决策（ES 版本 8.17.x、不做降级、分词、别名、错误码）在本设计定稿。
