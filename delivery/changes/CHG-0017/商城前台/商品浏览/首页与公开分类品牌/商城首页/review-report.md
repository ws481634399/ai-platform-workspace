# Review Report — STORY-003-02-01-01 商城首页

## 0. 元信息

- Change ID：CHG-0017
- Story ID：STORY-003-02-01-01
- 审查对象：DU-BE-701（repo-1）、DU-FE-701（repo-2）
- 审查时间：2026-09-15
- 审查者：trae-agent

## 1. 检查结论

**通过（PASS）。** 实现与 story-design 一致，复用已有能力（分类树、商品列表价区填充），测试覆盖充分，无阻塞问题。

## 2. 发现清单

| 编号 | 严重度 | 发现 | 处理 |
|------|--------|------|------|
| F-001 | info | 分类 iconImageUrl 字段暂为 null（Category 聚合无 icon 字段） | 符合 M3 设计，前端可忽略 |
| F-002 | info | 推荐位复用新品列表（source=FALLBACK_NEWEST） | M3 占位，后续推荐引擎替换 |

无 blocker / major 发现。

## 3. 检查项明细

| 项 | 结论 |
|----|------|
| 接口契约与设计一致 | GET /api/mall/home → HomeView{categoryEntries,newArrivals,recommends,banners} |
| 分类入口 | 仅启用根分类，≤8，sort 序，@StringId |
| 新品 | ON_SALE + EXISTS 启用 SKU，LIMIT 10，价区 MIN/MAX 填充 |
| 推荐 | fallback 同新品，source=FALLBACK_NEWEST |
| banners | 空数组 [] |
| 空态 | 各数组返回 [] 非 null |
| 安全 | 匿名，网关白名单已由 DU-BE-702 加好 |
| 复用 | 复用 ProductApplicationService.mallPage（EXISTS+价区）、CategoryApplicationService.mallTree |
| 测试覆盖 | 3 例覆盖聚合/空态/上限 |

## 4. Deviations

无。
