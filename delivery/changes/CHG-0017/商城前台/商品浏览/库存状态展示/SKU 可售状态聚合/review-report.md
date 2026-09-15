# Review Report — STORY-003-02-03-01 SKU 可售状态聚合

## 0. 元信息

- Change ID：CHG-0017
- Story ID：STORY-003-02-03-01
- 审查对象：DU-BE-705（repo-1）
- 审查时间：2026-09-15
- 审查者：trae-agent

## 1. 检查结论

**通过（PASS）。** 实现与 story-design 一致，三态阈值与降级逻辑正确，白名单 DTO 物理隔离精确库存。

## 2. 发现清单

| 编号 | 严重度 | 发现 | 处理 |
|------|--------|------|------|
| F-001 | info | inventory 与 product 各自定义 AVAILABILITY_BATCH_INVALID 错误码（B2208/B2181） | 符合各域错误码段划分惯例 |

无 blocker / major 发现。

## 3. 检查项明细

| 项 | 结论 |
|----|------|
| 内部端点批量 SQL、无记录=0 | 一次 findBySkuIds，map.getOrDefault(id, 0L) |
| 阈值常量 SSOT | StockStatus.STOCK_IN_THRESHOLD=10 |
| 三态映射 | 0→OUT、1-9→LOW、≥10→IN |
| 白名单 DTO | SkuAvailabilityView 仅 skuId+stockStatus，无 availableQty |
| 降级 | inventory 异常 → 全 UNKNOWN，HTTP 200 |
| 批量校验 | 空/>100/非正 → 400；无 token → 401 |
| 网关 | /api/mall/skus/** permitAll（DU-BE-702 已加）；/api/internal/inventory/** denyAll |

## 4. Deviations

无。
