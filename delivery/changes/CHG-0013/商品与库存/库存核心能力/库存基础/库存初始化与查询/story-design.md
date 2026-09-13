---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-002-04-01-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-01-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed

## 1. 模块改动（Module Changes）

### repo-1 mall-inventory

- `domain.inventory.Inventory`：聚合根，字段 id/skuId/totalQuantity/lockedQuantity/version；领域行为 initialize/adjust/lock/release/confirmDeduction（lock/release/confirmDeduction 在后续 Story 补充）。
- `domain.inventory.InventoryLog`：流水实体，字段 id/skuId/operationType/quantity/beforeQuantity/afterQuantity/businessId/operator/traceId/occurredAt。
- `domain.inventory.InventoryRepository`：端口 findBySkuId/save/insertLog。
- `domain.inventory.InventoryOperationType`：枚举 INIT/ADJUST/LOCK/RELEASE/DEDUCT。
- `infrastructure.persistence.inventory`：InventoryPo/InventoryLogPo + Mapper + Repository 实现。
- `application.inventory.InventoryApplicationService`：init/getBySkuId/batchGet/page。
- `interfaces.rest.admin.InventoryAdminController`：/api/admin/inventory/stocks，权限 inventory:stock:*。
- `infrastructure.config.InventorySecurityConfiguration`：资源服务器配置。
- `infrastructure.client.SkuClient`：RestTemplate 调用 mall-product 内部接口校验 SKU 存在。

### repo-1 mall-identity

- V4__add_inventory_permissions.sql：inventory:stock:* 权限码 + 库存菜单。

### repo-1 mall-gateway

- application.yml 追加 /api/admin/inventory/** 与 /api/internal/inventory/** 路由到 mall-inventory。

### repo-2 mall-admin

- `src/views/inventory/InventoryListView.vue`：库存列表（含初始化）。
- `src/api/inventory/inventory.ts`：API 封装。

## 2. 接口契约细化

| 方法 | 路径 | 权限 | 请求 | 响应 |
| --- | --- | --- | --- | --- |
| GET | /api/admin/inventory/stocks | inventory:stock:list | ?skuId&page&size | PageView<InventoryView> |
| GET | /api/admin/inventory/stocks/{skuId} | inventory:stock:detail | - | InventoryView |
| POST | /api/admin/inventory/stocks/init | inventory:stock:init | {skuId, totalQuantity} | InventoryView |

InventoryView: { skuId, totalQuantity, lockedQuantity, availableQuantity }

## 3. 数据变更

- Flyway V1：inventory_stock、inventory_log 两表。
- inventory_stock.sku_id 唯一（uk）。
- inventory_log 无唯一约束（流水追加）。

## 4. 错误处理

- SKU 不存在：BusinessException(INVALID_ARGUMENT, "SKU 不存在")。
- 重复初始化：BusinessException(CONFLICT, "库存已存在")。
- 初始库存为负：IllegalArgumentException → BusinessException(INVALID_ARGUMENT)。
- 无权限：403（Spring Security）。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-401 | repo-1 | 库存权限码（identity V4）+ Inventory 聚合、inventory_stock/inventory_log 表、初始化与查询 API、INIT 流水、SKU 契约校验、安全配置与网关路由 | AC-001,002,003,004,005,006,007,018,020,021 | CHG-0012 |
| DU-FE-401 | repo-2 | 库存列表页（含初始化） | AC-007,020 | DU-BE-401 |

## 6. 测试策略

- 后端：Inventory 聚合不变量单元测试（total>=0、locked>=0）；InventoryApplicationService 集成测试（H2）；权限 403 测试；初始化幂等测试。
- 前端：vitest 组件测试 + vue-tsc + eslint + build。
