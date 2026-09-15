# Implementation（跨仓实施汇总）— 商城商品列表 STORY-003-02-02-01

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0017（商城商品浏览体验）
- Story：STORY-003-02-02-01 商城商品列表
- 实施日期：2026-09-16

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-703 | repo-1 | mall-product 90/90（新增 6 + 既有 84） |
| DU-FE-703 | repo-2 | mall-web 71/71（新增 3 + 既有 68），build 成功 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 751a792 | DU-BE-703 | repo-1 | 商品列表增强：brandIds 多选、子孙分类、价区派生表排序、size≤50 |
| 5a97392 | DU-FE-703 | repo-2 | 商品列表页：分类树+品牌多选+排序+分页，query 唯一状态源 |

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0017/商城前台/商品浏览/商品列表与详情/商城商品列表/DU-BE-703/implementation.md`
  - `ProductMapper.selectMallPage` 自定义 SQL LEFT JOIN 价区派生表，ORDER BY 白名单
  - 子孙分类深度≤3 内存展开，分类不存在返空页；brandIds 去重上限50
- repo-2：`implementation/ai-platform-frontend/delivery/CHG-0017/商城前台/商品浏览/商品列表与详情/商城商品列表/DU-FE-703/implementation.md`
  - ProductListView route.query 唯一状态源，requestSeq 竞态防护

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-006 | 列表分页 size≤50，minPrice/maxPrice 非空 | passed（sizeCap50 / priceRangeNonNull） |
| AC-007 | 子孙分类展开（深度≤3） | passed（descendantCategory） |
| AC-008 | brandIds 多选交集 | passed（brandIdsMultiSelect） |
| AC-009 | 四种排序，价区排序走派生表 SQL | passed（sortByPrice） |
| AC-020 | 列表页筛选/排序/分页与 URL query 双向同步 | passed（ProductListView watch route） |

## 5. 前置 Story 代码提交（repos-coverage 累计）

| Commit | Story | 说明 |
| --- | --- | --- |
| b4b5a1f | STORY-003-02-01-02 | 公开分类树/品牌接口 + 网关白名单 |
| b982bf5 | STORY-003-02-03-01 | SKU 可售状态聚合 |
| 868ee02 | STORY-003-02-01-01 | 商城首页聚合 |
| 2c85e52 | STORY-003-02-01-01 | 商城首页 FE |
