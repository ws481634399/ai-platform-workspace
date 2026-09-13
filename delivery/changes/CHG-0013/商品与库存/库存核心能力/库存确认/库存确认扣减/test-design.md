# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 位置：STORY 级 —— `CHG-0013/.../库存确认扣减/test-design.md`
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-04-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- 状态流转: designed → tasked
- TC 总数: 4

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API 集成测试：POST /internal/inventory/confirm 基于 LOCKED reservation → total-=quantity、locked-=quantity，状态 DEDUCTED | AC-015 | DU-BE-404 | 确认扣减成功 |
| TC-002 | API 集成测试：同一 reservationId 重复确认 → 不重复扣减，返回成功 | AC-016 | DU-BE-404 | 幂等扣减 |
| TC-003 | API 集成测试：基于已 RELEASED/DEDUCTED reservation 确认 → INVALID_STATE | AC-017 | DU-BE-404 | 状态机 |
| TC-004 | 数据断言：确认扣减后 inventory_log 存在 DEDUCT 记录，含 before/after | AC-018 | DU-BE-404 | DEDUCT 流水 |

## 2. 测试策略

- Unit：Inventory.confirmDeduction 领域行为与状态机校验。
- API 集成：@SpringBootTest + MockMvc + H2，先锁定再确认。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-403 锁定后 reservation 存在且状态 LOCKED。
