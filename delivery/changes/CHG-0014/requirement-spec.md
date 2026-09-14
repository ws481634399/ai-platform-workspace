# Requirement Spec（需求级产品规格）

## 0. 元信息

- Change：CHG-0014
- Story：STORY-002-02-01-01
- 优先级：P0

## 1. 背景

M1/M2 主体代码已存在，但真实网关、后台整体表单、内部服务信任边界和前端质量门未闭环。

## 2. 用户价值

- 商品管理员一次形成含 SKU、图片和属性的完整商品。
- M3 商城与下游服务能通过网关消费 M2 商品 API。
- 库存写操作只能由受信服务调用。

## 3. 功能范围

### 3.1 包含

- Product+至少一个 SKU 同事务创建。
- mall-admin 图片/属性/SKU 完整维护。
- Mall/Internal Product 网关路由。
- Inventory Internal SERVICE 授权。
- login 401 不 refresh；mall-admin lint 0 error。

### 3.2 不包含

- 手机端。
- mall-web 商品列表/详情页（M3）。
- 图片上传服务。

### 3.3 Story 拆分总表

| Story | 范围 | 优先级 |
|---|---|---|
| STORY-002-02-01-01 | 跨仓验收缺口修复 | P0 |

## 4. 业务规则总纲

- Product 创建必须含至少一个 SKU，任一失败整体回滚。
- Product 最多一张主图，非规格属性名不重复。
- mall product 公开；internal inventory 只接受 SERVICE。

## 5. 全局验收标准

| AC | 验收标准 |
|---|---|
| AC-001 | 合法 Product+至少一个 SKU 一次提交创建成功 |
| AC-002 | SKU 非法时 Product/图片/属性/SKU 均不落库 |
| AC-003 | 后台可新增、编辑、回显商品图片、主图和属性 |
| AC-004 | 创建提交前可维护多个 SKU 的规格/价格/图片 |
| AC-005 | 匿名 `/api/mall/products/**` 经网关可达 |
| AC-006 | 已认证 `/api/internal/products/**` 经网关可达 |
| AC-007 | anonymous/ADMIN 不得写库存内部接口，SERVICE 可访问 |
| AC-008 | login 401 不触发 refresh |
| AC-009 | mall-admin test/type-check/lint/build 全通过 |

## 6. 非功能需求

- 不引入新框架或基础设施；兼容现有更新与独立 SKU API。

## 7. 成功指标

- AC-001～009 具有自动化证据，并完成桌面端网关/浏览器联调。

