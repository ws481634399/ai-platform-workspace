# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-04-01-01
- Feature Path: 订单交易 > 交易异常与补偿 > 交易补偿基础 > 交易异常补偿与幂等加固
- 状态流转: designed → tasked
- TC 总数: 11

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 集成：落库失败 + 同步 release 成功 → 无任务行、reservation RELEASED（场景 A 正路径） | AC-001 | DU-BE-906 | [S7] 场景十 |
| TC-002 | 集成：落库失败 + release 失败 → PENDING 任务（payload reservationIds、next_retry≈+30s）；直接调 runDue（mock 转成功）→ SUCCESS、reservation 终态 RELEASED | AC-001 | DU-BE-906 | [S7] |
| TC-003 | 集成：cancel 后 release 故障 → 任务 PENDING；pay 后 confirm 故障同构；重试成功 | AC-002 | DU-BE-906 | [S7] 场景 B |
| TC-004 | 单测/集成：handler 遇 reservation 已 RELEASED/DEDUCTED → 直接 SUCCESS，stock 不变（配合重复 pay/cancel 场景 C/D） | AC-003 | DU-BE-906 | [S7] |
| TC-005 | 单测：退避序列 30s/1m/2m/5m/10m；连续失败 5 次后 FAILED_DEAD、ERROR 日志 | AC-004,007 | DU-BE-906 | [S7] |
| TC-006 | API（order:compensation）：GET 列表按 status/分页；SUCCESS 行 retry → 400；不存在 → 404 | AC-004 | DU-BE-906 | [S7] |
| TC-007 | API：FAILED_DEAD 行 manual retry（mock 恢复）→ 重置 retry_count 并立即成功 SUCCESS；仍失败则重新退避 | AC-004 | DU-BE-906 | [S7] |
| TC-008 | 集成：同 (businessType,businessId,operation) 并发落任务（两线程 insertIgnore）→ 唯一行，payload 合并 | AC-005 | DU-BE-906 | [S7] |
| TC-009 | 日志审计：失败/重试/DEAD 日志含 orderNo/traceId/operation/retryCount；断言无 token/secret 字样 | AC-006 | DU-BE-906 | [S7] 场景 E |
| TC-010 | 单测：findDue 仅取 PENDING 且 next_retry_at<=now LIMIT 50；单条 handler 抛异常不影响后续条（列表 3 条中间异常） | AC-007 | DU-BE-906 | [S7] |
| TC-011 | 配置：scheduler-enabled=false 时调度 bean 不装配；默认 true 装配（context 两种启动） | AC-007 | DU-BE-906 | [S7] |

## 2. 测试策略

- V2 Flyway H2 真实任务表；inventoryPort 用可编排故障脚本的 mock（第 N 次失败后恢复）。
- 调度不依赖真实定时器：测试直接调 CompensationService/拾取方法；@ConditionalOnProperty 双 context 验证装配。
- 日志用 LogCaptor 类工具捕获断言。

## 3. 不可测项标注

- 多实例调度互斥不在 M4 范围（单实例部署假设，记录于 design）。

## 4. 依赖与前置条件

- DU-BE-903 已建立 pay/cancel 日志挂点；Integration Gate 场景 A~E 在 change 级 test-design 统一端到端执行。
