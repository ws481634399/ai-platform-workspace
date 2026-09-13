# Implementation（跨仓实施汇总）— 商城商品列表与详情查询 STORY-002-03-02-01

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文在各实现仓 DU 目录。

## 0. 元信息

- Change ID: CHG-0012
- Story: STORY-002-03-02-01 商城商品列表与详情查询
- Test Design 来源: 本目录 test-design.md
- DU Task 来源: repo-1 DU-BE-307 仓内 task-design.md / task-spec.md
- 状态流转: tasked → developing
- 开始时间: 2026-09-13

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
| --- | --- | --- | --- | --- |
| DU-BE-307 | repo-1（ai-platform-backend） | completed | 25fcddc | 5df94fc |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 25fcddc | DU-BE-306/307/308 | repo-1 | 开发基线（非本 DU 改动） |
| f0a26b3 | DU-BE-306/307/308 | repo-1 | feat(CHG-0012): 商品上下架与发布、商城查询、内部契约快照 |
| 5df94fc | DU-BE-306/307 | repo-1 | docs(sdd): CHG-0012 DU status completed |
| 036a77c | DU-FE-304 | repo-2 | 开发基线（非本 DU 改动） |
| d7f9034 | DU-FE-304 | repo-2 | feat(CHG-0012): 商品列表增加上架/下架操作 |

## 3. 各仓实施引用

### repo-1（ai-platform-backend / mall-product）

- DU implementation: implementation/ai-platform-backend/delivery/CHG-0012/商品与库存/商品发布与商城查询/商城查询/商城商品列表与详情查询/DU-BE-307/implementation.md
- 范围：MallProductController（GET /api/mall/products 列表、GET /api/mall/products/{id} 详情）、MallProductDtos（MallProductListItemView/MallProductDetailView，不含库存字段）、ProductRepository.mallPage（硬过滤 status=ON_SALE，按创建时间倒序）、ProductSecurityConfiguration（/api/mall/** permitAll）。

## 4. Fan-in 状态

- [x] 所有 DU 物化完成（du-materialized）
- [x] 所有 DU 进入 testing（du-fan-in-testing）
- [x] 所有 DU completed（du-fan-in-complete）
