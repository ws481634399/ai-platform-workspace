---
affected-repositories: [repo-1]
story-id: "STORY-005-01-02-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §2.0/§2.2/§2.5
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0020
- Story ID: STORY-005-01-02-01
- 状态流转: specified → designed
- 相关仓库: repo-1（mall-search/mall-gateway）、repo-4（ES 运行环境，复用 DU-WS-501）
- 需要 Migration: no
- 数据变更概要: 无（ES 索引由 CHG-0021 生命周期组件创建；查询侧缺索引按 B0501 处理）

## 1. 模块改动（Module Changes）

### repo-1 mall-search（DU-BE-502）

- domain.search：SearchDocument（字段与 docId 见需求设计 §2.2 冻结）、SearchQuery（keyword/sort/page/size；本 Story 仅 keyword+分页，过滤字段在 STORY-005-01-02-02 加入同一对象）、SearchPage<T>、SortMode 枚举（DEFAULT/PRICE_ASC/PRICE_DESC/NEWEST）。
- application.search.ProductSearchService：参数归一（trim、page 默认 1、size 默认 20 上限 100）、组装 ES bool/multi_match 查询、hits→SearchDocument→SearchProductItemMapper（VO 字段名严格对齐 PRD：id/name/imageUrl/priceFen... 以 story-spec 契约为准）、total 取 hits.total.value。
- infrastructure.elasticsearch.ElasticsearchProductSearchRepository（implements domain 端口）：
  - bool.must[multi_match(productName^3, keywords, brandName, categoryName; operator or)]；keyword 为空时 must 不追加；
  - 过滤 status=ON_SALE（仅售在架，同步侧保证；查询侧仍显式 filter 兜底）；
  - sort 见 STORY-005-01-02-02（本 Story 先实现 DEFAULT：_score desc, updatedAt desc）。
- interfaces.rest.mall.MallSearchController：GET /api/mall/search/products（permitAll 由网关与本地 security permitAll 双保险），UnifyResult 包裹；参数绑定失败 → B0502。
- mall-gateway application.yml：- Path=/api/mall/search/** → lb://mall-search，白名单常量类/配置补 /api/mall/search（匿名）。

## 2. 接口契约细化

| 方法 | 路径 | 参数 | 响应 |
| --- | --- | --- | --- |
| GET | /api/mall/search/products | keyword(≤64)、page(≥1 默认1)、size(1..100 默认20) | UnifyResult\<SearchPage<ProductSearchItem>> |

ProductSearchItem 字段（冻结）：productId(long)、productName(string)、mainImage(string,可空)、minPrice(long,分)、maxPrice(long,分)、categoryId(long)、categoryName(string)、brandId(long,可空)、brandName(string,可空)。
分页响应：items[]、total(long)、page(int)、size(int)。
非法分页（page<1/size 越界/keyword 超长）：B0502 400，message 指明字段。

## 3. 数据变更

无。查询索引 mall_products 别名由 CHG-0021 保证存在。

## 4. 错误处理

- ES 异常 → B0501（复用 STORY-005-01-01-02 Advice）；参数异常 → B0502；空结果 200 空 items。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-502 | repo-1 | mall-search 关键词查询/分页/结果映射 + 网关路由放行 | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008 | 无 |

> 跨 Story 依赖（不入本表 depends-on）：DU-BE-502 实际前置 DU-WS-501（STORY-005-01-01-01）与 DU-BE-501（STORY-005-01-01-01/02）；执行顺序服从 requirement-design.md §5 Story 设计分派。

## 6. 测试策略

- AbstractElasticsearchIT：bulk 造数（含中英文、无图、无品牌、无命中关键词），断言：命中排序 _score、分页 total/items 长度、默认分页、非法参数 400、ES 停服 503。
- gateway 路由：路由断言单测/或在集成阶段验证（Integration Gate）。
