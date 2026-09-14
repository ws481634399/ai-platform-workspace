---
story-id: "STORY-003-02-03-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S5]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0017
- Story ID: STORY-003-02-03-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

在 mall-product 提供商城侧批量 SKU 可售状态聚合：经内部契约一次批量调用 mall-inventory，按统一阈值映射三态返回；同时作为 mall-cart 实时校验的内部复用能力；避免 N+1，不向前端暴露精确库存。

## 2. Scope（范围）

### 2.1 包含

- [S5] 商城批量可售查询接口（mall-product 对浏览器）；product→inventory 内部批量调用（SERVICE 凭证，CHG-0015）；阈值常量映射；降级语义；内部复用接口形状（供 mall-cart）。

### 2.2 不包含

- 精确库存数对外展示；库存管理（M2 已交付）；下单锁库存（M4）。

## 3. 业务规则

- 入参 skuIds ≤100；返回 IN_STOCK/LOW_STOCK/OUT_OF_STOCK；阈值 LOW_STOCK 边界常量 10（0 缺货、1–9 不足、≥10 有货），与购物车共用。
- 仅一次批量内部调用，禁止循环单查（测试/日志验证）。
- inventory 故障：返回条目级 UNKNOWN 或整体 503（设计定，默认条目级 UNKNOWN + 整车 200）。
- 下架/失效 SKU 由商品状态先过滤；库存只管数值映射。

## 4. 接口与字段规格

- 商城：GET/POST /api/mall/skus/availability（POST { skuIds:string[] }）→ [{ skuId:string, status: IN_STOCK|LOW_STOCK|OUT_OF_STOCK|UNKNOWN }]
- 内部：product 对 cart 暴露的内部聚合契约（design 定路径，归 /api/internal）。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-015 | 批量（≤100）返回各 SKU 三态，仅一次 inventory 调用（无 N+1 实证） |
| AC-016 | 阈值映射正确（0 缺货/1–9 不足/≥10 有货），公开响应无精确数字 |
| AC-017 | inventory 不可用时优雅降级（UNKNOWN/可重试），商城不白屏 |
