# Implementation（跨仓实施汇总）— 搜索筛选与排序 STORY-005-01-02-02

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0020（Elasticsearch 商品搜索）
- Story：STORY-005-01-02-02 搜索筛选与排序
- 实施日期：2026-09-18

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-511 | repo-1（ai-platform-backend） | 类目/品牌 term、价格区间相交 range、四排序（DEFAULT/price_asc/price_desc/newest）、参数 400 校验；ProductSearchApiTest 4 个相关用例 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 82ccf6e | DU-BE-511 | repo-1 | feat(search): 筛选（categoryId/brandId/价格区间）与排序（价格升降/最新/默认）及非法参数 400 B0502 |

## 3. 各仓实施引用

- repo-1（ai-platform-backend）：
  - 实施记录：`implementation/ai-platform-backend/delivery/CHG-0020/商品搜索/商品搜索查询/关键词搜索与筛选/搜索筛选与排序/DU-BE-511/implementation.md`
  - 要点：
    - `SearchQuery`/`SortMode`：categoryId/brandId/minPriceFen/maxPriceFen（整数分）/sort；SortMode.from 仅认小写 price_asc/price_desc/newest，未知值回退 DEFAULT。
    - `ProductSearchService`：负价格/min>max 抛 IllegalArgumentException（400 B0502，文案可安全回显）；categoryId/brandId 非正经 positiveOrNull 忽略。
    - `ElasticsearchProductSearchAdapter`：term categoryId/brandId；价格区间相交（maxPriceFen→minPrice.lte、minPriceFen→maxPrice.gte，单边开边界）；排序 price_asc=[minPrice asc,_score]、price_desc=[maxPrice desc,_score]、newest=[publishedAt desc missing=_last,_score]、DEFAULT=[_score desc,updatedAt desc]；ON_SALE filter 恒效。
    - 测试布局：未单独建 QueryNormalizeTest/FilterSortIT，归一与 DSL 断言统一承载于 ProductSearchApiTest（见 DU DEV-2）。

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | categoryId/brandId term 过滤 | passed（ProductSearchApiTest.categoryAndBrandFilter：categoryId=10→4 条） |
| AC-002 | 价格闭区间/单边/相交（区间跨段商品命中、边界 30000 命中、max=5000 单边） | passed（ProductSearchApiTest.priceRangeIntersection） |
| AC-003 | 多条件组合取交集（keyword multi_match + 双 term + range 同 BoolQuery） | passed（categoryAndBrandFilter 叠加 brandId=100→2 条，类目 20 的 id5 被排除；priceRangeIntersection 带关键词组合） |
| AC-004 | price_asc/price_desc 严格序；newest 按 publishedAt 降序、null 排尾 | passed（ProductSearchApiTest.sorts：升序 2,6,1,3；降序首 3 尾 2；newest id1 在前、id6 第 4） |
| AC-005 | 未知 sort 值不报错、回退默认综合排序 | passed（ProductSearchApiTest.invalidParams：sort=hacker→200） |
| AC-006 | min>max、负价格 →400 统一 B0502；非数字为框架类型异常（DU-BE-502 DEV-1） | passed（invalidParams：min30000>max10000、min=-1、keyword 65 长度均 400 B0502） |
| AC-007 | 组合条件下 total 为过滤后命中数且 ON_SALE 恒效（OFF_SALE id4 任何组合不出现） | passed（sorts/categoryAndBrandFilter 组合数据集断言；trackTotalHits 命中数） |
