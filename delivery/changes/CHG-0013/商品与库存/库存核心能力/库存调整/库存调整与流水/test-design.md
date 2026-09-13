# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 位置：STORY 级 —— `CHG-0013/.../库存调整与流水/test-design.md`
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-02-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- 状态流转: designed → tasked
- TC 总数: 4

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 备注 |
| --- | --- | --- | --- |
| TC-001 | API 集成测试：POST /{skuId}/adjust 正 delta → total 增加；负 delta → total 减少；流水记录 before/after/delta/reason/operator | AC-008 | DU-BE-402 | 调整 |
| TC-002 | API 集成测试：负 delta 导致 total<0 → INVALID_ARGUMENT，库存不变 | AC-009 | DU-BE-402 | 防负 |
| TC-003 | 数据断言：调整后 inventory_log 存在 ADJUST 记录，含 before/after/delta/reason | AC-018 | DU-BE-402 | ADJUST 流水 |
| TC-004 | 安全切片：无 inventory:stock:adjust → 403；有权限 → 200；流水页无 inventory:log:list → 403 | AC-020 | DU-BE-402 | RBAC |

## 2. 测试策略

- Unit：Inventory.adjust 正负 delta 与防负校验。
- API 集成：@SpringBootTest + MockMvc + H2。
- 前端：调整弹窗表单校验 + 流水页渲染。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-401 初始化后库存存在。
