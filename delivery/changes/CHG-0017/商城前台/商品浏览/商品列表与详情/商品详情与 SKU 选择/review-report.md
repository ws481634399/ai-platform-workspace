# Review Report — STORY-003-02-02-02 商品详情与 SKU 选择

## 0. 元信息

- Change ID：CHG-0017
- Story ID：STORY-003-02-02-02
- 审查对象：DU-BE-704（repo-1）、DU-FE-704（repo-2）
- 审查时间：2026-09-16
- 审查者：trae-agent

## 1. 检查结论

**通过（PASS）。** 详情聚合与 SKU 矩阵选择实现符合 requirement-design §2.4/§4 契约：后端矩阵归并直线算法 + 冲突/缺值防御齐备；前端表驱动选择器、三态降级（UNKNOWN 不阻塞图文）、富文本净化到位。自审发现 2 个 FE 缺陷（多维禁用误判、StateView API 误用）已修复并补守护测试。

## 2. 发现清单

| 编号 | 严重度 | 发现 | 处理 |
|------|--------|------|------|
| F-001 | major | SkuSelector 初版 isValueDisabled 仅枚举首个未选维度，三维度以上未选时组合键残留通配符 → 所有维度值误禁用 | 已修复（92b0839）：遍历 skuIndex 全部组合做兼容性匹配；补三维度守护测试 |
| F-002 | major | ProductDetailView 误用 StateView 不存在的 `state` prop，实际 API 为 loading/error/is-empty → 状态视图不生效 | 已修复（92b0839）：对齐三 prop，404→is-empty 专门态 |
| F-003 | minor | availability 批量失败会导致整个详情页 error，违背"UNKNOWN 不阻塞图文浏览"设计 | 已修复（92b0839）：内层 try/catch 降级空 map（各 SKU 显示 UNKNOWN + 重试） |
| F-004 | info | 加购按钮为占位（console.info） | 符合 Story 边界，CHG-0018 DU-FE-801 接入 |
| F-005 | info | DOMPurify 在 happy-dom 下降级不净化（环境限制，浏览器正常） | ProductDetailView.spec 用 `@vitest-environment jsdom` 验证净化，新增 jsdom devDep |

无遗留 blocker / major。

## 3. 检查项明细

| 项 | 结论 |
|----|------|
| 404 统一口径（不存在/非 ON_SALE/无启用 SKU） | getMallById 既有口径 + 2 例测试；前端 404 专门态无加购入口 |
| specDimensions 归并 | LinkedHashMap 维度首次序 + LinkedHashSet 值去重保序 |
| skuIndex 组合键唯一 | `value1\|value2` 按 dimensionsOrder；冲突取 skuId 较小 + warn 不 500 |
| 禁用/缺规格 SKU | 禁用不进矩阵但保留 skus；空 specs 跳过矩阵 |
| brand/category 缺失降级 | try/catch → null / 已上溯段，不 500；categoryPath 深度 ≤3 |
| 选择器联动 | 组合键 computed 表查找；onSkuChange 切主图（imageUrl ?? 主图）、价格、三态 |
| DISABLED 置灰 | isValueDisabled 全组合兼容匹配（任意维度数） |
| 三态 + UNKNOWN 降级 | StockBadge 四态文案；批量失败不阻塞；局部重试；OUT_OF_STOCK/UNKNOWN 禁用加购 |
| 富文本安全 | DOMPurify.sanitize 后 v-html；jsdom 测试验证 script 剥离 |
| 金额整数分 | priceFen number 透传，PriceText 整数拆分，无 parseFloat |
| 类型/构建 | vue-tsc 零错误；vite build 成功；mall-product 93、mall-web 85 全绿 |

## 4. Deviations

无。
