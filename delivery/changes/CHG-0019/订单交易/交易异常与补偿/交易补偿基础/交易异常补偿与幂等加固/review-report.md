# Review Report — STORY-004-04-01-01 交易异常补偿与幂等加固

## 0. 元信息

- Change ID：CHG-0019
- Story ID：STORY-004-04-01-01
- 审查对象：DU-BE-906（repo-1 CompensationTask + 调度 + handler + admin 补偿端点）+ DU-FE-903（repo-2 补偿台）
- 审查时间：2026-09-17
- 审查者：trae-agent
- 测试报告来源：`evidence/test-report.md`（mall-order 18/18、mall-inventory 28/28、mall-admin 35/35）

## 1. 检查结论

**通过（PASS）。** CompensationTask 落表（V2），唯一键 (business_type,business_id,operation) 防重复行；有界指数退避调度（maxRetries=5，超限 FAILED_DEAD）；InventoryCompensationHandler 调用 inventory 幂等 API，对已处目标态预留直接判成功不重复增减；admin 手动 retry 重置 retryCount/status 并立即执行；关键失败日志含 orderNo+traceId，无 secret/token；状态迁移写 history 幂等路径不重复。

## 2. 发现清单

| 编号 | 严重度 | 发现 | 处理 |
|------|--------|------|------|
| F-001 | minor | 补偿任务时间戳 NULL 兼容（V2 NOT NULL） | 已处理：落 PO 时 createdAt/updatedAt 回填 Instant.now()，与 inventory 预留同模式 |
| F-002 | info | 调度器未使用 Spring @Scheduled，由上层调用 fetchDue+handle | 设计内：本 Story 交付核心能力，调度触发方式由上层集成；fetchDue 已有界 LIMIT 不无限拾取 |

无遗留 blocker / major。

## 3. 完成确认

| 检查项 | 结论 |
|--------|------|
| 锁成功落库失败：release 成功无任务；release 失败 → PENDING 重试至 SUCCESS | 通过（TC-001 lockMidwayFailure） |
| 取消 release 首次失败 → 退避重试成功；支付 confirm 失败同构 | 通过（TC-002） |
| 重复 pay/cancel 不重复库存副作用；handler 对目标态预留直接成功 | 通过（TC-003） |
| 超 5 次 → FAILED_DEAD + ERROR；admin 列表可查；手动 retry 重置执行成功 | 通过（TC-004） |
| 同单同操作并发不重复行（唯一键复用） | 通过（TC-005 V2 uk） |
| 失败日志 orderNo+traceId 可定位，无 secret/token；迁移有 history | 通过（TC-006） |
| 调度有界、单条异常不影响下一条、无无限重试 | 通过（TC-007 fetchDue LIMIT + maxRetries 守门） |

## 4. Deviations

无实质偏离。
