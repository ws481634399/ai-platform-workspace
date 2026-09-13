# Review Report（Change 级聚合）— CHG-0012

> 阶段：sdd-review 聚合产物（多 Story Change，状态保持 testing）
> 五查逐条记录在各 Story review-report.md，本文件仅聚合结论与跨 Story 检查。

## 0. 元信息

- Change ID: CHG-0012
- Test Report 来源: evidence/test-report.md + 三 Story evidence/test-report.md
- Evidence 索引: evidence/evidence.yaml（EV-001~016）
- 状态流转: testing（检查点，状态不变）
- 检查时间: 2026-09-13

## 1. 检查结论

### 1.1 需求一致性

- Change 全局 AC-001~018 与 Story AC 映射核对完成，逐条对照见 convergence.md §4；全部通过。

### 1.2 设计一致性

- Product 聚合 publish/unpublish 校验链与状态机与设计一致；领域事件注册。
- 商城 mallPage 硬过滤 ON_SALE、按创建时间倒序、非 ON_SALE 详情 404、不含库存字段，与设计一致。
- 内部 ProductSnapshot 字段（price 为分）与设计一致。
- Flyway V5 新增 product:product:publish 权限码，与设计一致。

### 1.3 跨仓一致性（Phase 2.4）

- 权限码 product:product:publish 在后端 @PreAuthorize、V5 种子、前端 v-permission 三处一致。
- 状态枚举 DRAFT/ON_SALE/OFF_SALE/DISABLED 前后端一致。
- DU baseline/result 在 metadata.yaml、implementation.md、evidence.yaml 对齐。

### 1.4 代码质量

- 后端 61、前端 28 全绿；无回归。
- 前端 type-check 0 error、build 成功。
- standards 规范对照无明确违规。

### 1.5 知识同步候选

1. Product 聚合领域事件集合用 new ArrayList 包装（沿用 CHG-0011 约束）。
2. 内部服务间调用认证策略（mTLS/service token）留待网关/服务治理 Change。

## 2. 发现清单

无 blocker/major 开放项。

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 全部 blocker/major finding 已闭环
- [x] 跨 Story 一致性已核对
- [x] 知识同步候选已登记
