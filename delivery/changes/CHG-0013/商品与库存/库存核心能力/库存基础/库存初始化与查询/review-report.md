# Review Report — 库存初始化与查询 STORY-002-04-01-01

> 阶段：sdd-review 产物（Story 级检查点，状态保持 testing）
> 输入：story-spec.md / story-design.md / test-design.md + 仓内 DU-BE-401 / DU-FE-401 产物 + evidence/test-report.md + Change evidence/evidence.yaml + standards/

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-01-01（库存初始化与查询）
- Test Report 来源: 本目录 evidence/test-report.md
- Evidence 索引: CHG-0013/evidence/evidence.yaml
- 状态流转: testing（检查点，状态不变）
- 检查时间: 2026-09-13

## 1. 检查结论

五项检查全部执行；无 blocker/major 开放项。

### 1.1 需求一致性

| AC | 需求要点 | 证据 | 结论 |
| --- | --- | --- | --- |
| AC-001 | 为已存在 SKU 初始化库存（total>=0）→ 成功 | InventoryTest.initializeSetsQuantities | 一致 |
| AC-002 | 为不存在 SKU 初始化 → 拒绝，INVALID_ARGUMENT | SkuClient.exists=false → skuNotFound | 一致 |
| AC-003 | 重复初始化同一 SKU → 拒绝，CONFLICT | InventoryException.alreadyExists | 一致 |
| AC-004 | 初始库存为负 → 拒绝，INVALID_ARGUMENT | InventoryTest.initializeRejectsNegative | 一致 |
| AC-005 | 单 SKU 查询返回 total/locked/available | InventoryAdminController GET /{skuId} | 一致 |
| AC-006 | 批量 SKU 查询 | InventoryAdminController POST /batch | 一致 |
| AC-007 | 后台分页查询库存列表 | InventoryAdminController GET /stocks | 一致 |

### 1.2 设计一致性

- Inventory 聚合 initialize() 校验 SKU 存在性（SkuClient）、幂等（existsBySkuId）、非负，与 story-design §2 一致。
- 接口契约 POST /api/admin/inventory/stocks、GET /{skuId}、POST /batch、GET /stocks，与 story-design §6 一致。
- 权限码 inventory:stock:init / inventory:stock:view，与 mall-identity V6 迁移一致。
- 库存独立上下文，inventory_stock 表仅 skuId，无 product 主数据字段，与设计一致。

### 1.3 跨仓一致性

- 契约闭环：后端 inventory 端点 ↔ 前端 inventoryApi 一一对应。
- 权限码闭环：V6 种子 inventory:* ↔ Controller @PreAuthorize ↔ 前端 v-permission 一致。
- baseline/result：repo-1 c93d113→78ffd23、repo-2 1420de6→b89af55，与各仓 DU metadata.yaml 一致。

### 1.4 代码质量

- mall-inventory 13 测试 + mall-product 61 回归全绿，无回归。
- Inventory 聚合遵循 DDD 四层，createNew/reconstitute 静态工厂，异常继承 BusinessException。
- 前端 type-check + build 通过。
- 未发现 standards/ 规范违规。

### 1.5 知识同步候选

- 库存与商品独立上下文，通过内部 API 契约交互，不共享实体。
- Flyway 迁移字段无 DEFAULT 时 toPo 用 field != null ? field : Instant.now()（CHG-0011 沉淀）。
- 统一在 Change converge 阶段评估沉淀。

## 2. 发现清单

无 blocker；无 major 开放项。

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 全部 blocker/major finding 已闭环
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对
