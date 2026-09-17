# Implementation（跨仓实施汇总）— 交易异常补偿与幂等加固 STORY-004-04-01-01

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0019（M4 订单交易闭环）
- Story：STORY-004-04-01-01 交易异常补偿与幂等加固
- 实施日期：2026-09-17

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-906 | repo-1 | CompensationTask 落表（V2）+ 有界指数退避调度 + inventory 补偿 handler + admin 补偿端点；OrderApiTest 17/17（补偿相关用例） |

> 补偿台前端（CompensationListView）复用 mall-admin 订单模块，在 DU-FE-903（22ad40f）同提交内交付，逻辑归属本 Story AC-004。

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| a06ed4c | DU-BE-906 | repo-1 | feat(order): CompensationTask 有界退避补偿 + inventory handler + admin 补偿端点 |
| 22ad40f | DU-FE-903 | repo-2 | feat(order): mall-admin 补偿任务台（status 筛选 + 手动重试） |

## 3. 各仓实施引用

- repo-1：
  - `CompensationTask` 聚合（businessType/businessId/operation/status PENDING|SUCCESS|FAILED_DEAD/retryCount/maxRetries=5/nextRetryAt/lastError），唯一键 (business_type, business_id, operation) 复用，避免同单同操作并发生成重复任务行
  - `CompensationService.register`：锁成功但 release/confirm 失败、或建单全锁后落库失败同步 release 失败 → 落 PENDING 任务（nextRetryAt=now）
  - `CompensationService.fetchDue(batchLimit)`：有界拾取 PENDING 且 nextRetryAt<=now（LIMIT），单条异常 catch ERROR 日志含 orderNo+traceId 后 continue，不影响下一条
  - `InventoryCompensationHandler.handle`：调 inventory release/confirm（幂等 API），对已处目标态预留直接判成功，不重复增减；成功 → SUCCESS；失败 retryCount+1、nextRetryAt 指数退避，>5 次 → FAILED_DEAD + ERROR 日志
  - `CompensationService.retry(id)`（admin 手动重试）：重置 retryCount=0、status=PENDING、nextRetryAt=now，触发执行后返回最新状态
  - `AdminCompensationController`：GET /api/admin/compensations（status 筛选/分页）、POST /api/admin/compensations/{id}/retry，权限码 order:compensation
  - 关键失败日志统一带 orderNo + traceId；日志无 secret/token；状态迁移不重复写 history（幂等路径）
- repo-2：
  - CompensationListView：status 下拉（PENDING/SUCCESS/FAILED_DEAD）、表格（任务 ID/业务单号/操作类型/重试进度/状态/最近错误/下次重试/更新时间）、手动重试按钮（PENDING/FAILED_DEAD 可点）

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | 锁成功+落库失败：同步 release 成功 → 无任务/RELEASED；release 也失败 → PENDING 任务，调度重试至 SUCCESS | passed（lockMidwayFailureReleasesAndCompensates：释放再失败登记补偿、admin retry 后 SUCCESS） |
| AC-002 | 取消时 release 首次失败 → 落 PENDING 退避重试成功；支付 confirm 失败同构 | passed（同用例释放失败路径 + 退避算法单测） |
| AC-003 | 重复 pay/cancel 不产生重复库存副作用；handler 对目标态预留直接成功 | passed（cancelAndIdempotent + InventoryReleaseConfirmCasTest 幂等断言） |
| AC-004 | 超 5 次 → FAILED_DEAD + ERROR；admin 列表可查；手动 retry 重置执行成功 → SUCCESS | passed（lockMidwayFailure 人工重试成功断言；CompensationService 重试上限分支） |
| AC-005 | 同单同操作并发补偿不重复行（唯一键复用） | passed（V2 uk_compensation_business 唯一键 + register 幂等） |
| AC-006 | 失败日志 orderNo+traceId 可定位，无 secret/token；每次迁移有 history | passed（OrderWebExceptionHandler/Service 日志格式化断言 + fullHappyPath history 4 条） |
| AC-007 | 调度拾取有界、单条异常不影响下一条、无无限重试 | passed（fetchDue LIMIT + maxRetries=5 FAILED_DEAD 守门） |
