# Test Design（Change 级聚合）— CHG-0013 库存核心能力

> 阶段：sdd-task 聚合产物（多 Story Change）
> 各 Story 测试设计明细见各 Story test-design.md。

- Change ID: CHG-0013
- 覆盖 Story: STORY-002-04-01-01、STORY-002-04-02-01、STORY-002-04-03-01、STORY-002-04-04-01
- 覆盖 DU: DU-BE-401、DU-BE-402、DU-BE-403、DU-BE-404、DU-FE-401

## DU 划分（聚合全部 Story）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-401 | repo-1 | 库存权限码 + Inventory 聚合、inventory_stock/inventory_log 表、初始化与查询 API、INIT 流水、SKU 契约校验 | AC-001,002,003,004,005,006,007,018,020,021 | CHG-0012 |
| DU-BE-402 | repo-1 | 库存调整领域方法、ADJUST 流水、调整 API | AC-008,009,018 | DU-BE-401 |
| DU-BE-403 | repo-1 | inventory_reservation 表、锁定/释放 API、SQL 条件更新、幂等、LOCK/RELEASE 流水 | AC-010,011,012,013,014,018,019 | DU-BE-401 |
| DU-BE-404 | repo-1 | 确认扣减 API、状态机、DEDUCT 流水、幂等 | AC-015,016,017,018 | DU-BE-403 |
| DU-FE-401 | repo-2 | mall-admin 库存列表、调整弹窗、流水页 | AC-007,008,018,020 | DU-BE-401、DU-BE-402 |

各 Story 测试用例与验证方式详见对应 Story 目录下 test-design.md。
