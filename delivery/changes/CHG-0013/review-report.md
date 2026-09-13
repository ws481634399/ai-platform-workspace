# Review Report（Change 级聚合）— CHG-0013

> 阶段：sdd-review 聚合产物（多 Story Change，状态保持 testing）
> 五查逐条记录在各 Story review-report.md，本文件仅聚合结论与跨 Story 检查。

## 0. 元信息

- Change ID: CHG-0013
- Test Report 来源: evidence/test-report.md + 四 Story evidence/test-report.md
- Evidence 索引: evidence/evidence.yaml（EV-001~014）
- 状态流转: testing（检查点，状态不变）
- 检查时间: 2026-09-13

## 1. 检查结论

### 1.1 需求一致性

- Change 全局 AC-001~021 与 Story AC 映射核对完成，逐条对照见 convergence.md §4；全部通过。

### 1.2 设计一致性

- Inventory 聚合 initialize/adjust/lock/release/confirmDeduction 与设计一致；状态机与幂等处理正确。
- InventoryReservation 状态机 LOCKED→RELEASED/DEDUCTED，reconstitute 重建，与设计一致。
- 并发安全使用 SQL 条件更新 `WHERE (total - locked) >= ?`，与设计一致。
- Flyway V1/V2 建表（inventory_stock/inventory_log/inventory_reservation）仅含 skuId，无 product 主数据字段，与设计一致。
- mall-identity V6 新增 inventory:stock:*、inventory:log:list 权限码，与设计一致。

### 1.3 跨仓一致性（Phase 2.4）

- 权限码 inventory:stock:*、inventory:log:list 在后端 @PreAuthorize、V6 种子、前端 v-permission 三处一致。
- 库存操作枚举 INIT/ADJUST/LOCK/RELEASE/DEDUCT 前后端一致。
- DU baseline/result 在 metadata.yaml、implementation.md、evidence.yaml 对齐。

### 1.4 代码质量

- 后端 74 测试全绿；无回归。
- 前端 type-check 0 error、build 成功。
- standards 规范对照无明确违规。

### 1.5 知识同步候选

- 并发安全用 SQL 条件更新（非乐观锁版本号），适合库存扣减场景。
- 库存与商品独立上下文，通过内部 API 契约交互。
- 统一在 convergence.md 评估沉淀。

## 2. 发现清单

无 blocker；无 major 开放项。

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 全部 blocker/major finding 已闭环
- [x] 跨仓一致性已核对
- [x] 知识同步候选已记录
