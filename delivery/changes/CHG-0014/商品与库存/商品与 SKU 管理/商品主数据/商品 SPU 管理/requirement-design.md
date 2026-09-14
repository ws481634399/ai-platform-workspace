---
affected-repositories: [repo-1, repo-2]
---

# Requirement Design（需求级方案设计）

## 0. 元信息

- Change：CHG-0014
- Story：STORY-002-02-01-01
- 影响仓库：repo-1、repo-2

## 1. 当前状态

- Product API 把 Product 与 SKU 拆成两次创建；mall-admin 图片/属性固定提交空数组。
- Mall/Internal Product Controller 存在，但网关无对应路由。
- Inventory Internal Controller 可写库存，业务服务层却 `permitAll`。
- mall-admin 登录 401 会误调 refresh，ESLint 存在 1 error。

## 2. 提议方案

- 扩展 `CreateProductRequest` 加入 `skus`，Application Service 在同一 `@Transactional` 方法中校验并持久化 Product/图片/属性/SKU。
- 保留现有 `POST /{id}/skus` 作为创建后追加 SKU 契约。
- mall-admin 表单使用本地数组编辑 SKU、图片、属性；新建时一次提交，编辑时复用现有 Product 更新与 SKU 子资源 API。
- Gateway 新增 Product Mall 公开路由和 Internal 认证路由；SecurityWebFilterChain 只对 `/api/mall/**` 放行。
- Inventory 业务服务从 JWT 的 `subject_type` 映射 `ROLE_SERVICE`，内部库存路由要求该角色。
- HTTP 拦截器排除 login/refresh 认证端点；修正 `window` lint 环境识别。

## 2.1 备选方案对比

| 方案 | 优点 | 缺点 | 结论 |
|---|---|---|---|
| 创建 Product 后再建 SKU | 不改契约 | 违反 AC，产生不完整聚合 | 不选 |
| Product 创建契约包含 SKU | 原子、与聚合语义一致 | 需兼容前端 DTO | 选用 |
| 内部 API 使用固定 API Key | 实现简单 | 新增密钥分发/轮换 | 不选 |
| 复用 SERVICE JWT | 对齐 M1 多主体身份 | 调用方需服务 Token | 选用 |

## 3. 仓库影响（Repository Impact）

### 3.1 repo-1

- mall-product：创建 DTO/Application Service/接口测试。
- mall-gateway：路由与公开路径授权。
- mall-inventory：SERVICE 主体权限转换和内部接口安全测试。

### 3.2 repo-2

- mall-admin：Product DTO/表单、HTTP 拦截器、lint 错误与测试。
- mall-web：无改动。

## 4. 跨仓协作（Cross-Repository Contract）

- repo-1 先冻结 `POST /api/admin/products` 的 `skus[]` 请求字段；repo-2 按契约提交。
- `images[]` 使用 `objectKey/imageUrl/main/sort`，`attributes[]` 使用 `name/value`，`skus[]` 使用 `skuCode/specifications/salePriceInCents/mainImageUrl`。

## 5. Story 设计分派（Story Design Assignments）

| Story | 设计产物 | AC |
|---|---|---|
| STORY-002-02-01-01 | 商品聚合完整创建、网关、内部安全、mall-admin 补全 | AC-001～009 |

## 6. DU 划分（Delivery Units）

| DU | 仓库 | 范围 | 依赖 |
|---|---|---|---|
| DU-BE-401 | repo-1 | 商品原子创建、网关路由、库存 SERVICE 授权 | 无 |
| DU-FE-402 | repo-2 | mall-admin 完整商品表单与 M1 回归 | DU-BE-401 契约 |

## 7. 风险

- 旧前端调用不提交 `skus` 将被拒绝；仅管理端使用该创建契约，同步更新 repo-2。
- SERVICE JWT 联调需可签发的服务凭证；自动化安全测试必须覆盖 ADMIN 拒绝。

## 8. 待澄清问题

- 无。
