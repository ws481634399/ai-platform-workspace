# Implementation（跨仓实施汇总）— 公开分类与品牌查询 STORY-003-02-01-02

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文位于各实现仓 DU 目录。

## 0. 元信息

- Change ID：CHG-0017（商城商品浏览体验）
- Story：STORY-003-02-01-02 公开分类与品牌查询
- 实施日期：2026-09-15
- 范围边界：商城公开分类树（启用、禁用父整枝剪除）、品牌分页（仅 ENABLED、keyword 模糊转义、size≤200）、网关匿名白名单。

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-702 | repo-1（ai-platform-backend） | 完成并验证：mall-product 75/75（新增 5 + 既有 70）、mall-gateway 19/19 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| b4b5a1f | DU-BE-702 | repo-1 | feat(product): 公开分类树与品牌查询接口 + 网关白名单 |

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0017/商城前台/商品浏览/首页与公开分类品牌/公开分类与品牌查询/DU-BE-702/implementation.md`
  - DEV-1：BrandRepositoryImpl.page() 链式 `.eq(boolean,...)` 改 if 块（ECJ 重载推断失败）；keyword 改 `LIKE ... ESCAPE '!'` + 转义 `%`/`_`/`!`
  - 网关 mall-product-mall 路由 predicate 与白名单一次性追加后续 home/skus 路径（本 Story 先写全）

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-003 | categories/tree 匿名 200，仅启用分类树，禁用父整枝剪除（含启用子），按 sort 排序 | passed（MallCatalogApiTest::categoryTreeEnabledOnlyAndPrune） |
| AC-004 | brands 匿名 200，仅 ENABLED，keyword 模糊，id 字符串 | passed（MallCatalogApiTest::brandsEnabledKeywordAndSizeCap） |
| AC-005 | internal 路径外部不可达（沿用 CHG-0015 denyAll） | passed（GatewaySecurityConfiguration /api/internal/** denyAll） |
