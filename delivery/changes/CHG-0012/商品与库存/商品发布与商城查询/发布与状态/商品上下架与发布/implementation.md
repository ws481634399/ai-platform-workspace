# Implementation（跨仓实施汇总）— 商品上下架与发布 STORY-002-03-01-01

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文在各实现仓 DU 目录。

## 0. 元信息

- Change ID: CHG-0012
- Story: STORY-002-03-01-01 商品上下架与发布
- Test Design 来源: 本目录 test-design.md
- DU Task 来源: repo-1 DU-BE-306、repo-2 DU-FE-304 各仓 task-design.md / task-spec.md
- 状态流转: tasked → developing
- 开始时间: 2026-09-13

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
| --- | --- | --- | --- | --- |
| DU-BE-306 | repo-1（ai-platform-backend） | completed | 25fcddc | f0a26b3 |
| DU-FE-304 | repo-2（ai-platform-frontend） | completed | 036a77c | d7f9034 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 25fcddc | DU-BE-306 | repo-1 | 开发基线（非本 DU 改动） |
| f0a26b3 | DU-BE-306/307/308 | repo-1 | feat(CHG-0012): 商品上下架与发布、商城查询、内部契约快照 |
| 036a77c | DU-FE-304 | repo-2 | 开发基线（非本 DU 改动） |
| d7f9034 | DU-FE-304 | repo-2 | feat(CHG-0012): 商品列表增加上架/下架操作 |

## 3. 各仓实施引用

### repo-1（ai-platform-backend / mall-product）

- DU implementation: implementation/ai-platform-backend/delivery/CHG-0012/商品与库存/商品发布与商城查询/发布与状态/商品上下架与发布/DU-BE-306/implementation.md
- 范围：Product 聚合新增 publish()/unpublish() 行为与领域事件注册；ProductApplicationService 新增 publish/unpublish；ProductAdminController 新增 POST /{id}/publish、POST /{id}/unpublish；ProductErrorCode 新增 B2150/B2151/B2152；ProductException 新增 publishValidationFailed/alreadyOnSale/notOnSale；mall-identity V5 迁移新增 product:product:publish 权限码。

### repo-2（ai-platform-frontend / mall-admin）

- DU implementation: implementation/ai-platform-frontend/delivery/CHG-0012/商品与库存/商品发布与商城查询/发布与状态/商品上下架与发布/DU-FE-304/implementation.md
- 范围：product.ts 新增 publish(id)/unpublish(id) API；ProductListView.vue 操作列增加上架/下架按钮与确认逻辑。

## 4. Fan-in 状态

- [x] 所有 DU 物化完成（du-materialized）
- [x] 所有 DU 进入 testing（du-fan-in-testing）
- [x] 所有 DU completed（du-fan-in-complete）
