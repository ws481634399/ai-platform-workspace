# Implementation（跨仓实施汇总）— 库存锁定与释放 STORY-002-04-03-01

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文在各实现仓 DU 目录。

## 0. 元信息

- Change ID: CHG-0013
- Story: STORY-002-04-03-01 库存锁定与释放
- Test Design 来源: 本目录 test-design.md
- DU Task 来源: repo-1 DU-BE-403 task-design.md / task-spec.md
- 状态流转: tasked → developing
- 开始时间: 2026-09-13

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
| --- | --- | --- | --- | --- |
| DU-BE-403 | repo-1（ai-platform-backend） | completed | c93d113 | 08d619f |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| c93d113 | — | repo-1 | 开发基线 |
| 08d619f | DU-BE-401/402/403/404 | repo-1 | feat(inventory): 库存核心领域模型与持久化层 |
| e2bff4b | DU-BE-401/402/403/404 | repo-1 | feat(inventory): 库存应用服务与管理端/内部接口 |
| eacca66 | DU-BE-401/402/403/404 | repo-1 | feat: 库存跨服务支持与权限路由 |
| b453261 | DU-BE-401/402/403/404 | repo-1 | test(inventory): 库存聚合与预留状态机单元测试 |

## 3. 各仓实施引用

### repo-1（ai-platform-backend / mall-inventory）

- DU implementation: implementation/ai-platform-backend/delivery/CHG-0013/商品与库存/库存核心能力/库存预留/库存锁定与释放/DU-BE-403/implementation.md
- 范围：Inventory.lock/release 校验；InventoryReservation 状态机 LOCKED→RELEASED；lockStock SQL 条件更新并发安全；reservationId 幂等；InternalInventoryController POST /lock、/release；V2 inventory_reservation 表。
