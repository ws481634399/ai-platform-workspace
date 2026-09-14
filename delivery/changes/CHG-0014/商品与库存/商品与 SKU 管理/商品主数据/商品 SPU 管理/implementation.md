# Implementation（跨仓实施汇总）— 商品 SPU 管理 STORY-002-02-01-01

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文位于各实现仓 DU 目录。

## 0. 元信息

- Change ID：CHG-0014
- Story：STORY-002-02-01-01 商品 SPU 管理
- 实施日期：2026-09-14
- 范围边界：不包含手机端与 M3 mall-web 商品列表/详情页。

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-401 | repo-1（ai-platform-backend） | 完成并验证 |
| DU-FE-402 | repo-2（ai-platform-frontend） | 完成并验证 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 6efd0b9 | DU-BE-401 | repo-1 | Product 聚合创建、Gateway Product routes、Inventory SERVICE 安全边界及测试 |
| b34ae62 | DU-FE-402 | repo-2 | mall-admin 商品聚合编辑页、HTTP 401/路由/lint 回归及测试 |
| a89fe9e | DU-FE-402 | repo-2 | 补充 payload 自动化测试并收口异步错误处理 |
| 5f9067c | DU-FE-402 | repo-2 | 拆分商品资源编辑子组件，页面主文件收敛到 300 行 |

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0014/商品与库存/商品与 SKU 管理/商品主数据/商品 SPU 管理/DU-BE-401/implementation.md`
- repo-2：`implementation/ai-platform-frontend/delivery/CHG-0014/商品与库存/商品与 SKU 管理/商品主数据/商品 SPU 管理/DU-FE-402/implementation.md`

## 4. 与 Task 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001, AC-002 | Product 初始 SKU 聚合事务与 API 测试 | passed |
| AC-003, AC-004 | mall-admin 图片/属性/创建前 SKU 表单与浏览器检查 | passed |
| AC-005, AC-006 | Gateway Product route contract tests | passed |
| AC-007 | Inventory anonymous/ADMIN/SERVICE 安全测试 | passed |
| AC-008 | HTTP login 401 回归测试 | passed |
| AC-009 | Vitest/type-check/lint/build | passed |

## 5. Fan-in 与验证结论

- 后端完整 Maven reactor：171 passed，0 failed/error/skipped。
- mall-admin：31 tests passed；type-check、lint（0 error）与 build 通过。
- 实际页面：管理员登录成功，商品新建页图片、属性和 SKU 区块正常显示。
- 未重启或终止用户当前运行的服务；源码变更需在用户下次重启对应后端服务后进入运行态。
