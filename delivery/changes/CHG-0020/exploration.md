# Exploration（需求探索报告）

> 阶段：sdd-explore 产物
> 业界锚点：Discovery（Problem → Evidence → Conflict → Recommendation）
> 输入：requirement.md（原文沉淀；本文件不复述原文，只做分析）
> 产出状态：exploring（推进 Change 状态）

## 1. 需求要点

- 做什么：把商城商品检索从 mall-product 的数据库分页筛选**升级为独立的 Elasticsearch 搜索链路**——repo-4 新增 Elasticsearch 基础设施，mall-search（8107，当前空骨架）接入 ES 并交付关键词检索、分类/品牌/价格组合筛选、四种排序、标准分页、Search DTO 读模型、明确异常响应，mall-web 新增搜索框与搜索结果页（筛选/排序/分页/空态/Loading/Error，点击进既有详情页）。
- 给谁：商城用户（GUEST/MEMBER 均可搜索，游客可访问）；后续 AI 商品检索也复用该投影（M6，不在本 Change）。
- 解决什么问题：M2 已建立商品权威数据，但数据量大时数据库 LIKE/筛选无法支撑高性能检索；M5 形成 `Product → Search Index → Elasticsearch → 商城搜索` 能力链。
- 四条必须守住的边界（需求原文反复强调）：
  1. **Product DB 是唯一 Source of Truth，ES 只是 Search Projection**：mall-search 不得提供任何修改 Product/SKU/Brand/Category 业务状态的能力，不直连 mall_product 库；
  2. **搜索返回 Search DTO，不返回 Product Aggregate**：只给结果页所需 productId/name/image/price/brand/category；
  3. **搜索不承担详情与交易**：详情仍走 mall-product；索引只可有货/缺货弱实时展示，可售库存与成交价仍分别以 mall-inventory、mall-product 实时查询为准（下单重校验在 M4 已落地，搜索不改变该链路）；
  4. **下架商品不得出现在正常搜索结果**：status 过滤是查询硬条件。
- 隐含需求（设计必须回答）：
  - **Elasticsearch 选型与版本**：docker-compose 新增单节点 ES（本地开发），版本需与 Spring Boot 3.5.x 官方 ES Java Client 兼容矩阵对齐（8.x，禁用默认 HTTP 压缩外的安全复杂度：单节点、内网、无安全认证或基础认证由 Design 定稿），含健康检查与数据卷；
  - **Client 选型**：使用官方 `co.elastic.clients:elasticsearch-java`（不用已废弃 RestHighLevelClient），版本经 mall-bom 统一管理；
  - **Mapping 归属切分**：本 Change 的查询测试需要索引结构——Search Document 字段/Mapping 的**代码化生命周期管理（Create/Rebuild/Replace、Bulk 构建）属于 CHG-0021**；本 Change 只在测试夹具（Testcontainers）中创建临时 Mapping，并在应用层定义 SearchDocument/SearchDTO 模型；两个 Change 的设计需在 PRD 阶段对齐字段集（productId/productName/categoryId/categoryName/brandId/brandName/mainImage/keywords/status/minPrice/maxPrice/updatedAt）；
  - **中文分词**：商品名称/关键词中文检索效果依赖分词器（IK 或 ES 内置 standard），本地单节点安装 IK 增加基础设施成本；Design 需在"内置分词+ngram/前缀"与"IK 分词插件"之间决策（建议：M5 用内置 analyzer + search_phrase/多字段 bool 查询满足验收，IK 留待后续增强）；
  - **价格字段映射**：minPrice/maxPrice 沿用项目整数分 Long 约定，ES mapping 为 long（禁止 double/float 语义）；
  - **网关与鉴权**：新增 `/api/mall/search/**` → mall-search:8107 路由，参照 `/api/mall/products/**` 游客可访问策略（permitAll 公开端点）；`/api/internal/**` 继续 denyAll；
  - **异常归一**：ES 不可用/连接超时/索引不存在（index_not_found）三类底层异常统一捕获为业务错误（建议错误码段 B05xx：product B21xx、inventory B22xx、order B04xx、cart B03xx 已占用），不可透传不可理解的 500；空结果是正常业务响应（200 + 空分页），不是异常；
  - **降级决策**：需求授权 Design 决定是否做数据库降级。建议 M5 **不做** DB 降级：降级路径需重写 mall-product 列表筛选并保证"下架/状态一致性"，成本高且易产生双口径；M5 只做明确错误响应（前端 Error 态可提示"搜索暂时不可用"），降级作为后续增强；如 PRD 评审要求降级，则仅允许按 ON_SALE 条件走 mall-product 既有公开列表接口，禁止 mall-search 直查商品库；
  - **"新品排序"定义**：按商品发布时间/createdAt 倒序，字段由 CHG-0021 索引文档提供（publishedAt/createdAt）；
  - **分页约束**：页码+页签模型与项目统一分页响应一致（UnifyResult + 既有 PageResult 形态），限制最大 pageSize（如 100）防止深分页/大结果集。

知识检索结果（引用来源）：

- M5.md 全文：REQ-M5-001 十四章 + 13 条验收、Integration Gate 场景一（商品搜索）/场景五（ES 故障）、DoD REQ-M5-001 九项与阶段验收（商品搜索 E2E、Search 不成为 Product SoT、无跨服务数据库访问）。
- product/08-系统与微服务架构.md：mall-search 定位"商品检索、筛选、排序、索引管理 | Elasticsearch"，端口 8107；网关路由 `/api/mall/search/** → mall-search`、`/api/mall/public-features → mall-system`。
- product/09-数据库设计.md 既有约定：金额整数分；mall_search 库已在基础设施初始化脚本中预建。
- standards/engineering/backend/database-access-standard.md §7.2：跨服务数据一致性走事件/消息/最终一致，禁止跨服务数据库强依赖——支撑"mall-search 不直连 mall_product 库"。
- 代码调研结论（本 Change explore 实测）：
  - `mall-services/mall-search`：纯空骨架（MallSearchApplication + smoke test + application.yml 含 MySQL mall_search 数据源与 8107 端口 + 空 migration 目录），pom 仅有 mall-common-web/log/test + MyBatis-Plus/Flyway/MySQL/Nacos，**无任何 ES 依赖**；
  - repo-4 `deploy/docker-compose.infra.yml` 仅 mysql/redis/nacos/minio 四服务，**无 Elasticsearch**；MySQL 初始化脚本已含 mall_search、mall_system 库；
  - mall-gateway：无 8107/8108 路由；`/api/internal/**` 全局 denyAll；
  - mall-web：已有 HomeView、ProductListView/ProductDetailView，**无搜索结果页**；商品详情页可直接承接搜索点击跳转；
  - mall-product 商城侧已有列表筛选（分类/品牌/排序/价格区间，CHG-0017 交付）作为搜索体验与降级的参照口径。
- 历史 Change：CHG-0012/0017（商品发布、商城列表筛选）提供状态/筛选口径；CHG-0015（内部凭证/网关鉴权链）提供内部调用与网关样板；无已交付搜索能力。

## 2. Story 归属判定

- Feature ID: FEAT-005（新建 L1 业务域：商品搜索），本 Change 归属 L2 **FEAT-005-01 商品搜索查询**；FEAT-005-02 索引同步归属 CHG-0021。
- Story 节点（feature-tree.yaml 已新建，本 Change 含 5 个，均为 planned）：
  - STORY-005-01-01-01 **建立 mall-search 与 Elasticsearch 基础环境**（L3 FEAT-005-01-01 搜索服务基础）：repo-4 compose 新增 ES（单节点/健康检查/卷/网络/环境变量/.env 样例）；mall-search pom 接入官方 ES Java Client（mall-bom 管版本）、连接配置、ES 健康检查端点、Testcontainers ES 测试基线；
  - STORY-005-01-01-02 **搜索异常响应与降级**：ES 不可用/超时/索引不存在的统一异常捕获、B05xx 错误码与可定位日志（traceId）、空结果正常响应；按 Design 决策实现/不实现 DB 降级及降级口径；
  - STORY-005-01-02-01 **商品关键词搜索**（L3 FEAT-005-01-02 关键词搜索与筛选；本 Change 锚点 Story）：多字段匹配（productName/keywords/brandName/categoryName）+ status=ON_SALE 硬过滤；SearchDocument 读模型与精简 SearchDTO；标准分页；网关路由与公开访问；
  - STORY-005-01-02-02 **搜索筛选与排序**：categoryId/brandId/priceRange bool 组合过滤；默认/价格升降序/新品（发布时间倒序）排序；与分页可组合；pageSize 上限；
  - STORY-005-01-02-03 **mall-web 商品搜索体验**：全局搜索框、SearchView 结果页（关键词回显、筛选侧栏、排序控件、分页、无结果/Loading/Error 态）、点击跳转既有 ProductDetailView。
- 是否新建 candidate: 否（全部为 REQ 明确范围，已 materialize 到 feature-tree）。
- Feature 路径: 商品搜索 → 商品搜索查询 → 搜索服务基础/关键词搜索与筛选 → 对应 Story。
- Integration Gate 场景一/场景五不单独建 Story，作为 change 级 test-design/converge 验收场景，与 CHG-0021 联调执行。

## 3. 证据评估

- 业务依据：M5.md REQ-M5-001 13 条验收行为边界清晰（搜什么、怎么过滤排序、返回什么、不能做什么）；Integration Gate 两场景给出端到端判定。
- 领域依据：M2 已交付商品上下架状态（ON_SALE 口径）、分类品牌、SKU 价格整数分；M3 已交付游客可访问的商品列表/详情页面与网关公开端点放行模式。
- 工程依据：微服务同构样板充分（mall-cart/order 的 RestClient+JWT 资源服务器+Redis+Testcontainers 集成测试）；mall_search 库已预建；product/08 已预先规划端口与路由。
- 主要未知：ES 为技术栈新增组件（团队首个 ES 服务），版本/分词器/Client 配置无历史决策，需 Design 定稿——属方案选择型未知，非业务证据缺口。
- 结论: **充分**。无阻断性未知；ES 技术选型与降级取舍列入 §5，由 PRD/Design 直接定稿。

## 4. 冲突点检测

- 与 specs/standards 冲突: 无。需求边界与 database-access-standard §7.2（禁止跨服务强依赖）、architecture 微服务划分（product/08）一致。
- 与既有 Change 重叠或沿用:
  - 商品列表的数据库筛选已在 CHG-0017 交付，mall-web 商品列表页**保留**（分类浏览场景），搜索是独立入口/页面，二者不是替代关系，不改动既有 ProductListView；
  - 索引 Mapping 管理/全量构建虽在 REQ-M5-001 验收中隐含（"ES 可以正常运行/可搜索"），但需求第十四章明确"索引同步机制由 REQ-M5-002 完成"，故 Mapping 生命周期与数据灌入**划入 CHG-0021**；本 Change 仅以测试夹具建临时索引，开发联调数据依赖 CHG-0021 全量构建（建议 CHG-0021 在 CHG-0020 查询 Story 之后紧随开发，或同一迭代并行，阶段 Integration Gate 统一验收）；
  - mall-search 不消费 mall_product 库，商品数据只经 mall-product Internal API（全量读取端点在 CHG-0021 新增）。
- 与已规划 Story 重复: 无（FEAT-005 为全新分支；feature-tree 中 STORY-003-02-02-01 商城商品列表为 DB 筛选，语义不同）。
- 处理决策:
  - 1 个 REQ 拆 5 个 Story：基础设施（ES 环境+服务接入）与查询能力分离，因 repo-4/repo-1 跨仓且 ES 是新组件；异常降级独立成 Story，因其验收点（故障场景五）与正常查询完全不同；查询后端按"检索/筛选排序"与"前端体验"拆为 3 个 Story（接口能力组合递进 + mall-web 独立应用）。
  - 搜索弱库存展示字段本期不建索引文档（需求允许但非必须），避免与 mall-inventory 产生新耦合；M5 结果卡片不展示库存态，详情页已有可售状态。

## 5. 待澄清问题

- 以下决策基于需求授权（"具体由 Design 决定"）与项目既有约定，建议 PRD/Design 直接定稿，不再人工澄清：
  1. ES 版本：8.x 最新稳定版（与 Spring Boot 3.5 / 官方 Java Client 兼容），docker-compose 单节点、内网、xpack 安全简化配置；数据卷 ai-platform-es-data；
  2. Client：官方 elasticsearch-java（mall-bom 统一版本），不引入 Spring Data ES 仓储魔法（保持 DDD + 显式 Repository 风格与其他服务一致）；
  3. 中文分词：M5 使用 ES 内置 standard analyzer + bool/phrase 查询满足"名称可搜到"验收；IK 插件列为后续增强（基础设施可扩展点）；
  4. 索引文档字段集按需求第三章最小集 + 发布时间字段（新品排序需要），Mapping 细节在 CHG-0021 代码化；
  5. 降级：M5 不做数据库降级搜索，仅明确异常响应 + 前端 Error 态；
  6. 错误码段 B05xx；分页最大 pageSize=100，默认 20（或与商品列表既有默认值对齐）；
  7. `/api/mall/search/**` 网关 permitAll（游客可搜），搜索不暴露任何写接口；
  8. 价格字段一律整数分 long；搜索结果价格字段命名与 mall-web 既有商品卡片契约对齐（priceFen 等，PRD 定稿，重蹈 M3 前后端契约对齐的覆辙要在 PRD 一次性定清）。
- 需 prd 阶段与用户确认的唯一策略点：**ES 故障时 mall-web 搜索页的体验口径**（错误提示 + 是否保留分类浏览入口），不阻断开发。
