---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-003-02-02-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0017
- Story ID: STORY-003-02-02-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed
- 需要 Migration: no
- 数据变更概要: 无

## 1. 模块改动（Module Changes）

### repo-1 mall-product

- `ProductCommands.ProductPageQuery` 扩展：brandIds(List)、sort(String)；保留 keyword（前端不开放）。
- `ProductApplicationService.mallPage`：sort 白名單映射（default/newest/price_asc/price_desc，非法→default）；categoryId 子孙展开（CategoryTreeExpander：载入启用分类树内存展开为 ID 集合，深度断言 ≤3）；brandIds 交集过滤。
- `ProductRepositoryImpl.mallPage`：MyBatis-Plus QueryWrapper 增加 categoryId IN（后代集）、brandId IN；排序 newest/default → published_at DESC,id DESC；price_asc/desc → 派生表 JOIN SKU 分组 minPrice 排序（保证分页 total 准确，禁止内存排序）；固定 ON_SALE + EXISTS 启用 SKU（CHG-0015）。
- Controller：入参 brandIds（逗号分隔）、sort、size 上限收敛 50；View 复用 ListItem（价区非 null）。

### repo-2 mall-web

- `src/api/product.ts`：pageProducts(query)。
- views `product/ProductListView.vue`：URL query 同步（categoryId/brandIds/sort/page，可分享刷新）；侧栏分类树（catalog store）+ 品牌多选；排序条；分页；ProductCard 栅格；StateView 空/错/载；空分类（分类下无有效后代商品）Empty。
- router：/products、/categories/:categoryId 复用列表页。

## 2. 接口契约细化

| 方法 | 路径 | 参数 |
| --- | --- | --- |
| GET | /api/mall/products | categoryId?:string, brandIds?:string(逗号分隔), sort?:default\|newest\|price_asc\|price_desc, page=1, size(1..50) |
- 响应 PageView<ListItem>；非法 sort 静默回落 default；size>50 → 400（参数级提示，不静默放大查询）。

## 3. 数据变更

- 无。

## 4. 错误处理

- 分类不存在/已禁用：按空结果集处理（Empty），不 404（筛选语义）。
- brandIds 含非法 ID：忽略非法项；全部非法 → 空结果。
- 后端任何未知 query 参数忽略。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-703 | repo-1 | 列表 sort/品牌多选/子孙分类/分页收敛 + 派生表价区排序 | AC-006,007,008,009,010,020 | — |
| DU-FE-703 | repo-2 | 列表页筛选/排序/分页/URL 同步与全部状态态 | AC-006,007,008,009,018,019,020 | DU-BE-703 |

> 跨 Story 依赖：DU-FE-703 分类树/品牌数据契约依赖 STORY-003-02-01-02 的 DU-BE-702；跨 Change 依赖 CHG-0015 DU-BE-501（价区/过滤/字符串 ID）。

## 6. 测试策略

- 后端：排序四态结果断言（含同分稳定序）；子孙分类多层用例；品牌多选交集；非法 sort 回落；size 边界 50/51；total 与翻页恒定；价区排序派生表 SQL 集成测试（MySQL 测试方式对齐项目现状）。
- 前端：query 同步与刷新恢复；筛选组合交互；空/错态；vue-tsc/eslint/build；金额域保持 number 的类型测试。
