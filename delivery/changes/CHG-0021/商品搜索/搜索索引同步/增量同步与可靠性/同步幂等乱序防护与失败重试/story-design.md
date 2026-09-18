---
affected-repositories: [repo-1]
story-id: "STORY-005-02-02-02"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §2.3/§2.4
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0021
- Story ID: STORY-005-02-02-02
- 状态流转: specified → designed
- 相关仓库: repo-1（mall-search）
- 需要 Migration: no
- 数据变更概要: 无新表（search_sync_failure_record 已由 V1 创建）

## 1. 模块改动（Module Changes）

### repo-1 mall-search（DU-BE-506）

- upsert 写 ES 使用 IndexRequest.version(updatedAtMillis).versionType(EXTERNAL_GTE)；
  - VersionConflictEngineException → 捕获消化：记 INFO 日志（"stale event ignored"），按成功处理（不落失败表）；
  - docId=productId 字符串，保证同文档幂等覆盖。
- application.search.SearchSyncFailureService：
  - recordFailure(productId,op,payload,reason)：INSERT PENDING，next_retry_at=now()+30s，retry_count=0；同 product+op 已有 PENDING 行则更新 payload/reason（不新增重复行）；
  - @Scheduled(fixedDelay=30s) retryPending()：SELECT ... WHERE status='PENDING' AND next_retry_at<=now() LIMIT 100；逐条重放 upsert/delete：
    - 成功 → SUCCEEDED；
    - 失败且 retry_count+1≥5 → FAILED_DEAD；
    - 否则 retry_count+1，next_retry_at 按退避 [30s,1m,2m,5m,10m] 推进；
  - 启用 @EnableScheduling（若主类/配置未启用）；调度仅 mall-search 单实例，不做分布式锁（单节点部署，注释写明多实例需 ShedLock）。
- 管理支持：SearchIndexAdminController 增 GET /api/admin/search/sync-failures（status 筛选、简单分页，权限码复用 search:index:list）与 POST /api/admin/search/sync-failures/{id}/retry（search:index:rebuild 权限复用；重置 next_retry_at/PENDING→立即重试）。FAILED_DEAD 人工重试路径。
- product 侧 SearchSyncClient 调用失败兜底：AFTER_COMMIT listener catch 后不依赖本地表（product 库无该表）——仅 log.error；落表责任在 mall-search 端点（ES 故障时端点自己落表）。端点不可达的极端窗口：依赖 WARN 日志+一致性检查+手工重建兜底（M5 明示接受边界）。

## 2. 接口契约细化

| 方法 | 路径 | 权限码 | 说明 |
| --- | --- | --- | --- |
| GET | /api/admin/search/sync-failures?status=&page=&size= | search:index:list | 失败记录分页 |
| POST | /api/admin/search/sync-failures/{id}/retry | search:index:rebuild | 人工重试；404 不存在 → B0504 |

新增错误码：B0504 SYNC_FAILURE_NOT_FOUND(404)。

## 3. 数据变更

无 DDL。failure_record 状态机：PENDING → SUCCEEDED / PENDING×退避 → FAILED_DEAD →（人工 retry）→ PENDING。

## 4. 错误处理

- 版本冲突=成功语义；重试全部异常类型（连接/ES）均捕获计数；
- 调度任务单条异常不影响批次其余记录；
- 人工重试不存在记录 → B0504。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-506 | repo-1 | external_gte 乱序防护/冲突消化/退避重试调度/失败管理端点 | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008 | 无 |

> 跨 Story 依赖（不入本表）：DU-BE-506 实际前置 DU-BE-505（STORY-005-02-02-01 增量端点/事件链路），dev 同一迭代按序 BE-505→BE-506 实施。

## 6. 测试策略

- 单测：退避序列计算、5 次→FAILED_DEAD、同 product+op 去重；
- IT：乱序（旧 updatedAt 事件晚到）被忽略且文档保持新值；重复 sync 幂等；
- 故障注入：ES 停→sync 受理落 PENDING→恢复 ES→调度后 SUCCEEDED 且文档可搜；人工 retry FAILED_DEAD 路径。
