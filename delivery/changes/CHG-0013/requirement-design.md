---
affected-repositories: [repo-1, repo-2]
---

# Requirement Design（需求级方案设计）

> 层级：Requirement 级产物——本次 Change 的技术方案骨架
> 业界锚点：ADR（Context → Decision → Alternatives → Consequences）+ 跨仓影响面
> 输入：requirement-spec.md + product/06 §10.1 Inventory 聚合
> 产出状态：designed
> 分层关系：本文是 Requirement 级；Story 内部的详细设计见各 Story 目录 story-design.md。

## 0. 元信息

- Change ID: CHG-0013
- spec 来源: requirement-spec.md（REQ-M2-004 库存核心能力）
- 相关仓库: repo-1（ai-platform-backend）、repo-2（ai-platform-frontend）
- 受影响仓库数: 2

## 1. 当前状态

- 当前架构模式: Spring Boot 3.5 / Spring Cloud 微服务 + 独立前端仓；后端 DDD 四层，鉴权经网关 + JWT 资源服务器。
- 相关模块:
  - `mall-services/mall-inventory`：骨架已存在（CHG-0003 创建），仅 MallInventoryApplication + SmokeTest，pom 含 mybatis-plus、flyway、mysql、mall-common-web、mall-common-log、mall-common-test；无业务代码、无 Flyway 迁移、无安全配置。
  - `mall-services/mall-product`：CHG-0011 已落地 Product/SKU 聚合，SKU 通过内部接口 `/api/internal/products/{productId}/skus/{skuId}/snapshot` 暴露（CHG-0012 DU-BE-308）。
  - `mall-common/mall-common-security`：`JwtSubjectConverter` 从 JWT permissions claim 映射 GrantedAuthority，方法级 `hasAuthority` 直接可用。
  - `mall-identity`：已注册分类/品牌/商品权限与菜单；库存权限/菜单待追加。
  - 前端 `mall-admin`：CHG-0010/0011/0012 已交付分类/品牌/商品页，http.ts 解包 UnifyResult、permission store has()、组件注册表。
  - 复用基础：`UnifyResult`、`GlobalExceptionHandler`+`BusinessException`、`PageView`。

## 2. 提议方案

- 方案概要: 在 mall-inventory 内按 DDD 四层实现 Inventory 聚合根（totalQuantity/lockedQuantity/version）与库存流水 InventoryLog 实体、库存预留 InventoryReservation 实体；Flyway V1 建 inventory_stock/inventory_log、V2 建 inventory_reservation；SKU 存在性通过 mall-contracts 内部接口校验（OpenFeign 或 RestTemplate，M2 用 RestTemplate 直连，不引入 OpenFeign 依赖）；锁定采用 SQL 条件更新 `UPDATE inventory_stock SET locked = locked + ? WHERE sku_id = ? AND (total - locked) >= ?` 防超卖；幂等通过 reservationId 唯一约束兜底；mall-identity 追加 inventory:* 权限与库存菜单；mall-admin 新增库存列表/初始化/调整/流水页。
- 关键组件:
  - 后端 mall-inventory：`domain.inventory.Inventory`（聚合根）、`InventoryLog`（流水实体）、`InventoryReservation`（预留实体）；`InventoryRepository` 端口 + MyBatis-Plus 适配器（含条件更新锁定方法）；`InventoryApplicationService`（init/get/batchGet/page/adjust/lock/release/confirmDeduction）；`InventoryAdminController`（/api/admin/inventory/**，权限 inventory:*）；`InternalInventoryController`（/api/internal/inventory/**，供 mall-order 调用锁定/释放/扣减）。
  - 数据：inventory_stock（skuId 唯一）、inventory_log（流水）、inventory_reservation（reservationId 唯一）。
  - 权限资产：mall-identity 追加 inventory:stock:list/detail/init/adjust、inventory:log:list 权限码 + "库存管理"菜单。
  - 前端：`src/views/inventory/InventoryListView.vue`、`InventoryAdjustView.vue`、`InventoryLogView.vue`；`src/api/inventory/inventory.ts`。
- 关键不变量实现:
  - 初始化：校验 SKU 存在（内部接口）；total >= 0；skuId 唯一（uk 兜底）；落 INIT 流水。
  - 调整：领域方法 adjust(delta, reason) 校验 total + delta >= 0；落 ADJUST 流水（before/after/delta）。
  - 锁定：SQL 条件更新 affected rows = 1 才成功；创建 reservation（LOCKED）；同一 reservationId 重复锁定返回原结果（先查 reservation）。
  - 释放：查 reservation 状态 LOCKED → locked -= delta、状态 RELEASED；已 RELEASED → 幂等返回成功。
  - 确认扣减：查 reservation 状态 LOCKED → total -= delta、locked -= delta、状态 DEDUCTED；已 DEDUCTED → 幂等返回成功；非 LOCKED → INVALID_STATE。
  - 流水：INIT/ADJUST/LOCK/RELEASE/DEDUCT 全量记录。

## 2.1 备选方案对比（Alternatives Considered）

| 方案 | 描述 | 优点 | 缺点 | 是否采纳 |
| ---- | ---- | ---- | ---- | -------- |
| A（选中） | 独立 mall-inventory 服务 + inventory_stock/inventory_log/inventory_reservation 三表 + SQL 条件更新锁定 + reservationId 幂等 | 对齐 product/06 §10.1 Inventory 聚合；独立上下文边界清晰；SQL 条件更新无分布式锁即可防超卖；幂等键唯一约束兜底 | 需 mall-order 通过内部 API 调用（M4）；跨服务事务用 Saga/MQ（M7） | 是 |
| B（备选） | 库存放 mall-product 内（product_sku 加 stock 字段） | 部署简单、无跨服务调用 | 违背领域边界（Inventory 独立上下文）；商品与库存耦合；无法独立扩展 | 否 |

## 3. 仓库影响（Repository Impact）

- 受影响仓库数: 2
- 主要修改点: repo-1 承担后端（mall-inventory 库存实现 + mall-identity 权限菜单 + 网关路由）；repo-2 承担 mall-admin 库存页面。

### 3.1 repo-1（ai-platform-backend）

- `mall-inventory`：新增 domain.inventory（Inventory/InventoryLog/InventoryReservation）、application（InventoryApplicationService）、interfaces.rest.admin（InventoryAdminController + DTO）、interfaces.rest.internal（InternalInventoryController）、infrastructure.persistence（PO/Mapper/Repository）；Flyway V1（inventory_stock/inventory_log）、V2（inventory_reservation）；新增 InventorySecurityConfiguration（资源服务器）。
- `mall-identity`：新增 `V4__add_inventory_permissions.sql`，插入 inventory:stock:list/detail/init/adjust 与 inventory:log:list 共 5 个权限码 + "库存管理"页面菜单。
- `mall-gateway`：新增 /api/admin/inventory/** 与 /api/internal/inventory/** 路由转发到 mall-inventory。

### 3.2 repo-2（ai-platform-frontend）

- `mall-admin`：新增库存列表页（含初始化）、库存调整弹窗、库存流水页；`src/api/inventory/inventory.ts`；component-registry 注册库存组件。

## 4. 跨仓协作（Cross-Repository Contract）

- 接口契约:
  - 前端 → 网关 → mall-inventory 管理端 REST：`/api/admin/inventory/stocks`（list/init/adjust）、`/api/admin/inventory/logs`（流水），统一 UnifyResult。
  - mall-order → mall-inventory 内部 REST：`POST /api/internal/inventory/lock`、`POST /api/internal/inventory/release`、`POST /api/internal/inventory/confirm`，入参含 reservationId/skuId/quantity。
  - mall-inventory → mall-product 内部 REST：`GET /api/internal/products/{productId}/skus/{skuId}/snapshot`（校验 SKU 存在，仅初始化时调用）。
- 仓库依赖: repo-2 运行期依赖 repo-1 HTTP；mall-inventory 运行期依赖 mall-product HTTP（仅 SKU 校验）；源码与部署独立。
- 集成边界: 权限事实源 mall-identity；mall-inventory 消费 JWT claim；网关只做认证转发。
- Migration Impact: mall_inventory V1/V2 新表；mall_identity V4 纯插入权限菜单。
- 跨仓时序: 后端 DU 先于前端 DU 联调；mall-product SKU 内部接口已由 CHG-0012 提供。

## 5. Story 设计分派（Story Design Assignments）

| Story ID | 技术要点摘要 | 涉及仓库 | 公共组件/契约归属 |
| -------- | ------------ | -------- | ----------------- |
| STORY-002-04-01-01 | Inventory 聚合、inventory_stock/inventory_log 表、初始化与查询 API（单/批/后台）、INIT 流水、SKU 契约校验、后台查询页 | repo-1、repo-2 | Requirement 级公共：InventorySecurityConfiguration、UnifyResult、网关路由；InventoryStatus 枚举、权限码 inventory:stock:* 由本 Story 锁定 |
| STORY-002-04-02-01 | 库存调整领域方法、ADJUST 流水、后台调整与流水页 | repo-1、repo-2 | 复用 Inventory 聚合与 Repository；权限码 inventory:stock:adjust、inventory:log:list |
| STORY-002-04-03-01 | inventory_reservation 表、锁定/释放状态机、SQL 条件更新、reservationId 幂等、LOCK/RELEASE 流水 | repo-1 | 复用 Inventory 聚合；ReservationStatus 枚举 |
| STORY-002-04-04-01 | 确认扣减状态机（LOCKED→DEDUCTED）、DEDUCT 流水、幂等 | repo-1 | 复用 Inventory 聚合与 reservation；内部接口供 mall-order |

### 5.1 公共组件与共享契约

- `Inventory`：聚合根，字段 id/skuId/totalQuantity/lockedQuantity/version。
- `InventoryLog`：流水实体，字段 id/skuId/operationType(INIT/ADJUST/LOCK/RELEASE/DEDUCT)/quantity/beforeQuantity/afterQuantity/businessId/operator/traceId/occurredAt。
- `InventoryReservation`：预留实体，字段 id/reservationId/skuId/quantity/status(LOCKED/RELEASED/DEDUCTED)。
- 权限码 SSOT：inventory:stock:{list,detail,init,adjust}、inventory:log:list。
- 路由路径 SSOT：/api/admin/inventory/stocks、/api/admin/inventory/logs、/api/internal/inventory/{lock,release,confirm}。

## 6. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-401 | repo-1 | 库存权限码（identity V4）+ Inventory 聚合、inventory_stock/inventory_log 表、初始化与查询 API（单/批/后台）、INIT 流水、SKU 契约校验、安全配置与网关路由 | AC-001,002,003,004,005,006,007,018,020,021 | CHG-0012 SKU 内部接口 |
| DU-BE-402 | repo-1 | 库存调整领域方法、ADJUST 流水、调整 API | AC-008,009,018 | DU-BE-401 |
| DU-BE-403 | repo-1 | inventory_reservation 表、锁定/释放 API、SQL 条件更新、幂等、LOCK/RELEASE 流水 | AC-010,011,012,013,014,018,019 | DU-BE-401 |
| DU-BE-404 | repo-1 | 确认扣减 API、状态机、DEDUCT 流水、幂等 | AC-015,016,017,018 | DU-BE-403 |
| DU-FE-401 | repo-2 | mall-admin 库存列表（含初始化）、调整弹窗、流水页 | AC-007,008,018,020 | DU-BE-401、DU-BE-402 |

## 7. 风险

- 并发锁定：SQL 条件更新在高并发下可能导致大量重试；M2 数据规模可控，后续 M7 可引入队列削峰。
- 幂等键冲突：reservationId 由订单侧生成，需保证全局唯一；DB uk 兜底返回 CONFLICT 时由调用方处理。
- SKU 校验跨服务调用：初始化时同步调用 mall-product 内部接口，若 mall-product 不可用则初始化失败；M2 接受同步调用，M7 可改为事件驱动。
- 库存为负防护：SQL 条件更新与领域校验双重保证；adjust 负 delta 需校验 total + delta >= 0。

## 8. 待澄清问题

- reservationId 生成方：由 mall-order 生成（M4），mall-inventory 只消费；本 Change 假设调用方传入合法 reservationId。
- 批量锁定多 SKU：M4 下单可能一次锁定多 SKU，本 Change 提供单 SKU 锁定接口，批量由调用方循环调用或后续扩展。
- 库存锁定超时：触发侧归属 M4，本 Change 只提供释放接口与幂等。
