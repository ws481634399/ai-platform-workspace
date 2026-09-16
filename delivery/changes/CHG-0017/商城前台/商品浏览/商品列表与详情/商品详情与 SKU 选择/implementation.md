# Implementation（跨仓实施汇总）— 商品详情与 SKU 选择 STORY-003-02-02-02

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0017（商城商品浏览体验）
- Story：STORY-003-02-02-02 商品详情与 SKU 选择
- 实施日期：2026-09-16

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-704 | repo-1 | mall-product 93/93（新增 3 + 既有 90） |
| DU-FE-704 | repo-2 | mall-web 85/85（新增 14 + 既有 71），build 成功 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 8496b53 | DU-BE-704 | repo-1 | 详情增强：brandName/categoryPath/specDimensions/skuIndex + 冲突防御 |
| 30712bd | DU-FE-704 | repo-2 | 详情页 + SkuSelector 表驱动选择器 + StockBadge 三态 |
| 92b0839 | DU-FE-704 | repo-2 | 自审修复：多维禁用算法、StateView props 对齐、UNKNOWN 降级、tsc 零错误 + 5 例测试 |

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0017/商城前台/商品浏览/商品列表与详情/商品详情与 SKU 选择/DU-BE-704/implementation.md`
  - `MallProductController.toDetailView`：brandName 缺失降级 null；categoryPath 沿 parent_id 上溯 ≤3；specDimensions LinkedHashMap 归并去重保序；skuIndex 组合键 `value1|value2`；冲突取 skuId 较小并 warn；仅启用 SKU 进矩阵
- repo-2：`implementation/ai-platform-frontend/delivery/CHG-0017/商城前台/商品浏览/商品列表与详情/商品详情与 SKU 选择/DU-FE-704/implementation.md`
  - SkuSelector 声明式 computed 表查找，DISABLED 组合置灰；StockBadge 三态 + UNKNOWN 重试；ProductDetailView DOMPurify 富文本净化、批量 availability、404 专门态；路由 `/products/:id`

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-011 | 详情 200 含图集/品牌/分类路径/介绍/规格维度/SKU 索引 | passed（detailWithMatrix） |
| AC-012 | 选规格定位唯一 skuId，切换联动价格/图片/可售状态 | passed（SkuSelector 选齐命中唯一 SKU；onSkuChange 切主图/价格/StockBadge） |
| AC-013 | 不存在/下架/无启用 SKU → 404 不可售页，无加购操作态 | passed（detailNotFound / detailNoEnabledSku；前端 empty 专门态无加购入口） |
| AC-014 | 失效 SKU 组合不可选，缺货有明确标识 | passed（DISABLED 组合置灰 disabled 测试；OUT_OF_STOCK 缺货徽标） |
| AC-018 | 详情加载/错误/不存在视图完整 | passed（StateView loading/error/empty + 404） |
| AC-020 | SKU 价格整数分，前端无浮点金额 | passed（priceFen number；PriceText 整数拆分；无 parseFloat） |

## 5. 前置 Story 代码提交（repos-coverage 累计）

| Commit | Story | 说明 |
| --- | --- | --- |
| b4b5a1f | STORY-003-02-01-02 | 公开分类树/品牌接口 + 网关白名单 |
| b982bf5 | STORY-003-02-03-01 | SKU 可售状态聚合 |
| 868ee02 | STORY-003-02-01-01 | 商城首页聚合 |
| 2c85e52 | STORY-003-02-01-01 | 商城首页 FE |
| 751a792 | STORY-003-02-02-01 | 商品列表增强 BE |
| 5a97392 | STORY-003-02-02-01 | 商品列表页 FE |
