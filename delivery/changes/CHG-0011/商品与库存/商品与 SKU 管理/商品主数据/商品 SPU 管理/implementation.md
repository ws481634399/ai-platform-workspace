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
- [x] 所有 DU 进入测试（du-fan-in-testing）
- [x] 所有 DU completed（du-fan-in-complete）

## 5. 交付后联调补全（2026-09-13）

- 缺陷：真实集成环境点击商品列表页，`/api/admin/products/**` 经网关 404——DU-BE-304 交付了 ProductAdminController 但网关未配 products 路由（同类遗漏参见 CHG-0007 身份路由、CHG-0010 手工联调登记项）。
- 修复（repo-1 mall-gateway application.yml）：新增路由 `mall-product-admin-spu`，`Path=/api/admin/products/**`（覆盖 SPU 端点与 `/{id}/skus` 子资源）→ `${MALL_GATEWAY_PRODUCT_URI:http://localhost:8103}`，与 CHG-0010 分类品牌路由共用同一覆写变量。
- 权限链路依赖：商品接口 `@PreAuthorize('product:product:*')` 的跨服务权限传播依赖 CHG-0010 补全的 RedisSnapshotAuthorityConverter（见 CHG-0010 分类管理 Story implementation.md §5），本次联调同时验证该公共机制对本 Story 生效。
- 实测（2026-09-13，经网关）：`GET /api/admin/products?pageNo=1&pageSize=10` → 200 空分页；`GET /api/admin/products/999` → 业务 404 B2141（路由与鉴权均通）。
