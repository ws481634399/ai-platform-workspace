# Review Report（Change 级聚合）— CHG-0011

> 阶段：sdd-review 聚合产物（多 Story Change，状态保持 testing）
> 五查逐条记录在各 Story review-report.md，本文件仅聚合结论与跨 Story 检查。

## 0. 元信息

- Change ID: CHG-0011
- Test Report 来源: evidence/test-report.md + 两 Story evidence/test-report.md
- Evidence 索引: evidence/evidence.yaml（EV-001~012）
- 状态流转: testing（检查点，状态不变）
- 检查时间: 2026-09-13

## 1. 检查结论

### 1.1 需求一致性

- Change 全局 AC-001~015 与 Story AC（SPU 11 + SKU 8）映射核对完成，逐条对照见 convergence.md §4；全部通过（AC-011 浏览器手工走查为登记跟踪项，自动化契约证据闭环）。
- 明细：商品 SPU Story review-report.md §1.1、SKU Story review-report.md §1.1。

### 1.2 设计一致性

- DDD 分层在两个后端 DU 一致落地：Product 聚合根统一管理 SKU 实体生命周期，domain 不感知框架；Money 分价（long）贯穿 Product/Sku；SpecificationHash 规格组合唯一哈希。
- 接口契约 /api/admin/products + /{id}/skus 子资源、ProductView/SkuView、权限码 product:product:* / product:sku:* 与设计一致。
- Flyway V2/V3/V4 迁移无重复/冲突；product_spu/product_sku 无 stock 字段（领域边界）。

### 1.3 跨仓一致性（Phase 2.4）

- API/字段/枚举/权限码在后端 DTO、后端 @PreAuthorize、V4 菜单种子、前端 TS 类型、前端 has() 五处保持字符串级一致。
- DU baseline/result 在仓内 metadata.yaml、仓内 DU implementation.md、Story/Change implementation.md、Change evidence.yaml 四处对齐；3 个 DU 状态均 completed 并经 openspec du sync-status 同步。
- 跨 Story 依赖：DU-BE-305 依赖 DU-BE-304（Product 聚合根与仓储），在 requirement-design §6 声明，同 commit 交付。

### 1.4 代码质量

- 后端 36、前端 28 全绿；无 SQL 注入面；400/403/409 状态语义稳定；无物理删除入口。
- 前端 0 type/lint error、build 成功；el-table row 类型断言、mainImageUrl 空值处理。
- standards 规范对照无明确违规。

### 1.5 知识同步候选

1. MyBatis-Plus `_json` 列名双重序列化陷阱 → 候选 standards。
2. 聚合根集合不可变性（new ArrayList 包装）→ 候选 standards。
3. SpecificationHash 规格组合唯一哈希模式 → 候选 standards。
4. Money 分价模式（long + BIGINT）→ 候选 standards。

## 2. 发现清单

无 blocker/major 开放项；dev 期 major（MyBatis-Plus JSON 双重序列化）已在 red-green 闭环。

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 全部 blocker/major finding 已闭环
- [x] 跨 Story 一致性已核对
- [x] 知识同步候选已登记
