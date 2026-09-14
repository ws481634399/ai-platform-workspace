---
affected-repositories: [repo-1]
story-id: "STORY-003-02-01-02"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0017
- Story ID: STORY-003-02-01-02
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed
- 需要 Migration: no
- 数据变更概要: 无

## 1. 模块改动（Module Changes）

### repo-1 mall-product

- `interfaces.rest.mall.MallCategoryController`：GET /api/mall/categories/tree；调用分类应用层取启用分类（已有 admin tree 能力，新增仅启用过滤的只读方法或在 assembler 层过滤），禁用节点子树整棵剪除。
- `interfaces.rest.mall.MallBrandController`：GET /api/mall/brands?keyword=&page=&size=；仅 ENABLED；默认全量（硬上限 200），keyword 模糊 name。
- `interfaces.rest.mall.dto.MallCatalogDtos`：CategoryNode{id,name,sort,children}、BrandView{id,name,logoUrl,sort}（@StringId）。
- assembler：复用 admin 分类树装配逻辑但输出独立 mall DTO（禁止复用 admin DTO）。

### repo-1 mall-gateway

- product-mall 路由 predicate 扩展：Path=/api/mall/products/**,/api/mall/categories/**,/api/mall/brands/**,/api/mall/home,/api/mall/skus/**（本 Story 先行写全，后续 Story 直接生效）。
- 白名单追加 /api/mall/categories/**、/api/mall/brands/**（显式 GET 只读语义）。

## 2. 接口契约细化

| 方法 | 路径 | 鉴权 | 响应/错误 |
| --- | --- | --- | --- |
| GET | /api/mall/categories/tree | 匿名 | UnifyResult<List<CategoryNode>>；空树返 [] |
| GET | /api/mall/brands?keyword=&page=1&size=200 | 匿名 | UnifyResult<{items:BrandView[],total}>；size>200 收敛 200 |
- internal 路径外部不可达：沿用 CHG-0015 denyAll。

## 3. 数据变更

- 无。

## 4. 错误处理

- keyword 超长（>64）→ 400；分页参数非法回落默认（与商品列表同口径）。
- 禁父启子的子树：父禁用则整枝剪除（不返回孤儿节点）。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-702 | repo-1 | 公开分类树/品牌接口、树剪枝、网关白名单 | AC-003,004,005 | — |

> 跨 Change 依赖：网关白名单机制与 @StringId 由 CHG-0015 DU-BE-501 提供。本 Story 无独立 FE DU（分类/品牌数据由首页与列表页消费，页面在对应 Story 交付）。

## 6. 测试策略

- 集成测试：启用/禁用混合分类数据下树结构与剪枝断言；品牌 keyword 过滤与上限；网关匿名 200 与 internal 外拒；JSON 断言 id 字符串、空集合返 []。
