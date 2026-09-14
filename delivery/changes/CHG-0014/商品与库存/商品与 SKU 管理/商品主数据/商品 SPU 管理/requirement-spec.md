# Requirement Spec（需求级产品规格）

## 0. 元信息

- Change：CHG-0014
- 来源：REQ-M1-QUALITY、REQ-M2-002、REQ-M2-003、REQ-M2-004 验收缺口
- 优先级：P0

## 1. 背景

M1/M2 主体代码已存在，但真实网关、后台整体表单、内部服务信任边界与质量门未形成闭环。

## 2. 用户价值

- 商品管理员能一次形成含 SKU、图片和属性的完整商品。
- M3 商城与下游服务能通过网关消费 M2 商品查询契约。
- 库存写操作不能被未授权主体调用。

## 3. 功能范围

### 3.1 包含

- `POST /api/admin/products` 接收至少一个 SKU，Product、图片、属性、SKU 同事务创建。
- mall-admin 创建/编辑页可维护商品图片、主图、非规格属性、SKU 规格/价格/主图。
- 网关公开 `/api/mall/products/**`，并为 `/api/internal/products/**` 保留认证。
- `/api/internal/inventory/**` 仅允许 `subject_type=SERVICE`。
- 登录 401 不触发 refresh；mall-admin lint 达到 0 error。

### 3.2 不包含

- 手机端、响应式布局。
- mall-web 商品列表与详情页面（M3）。
- 图片上传服务；本阶段维护 objectKey 与 imageUrl。

### 3.3 Story 拆分总表

| Story | 范围 | 优先级 |
|---|---|---|
| STORY-002-02-01-01 | M1/M2 商品主数据验收缺口修复（跨后端/前端） | P0 |

## 4. 业务规则总纲

- Product 创建时必须包含至少一个 SKU，任一写入失败整体回滚。
- 一个 Product 最多一张主图；SKU 图片为可选 URL。
- 商品非规格属性以键值对维护，属性名不得重复。
- 商城商品查询公开；内部商品和库存变更契约需认证，库存变更只接受 SERVICE。

## 5. 全局验收标准

| AC | 验收标准 |
|---|---|
| AC-001 | 合法 Product + 至少一个 SKU 一次提交创建成功，返回 DRAFT 商品 ID |
| AC-002 | SKU 非法时 Product、图片、属性与 SKU 均不落库 |
| AC-003 | 后台可新增、编辑并回显商品图片、主图与属性 |
| AC-004 | 后台创建表单可在提交前维护一个或多个 SKU，含规格、价格与主图 URL |
| AC-005 | 未登录请求 `/api/mall/products/**` 可达且只返回 ON_SALE；网关不再返回 404 |
| AC-006 | 已认证服务可通过网关访问 `/api/internal/products/**` |
| AC-007 | 匿名或 ADMIN 调用库存 lock/release/confirm 返回 401/403，SERVICE 可访问 |
| AC-008 | 错误登录只发送登录请求，不调用 refresh |
| AC-009 | mall-admin test/type-check/lint/build 全部通过 |

## 6. 非功能需求

- 不引入新框架或新基础设施。
- 兼容现有商品更新与独立 SKU 维护 API。
- 公开商城接口仍由 Product Query 层强制 ON_SALE 过滤。

## 7. 成功指标

- AC-001～AC-009 具有可重复自动化证据。
- 通过网关与浏览器完成桌面端联调。

