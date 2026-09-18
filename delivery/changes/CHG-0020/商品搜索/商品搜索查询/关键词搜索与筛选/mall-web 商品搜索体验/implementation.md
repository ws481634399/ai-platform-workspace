# Implementation（跨仓实施汇总）— mall-web 商品搜索体验 STORY-005-01-02-03

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0020（Elasticsearch 商品搜索）
- Story：STORY-005-01-02-03 mall-web 商品搜索体验
- 实施日期：2026-09-18

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-FE-501 | repo-2（ai-platform-frontend） | mall-web 搜索 API 客户端/Pinia store/搜索结果页（URL 状态源、筛选排序分页、三态、元分换算、竞态防护）+ /search 路由；search.spec.ts 5 例，store/视图专属单测缺（见 DEV） |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| ec0921b | DU-FE-501 | repo-2 | feat(web): mall-web 商品搜索体验（api/search.ts、stores/search.ts、SearchView、/search 路由；同提交含 CHG-0022 关闭态） |

## 3. 各仓实施引用

- repo-2（ai-platform-frontend）：
  - 实施记录：`implementation/ai-platform-frontend/delivery/CHG-0020/商品搜索/商品搜索查询/关键词搜索与筛选/mall-web 商品搜索体验/DU-FE-501/implementation.md`
  - 要点：
    - `src/api/search.ts`：ProductSearchItem 7 字段/ProductSearchPage{items,total,page,size}/ProductSearchSort（''|price_asc|price_desc|newest）；serializeSearchQuery 空值省略、0 分边界保留；searchApi.products 调 GET /api/mall/search/products 并解包 UnifyResult。
    - `src/stores/search.ts`：Pinia setup store（keyword/filters/sort/page/size20/items/total/loading/error）；requestSeq 序号竞态防护（旧响应丢弃）；resolveErrorMessage 归一文案；resetFilters。
    - `src/views/search/SearchView.vue`：route.query 唯一状态源（watch fullPath immediate）；四排序 Tab；元↔分 Math.round 换算；最低>最高提示「最低价格不能高于最高价格」拦截不发请求；StateView 三态；热门词；卡片 router.push('/products/'+id)；分页；search.enabled 关闭态（CHG-0022）。
    - `src/router/index.ts`：search→SearchView（第 49–54 行）、products/:id→ProductDetailView（第 55–60 行）；`MallLayout.vue` nav「搜索」链接，Header 全局搜索框实际跳 /products?keyword=（偏离见下）。

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | 搜索框回车进入结果页并回显关键词、展示结果卡片 | passed（/search 页内搜索框 + nav 入口；Header 全局框实际跳 /products?keyword= 列表页，见 DU-FE-501 DEV-1，功能可达但入口与设计有差异） |
| AC-002 | 筛选/四排序/分页与 URL query 双向同步，刷新/前进后退一致 | passed（SearchView route.query 唯一状态源、buildRouterQuery 空值省略/page>1 才带；无独立组件测试） |
| AC-003 | 加载/空/失败三态明确，失败可重试、空态有热门词/逛商品出口 | passed（StateView + resolveErrorMessage 重试；关闭态另有出口） |
| AC-004 | 点卡片进入既有详情页正常渲染 | passed（router.push('/products/'+id)，products/:id 路由真实存在） |
| AC-005 | 元输入 Math.round 正确换算分；非法区间即时提示不发请求；0 分边界保留 | passed（SearchView yuanToFen/yuanFromFen + 拦截提示；search.spec.ts minPriceFen:0 边界用例） |
| AC-006 | vitest + type-check/lint/build 门禁 | partial（门禁脚本齐备；src/api/search.spec.ts 5 例：解包/空参省略/完整参/0 边界/三排序透传；**stores/search.spec.ts 与 SearchView 专属 spec 不存在**，竞态/三态/query 同步无自动化断言，见 DU-FE-501 DEV-2，需后续补测试或以 Integration Gate 联测闭合） |
