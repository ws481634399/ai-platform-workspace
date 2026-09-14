---
affected-repositories: [repo-1, repo-2]
---

# Requirement Design（需求级方案设计）

## 0. 元信息

- Change：CHG-0014
- Story：STORY-002-02-01-01
- 仓库：repo-1、repo-2

## 1. 当前状态

Product/SKU 拆分创建，mall-admin 丢弃图片/属性，Mall/Internal Product 无网关路由，Inventory internal `permitAll`，M1 lint/401 存在回归。

## 2. 提议方案

- 扩展 Product 创建 DTO 含 `skus[]`，应用服务单事务持久化。
- mall-admin 在创建前本地编辑 images/attributes/skus，一次提交。
- Gateway 新增 mall/internal product routes，仅 mall route public。
- Inventory 复用 JWT `subject_type=SERVICE` 作为 internal 授权条件。
- HTTP 拦截器排除 login/refresh，修复 lint。

## 2.1 备选方案对比（Alternatives Considered）

| 方案 | 优点 | 缺点 | 结论 |
|---|---|---|---|
| 继续拆分创建 Product/SKU | 不改 API | 违反原子创建 AC | 不选 |
| Product 创建包含 SKU | 对齐聚合和事务 | 需同步前端 | 选用 |
| 内部 API Key | 简单 | 新增密钥生命周期 | 不选 |
| SERVICE JWT | 复用 M1 身份体系 | 调用方需 Token | 选用 |

## 3. 仓库影响（Repository Impact）

### 3.1 repo-1

- mall-product、mall-gateway、mall-inventory。

### 3.2 repo-2

- mall-admin；mall-web 无改动。

## 4. 跨仓协作（Cross-Repository Contract）

- repo-1 先冻结 `POST /api/admin/products` 的 `images[]/attributes[]/skus[]` 契约，repo-2 后对齐。

## 5. Story 设计分派（Story Design Assignments）

| Story | 范围 | AC |
|---|---|---|
| STORY-002-02-01-01 | 商品聚合、网关、库存授权、mall-admin 补全 | AC-001～009 |

## 6. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
|---|---|---|---|---|
| DU-BE-401 | repo-1 | Product 事务、Gateway、Inventory Security | AC-001,002,005,006,007 | 无 |
| DU-FE-402 | repo-2 | mall-admin 表单与 M1 回归 | AC-003,004,008,009 | DU-BE-401 |

## 7. 风险

- 创建契约改为要求 SKU，需同步更新管理端。
- SERVICE JWT 需安全测试覆盖 ADMIN 拒绝。

## 8. 待澄清问题

- 无。
