---
story-id: "STORY-005-02-02-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S3]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.1 [S3]/§4/§5
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0021
- Story ID: STORY-005-02-02-01 商品变更增量同步
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`（S3）

## 1. Story 目标

商品写路径事务提交后准实时同步搜索投影：mall-product 在创建/更新/上架/下架/SKU 改价后发布 Spring 应用事件，AFTER_COMMIT 监听器经 SearchSyncClient 调 mall-search 内部同步端点；mall-search 执行单条 upsert（ON_SALE 建/更新文档）与下架硬删除；同步 best-effort 不阻断商品主事务；乱序/失败落表机制在 STORY-005-02-02-02 交付，本 Story 接入其端点契约。

## 2. Scope（范围）

### 2.1 包含

- [S3] mall-product：product 变更事件（复用既有 ProductPublishedDomainEvent/ProductUnpublishedDomainEvent 语义 + 新增/统一 ProductChangedApplicationEvent：created/updated/published/unpublished/priceChanged，载荷 productId）。
- [S3] ProductSearchSyncListener：@TransactionalEventListener(phase=AFTER_COMMIT)，按 productId 组装投影（复用投影查询服务，单商品版）并调用 search 内部端点；异常仅 WARN（search 侧负责失败落表）。
- [S3] SearchSyncClient（mall-product infra client）：POST /api/internal/search/products/sync（单条 upsert）、DELETE /api/internal/search/products/{productId}；X-Internal-Token；短超时（connect 1s/read 3s）。
- [S3] mall-search InternalSearchSyncController + SyncApplicationService：upsert 收 ProductProjectionView → 组装文档写 ES（ON_SALE 写、非 ON_SALE 删）；delete 硬删除幂等；写失败落 failure_record（表已在 V1）并返回受理成功（本 Story 建落表调用，调度重试在后续 Story）。
- [S3] 触发点接线：create（若直接上架）、update、publish、unpublish、addSku/updateSku/changeSkuStatus（影响价格摘要/可售性）。

### 2.2 不包含

- external version 乱序比较与退避调度/人工重试端点（STORY-005-02-02-02）。
- MQ/Outbox；批量事件合并（单事件单商品，M5 足够）。

## 3. 业务规则

- [时序] 仅 AFTER_COMMIT 触发：事务回滚不产生同步事件。
- [不阻断] 同步调用任何异常（连接拒绝/超时/5xx）不得向外抛出影响 controller 响应；WARN 日志含 productId/eventType/traceId。
- [上架/变更] upsert：mall-search 按收到的投影 status 决定 ON_SALE 写文档、其他状态删文档（双保险，与下架事件一致）。
- [下架] 立即硬删除；删除不存在视为成功。
- [价格] 仅更新索引 minPrice/maxPrice 摘要；不存在任何从搜索价格回写订单/库存的路径。

## 4. 接口与字段规格

- POST /api/internal/search/products/sync（SERVICE）：body=ProductProjectionView（与投影端点同形状）→ {accepted:true}；ES 失败时仍 200 受理（已落 failure_record）。
- DELETE /api/internal/search/products/{productId}（SERVICE）→ {deleted:true}（幂等）。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 商品上架事务提交后 5s 内 ES 出现文档并可被 CHG-0020 搜索接口检出 |
| AC-002 | 商品改名/换分类品牌/换主图提交后，文档字段同步更新；SKU 改价后 minPrice/maxPrice 刷新 |
| AC-003 | 商品下架提交后文档被硬删除，搜索不可见；重复下架/删除不存在文档返回成功 |
| AC-004 | 新增 ENABLED SKU 改变价格极值、禁用唯一低价 SKU 后摘要正确；无启用 SKU 的在架商品不产生可搜索文档（或被删） |
| AC-005 | 模拟 mall-search 停止：商品上架仍成功（接口正常返回），product 日志有 WARN，不回滚 |
| AC-006 | 事务回滚（如校验失败）不产生任何同步调用 |
| AC-007 | 内部同步端点需 SERVICE 身份，经网关访问 404 |
