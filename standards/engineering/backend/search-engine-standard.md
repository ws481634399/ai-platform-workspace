---
title: 搜索引擎接入规范（Elasticsearch 投影/检索）
tags: [backend, elasticsearch, search, index-sync, projection, fail-degraded]
related-changes: [CHG-0020, CHG-0021]
---

# 搜索引擎接入规范（Elasticsearch 投影/检索）

> 版本：v0.1
> 类型：后端工程规范
> 作用域：OpenSpec Workspace
> 来源：CHG-0020 商品搜索、CHG-0021 搜索索引同步

## 1. 定位与边界

- Elasticsearch 是业务库的**只读投影/检索引擎**，不是事实源；事实源为 MySQL，搜索文档由事件同步链路构建。
- 搜索服务（mall-search）对外提供只读查询；索引维护（重建、失败重试）经 admin 端点；商品变更接收经内部端点。
- 版本基线：ES 客户端随 Spring Boot BOM（8.18.x）、服务端 8.17.x，**同 8.x 主版本互通**即兼容基线；升级主版本需专项验证。

## 2. 索引建模与 Mapping

- Mapping 以**代码化 JSON** 入仓（`resources/es/*.json`），禁止在 ES 上手改结构。
- 中文分析器采用**双映射**：主映射 `ik_max_word`，回退映射 `standard`；启动时探测 IK 插件可用性自动选择。两份映射的字段类型必须冻结一致，仅分析器不同，保证回退不改查询语义。
- 数值型业务 ID 字段在 ES 中映射为 `long`（如 productId）；文档 `_id` 使用字符串业务 ID（docId）。
- 索引一律经**别名**访问（如 `ai-mall-products`），应用不持有物理索引名。

## 3. 重建与别名切换

- 全量重建写**临时索引**（名含 UTC 时间戳），完成后用**单请求 `updateAliases` remove/add 原子切换**，随后 refresh 并删除旧索引。
- 重建失败必须保留临时索引现场与 FAILED 任务记录，便于排查，不得静默清理。
- 重建互斥：同一索引同一时刻只允许一个 PENDING/RUNNING 任务，重复发起返回 409（B0503）。
- 一致性检查返回总数对比与双向缺失 ID 列表，差集超过上限必须**双向截断并带 truncated 标记**，不得无声丢项。

## 4. 分页与排序

- 用户浅分页用 from/size，size 强制夹取值区间（1..100）。
- **全量 dump / 深分页**：PIT（`openPointInTime` + keepAlive）+ `_shard_doc` asc + `search_after`。
- ES 8.18 起禁止对 `_id` 做 fielddata 排序；需要稳定全序时用业务数值字段升序（如 DB 侧 id 升序分页），保证分批 total 保真。

## 5. 查询建模

- 商品文档以 SKU 价区字段表达价格区间（minPrice/maxPrice）；价区过滤按**区间相交**：`minPrice ≤ 请求上界 AND maxPrice ≥ 请求下界`，单边开边界。
- 在售商品查询恒挂 ON_SALE 过滤；出参字段走白名单，禁止全字段回传。
- 排序参数做枚举归一（DEFAULT/price_asc/price_desc/newest），非法值静默回退 DEFAULT，不抛 400。
- 公开 DTO 中的雪花业务 ID 必须按 [api-design-standard.md](api-design-standard.md) §5.3 加 `@StringId` 字符串出参；**新服务首次评审即纳入检查单**，不得遗留裸 Long。

## 6. 故障归一与降级

- ES 为非核心强依赖，查询链路**故障降级**：遍历异常 cause 链识别 `ConnectException`/`SocketTimeoutException`/索引 404 `ResponseException`（只认状态码，不依赖 reason 文本），归一为 503 B0501 SEARCH_UNAVAILABLE；未匹配异常原样抛出。
- 日志打 WARN 并带 traceId；响应体不得包含主机、端口、堆栈。
- 空结果返回 200 空页，不打 ERROR；health 指标 DOWN 不外抛导致进程失败；ES Client 懒连接，ES 离线时应用可正常启动。

## 7. 事件驱动投影同步

- 事件**不携带业务载荷**，只传 ID；消费方在 `AFTER_COMMIT` 后回源重查权威态，按查询结果决定 upsert/delete（反腐败层：外部消息不直接写投影）。
- 乱序防护：文档带版本号，写入用 `external_gte` 版本仲裁，旧版本消息不覆盖新文档。
- 事务回滚零推送：依赖 AFTER_COMMIT 语义，未提交的变更不得触发同步。
- 失败处理为**有界退避死信**：退避 30s/1m/2m/5m/10m、最多 5 次，超过置 FAILED_DEAD；人工 rearm 后以同一请求立即 replay，重放时重新回源拉取、不信旧 payload；应用层唯一键复用行去重。该范式与订单补偿任务（compensation_task）同构。

## 8. 内部端点安全

- 内部端点（`/api/internal/**`）双层防护：网关对匿名/认证用户统一 `denyAll` 返回 404（隐藏存在性），服务端方法级 `hasRole('SERVICE')`。
- 内部只读端点的分页响应结构与对应 admin 端点同构（`{total,page,size,items}`），size 同样夹 1..100。
- 设计文档声明的端点不得在实现阶段无声裁剪；确需裁剪必须登记 DU Deviations 并回修设计。

## 9. 跨端契约教训

- TS 端字面量枚举/常量漂移不会被 type-check 发现：枚举与契约值要么共享生成类型，要么必须有 api 契约层组件测试兜底。
