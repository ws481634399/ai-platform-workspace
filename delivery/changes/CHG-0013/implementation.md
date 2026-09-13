# Implementation（跨仓实施汇总）— CHG-0013

> 阶段：sdd-dev 产物（Change 级聚合）
> 本文件不承载实施正文；Story 级实施汇总见各 Story 目录 implementation.md，DU 正文在各实现仓 delivery/ 目录。

## 0. 元信息

- Change ID: CHG-0013
- Test Design 来源: 四 Story test-design.md
- DU Task 来源: repo-1 DU-BE-401/402/403/404、repo-2 DU-FE-401 各仓 task-design.md / task-spec.md
- 状态流转: tasked → developing
- 开始时间: 2026-09-13

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
| --- | --- | --- | --- | --- |
| DU-BE-401（库存初始化与查询后端） | repo-1 | completed | c93d113 | 08d619f |
| DU-BE-402（库存调整与流水后端） | repo-1 | completed | c93d113 | 08d619f |
| DU-BE-403（库存锁定与释放后端） | repo-1 | completed | c93d113 | 08d619f |
| DU-BE-404（库存确认扣减后端） | repo-1 | completed | c93d113 | 08d619f |
| DU-FE-401（库存列表与流水前端） | repo-2 | completed | 1420de6 | 8a52622 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| c93d113 | — | repo-1 | 开发基线 |
| 08d619f | DU-BE-401/402/403/404 | repo-1 | feat(inventory): 库存核心领域模型与持久化层 |
| e2bff4b | DU-BE-401/402/403/404 | repo-1 | feat(inventory): 库存应用服务与管理端/内部接口 |
| eacca66 | DU-BE-401/402/403/404 | repo-1 | feat: 库存跨服务支持与权限路由 |
| b453261 | DU-BE-401/402/403/404 | repo-1 | test(inventory): 库存聚合与预留状态机单元测试 |
| 1420de6 | — | repo-2 | 开发基线 |
| 8a52622 | DU-FE-401 | repo-2 | feat(admin): 库存列表与流水前端页面 |

## 3. 各仓实施引用

### repo-1（ai-platform-backend / mall-inventory）

- 库存初始化与查询：implementation/ai-platform-backend/delivery/CHG-0013/商品与库存/库存核心能力/库存基础/库存初始化与查询/DU-BE-401/implementation.md
- 库存调整与流水：implementation/ai-platform-backend/delivery/CHG-0013/商品与库存/库存核心能力/库存调整/库存调整与流水/DU-BE-402/implementation.md
- 库存锁定与释放：implementation/ai-platform-backend/delivery/CHG-0013/商品与库存/库存核心能力/库存预留/库存锁定与释放/DU-BE-403/implementation.md
- 库存确认扣减：implementation/ai-platform-backend/delivery/CHG-0013/商品与库存/库存核心能力/库存确认/库存确认扣减/DU-BE-404/implementation.md

### repo-2（ai-platform-frontend / mall-admin）

- 库存列表与流水前端：implementation/ai-platform-frontend/delivery/CHG-0013/商品与库存/库存核心能力/库存基础/库存初始化与查询/DU-FE-401/implementation.md
