# Test Design（Change 级聚合）— CHG-0013 库存核心能力

> 阶段：sdd-task 聚合产物（多 Story Change）
> 各 Story 测试设计明细见各 Story test-design.md，本文件聚合测试矩阵与跨 Story 回归策略。

## 0. 元信息

- Change ID: CHG-0013
- 覆盖 Story: STORY-002-04-01-01、STORY-002-04-02-01、STORY-002-04-03-01、STORY-002-04-04-01
- 覆盖 DU: DU-BE-401/402/403/404、DU-FE-401

## 1. 测试矩阵（聚合）

| Story | AC 范围 | 后端用例 | 前端用例 |
| --- | --- | --- | --- |
| 库存初始化与查询 | AC-001~007, AC-018, AC-020, AC-021 | InventoryTest（initialize 系列）+ Controller 测试 | InventoryListView |
| 库存调整与流水 | AC-008, AC-009, AC-018 | InventoryTest.adjust* | InventoryListView 调整弹窗 |
| 库存锁定与释放 | AC-010~014, AC-018, AC-019 | InventoryTest.lockAndRelease + InventoryReservationTest | — |
| 库存确认扣减 | AC-015~017, AC-018 | InventoryTest.confirmDeduction + InventoryReservationTest | — |

## 2. 跨 Story 回归策略

- 后端单次 `mvn -pl mall-services/mall-inventory,mall-services/mall-product -am test` 覆盖全部 DU。
- 前端 `pnpm type-check && pnpm build` 验证 mall-admin 编译与构建。
- 并发安全（AC-019）通过 lockStock SQL 条件更新设计验证，集成测试留待后续。

## 3. Story 级测试设计引用

- 库存初始化与查询: 库存基础/库存初始化与查询/test-design.md
- 库存调整与流水: 库存调整/库存调整与流水/test-design.md
- 库存锁定与释放: 库存预留/库存锁定与释放/test-design.md
- 库存确认扣减: 库存确认/库存确认扣减/test-design.md
