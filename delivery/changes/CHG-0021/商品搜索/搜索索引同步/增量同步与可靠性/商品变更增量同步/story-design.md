---
affected-repositories: [repo-1]
story-id: "STORY-005-02-02-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §2.3
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0021
- Story ID: STORY-005-02-02-01
- 状态流转: specified → designed
- 相关仓库: repo-1（mall-product、mall-search）
- 需要 Migration: no
- 数据变更概要: 无新表（复用 V1 failure_record，失败落表在 STORY-005-02-02-02）

## 1. 模块改动（Module Changes）

### repo-1 mall-product（DU-BE-505）

- domain.product.event.ProductSearchChangedEvent（record：productId、op=UPSERT/DELETE、occurredAt epoch milli）；注入既有 ApplicationEventPublisher。
- application 层在 7 个写方法事务内发布事件（@TransactionalEventListener AFTER_COMMIT 才真正推送）：
  - create/update/publish/addSku/updateSku/changeSkuStatus → UPSERT；unpublish/changeStatus(→下架) → DELETE；changeStatus 按目标状态决定 op。
- infrastructure.client.SearchSyncClient（OpenFeign name=mall-search contextId=searchSync；connectTimeout 1s/readTimeout 3s）：
  - POST /api/internal/search/products/sync（body=ProductSearchProjection）；DELETE /api/internal/search/products/{id}。

### repo-1 mall-search（DU-BE-505）

- interfaces.rest.internal.InternalSearchSyncController（SERVICE 鉴权同既有 internal）：
  - POST /api/internal/search/products/sync：upsert（id=productId；version=updatedAt 毫秒 external_gte，乱序防护在 STORY-02 完善）；ES 异常 → 落 search_sync_failure_record（写入服务在 BE-506 完整接入）并返回 200 {accepted:true}（冻结：受理即成功，由本地补偿重放）；
  - DELETE /api/internal/search/products/{id}：硬删除，文档不存在视为成功。
- application.search.SearchSyncApplicationService：upsert/delete 编排，domain→SearchDocument mapper 复用全量构建 mapper。

> 实施约束：DU-BE-505 与 DU-BE-506 在同一 dev 迭代内按序实施（BE-505→BE-506）；门禁测试以两者完成后的最终形态为准。

## 2. 接口契约细化

| 方法 | 路径 | 调用方 | 成功响应 |
| --- | --- | --- | --- |
| POST | /api/internal/search/products/sync | mall-product SERVICE | 200 {accepted:true} |
| DELETE | /api/internal/search/products/{id} | mall-product SERVICE | 200 {accepted:true}（不存在幂等成功） |

请求体：ProductSearchProjection（同 search-projection 响应结构）；DELETE 无需 body。

## 3. 数据变更

无 DDL。运行期写 search_sync_failure_record（V1 已建，完整重试在 BE-506）。

## 4. 错误处理

- AFTER_COMMIT 监听器内异常绝不抛回业务（事务已提交）：捕获 → ERROR 日志；
- 同步端点写 ES 失败：落表（PENDING）+ 返回 200 accepted（调用方无需重试，由 mall-search 本地补偿）；
- 下架硬删除：DELETE 文档缺失视为成功；
- product 完全调不通 search 的极端窗口：WARN 日志 + 一致性检查 + 手工重建兜底（M5 明示接受边界，converge 记录）。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-505 | repo-1 | product 事件发布(7写方法)+SearchSyncClient；search 内部 sync/delete 端点 | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007 | 无 |

> 跨 Story 依赖（不入本表）：DU-BE-505 实际前置 DU-BE-503（投影端点与全量链路）；dev 实施须先于 DU-BE-506（STORY-005-02-02-02）。

## 6. 测试策略

- product：@TransactionalEventListener 单测（回滚不发送、提交后发送；7 方法分别 UPSERT/DELETE 语义）；
- search：MockMvc 端点成功/文档不存在幂等；
- IT：改商品名→轮询搜索命中新词；下架→搜索不返回；上架/SKU 改价→min/max 变化；ES 停服时商品写操作仍成功（事务不阻断）。
