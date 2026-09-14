---
story-id: "STORY-003-02-02-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S3, S6]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0017
- Story ID: STORY-003-02-02-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

mall-web 商品列表页与后端列表查询：分页、分类（含后代）/品牌多选筛选、四种排序、真实价区（整数分）、主图与名称；过滤下架与无有效 SKU 商品；完整空/错/加载态。

## 2. Scope（范围）

### 2.1 包含

- [S3] 列表查询参数（page/pageSize/categoryId/brandIds/sort）、后代分类展开、价区聚合、分页响应；mall-web 列表页（筛选栏、排序栏、分页、商品卡片）。
- [S6] 空结果/网络错误/Loading。

### 2.2 不包含

- 详情与 SKU 矩阵（STORY-003-02-02-02）；分类树品牌接口（STORY-003-02-01-02）；关键词搜索（M5）。

## 3. 业务规则

- pageSize 默认 20、最大 50；categoryId 筛选含全部后代；brandIds 多选取交集；未知参数忽略、非法 sort 回落 default。
- minPrice/maxPrice 一条分组 SQL 聚合启用 SKU；无启用 SKU 商品排除。
- 金额字段整数分；ID 字符串。

## 4. 接口与字段规格

- GET /api/mall/products?page=1&pageSize=20&categoryId=&brandIds=&sort=
- 响应：{ total, page, pageSize, records: [{ id, name, mainImageUrl, minPrice, maxPrice }] }

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-006 | 分页参数生效，total/页数准确，超量 pageSize 被收敛或 400 |
| AC-007 | 分类筛选含后代，品牌多选与组合条件取交集 |
| AC-008 | 四种排序顺序正确，非法参数回落 default |
| AC-009 | records 含字符串 id、名称、主图、真实整数分价区（无 null） |
| AC-010 | 下架/无启用 SKU 商品不在列表返回 |
| AC-018 | 空结果/网络错误/加载中分别有空态/错态/Loading（列表部分） |
| AC-020 | 列表金额字段均整数分，前端无浮点解析 |
