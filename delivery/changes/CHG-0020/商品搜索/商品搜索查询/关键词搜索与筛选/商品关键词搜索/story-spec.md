---
story-id: "STORY-005-01-02-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S2]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.1 [S2]/§4/§5
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0020
- Story ID: STORY-005-01-02-01 商品关键词搜索
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`（S2）

## 1. Story 目标

交付商城搜索主读链路：mall-search 对 ES 别名 `mall_products` 执行多字段关键词检索（productName/keywords/brandName/categoryName），硬过滤上架状态，返回精简 SearchProductDTO 分页（productId/name/image/priceFen/brandName/categoryName），统一 UnifyResult；网关新增 `/api/mall/search/**` → 8107 游客可访问路由。

## 2. Scope（范围）

### 2.1 包含

- [S2] domain/search：SearchProductDocument 读模型（字段对齐 CHG-0021 索引文档：productId/productName/categoryId/categoryName/brandId/brandName/mainImage/keywords/status/minPrice/maxPrice/publishedAt/updatedAt）。
- [S2] infrastructure.elasticsearch：ElasticsearchSearchRepository（bool 查询：多字段 match + term status=ON_SALE；from/size 分页；default 排序）；SearchProductDTO 映射。
- [S2] interfaces.rest.mall：MallSearchController `GET /api/mall/search/products`（参数 keyword/page/size；本 Story 支持无关键词浏览）。
- [S2] 网关 mall-gateway：新增 mall-search-mall 路由（/api/mall/search/** → lb/直连 8107），公开访问放行；SearchSecurityConfiguration 配置 permitAll。
- [S2] 查询异常接入 STORY-005-01-01-02 的统一异常口径。

### 2.2 不包含

- 分类/品牌/价格筛选与排序参数（STORY-005-01-02-02）。
- mall-web 页面（STORY-005-01-02-03）；索引数据写入（CHG-0021）。

## 3. 业务规则

- [可售过滤] 任意查询（含无关键词浏览）必须带 status=ON_SALE term 过滤。
- [多字段匹配] keyword 对 productName（boost 较高）/keywords/brandName/categoryName 构建 multi-match/should；空白等同无条件。
- [读模型] 响应只含搜索摘要字段，禁止直接下发 ES 完整 _source 或 Product 聚合。
- [分页] page≥1（默认 1）；size 默认 20、最大 100；响应 {items,total,page,size}。
- [身份] 路由游客可访问；无任何写接口暴露在 mall 路由下。

## 4. 接口与字段规格

- `GET /api/mall/search/products?keyword=&page=1&size=20`（PUBLIC）
  - 响应 200：`{items:[{productId:"1",name,imageUrl,priceFen,brandName,categoryName}], total, page, size}`（UnifyResult 包裹）
  - 错误：B0501 搜索不可用 503。
- 查询目标：别名 mall_products（CHG-0021 建立）。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | Testcontainers 索引样例文档后，关键词命中 productName 可检出；命中 keywords/brandName/categoryName 也可检出 |
| AC-002 | 索引中 status=OFF_SALE 文档在任何查询下不返回 |
| AC-003 | 响应项仅含 productId/name/imageUrl/priceFen/brandName/categoryName 摘要字段，不含 SKU 列表等聚合字段 |
| AC-004 | page/size 切片正确、total 准确；size=500 被限制为 100；page=0/-1 回退第 1 页 |
| AC-005 | 无 keyword 返回 ON_SALE 商品 default 排序结果（搜索页浏览态） |
| AC-006 | 网关：无 token 经 8080 访问 GET /api/mall/search/products 返回 200（不 401） |
| AC-007 | 经网关访问 /api/internal/** 返回 404；mall-search 不存在任何经网关可达的写端点 |
| AC-008 | ES 故障时按统一 B05xx 口径返回（与 STORY-005-01-01-02 一致） |
