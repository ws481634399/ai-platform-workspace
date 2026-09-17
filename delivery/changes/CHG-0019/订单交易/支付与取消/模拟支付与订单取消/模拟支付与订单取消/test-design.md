# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-02-01-01
- Feature Path: 订单交易 > 支付与取消 > 模拟支付与订单取消 > 模拟支付与订单取消
- 状态流转: designed → tasked
- TC 总数: 12

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API：PENDING pay → PAID/paidAt/PAY history；inventory confirm 每行一次（mock）；reservation DEDUCTED、total/locked 同减（inventory 模块真实测试） | AC-001 | DU-BE-903 | [S3] Integration Gate 场景一 |
| TC-002 | API：重复 pay 第二次幂等 200；confirm 仅生效一次；无新增 history | AC-002 | DU-BE-903 | [S3] 场景六 |
| TC-003 | API：CANCELLED pay → B0407 409；他人/不存在 → 404 | AC-003 | DU-BE-903 | [S3] |
| TC-004 | API：PENDING cancel → CANCELLED/cancelledAt/reason/CANCEL history；release 每行一次、available 归还 | AC-004 | DU-BE-903 | [S3] |
| TC-005 | API：重复 cancel 幂等且 release 一次；PAID/SHIPPED/COMPLETED cancel → B0407；他人 404；reason 256 字 → 400 | AC-005 | DU-BE-903 | [S3] 场景七 |
| TC-006 | 并发：pay‖cancel 50 轮（两线程 latch）→ 终态唯一；PAID 必有 confirm、CANCELLED 必有 release，无撕裂 | AC-006 | DU-BE-903 | [S3] 场景八 |
| TC-007 | inventory 单测/集成：同 reservationId 并发重复 release/confirm（两线程）→ stock 只变一次、reservation 终态正确 | AC-007,008 | DU-BE-903 | [S3] CAS 加固 |
| TC-008 | inventory：DEDUCTED 再 release / RELEASED 再 confirm → 业务冲突异常；非 LOCKED casStatus rows=0 重读幂等 | AC-007 | DU-BE-903 | [S3] |
| TC-009 | inventory 回归：既有 lock/availability/分页等全部既有测试绿 | AC-008 | DU-BE-903 | [S3] |
| TC-010 | API：confirm 抛 5xx → 订单保持 PAID、ERROR 日志含 orderNo/traceId、返回 PAID 视图（本 Story 不落补偿表，下 Story 替换） | AC-009 | DU-BE-903 | [S3] |
| TC-011 | 单测：Order.pay/cancel 首次/重复/非法三态解释；history 仅真实迁移追加 | AC-001~005 | DU-BE-903 | [S3] |
| TC-012 | SQL 审查：casStatus/releaseStock/deductStock 条件 SQL 带 status/version 与 locked_quantity>=qty 守卫 | AC-007 | DU-BE-903 | [S3] |

## 2. 测试策略

- order 侧 H2 真实 CAS + mock inventoryPort；inventory 侧直接对 InventoryApplicationService 与 Mapper 做 H2 并发测试。
- 竞争用例重复 50 轮提高命中率；日志用 log capture 断言。

## 3. 不可测项标注

- 补偿任务落表在 STORY-004-04-01-01 验证（TC-010 仅断言日志与状态不回滚）。

## 4. 依赖与前置条件

- DU-BE-902；库存改造不得改响应契约，需保证 M3 消费者兼容。
