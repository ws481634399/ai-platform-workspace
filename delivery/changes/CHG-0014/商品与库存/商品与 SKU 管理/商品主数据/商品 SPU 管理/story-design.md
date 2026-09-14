---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-002-02-01-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

## 0. 元信息

- Story：STORY-002-02-01-01
- Change：CHG-0014

## 1. 模块改动（Module Changes）

### repo-1

- mall-product：CreateProduct DTO 加入 SKU，应用服务提供聚合创建事务。
- mall-gateway：添加 mall/internal product route，对 mall route permitAll。
- mall-inventory：解析 SERVICE 权限并保护 internal route。

### repo-2

- mall-admin：ProductEditView 实现 images/attributes/local skus 编辑；API DTO 对齐。
- HTTP interceptor 排除 login 请求的 refresh；修复 PageHeader lint。

## 2. 接口契约细化

- 创建请求先在 Controller 进行 Bean Validation，再交由 Application Service 统一事务。
- 空 `skus` 返回 400/A0001；SKU Code/规格冲突使用现有冲突错误。
- 网关授权顺序：auth public → mall product public → all authenticated。

## 3. 数据变更

- 无新表或迁移；复用 product_spu/product_image/product_attribute/product_sku。

## 4. 错误处理

- 创建参数错误 400，权限不足 403，未认证 401，唯一冲突 409。
- 前端保留表单内容并展示统一错误，不吞掉异常。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
|---|---|---|---|---|
| DU-BE-401 | repo-1 | Product 事务、Gateway、Inventory Security | AC-001,002,005,006,007 | 无 |
| DU-FE-402 | repo-2 | mall-admin 表单与 M1 回归 | AC-003,004,008,009 | DU-BE-401 |

## 6. 测试策略

- repo-1：Application Service 事务/接口测试，Gateway WebTestClient 授权测试，Inventory MockMvc Security 测试。
- repo-2：Vitest 验证 payload 与 401 行为，然后执行 type-check/lint/build。
- 联调：未登录 mall API、管理员后台页面和库存内部接口授权。
