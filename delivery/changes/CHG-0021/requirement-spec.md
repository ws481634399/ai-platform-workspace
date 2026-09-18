# Requirement Spec（需求级产品规格）

> 层级：Requirement 级产物——针对本次需求/Change（多 Story 统一一份）
> 业界锚点：PRD（Problem → Goals/Metrics → Scope → Requirements → AC）
> 输入：exploration.md + requirement.md + references/M5.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0021
- Requirement: REQ-M5-002 商品搜索索引同步
- 状态流转: exploring → specified
- 主要服务: mall-search（8107：索引生命周期/同步/重建/失败记录，repo-1）、mall-product（8103：变更触达 + 内部分页投影端点，repo-1）、mall-gateway（admin 路由，repo-1）
- 前端: mall-admin（索引重建触发/状态与一致性检查入口，repo-2）
- target-user: 系统自身（Product→ES 投影同步）、ADMIN/运维（手工重建、状态与失败可观测）
- pain-points: ES 投影需要可初始化、可长期保鲜、可恢复：没有全量构建则搜索无数据；商品变更不同步则搜旧/搜到下架；ES 故障期间同步不能永久丢失；Mapping 不能靠手工 Console
- expected-value: 上架商品可被搜索、变更准实时反映、下架立即消失、价格摘要刷新；故障可追踪可重试可重建，Projection 与权威数据最终一致且边界不破裂
- scope-in: 代码化 Mapping/Settings 与别名、首次全量 Bulk 构建、mall-product 分页投影端点、商品创建/更新/上架/下架/价格变更增量同步、幂等与乱序防护、search_sync_failure_record 有界重试、手工重建、基础一致性检查、mall-admin 运维入口
- scope-out: RocketMQ/Outbox/DLQ（M7）、删除商品的索引处理（当前模型无物理删除商品，仅下架）、搜索价反向回写交易、数据治理平台、向量索引

## 1. 背景

CHG-0020 交付了查询侧（ES 环境 + mall-search 检索 + mall-web 结果页），但查询依赖一份与 Product DB 对齐的索引投影。本 Change 交付投影的"建、灌、追、补、重建、核对"六大能力。坚持 Product DB 唯一 Source of Truth：同步链路只经 mall-product Internal API 读取（禁止 mall-search 直连 mall_product 库），只向 ES 单向写入；M5 触发机制限定为 Spring 应用事件 + 同步 HTTP 调用 + @Scheduled 后台任务（单实例），同步器接口化为 M7 替换 MQ 预留。订单成交价始终实时取 mall-product，搜索 minPrice/maxPrice 仅列表摘要。

## 2. 用户价值

- 商城用户（间接受益）：搜到的都是在架商品、名称/价格与详情一致，不会点进已下架商品。
- ADMIN/运维：ES 数据丢失、Mapping 升级、环境初始化后可在后台一键重建并观察进度/结果；能发现"上架数 vs 索引数"不一致并按 productId 排查；失败任务可人工重试。
- 平台：投影链路具备幂等、防乱序、有界重试与可观测性，不因 ES 短暂故障永久丢数据，也不把 ES 故障传导回商品主交易流程。

JTBD：

- 角色：系统；场景：When 商品上架/改名/改价/下架事务提交, I want 搜索索引准实时 upsert/delete；价值：So that 搜索结果与商品权威状态最终一致。
- 角色：运维；场景：When ES 卷损坏或 Mapping 需要升级, I want 触发全量重建且期间搜索不中断、完成后结果正确；价值：So that 故障可恢复、升级可执行。
- 角色：系统；场景：When ES 短暂不可用导致同步失败, I want 失败落记录并自动有界重试、超限后可人工介入；价值：So that 没有静默丢失的变更。

## 3. 功能范围

### 3.1 包含

- [S1 Mapping 生命周期与全量构建] Mapping/Settings 代码化（随应用启动 ensureIndex 幂等创建 + 管理端点可建）；查询别名 `mall_products` + 版本化物理索引（mall_products_v1）；SearchDocument 组装（minPrice/maxPrice=启用 SKU 售价极值，仅 ON_SALE 商品入索引）；mall-product 新增 `GET /api/internal/products/search-projection` 分页投影端点（SERVICE 鉴权）；分批 Bulk（500/批，稳定排序分页）首次全量构建 + 构建记录。
- [S2 手工重建与一致性检查] POST /api/admin/search/index/rebuild 双索引（临时索引 bulk→原子切别名→清理旧索引），可重复执行、有执行状态（search_index_rebuild_task）、失败可发现；GET /api/admin/search/index/consistency-check 输出上架数 vs 索引数与按 productId 差集；权限码 search:index:rebuild/search:index:list + 网关 admin 路由；mall-admin 搜索索引运维页。
- [S3 增量同步] mall-product 在创建/更新/上架/下架/SKU 改价事务提交后（@TransactionalEventListener AFTER_COMMIT）经 SearchSyncClient 调 mall-search 内部 upsert/delete 端点；mall-search 内部端点单条/批量 upsert（ON_SALE 建/更新文档）与下架 delete（硬删除，幂等）；投影失败不阻断商品主事务；搜索价只刷摘要。
- [S4 幂等乱序与失败重试] docId=productId 覆盖写幂等；文档携带 updatedAt 毫秒，ES external version（external_gte）防旧事件覆盖新文档；ES 写入失败时 search_sync_failure_record 落库（PENDING/退避），@Scheduled 30s 扫描有界重试（30s/1m/2m/5m/10m，≤5 次→FAILED_DEAD）；内部/admin 人工重试端点；结构化日志。

### 3.2 不包含

- MQ 驱动同步、Outbox、死信队列（M7 升级；同步器接口预留替换点）。
- 分布式调度/多实例抢锁（M5 单实例）；商品物理删除；库存数量入索引；审计每条文档变更的明细历史。

### 3.3 Story 拆分总表

| Story ID | 标题 | Scope 摘要 | 依赖 | 优先级 |
| --- | --- | --- | --- | --- |
| STORY-005-02-01-01 | 索引 Mapping 管理与首次全量构建 | S1：代码化 Mapping/别名、投影端点、SearchDocument、Bulk 全量构建 | CHG-0020 STORY-005-01-01-01 | P0 |
| STORY-005-02-01-02 | 手工重建与索引一致性检查 | S2：双索引重建/任务状态/数量差集检查/权限/运维页 | S1 | P0 |
| STORY-005-02-02-01 | 商品变更增量同步 | S3：product 事件触达、内部 upsert/delete、上下架/改价同步 | S1 | P0 |
| STORY-005-02-02-02 | 同步幂等乱序防护与失败重试 | S4：external version、失败记录表、退避重试、人工重试 | S3 | P0 |

## 4. 业务规则总纲

- [权威与方向] Product DB=SoT；同步只读 product 内部端点、只写 ES；mall-search 不提供商品数据修改能力；搜索价≠成交价，订单仍实时取价。
- [入索引集合] 仅 status=ON_SALE 且至少一个 ENABLED SKU 的商品建文档；草稿/DISABLED/下架不入索引（或被删除）；minPrice/maxPrice=启用 SKU salePriceInCents 极值（整数分 long）。
- [文档身份] ES docId=productId 字符串；upsert 为覆盖写，重复事件结果幂等；下架硬删除，删除不存在文档视为成功。
- [乱序防护] 文档 updatedAt 毫秒作为 external version（external_gte）：旧版本写入被 ES 拒绝时按"已被新版本覆盖"正常消化，不报错不重试。
- [主流程保护] product 侧 AFTER_COMMIT 同步调用 best-effort：调用失败/超时只记录（由 search 侧失败记录或 product 侧 WARN 日志承载），绝不回滚商品事务。
- [失败记录] search 内部写端点尝试 ES：ES 异常→落 search_sync_failure_record 并返回 202/200 已受理（product 不阻断）；重试上限 5 次后置 FAILED_DEAD，仅人工重试可再激活。
- [重建] 重建期间查询走旧索引（别名不切换则不中断）；构建到新索引成功后原子切别名；任务可重复触发（排队/拒绝并发由 design 定：M5 同一时间只允许一个 RUNNING，重复触发返回 409）。
- [一致性检查] 上报 product ON_SALE 总数（调 product 投影 count 或分页元信息）、ES count、缺失/多余 productId 差集（M5 数据量下全量比对）。
- [权限] 重建/查状态/检查需 ADMIN + search:index:rebuild / search:index:list；内部端点需 SERVICE（X-Internal-Token），网关 denyAll。

## 5. 全局验收标准

| ID | 验收标准（可测试） | 覆盖 Story |
| --- | --- | --- |
| AC-001 | mall-search 首次启动自动幂等创建物理索引与别名；重复启动不报错、不覆盖已有 Mapping | STORY-005-02-01-01 |
| AC-002 | Mapping/Settings 存在于代码资源中（无手工 Console 步骤）；字段类型符合设计（价格 long、分词器等） | STORY-005-02-01-01 |
| AC-003 | mall-product GET /api/internal/products/search-projection 分页返回上架商品投影（含价格摘要/分类品牌名/主图/updatedAt），需 SERVICE 身份，网关不可达 | STORY-005-02-01-01 |
| AC-004 | 触发全量构建后，ES 文档数=ON_SALE 有效商品数；无有效 SKU/非上架商品不入索引；分批 Bulk 成功 | STORY-005-02-01-01 |
| AC-005 | POST /api/admin/search/index/rebuild 执行双索引重建：重建中旧搜索可用，完成后别名指向新索引，新数据可搜到、旧物理索引被清理 | STORY-005-02-01-02 |
| AC-006 | 重建任务有状态记录（RUNNING/SUCCESS/FAILED + 进度/错误）；并发重复触发返回 409/明确提示 | STORY-005-02-01-02 |
| AC-007 | 一致性检查返回上架总数、索引总数、missing/extra productId 列表；人为删文档后能报出差异 | STORY-005-02-01-02 |
| AC-008 | 重建/检查端点受 RBAC 权限码控制；mall-admin 页面可触发重建、查看状态与检查结果 | STORY-005-02-01-02 |
| AC-009 | 商品上架 → ES 出现文档可被搜到；新建商品（上架时）→ 出现 | STORY-005-02-02-01 |
| AC-010 | 商品改名/改分类品牌/换主图后 → 文档对应字段更新；SKU 改价 → minPrice/maxPrice 摘要刷新 | STORY-005-02-02-01 |
| AC-011 | 商品下架 → 文档从正常搜索消失（硬删除），下架后搜不到；订单/详情链路不读取搜索价格 | STORY-005-02-02-01 |
| AC-012 | 同步调用失败不影响商品上架/下架事务成功（投影故障不拖垮主流程） | STORY-005-02-02-01 |
| AC-013 | 同一事件重复投递两次：最终仅一份正确文档，无重复/错误数据 | STORY-005-02-02-02 |
| AC-014 | 构造 updatedAt 更小的旧事件晚到：不覆盖新文档（external version 拒绝并被正常消化） | STORY-005-02-02-02 |
| AC-015 | ES 不可用时触发同步 → search_sync_failure_record 产生 PENDING 记录；恢复后定时重试成功→SUCCESS | STORY-005-02-02-02 |
| AC-016 | 连续失败 5 次 → FAILED_DEAD 不再自动重试；人工重试端点可重新激活并最终成功 | STORY-005-02-02-02 |
| AC-017 | Integration Gate 场景二/三/四/五（改名、下架、改价、ES 故障恢复）E2E 通过；后端测试全绿 | ALL |

## 6. 补充约束

- 触发机制仅限 Spring 应用事件 + 同步 HTTP + @Scheduled；同步器以接口封装（IndexSyncPort），M7 可替换为 MQ 订阅而不改应用层。
- M5 单实例调度；失败拾取 SQL 必须带 status='PENDING' 条件为未来多实例预留。
- 索引仅含 ON_SALE 文档；重建/重试的全集口径与该规则一致，保证数量核对天然可比。

## 7. 成功指标

- 新鲜度（本地环境记录）：商品事务提交后搜索可见延迟 P95 < 5s（同步调用 + 刷新策略）。
- 可靠性：同步失败 0 静默丢失（必有 failure_record 或 ERROR 日志）；重建可重复成功率 100%。
- 质量：mall-search/mall-product 单元 + Testcontainers 集成测试全绿；一致性检查可发现人为缺失文档。
