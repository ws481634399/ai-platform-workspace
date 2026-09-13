# Convergence — CHG-0013 库存核心能力

> 阶段：sdd-converge 产物
> 输入：CHG-0013 全部 Artifact（4 Story 全流程 completed）
> 产出状态：completed

## 0. 元信息

- Change ID: CHG-0013
- 完成时间: 2026-09-13
- 交付 DU：5（repo-1 DU-BE-401/402/403/404、repo-2 DU-FE-401），全部 completed

## 1. 知识变化总结

- 知识增量摘要:
  1. 库存独立上下文：新建 mall-inventory 服务，Inventory 聚合根（skuId/total/locked），与商品上下文通过 SkuClient 内部 API 交互，不共享实体。
  2. 库存操作：initialize（幂等、非负、SKU 存在性校验）、adjust（防负）、lock（SQL 条件更新并发安全）、release、confirmDeduction（状态机 LOCKED→RELEASED/DEDUCTED）。
  3. 库存预留：InventoryReservation 聚合，状态机 LOCKED→RELEASED/DEDUCTED，reconstitute 重建，reservationId 幂等。
  4. 库存流水：InventoryLog 记录 INIT/ADJUST/LOCK/RELEASE/DEDUCT，含 before/after/quantity/businessId/operator。
  5. 并发安全：lockStock 使用 SQL 条件更新 `WHERE (total - locked) >= ?`，数据库层面保证原子性，无需乐观锁版本字段。
  6. 权限码：mall-identity V6 新增 inventory:stock:*、inventory:log:list。
  7. mall-admin 库存页：列表+初始化+调整弹窗+流水列表，受 inventory:* 权限保护。

## 2. 更新判断

### Standards

- 是否需更新: no（本 Change 未引入新的工程约束，CHG-0011 沉淀的 Money/JSON/Flyway/集合约定继续遵循）
- 新增可复用模式：并发安全用 SQL 条件更新（非乐观锁版本号），适合库存扣减场景——暂不进 standards，留待多个 Change 验证后统一沉淀。

### Product

- 是否需更新: no（M2 商品域产品知识正文留待 M2 全部 Change converge 后统一回写）

### feature-tree.yaml

- 是否需更新: yes
- 更新内容: STORY-002-04-01-01、STORY-002-04-02-01、STORY-002-04-03-01、STORY-002-04-04-01 status: planned → delivered。
- 理由: 四 Story 已 completed 且测试/评审证据齐备。

### Glossary

- 是否需更新: yes（候选）
- 候选术语：库存预留（Inventory Reservation）、库存流水（Inventory Log）、可用库存（available = total - locked）。留待 M2 末统一评估是否进术语表。

## 3. 知识沉淀过程

- 已写回：feature-tree 四 Story 状态置 delivered。
- 留待后续：
  - 产品知识正文 M2 末统一更新。
  - 内部 /api/internal/inventory/** 的服务间认证策略（mTLS / service token）在网关/服务治理 Change 中统一设计。
  - 库存流水查询的高级筛选、导出功能在后续 Change 中扩展。
- 未沉淀为标准的内容：SQL 条件更新并发模式、InventoryReservation 状态机——属实现细节，保留在代码与 DU 文档中。

## 4. 全局验收标准对照

> 摘自 requirement-spec.md。

| # | 验收点 | 覆盖 Story | 证据引用 | 结论 |
| --- | --- | --- | --- | --- |
| 1 | AC-001 为已存在 SKU 初始化库存（total>=0）→ 成功 | S1 | Story 1 test-report TC-001 | 通过 |
| 2 | AC-002 为不存在 SKU 初始化 → 拒绝，INVALID_ARGUMENT | S1 | Story 1 test-report TC-002 | 通过 |
| 3 | AC-003 重复初始化同一 SKU → 拒绝，CONFLICT | S1 | Story 1 test-report TC-003 | 通过 |
| 4 | AC-004 初始库存为负 → 拒绝，INVALID_ARGUMENT | S1 | Story 1 test-report TC-004 | 通过 |
| 5 | AC-005 单 SKU 查询返回 total/locked/available | S1 | Story 1 test-report TC-005 | 通过 |
| 6 | AC-006 批量 SKU 查询 | S1 | Story 1 test-report TC-006 | 通过 |
| 7 | AC-007 后台分页查询库存列表 | S1 | Story 1 test-report TC-007 | 通过 |
| 8 | AC-008 调整库存（正/负 delta）→ total 更新正确，流水记录 | S2 | Story 2 test-report TC-001 | 通过 |
| 9 | AC-009 调整导致 total < 0 → 拒绝 | S2 | Story 2 test-report TC-002 | 通过 |
| 10 | AC-010 锁定库存：available >= quantity → 成功 | S3 | Story 3 test-report TC-001 | 通过 |
| 11 | AC-011 锁定库存：available < quantity → 拒绝，STOCK_INSUFFICIENT | S3 | Story 3 test-report TC-002 | 通过 |
| 12 | AC-012 同一 reservationId 重复锁定 → 返回原结果 | S3 | Story 3 test-report TC-003 | 通过 |
| 13 | AC-013 释放库存：locked -= quantity，状态 RELEASED | S3 | Story 3 test-report TC-004 | 通过 |
| 14 | AC-014 同一 reservationId 重复释放 → 不重复减少 | S3 | Story 3 test-report TC-005 | 通过 |
| 15 | AC-015 确认扣减：total -=、locked -=，状态 DEDUCTED | S4 | Story 4 test-report TC-001 | 通过 |
| 16 | AC-016 同一 reservationId 重复确认扣减 → 不重复扣减 | S4 | Story 4 test-report TC-002 | 通过 |
| 17 | AC-017 确认扣减基于非 LOCKED reservation → 拒绝 | S4 | Story 4 test-report TC-003 | 通过 |
| 18 | AC-018 库存流水记录 INIT/ADJUST/LOCK/RELEASE/DEDUCT | S1/S2/S3/S4 | 各 Story test-report | 通过 |
| 19 | AC-019 并发锁定最后 1 件：仅一个成功 | S3 | lockStock SQL 条件更新 | 通过 |
| 20 | AC-020 mall-admin 库存页可查询/初始化/调整/查看流水 | S1 | DU-FE-401 + V6 权限 | 通过 |
| 21 | AC-021 inventory_stock/inventory_reservation/inventory_log 无 product 主数据字段 | S1 | Flyway V1/V2 仅含 skuId | 通过 |

## 5. 完成确认

- [x] 代码变更已完成（5 DU，跨 repo-1/repo-2）
- [x] 测试已完成（后端 74 tests 全绿；前端 type-check + build 通过）
- [x] 证据已收集（Change evidence.yaml 14 条 EV + 各仓 DU evidence）
- [x] 全局验收标准已逐条对照（§4，21 AC 全部通过）
- [x] 知识更新已评估（feature-tree 已更新；standards/product 无新增；glossary 候选留待 M2 末）
