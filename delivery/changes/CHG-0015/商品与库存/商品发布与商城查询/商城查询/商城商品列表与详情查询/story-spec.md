---
story-id: "STORY-002-03-02-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S1, S2, S3, S4, S5]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 + exploration.md
> 产出状态：specified
> 说明：本 Story 为 M3 前置缺口修复，沿用既有 Story（CHG-0012 已 delivered 的商城查询）承接就绪修复项，不新增产品能力。

## 0. 元信息

- Change ID: CHG-0015
- Story ID: STORY-002-03-02-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

在 M3 功能开发前消除五类已实证阻塞：统一业务 ID 字符串序列化、修复网关商城公开路由 401、补齐库存→商品内部调用的 SERVICE 凭证、修复库存分页 total=0、让商品列表返回真实价区并过滤无有效 SKU 的商品；同时保证 mall-admin 既有功能零回归。

## 2. Scope（范围）

### 2.1 包含

- [S1] mall-common 统一 Long→String JSON 序列化策略 + product/inventory 对外 DTO 改造 + 入参兼容 + mall-admin 回归。
- [S2] 网关显式匿名放行既有商城只读 GET 接口；internal 路径外网拒绝；私有路由保持认证。
- [S3] 服务间 SERVICE 凭证机制；库存服务初始化 SKU 校验携带凭证。
- [S4] 库存分页 total 修复。
- [S5] 商品列表启用 SKU 价区聚合（整数分）与无有效 SKU 过滤。

### 2.2 不包含

- 新增公开分类树/品牌/批量库存接口（CHG-0017）；mall-web 页面；会员与购物车。

## 3. 业务规则

- 同 requirement-spec.md §4 全部规则；本 Story 不引入额外业务语义，仅修复与跨切面治理。
- 价区聚合使用单条分组查询（GROUP BY product_id 取 MIN/MAX），禁止逐商品 N+1。

## 4. 接口与字段规格

- 受影响既有接口（契约形状不变，仅 ID 表现形态/价区字段取值修正）：
  - GET /api/mall/products（分页：records[].id/minPrice/maxPrice）
  - GET /api/mall/products/{id}
  - 后台库存分页（total 修正）
  - product/inventory 其余对外 DTO 的 ID 字段
- 新增配置：mall-common 序列化开关（默认开启字符串化）；服务间凭证配置项（内部头名/密钥来自环境变量）。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 经网关匿名 GET /api/mall/products 返回 200 与商品数据，无需 Token |
| AC-002 | 经网关匿名 GET /api/mall/products/{id} 返回 200；不存在/下架返回明确 404/不可售 |
| AC-003 | 外部直接请求 /api/internal/** 被拒绝（403/404） |
| AC-004 | mall-inventory 初始化真实 SKU 库存成功，不再误报“SKU 不存在” |
| AC-005 | 库存分页 total 与实际记录数一致（33 行场景 total=33） |
| AC-006 | 商品列表 id 为 JSON 字符串，前端解析不丢精度 |
| AC-007 | 商品/SKU/分类/品牌/库存对外接口全部业务 ID 均为字符串（含嵌套/分页） |
| AC-008 | 入参字符串 ID 与数字 ID 均被正确处理 |
| AC-009 | 列表 minPrice/maxPrice 为启用 SKU 真实最低/最高价（整数分），无 null |
| AC-010 | 无启用 SKU 的商品不出现在商城列表 |
| AC-011 | mall-admin 商品/SKU/分类/品牌/库存页 CRUD 与分页跳转零回归 |
| AC-012 | 经网关拿到的 skuId 原样回传与后端一致，无末位偏差 |
