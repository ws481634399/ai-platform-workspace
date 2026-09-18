# Exploration（需求探索报告）

> 阶段：sdd-explore 产物
> 业界锚点：Discovery（Problem → Evidence → Conflict → Recommendation）
> 输入：requirement.md（原文沉淀；本文件不复述原文，只做改写分析）
> 产出状态：exploring（推进 Change 状态）

## 1. 需求要点

- 做什么：在 mall-product（权威数据）与 Elasticsearch（Search Projection）之间建立**完整的索引同步能力**——代码化索引 Mapping/Settings 生命周期（Create/Rebuild/Delete-Replace）、首次全量 Bulk 构建、商品新增/修改/上架/下架/价格变更增量同步、同步幂等、乱序防护、Sync Failure Record + 有界重试、后台手工重建、基础一致性检查；mall-product 需新增"分页投影读取"内部端点。
- 给谁：系统自身（mall-search 消费 Product 变更）、运维/管理员（手工重建、状态与失败可观测）；最终受益人是商城搜索用户（CHG-0020 搜索结果的新鲜度）。
- 解决什么问题：保证 ES 投影长期可用、可恢复、与 Product DB 最终一致——"搜得到、搜得准、改了能同步、挂了能重建"。
- 核心语义（需求硬约束）：
  1. **单向投影**：Product DB → ES，mall-search 永不反向写商品数据、不直连 mall_product 库；
  2. **搜索价 ≠ 成交价**：minPrice/maxPrice 仅列表摘要，订单仍实时取 mall-product 价格（M4 已如此实现），索引价格滞后不影响交易正确性；
  3. **下架不可见**：下架后文档删除或标记不可搜索，且不能"长期"残留——决定同步时效要求（M5 同步/事件触发为准实时，无 MQ 时接受秒级）；
  4. **失败不丢**：ES 故障时同步失败必须落记录、可重试，禁止 log-and-forget；
  5. **M5 不提前做 M7**：只用同步调用 / Spring 应用事件 / 后台任务，不引入 RocketMQ/Outbox/DLQ。
- 隐含需求（设计必须回答）：
  - **同步触发架构（M5 方案选型）**：三种候选——(a) mall-product 业务操作后经 Spring 应用事件 + RestClient 同步调用 mall-search 内部写端点；(b) mall-search 定时/触发式调 mall-product 分页投影端点拉取（轮询/重建同构）；(c) 混合：上架/改价等关键路径同步推送（失败落 mall-search 侧失败记录）+ 定时补偿拉取。建议 (c)：关键变更实时性靠同步推送（product 侧事件监听，调用失败不阻断商品主流程——投影失败不能让商品上架事务回滚），最终一致靠失败重试 + 低频对账；Design 定稿；
  - **下架策略**：Delete Document vs status=OFF_SALE 过滤。建议 **硬删除**：查询侧无需 status 兜底（CHG-0020 查询仍保留 ON_SALE 过滤作双保险），索引不积累垃圾文档；重建以 ON_SALE 商品为全集，天然一致；
  - **乱序防护**：Search Document 携带 updatedAt（毫秒）与 version（商品侧已有版本字段则直接用，否则用 updatedAt）；mall-search 写入用 ES `version_type=external`（external_gte）或写入前比较 updatedAt，旧事件到达不覆盖新文档；
  - **幂等**：Bulk/index 天然以 productId 为 docId 覆盖写；同一 Published 事件重复 → 文档内容一致；删除幂等（不存在视为成功）；
  - **全量/重建方案**：双索引 + alias 切换（products-v1 / reindex 临时索引 → bulk → refresh → alias 原子切换）满足"可重复执行、构建中旧索引继续服务、切换后新结果正确"；别名 `mall_products` 作为 CHG-0020 查询入口；原地 reindex 为备选；
  - **失败记录模型**：`search_sync_failure_record`（mall_search 库，Flyway）：productId/eventType/payload 摘要/status(PENDING/SUCCESS/FAILED_DEAD)/retryCount/maxRetries/lastError/nextRetryAt/createdAt/updatedAt——直接复用 CHG-0019 CompensationTask 有界退避模式（30s/1m/2m/5m/10m，上限 5 次），@Scheduled 单实例；提供内部/admin 手工重试；
  - **批量同步**：Bulk API 分批（如 500/批）；全量构建分页读取 mall-product 投影端点（游标/页码+稳定排序），防止深分页；
  - **一致性检查**：上架商品总数 vs ES count（index 仅含上架文档）+ 按 productId 抽样/全量差集检查；admin/内部端点返回报告（missing/extra/count），不建数据治理平台；
  - **mall-product 变更触点盘点**：商品创建/更新（SPU 基本信息）、上下架（CHG-0012 已有领域事件语义基础）、SKU 增改/价格调整（CHG-0011）——需确认现有代码是否已有 Spring ApplicationEvent 发布点，没有则在对应 Service 事务提交后（@TransactionalEventListener(AFTER_COMMIT)）补发；
  - **价格摘要来源**：minPrice/maxPrice = 启用 SKU salePriceInCents 极值（与商城列表 STORY-003-02-02-01 既有口径一致：无有效 SKU 商品不展示）；
  - **权限**：重建/一致性检查属后台高敏操作，挂 `/api/admin/search/**`（或内部端点 + admin 包装），RBAC 新增权限码（建议 search:index:rebuild / search:index:check，经菜单/权限 SQL 初始化，沿用 CHG-0019 order 权限种子模式）；mall-gateway 新增 8107 admin 路由。

知识检索结果（引用来源）：

- M5.md 全文：REQ-M5-002 十五章 + 13 条验收、Integration Gate 场景二（商品修改）/三（下架）/四（价格变化）/五（ES 故障可恢复）、DoD REQ-M5-002 十一项与阶段验收（修改/下架/价格同步、幂等、重建、ES 异常）。
- product/08-系统与微服务架构.md：mall-search 职责含"索引管理"，存储 Elasticsearch；mall-product 为商品权威数据。
- product/03-领域事件风暴.md / 06-聚合与领域模型设计.md：商品上下架领域事件语义（CHG-0012 已交付发布/下架领域行为），作为 M5 应用事件触点依据。
- standards/engineering/backend/database-access-standard.md §7.2：跨服务最终一致、禁止跨库强依赖——同步走 Internal API。
- 代码调研结论（本 Change explore 实测）：
  - mall-product `InternalProductController`：仅有 `GET /{productId}/skus/{skuId}`、`GET /skus/{skuId}`、`POST /skus/batch` 三个内部端点，**缺"分页枚举上架商品（含名称/分类/品牌/主图/价格摘要/updatedAt）"投影端点**，本 Change 新增（SERVICE 身份，X-Internal-Token）；
  - mall-search：空骨架 + mall_search MySQL 数据源已配（flyway 默认关闭），失败记录表从本 Change 开始建 V1 migration；
  - mall-product 商品写路径：SPU/SKU admin Controller + 上下架服务（CHG-0011/0012），事件发布现状需 design 阶段逐触点确认；
  - CHG-0019 已在 mall-order 落地 compensation_task + 指数退避调度 + 人工重试端点同构模式，可直接参照；
  - mall-gateway：无 8107 路由（CHG-0020 补 mall 搜索路由，本 Change 补 admin 搜索运维路由）。
- 历史 Change：CHG-0011（SKU/价格写路径）、CHG-0012（上下架领域行为）是增量同步的触点来源；CHG-0020（REQ-M5-001）提供 SearchDocument 读模型与 ES 连接，是本 Change 前置；CHG-0019（补偿/重试范式）直接复用设计经验。

## 2. Story 归属判定

- Feature ID: FEAT-005；本 Change 归属 L2 **FEAT-005-02 搜索索引同步**。
- Story 节点（feature-tree.yaml 已新建，本 Change 含 4 个，均为 planned）：
  - STORY-005-02-01-01 **索引 Mapping 管理与首次全量构建**（L3 FEAT-005-02-01 索引生命周期与全量构建；本 Change 锚点 Story）：Mapping/Settings 代码化（随应用启动/管理端点 Create，缺索引可引导）、别名方案、SearchDocument 组装（minPrice/maxPrice 口径）、mall-product 分页投影端点、分批 Bulk 全量构建与执行记录；
  - STORY-005-02-01-02 **手工重建与索引一致性检查**：admin/运维触发 Rebuild（双索引+别名切换）、可重复/有状态/可发现失败、数量差集检查报告、权限码与网关路由；
  - STORY-005-02-02-01 **商品变更增量同步**（L3 FEAT-005-02-02 增量同步与可靠性）：商品创建/更新/上架/下架/价格变更的事件触点（AFTER_COMMIT）→ 内部同步端点；单条+批量；上架 upsert、下架硬删除、价格摘要刷新；主流程不被投影失败阻断；
  - STORY-005-02-02-02 **同步幂等乱序防护与失败重试**：docId=productId 覆盖幂等、external version/updatedAt 比较、search_sync_failure_record 落表、有界退避调度与人工重试、可观测日志（traceId/productId/eventType）。
- 是否新建 candidate: 否。
- Feature 路径: 商品搜索 → 搜索索引同步 → 索引生命周期与全量构建/增量同步与可靠性 → 对应 Story。
- Integration Gate 场景二/三/四/五不单独建 Story，作为 change 级 test-design/converge 验收场景（与 CHG-0020 联合执行）。

## 3. 证据评估

- 业务依据：M5.md REQ-M5-002 13 条验收 + 4 个 Integration Gate 场景，生命周期/幂等/乱序/失败/重建/检查六类行为均有明确判定。
- 领域依据：Product 权威边界、上下架领域事件（M2）、整数分价格口径（M2/M3）、状态模型清晰；mall_search 独立库已预建。
- 工程依据：CHG-0019 compensation_task 提供失败记录+退避调度+人工重试的现成范式；ES Bulk/index/alias API 成熟；官方 Java Client 支持 external versioning；mall-product 数据量（本地/初期）分页全量无压力。
- 结论: **充分**。触点代码级盘点（哪些 Service 已有事件）留待 design 阶段逐点核实，属实现细节调查而非证据缺口。

## 4. 冲突点检测

- 与 specs/standards 冲突: 无。同步方式（同步调用/应用事件/后台任务）符合需求第十三章对 M5 的授权，也符合 database-access-standard 最终一致原则。
- 与既有 Change 重叠或沿用:
  - Mapping/查询字段集与 CHG-0020（REQ-M5-001）存在天然耦合：SearchDocument 模型由两 Change 共享——归属上放在 CHG-0021 代码化建索引，CHG-0020 只读消费；PRD 阶段两 Change 共同确认字段契约，避免各写一套；
  - mall-product 新增内部投影端点是对 CHG-0012 服务的增量（只加读端点，不改商品领域行为），DU 上标注 mall-product 仓内改动；
  - 失败重试不新建通用补偿平台，沿用 CHG-0019 的表+调度模式但表独立（search_sync_failure_record 归 mall_search 库），不与 order compensation_task 共表；
  - 与 M7 边界：应用事件/同步调用是临时方案，代码结构需为 M7 替换为 MQ 订阅留口（同步器接口化，触发机制可替换），但本期不写 MQ 代码。
- 与已规划 Story 重复: 无（FEAT-005-02 全新）。
- 处理决策:
  - 1 个 REQ 拆 4 个 Story：生命周期（建+灌）与运维能力（重建+检查）读写性质不同拆 2 个；增量链路与可靠性（幂等/乱序/重试）验收点不同拆 2 个；
  - 下架采用硬删除（需求授权二选一）；价格只刷摘要不回写订单链路；索引只含 ON_SALE 商品（草稿/下架不进索引）。

## 5. 待澄清问题

- 建议 PRD/Design 直接定稿（需求已授权 Design 决策）：
  1. 触发机制：关键路径 AFTER_COMMIT 同步推送 + 失败记录 + 定时补偿拉取（混合方案）；同步调用超时/失败不回滚商品主事务；
  2. 索引方案：别名 `mall_products` + 版本化物理索引（mall_products_v1），重建走临时索引 bulk 后原子切别名；查询（CHG-0020）一律对别名查询；
  3. docId=productId（字符串）；乱序防护用 updatedAt 毫秒 external_gte（商品侧无递增 version 时以 updatedAt 为准，同戳事件内容等价）；
  4. 下架硬删除；删除幂等（not_found 当成功）；
  5. 失败记录字段/退避策略照搬 CHG-0019（30s 起、最多 5 次、FAILED_DEAD 人工介入）；
  6. mall-product 投影端点：`GET /api/internal/products/search-projection?page&size&updatedAfter?`（SERVICE 鉴权），返回全量构建所需字段与价格摘要；具体契约 design 定；
  7. 后台权限码 search:index:rebuild、search:index:list（执行状态/检查结果查看），经 identity V? 权限种子 SQL + 菜单初始化；
  8. 批量大小 500/批，全量分页稳定排序（productId 游标式，避免大偏移）。
- 需在 design 阶段调查但不阻断：mall-product 四个写触点（创建/更新/上下架/SKU 价格）现有事务与事件代码结构，决定 @TransactionalEventListener 挂载点。
