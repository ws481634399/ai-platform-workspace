---
story-id: "STORY-005-02-02-02"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S4]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.1 [S4]/§4/§5
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0021
- Story ID: STORY-005-02-02-02 同步幂等乱序防护与失败重试
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`（S4）

## 1. Story 目标

为增量同步补齐可靠性三件套：docId=productId 覆盖写的天然幂等；以 updatedAt 毫秒为 external version（external_gte）防止旧事件覆盖新文档；ES 故障期间同步失败落 search_sync_failure_record，@Scheduled 有界指数退避自动重试，超过上限 FAILED_DEAD 并提供人工重试端点，全部尝试可观测。

## 2. Scope（范围）

### 2.1 包含

- [S4] 写入统一走 IndexOps：index(docId=productId, version=updatedAtMillis, versionType=external_gte)；delete 带当前版本语义（删除幂等：not_found 成功；version 冲突说明已被更新，跳过删除并登记 WARN——防旧下架删新更新）。
- [S4] VersionConflictEngineException 消化：视为"已被更新版本覆盖"，正常成功不落失败表。
- [S4] SyncFailureRecorder + Po/Mapper：search_sync_failure_record（id/productId/eventType/payload/status/retryCount/maxRetries/lastError/nextRetryAt/createdAt/updatedAt；同 productId+eventType 待处理记录复用更新）。
- [S4] SyncFailureRetryJob：@Scheduled(fixedDelay=30s) 扫描 PENDING AND nextRetryAt<=now（limit 100），重新拉 product 投影（按 productId 调投影单查/列表过滤）执行 upsert/delete；退避 30s/1m/2m/5m/10m；retryCount≥5 → FAILED_DEAD。
- [S4] `GET /api/internal/search/sync-failures?status=`（SERVICE）、`POST /api/admin/search/sync-failures/{id}/retry`（ADMIN search:index:rebuild）人工重试（重置计数→立即执行）。

### 2.2 不包含

- 分布式锁/多实例调度（M5 单实例；SQL 条件更新防并发拾取）。
- DLQ/死信平台；失败告警通知（仅日志）。

## 3. 业务规则

- [幂等] 同事件重复处理：文档内容相同，结果一份；失败记录唯一键防重复落表。
- [乱序] updatedAt 较小的写入被 ES 拒绝 → 成功消化；旧删除晚到且文档版本更新 → 不删除（WARN 记录）。
- [退避] 固定退避序列 30s/1m/2m/5m/10m；最大 5 次；FAILED_DEAD 不自动拾取。
- [重试数据源] 重试不相信旧 payload 状态，按 productId 重新获取当前投影后执行（当前为下架则删，在架则 upsert），保证最终对齐权威。
- [人工重试] 重置 retryCount=0、status=PENDING、nextRetryAt=now；需权限码。

## 4. 接口与字段规格

- GET /api/internal/search/sync-failures?status=PENDING|FAILED_DEAD（SERVICE）→ 分页/列表。
- POST /api/admin/search/sync-failures/{id}/retry（ADMIN search:index:rebuild）→ 当前记录状态。
- 内部写入同 STORY-005-02-02-01 契约（external version 对调用方透明，由 search 侧实现）。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 同一 upsert 事件连投两次：ES 仅一份文档、字段为最新，失败表无脏记录 |
| AC-002 | 先投 updatedAt=200 的文档，再投 updatedAt=100 的同商品事件：文档保持 200 版本内容，接口不报错 |
| AC-003 | 200 版 upsert 后到达旧版本(100) delete：文档不被删除且有 WARN 日志 |
| AC-004 | ES 停止期间产生同步：failure_record 落 PENDING（含 productId/eventType/错误）；ES 恢复后定时任务重试成功并置 SUCCESS |
| AC-005 | 持续故障下重试次数按退避序列递增，第 5 次后置 FAILED_DEAD 且不再被定时拾取 |
| AC-006 | 人工重试 FAILED_DEAD 记录（ES 已恢复）→ 记录重新 PENDING 并尽快成功 |
| AC-007 | 重试时商品已下架：重新拉投影为下架 → 执行删除并 SUCCESS；已重新上架：upsert 成功 |
| AC-008 | 集成测试（Testcontainers + 可控 ES 启停/wiremock 投影）覆盖上述主路径；mvn test 全绿 |
