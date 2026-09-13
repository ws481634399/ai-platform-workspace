# Implementation（跨仓实施汇总）— 库存初始化与查询 STORY-002-04-01-01

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文在各实现仓 DU 目录。

## 0. 元信息

- Change ID: CHG-0013
- Story: STORY-002-04-01-01 库存初始化与查询
- Test Design 来源: 本目录 test-design.md
- DU Task 来源: repo-1 DU-BE-401、repo-2 DU-FE-401 各仓 task-design.md / task-spec.md
- 状态流转: tasked → developing
- 开始时间: 2026-09-13

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
| --- | --- | --- | --- | --- |
| DU-BE-401 | repo-1（ai-platform-backend） | completed | c93d113 | 08d619f |
| DU-FE-401 | repo-2（ai-platform-frontend） | completed | 1420de6 | 8a52622 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 08d619f | DU-BE-401/402/403/404 | repo-1 | feat(inventory): 库存核心领域模型与持久化层 |
| e2bff4b | DU-BE-401/402/403/404 | repo-1 | feat(inventory): 库存应用服务与管理端/内部接口 |
| 8a52622 | DU-FE-401 | repo-2 | feat(admin): 库存列表与流水前端页面 |

## 3. 各仓实施引用

### repo-1（ai-platform-backend / mall-inventory）

- DU implementation: implementation/ai-platform-backend/delivery/CHG-0013/商品与库存/库存核心能力/库存基础/库存初始化与查询/DU-BE-401/implementation.md
- 范围：Inventory 聚合根 initialize/getAvailableQuantity；InventoryApplicationService init/page/getBySkuId/batchGet；InventoryAdminController 分页/详情/批量/初始化；SkuClient 校验 SKU；V1 建表迁移；mall-identity V6 权限。

### repo-2（ai-platform-frontend / mall-admin）

- DU implementation: implementation/ai-platform-frontend/delivery/CHG-0013/商品与库存/库存核心能力/库存基础/库存初始化与查询/DU-FE-401/implementation.md
- 范围：inventory.ts API；InventoryListView.vue 列表+初始化+调整弹窗；InventoryLogView.vue 流水列表；component-registry 注册。
