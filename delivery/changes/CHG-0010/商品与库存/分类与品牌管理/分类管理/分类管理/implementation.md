# Implementation（跨仓实施汇总）— 分类管理 STORY-002-01-01-01

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文在各实现仓 DU 目录（Reference do not duplicate）。

## 0. 元信息

- Change ID: CHG-0010
- Story: STORY-002-01-01-01 分类管理
- Test Design 来源: 本目录 test-design.md
- DU Task 来源: repo-1 DU-BE-302、repo-2 DU-FE-301 各仓 task-design.md / task-spec.md
- 状态流转: tasked → developing
- 开始时间: 2026-09-13

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 | Baseline | Result |
| --- | --- | --- | --- | --- |
| DU-BE-302 | repo-1（ai-platform-backend） | completed | 57b6534 | ca7eb95 |
| DU-FE-301 | repo-2（ai-platform-frontend） | completed | df16f31 | a4e3d06 |

## 2. Commit 记录

> Story 级机检（repos-coverage）要求与 Change 级 evidence.yaml 全量 code-change 对齐，故列 Change 全部 Commit；本 Story 直接相关为 DU-BE-302 / DU-FE-301 行。

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 57b6534 | DU-BE-302 | repo-1 | 开发基线（非本 DU 改动） |
| ca7eb95 | DU-BE-302 | repo-1 | feat(category): 分类后端、安全/权限/迁移/网关公共前置 |
| df16f31 | DU-FE-301 | repo-2 | 开发基线（非本 DU 改动） |
| c2f2c9c | DU-FE-301 | repo-2 | feat(category): 分类树维护页 |
| a4e3d06 | DU-FE-301 | repo-2 | docs(category): DU-FE-301 证据与元数据 |
| db43b7b | DU-BE-303 | repo-1 | 开发基线（姊妹 Story，非本 Story 改动） |
| 370ce59 | DU-BE-303 | repo-1 | feat(brand): 品牌主数据后端与分页能力（姊妹 Story） |
| 7cba45e | DU-BE-303 | repo-1 | docs(brand): DU-BE-303 证据与元数据（姊妹 Story） |
| 0789e6b | DU-FE-302 | repo-2 | feat(brand): 品牌维护页（姊妹 Story） |
| 6feacef | DU-FE-302 | repo-2 | docs(brand): DU-FE-302 证据与元数据（姊妹 Story） |

## 3. 各仓实施引用

### repo-1（ai-platform-backend / mall-product + mall-identity + mall-gateway）

- DU implementation: implementation/ai-platform-backend/delivery/CHG-0010/商品与库存/分类与品牌管理/分类管理/分类管理/DU-BE-302/implementation.md
- 范围：分类聚合/规则/应用服务/仓储、管理端五端点与方法级权限、V1 分类品牌建表迁移、identity V3 权限菜单、gateway 静态路由、根 pom `<parameters>`、共享安全测试切片。

### repo-2（ai-platform-frontend / mall-admin）

- DU implementation: implementation/ai-platform-frontend/delivery/CHG-0010/商品与库存/分类与品牌管理/分类管理/分类管理/DU-FE-301/implementation.md
- 范围：category API 客户端、CategoryTreeView 树表维护页、component-registry 注册 CategoryTree。

## 4. Fan-in 状态

- [x] 所有 DU 物化完成（du-materialized）
- [x] 所有 DU 进入测试（du-fan-in-testing）
- [x] 所有 DU completed（du-fan-in-complete）

## 5. 交付后联调补全（2026-09-13）

- 触发：convergence.md §3 登记的浏览器手工联调走查在真实集成环境执行时，发现分类/品牌接口经网关访问返回 403（自动化测试用 mock 权限无法暴露）。
- 根因：JWT 不含权限码、网关不透传权限，下游 mall-product 从恒为空的 `permissions` claim 取权；另 identity 未配 REDIS_PASSWORD 致授权快照从未写入 Redis。
- 修复（代码在 repo-1，回刷正文见仓内 DU-BE-302 implementation.md「交付后联调补全」）：
  - mall-common-security 新增 AuthorizationKeys / AuthoritySnapshot / RedisSnapshotAuthorityConverter（经共享 Redis 指针+快照加载权限，fail-closed）；
  - mall-identity 快照写入时同步维护 `authz:current:{adminId}` 指针，补 spring.data.redis.*；
  - mall-product 安全链改用新转换器，补 spring.data.redis.*。
- 实测：登录 → bootstrap 后 GET /api/admin/categories/tree 与 GET /api/admin/brands 经网关均 200，分类管理页面可正常进入与展示。
- 后续约束：CHG-0011/0012/0013 下游服务资源服务器统一接入该转换器（inventory 属 CHG-0013 范围）。
