# Test Design（Change 级聚合）— CHG-0013 库存核心能力

> 阶段：sdd-task 聚合产物（多 Story Change）
> 各 Story 测试设计明细见各 Story test-design.md。

- Change ID: CHG-0013
- 覆盖 Story: STORY-002-04-01-01、STORY-002-04-02-01、STORY-002-04-03-01、STORY-002-04-04-01

## 1. 测试用例

| TC     | 验证方式                                 | verified-by AC | 备注     |
| ------ | ---------------------------------------- | -------------- | -------- |
| TC-001 | 初始化库存（合法 SKU，total>=0）→ 成功   | AC-001         | S1       |
| TC-002 | 不存在 SKU 初始化 → 拒绝                 | AC-002         | S1       |
| TC-003 | 重复初始化 → CONFLICT                    | AC-003         | S1       |
| TC-004 | 负库存初始化 → 拒绝                      | AC-004         | S1       |
| TC-005 | 单 SKU 查询 total/locked/available       | AC-005         | S1       |
| TC-006 | 批量 SKU 查询                            | AC-006         | S1       |
| TC-007 | 后台分页查询                             | AC-007         | S1       |
| TC-008 | 调整库存正/负 delta + 流水               | AC-008         | S2       |
| TC-009 | 调整后 total<0 → 拒绝                    | AC-009         | S2       |
| TC-010 | 锁定成功 locked+=q                       | AC-010         | S3       |
| TC-011 | 锁定超额 → STOCK_INSUFFICIENT            | AC-011         | S3       |
| TC-012 | 幂等锁定                                 | AC-012         | S3       |
| TC-013 | 释放成功 locked-=q                       | AC-013         | S3       |
| TC-014 | 幂等释放                                 | AC-014         | S3       |
| TC-015 | 确认扣减 total/locked -=q                | AC-015         | S4       |
| TC-016 | 幂等扣减                                 | AC-016         | S4       |
| TC-017 | 非 LOCKED 状态扣减 → 拒绝                | AC-017         | S4       |
| TC-018 | 流水记录 INIT/ADJUST/LOCK/RELEASE/DEDUCT | AC-018         | 全 Story |
| TC-019 | 并发锁定 SQL 条件更新                    | AC-019         | S3       |
| TC-020 | 前端库存页 + 权限保护                    | AC-020         | S1       |
| TC-021 | 表无 product 主数据字段                  | AC-021         | S1       |

各 Story 详细测试设计见对应 Story 目录下 test-design.md。
