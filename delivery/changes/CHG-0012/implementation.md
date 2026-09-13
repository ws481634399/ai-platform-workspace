# Implementation（跨仓实施汇总）— CHG-0012

> 阶段：sdd-dev 产物（Change 级聚合）
> 本文件不承载实施正文；Story 级实施汇总见各 Story 目录 implementation.md，DU 正文在各实现仓 delivery/ 目录。

## 0. 元信息

- Change ID: CHG-0012
- Test Design 来源: 三 Story test-design.md
- DU Task 来源: repo-1 DU-BE-306/307/308、repo-2 DU-FE-304 各仓 task-design.md / task-spec.md
- 状态流转: tasked → developing
- 开始时间: 2026-09-13

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
| --- | --- | --- | --- | --- |
| DU-BE-306（商品上下架与发布后端） | repo-1 | completed | 25fcddc | 5df94fc |
| DU-BE-307（商城查询后端） | repo-1 | completed | 25fcddc | f1e75f6 |
| DU-BE-308（内部契约与快照后端） | repo-1 | completed | 25fcddc | c6baa1a |
| DU-FE-304（商品上下架前端） | repo-2 | completed | 036a77c | 2af5f93 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 25fcddc | DU-BE-306/307/308 | repo-1 | 开发基线 |
| f0a26b3 | DU-BE-306/307/308 | repo-1 | feat(CHG-0012): 商品上下架与发布、商城查询、内部契约快照 |
| 5df94fc | DU-BE-306/307 | repo-1 | docs(sdd): DU status completed |
| f1e75f6 | DU-BE-307/308 | repo-1 | docs(sdd): DU-BE-307/308 evidence |
| 036a77c | DU-FE-304 | repo-2 | 开发基线 |
| d7f9034 | DU-FE-304 | repo-2 | feat(CHG-0012): 商品列表增加上架/下架操作 |

## 3. 各仓实施引用

### repo-1（ai-platform-backend / mall-product）

- 商品上下架与发布：implementation/ai-platform-backend/delivery/CHG-0012/商品与库存/商品发布与商城查询/发布与状态/商品上下架与发布/DU-BE-306/implementation.md
- 商城商品列表与详情查询：implementation/ai-platform-backend/delivery/CHG-0012/商品与库存/商品发布与商城查询/商城查询/商城商品列表与详情查询/DU-BE-307/implementation.md
- 内部查询契约与商品快照：implementation/ai-platform-backend/delivery/CHG-0012/商品与库存/商品发布与商城查询/内部契约与快照/内部查询契约与商品快照/DU-BE-308/implementation.md

### repo-2（ai-platform-frontend / mall-admin）

- 商品上下架前端：implementation/ai-platform-frontend/delivery/CHG-0012/商品与库存/商品发布与商城查询/发布与状态/商品上下架与发布/DU-FE-304/implementation.md

### Story 级跨仓汇总

- 商品上下架与发布：商品与库存/商品发布与商城查询/发布与状态/商品上下架与发布/implementation.md
- 商城商品列表与详情查询：商品与库存/商品发布与商城查询/商城查询/商城商品列表与详情查询/implementation.md
- 内部查询契约与商品快照：商品与库存/商品发布与商城查询/内部契约与快照/内部查询契约与商品快照/implementation.md
