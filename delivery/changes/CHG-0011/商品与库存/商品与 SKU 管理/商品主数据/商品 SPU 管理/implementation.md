# Implementation（跨仓实施汇总）— 商品 SPU 管理 STORY-002-02-01-01

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文在各实现仓 DU 目录。

## 0. 元信息

- Change ID: CHG-0011
- Story: STORY-002-02-01-01 商品 SPU 管理
- Test Design 来源: 本目录 test-design.md
- DU Task 来源: repo-1 DU-BE-304、repo-2 DU-FE-303 各仓 task-design.md / task-spec.md
- 状态流转: tasked → developing
- 开始时间: 2026-09-13

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
| --- | --- | --- | --- | --- |
| DU-BE-304 | repo-1（ai-platform-backend） | completed | 7cba45e | 23a1dfb |
| DU-FE-303 | repo-2（ai-platform-frontend） | completed | 6feacef | f14ead4 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 7cba45e | DU-BE-304 | repo-1 | 开发基线（非本 DU 改动） |
| 23a1dfb | DU-BE-304 | repo-1 | feat(product): 商品 SPU 与 SKU 管理后端 |
| c65e75b | DU-BE-304 | repo-1 | docs(sdd): CHG-0011 DU-BE-304/305 任务产物 |
| 6feacef | DU-FE-303 | repo-2 | 开发基线（非本 DU 改动） |
| f14ead4 | DU-FE-303 | repo-2 | feat(product): 商品 SPU 与 SKU 管理前端 |

## 3. 各仓实施引用

### repo-1（ai-platform-backend / mall-product）

- DU implementation: implementation/ai-platform-backend/delivery/CHG-0011/商品与库存/商品与 SKU 管理/商品主数据/商品 SPU 管理/DU-BE-304/implementation.md
- 范围：Product 聚合根（SPU 基本信息/图片/属性/状态流转）、ProductApplicationService（create/update/changeStatus/page/getById）、ProductAdminController（/api/admin/products）、Flyway V2（product_spu / product_image / product_attribute）。

### repo-2（ai-platform-frontend / mall-admin）

- DU implementation: implementation/ai-platform-frontend/delivery/CHG-0011/商品与库存/商品与 SKU 管理/商品主数据/商品 SPU 管理/DU-FE-303/implementation.md
- 范围：product API 客户端、ProductListView（分页/筛选/分类品牌联动）、ProductEditView（基本信息 + SKU 管理）、component-registry 注册 ProductList、静态路由 ProductList/ProductEdit。

## 4. Fan-in 状态

- [x] 所有 DU 物化完成（du-materialized）
- [x] 所有 DU 进入 testing（du-fan-in-testing）
- [x] 所有 DU completed（du-fan-in-complete）
