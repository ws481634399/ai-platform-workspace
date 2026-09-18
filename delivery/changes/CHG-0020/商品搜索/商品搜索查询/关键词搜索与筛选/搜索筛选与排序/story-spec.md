---
story-id: "STORY-005-01-02-02"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S3]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 闭输入：requirement-spec.md §3.1 [S3]/§4/§5
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0020
- Story ID: STORY-005-01-02-02 搜索筛选与排序
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`（S3）

## 1. Story 目标

在关键词搜索之上提供组合筛选与基础排序：categoryId、brandId、minPrice/maxPrice 的 bool 组合过滤；default/price_asc/price_desc/newest 四种排序；筛选、排序、分页自由组合；非法参数安全回退/拒绝。

## 2. Scope（范围）

### 2.1 包含

- [S3] GET /api/mall/search/products 新增参数 categoryId、brandId、minPriceFen、maxPriceFen、sort。
- [S3] ES bool filter：term categoryId / term brandId / range minPriceFen-lte-maxPriceFen（价格对 minPrice/maxPrice 摘要字段过滤，M5 口径：商品任一可售 SKU 价格区间与筛选区间相交；design 细化 range 语义）。
- [S3] 排序：default（_score/updatedAt 兜底）、price_asc（minPrice asc）、price_desc（maxPrice desc 或 minPrice desc，design 定一个）、newest（publishedAt desc, updatedAt 兜底）。
- [S3] 参数校验：min>max → 400；非法 sort 回退 default；非正 ID 忽略。

### 2.2 不包含

- 分类子孙树展开（M5 按 categoryId 精确过滤；需要子树时前端后续增强或 CHG-0021 冗余 ancestorIds，本期不做）。
- facet 聚合计数、销量/综合排序、多品牌多选（M5 brandId 单选）。

## 3. 业务规则

- [组合] keyword 与各筛选以 bool must/filter 叠加，结果同时满足全部条件。
- [价格闭区间] minPriceFen/maxPriceFen 均为整数分闭区间；只传一侧按单边过滤；min>max 返回 B05xx/400 参数错误。
- [排序枚举] default/price_asc/price_desc/newest 全平台唯一；未知值不报错，回退 default。
- [分页] 继承 STORY-005-01-02-01 规则；筛选+排序下 total 为过滤后总数。

## 4. 接口与字段规格

- `GET /api/mall/search/products?keyword=&categoryId=&brandId=&minPriceFen=&maxPriceFen=&sort=default|price_asc|price_desc|newest&page=&size=`
  - 200 同分页结构；400 参数错误（min>max）；503 搜索不可用。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | categoryId 过滤仅返回该分类文档；brandId 同理 |
| AC-002 | minPriceFen/maxPriceFen 闭区间过滤正确（边界值文档命中）；只传 min/max 单边生效 |
| AC-003 | 关键词+品牌+价格区间同时传入，结果同时满足三条件 |
| AC-004 | sort=price_asc 结果按价格严格升序、price_desc 严格降序；newest 按发布时间倒序 |
| AC-005 | sort=unknown 回退 default 且不报错；default 排序稳定 |
| AC-006 | minPriceFen>maxPriceFen → 400 统一参数错误结构；非数字参数 → 400 |
| AC-007 | 筛选+排序+分页组合下 total/切片正确；ON_SALE 过滤始终生效 |
