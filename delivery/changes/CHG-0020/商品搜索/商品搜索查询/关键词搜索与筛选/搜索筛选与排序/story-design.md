---
affected-repositories: [repo-1]
story-id: "STORY-005-01-02-02"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §2.2/§2.3
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0020
- Story ID: STORY-005-01-02-02
- 状态流转: specified → designed
- 相关仓库: repo-1（mall-search）
- 需要 Migration: no
- 数据变更概要: 无

## 1. 模块改动（Module Changes）

### repo-1 mall-search（DU-BE-502 增量）

- SearchQuery 增 categoryId(Long)、brandId(Long)、minPrice(Long)、maxPrice(Long)、sort(String→SortMode)。
- ElasticsearchProductSearchRepository bool.filter 追加（仅非空追加）：
  - term categoryId；term brandId；
  - 价格区间相交：range minPrice lte maxPrice AND range maxPrice gte minPrice（字段均 long 分）；
- 排序：
  - DEFAULT：_score desc, updatedAt desc；
  - PRICE_ASC：minPrice asc, _score desc；PRICE_DESC：maxPrice desc, _score desc；
  - NEWEST：publishedAt desc（null 排尾）, _score desc；
  - sort 缺省 → DEFAULT；sort 非枚举值 → 回退 DEFAULT 并在响应不报错（宽松）；page/size/价格类非法（minPrice>maxPrice、负数）→ B0502。
- MallSearchController 增 query 参数绑定 categoryId/brandId/minPriceFen/maxPriceFen/sort（请求参数名冻结为 minPriceFen/maxPriceFen，内部 long 分）。

## 2. 接口契约细化

GET /api/mall/search/products 新增参数：

| 参数 | 类型 | 规则 |
| --- | --- | --- |
| categoryId | long | 可空 |
| brandId | long | 可空 |
| minPriceFen | long | ≥0，可空；与 maxPriceFen 须 ≤ |
| maxPriceFen | long | ≥0，可空 |
| sort | string | default/price_asc/price_desc/newest，大小写不敏感；非法值回退 default |

空筛选集（某 categoryId 下无在售）：200 + 空分页。

## 3. 数据变更

无。

## 4. 错误处理

- minPriceFen>maxPriceFen、负值、非数字绑定失败 → B0502 400，message 标注字段；
- 非法 sort 不报错，回退 DEFAULT（需求冻结的宽松策略）。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-511 | repo-1 | 三维过滤/价格区间相交/四排序（DEFAULT/PRICE_ASC/PRICE_DESC/NEWEST）/参数校验 | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007 | 无 |

> 跨 Story 依赖与复用（不入本表）：DU-BE-511 是 DU-BE-502（STORY-005-01-02-01 查询主链路）的同模块增量，前置 DU-BE-501/510 基线。

## 6. 测试策略

Testcontainers 造数矩阵（2 类目/3 品牌/多价格段/含未发布）：
- 单维过滤、组合过滤、区间边界相等（min==max 命中等值）、无交集返回空；
- 四种排序顺序断言（price_asc/desc 取边界商品、newest 按 publishedAt）；
- 非法 sort 回退 default；价格反向/负数 400。
