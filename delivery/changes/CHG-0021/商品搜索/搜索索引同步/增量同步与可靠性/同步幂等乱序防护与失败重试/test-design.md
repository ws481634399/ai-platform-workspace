# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0021
- Story ID: STORY-005-02-02-02
- Feature Path: 商品搜索 > 搜索索引同步 > 增量同步与可靠性 > 同步幂等乱序防护与失败重试
- 状态流转: designed → tasked
- TC 总数: 8

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 集成：相同 upsert 连投两次 → ES 仅 1 文档且字段为最新；failure_record 无脏行 | AC-001 | DU-BE-506 | [S1] |
| TC-002 | 集成：投 v200 再投 v100 upsert → 文档保持 v200 内容，接口 200（VersionConflict 消化，INFO 日志） | AC-002 | DU-BE-506 | [S1] |
| TC-003 | 集成：v200 upsert 后到 v100 delete → 文档仍在；日志 WARN/INFO 记录旧事件忽略 | AC-003 | DU-BE-506 | [S1] |
| TC-004 | 集成：停 ES 触发 sync → 返回 200 受理 + failure_record 一行 PENDING（productId/op/reason/payload 齐）；启 ES 后 @Scheduled 拾取 → SUCCESS 且文档可搜 | AC-004 | DU-BE-506 | Integration Gate 场景五 |
| TC-005 | 单测/集成：退避序列 30s/1m/2m/5m/10m 断言 next_retry_at；第 5 次失败后 FAILED_DEAD，调度查询不再拾取 | AC-005 | DU-BE-506 | [S1] 时钟用可注入 Clock |
| TC-006 | API：POST /api/admin/search/sync-failures/{id}/retry 对 FAILED_DEAD（ES 已恢复）→ 重置 PENDING 并尽快成功；不存在 id → 404 B0504 | AC-006 | DU-BE-506 | [S1] |
| TC-007 | 集成：重试时拉投影为下架 → 执行 DELETE 并 SUCCESS；重新上架后重试 → upsert 成功 | AC-007 | DU-BE-506 | [S1] |
| TC-008 | 构建门禁：mvn -pl mall-services/mall-search -am test 全绿（含上述 IT） | AC-008 | DU-BE-506 | [S1] |

## 2. 测试策略

- 版本控制用真实 ES external_gte 验证（不 mock 版本冲突语义）；
- 退避调度单测注入固定 Clock；批次扫描 LIMIT 100 用 repository 单测验证 SQL；
- 调度器直接方法调用（不走真实 30s 等待）保证测试速度。

## 3. 不可测项标注

- 无。

## 4. 依赖与前置条件

- DU-BE-505 增量链路、V1 failure_record 表；@EnableScheduling 启用。
