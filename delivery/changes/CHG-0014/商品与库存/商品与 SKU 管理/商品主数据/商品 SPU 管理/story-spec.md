---
story-id: "STORY-002-02-01-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008, AC-009]
---

# Story Spec（Story 产品规格）

## 0. 元信息

- Story：STORY-002-02-01-01
- Change：CHG-0014

## 1. Story 目标

让已交付的 M1/M2 商品链路符合已确认验收标准，在不实现 M3 mall-web 页面的前提下，实现可达、可维护、可授权、可自动验证的闭环。

## 2. Scope（范围）

### 2.1 包含

- 完整 Product + SKU 创建契约与事务。
- mall-admin 图片、属性、SKU 表单。
- Mall/Internal Product 网关路由。
- Inventory Internal SERVICE 授权。
- M1 lint 与登录 401 回归。

### 2.2 不包含

- 手机端。
- mall-web 真实商城页面。
- 新的图片上传服务。

## 3. 业务规则

- 创建 Product 必须包含至少一个合法 SKU。
- Product 与其初始 SKU、图片、属性在单事务中持久化。
- 只有 SERVICE 主体可执行库存内部写操作。
- M2 商城 API 免登录，但页面由 M3 实现。

## 4. 接口与字段规格

- `POST /api/admin/products`：新增必填 `skus` 数组；每项含 `skuCode`、`specifications`、`salePriceInCents`、可选 `mainImageUrl`。
- `GET /api/mall/products` / `GET /api/mall/products/{id}`：公开网关路由。
- `GET /api/internal/products/**`：已认证网关路由。
- `POST /api/internal/inventory/{lock|release|confirm}`：需 `ROLE_SERVICE`。

## 5. Story 验收标准

继承 requirement-spec.md 的 AC-001～AC-009，全部由 test-design.md 可追溯验证。
