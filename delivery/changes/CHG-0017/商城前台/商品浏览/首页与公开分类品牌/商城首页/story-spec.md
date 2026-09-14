---
story-id: "STORY-003-02-01-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S1, S6]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0017
- Story ID: STORY-003-02-01-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

建立 mall-web 商城首页：顶部导航/分类入口、Banner 占位、新品与推荐商品区，全部取真实后端数据，游客直接可访；具备 Loading/Empty/Error 状态，为完整浏览路径提供入口。

## 2. Scope（范围）

### 2.1 包含

- [S1] 首页布局、分类导航入口、新品/推荐商品区（首期同源数据：上架时间倒序前 N）、Banner 静态占位。
- [S6] 首页数据加载 Loading/Empty/Error。

### 2.2 不包含

- 分类树/品牌接口实现（STORY-003-02-01-02，本 Story 消费）；列表/详情页；运营配置后台。

## 3. 业务规则

- 商品位仅上架且有启用 SKU 的商品；新品 N 与推荐 N 由配置常量给出（各 10）。
- 游客可访问；点击分类/商品分别跳列表/详情路由。

## 4. 接口与字段规格

- 消费 GET /api/mall/products（列表接口，首页用 sort=newest&pageSize=10）与 GET /api/mall/categories/tree。
- 前端路由：/（首页）、/products、/product/:id。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 匿名访问首页 → 分类入口与新品/推荐区为真实商品数据 |
| AC-002 | 商品区仅含上架且有启用 SKU 的商品；无数据显示空态 |
| AC-019 | mall-web 首页游客可直接访问，build/lint/type-check 通过（首页部分） |
