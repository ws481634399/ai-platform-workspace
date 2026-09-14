---
story-id: "STORY-003-02-01-02"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S2]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0017
- Story ID: STORY-003-02-01-02
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

新增商城公开分类树与品牌查询接口并在网关匿名放行，仅返回有效数据，为首页导航、列表筛选与分类浏览提供数据源。

## 2. Scope（范围）

### 2.1 包含

- [S2] GET /api/mall/categories/tree（启用分类树、排序、禁用子树裁剪）；GET /api/mall/brands（启用品牌、关键字、分页/全量）；网关白名单。

### 2.2 不包含

- 分类/品牌后台管理（M2 已交付）；首页与列表页面。

## 3. 业务规则

- 仅 status=启用；分类按 sort 排序并保持父子层级；禁用父分类时其整棵子树不返回。
- 品牌支持 name 关键字模糊匹配；返回 id（字符串）/name/logoUrl/sort。
- internal 路径继续外网不可达。

## 4. 接口与字段规格

- GET /api/mall/categories/tree → [{ id, name, parentId(string|null), sort, children:[] }]
- GET /api/mall/brands?keyword=&page=&pageSize= → 分页包装；亦可返回全量有效集（设计定其一，首期全量 + pageSize 上限 100）。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-003 | categories/tree 匿名 200，仅启用分类树且排序正确，禁用子树不出现 |
| AC-004 | brands 匿名 200，仅启用品牌，关键字过滤有效 |
| AC-005 | 外部直访对应 internal 路径不可达 |
