# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0017
- Story ID: STORY-003-02-02-02
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- Feature Path: 商城前台 > 商品浏览 > 商品列表与详情 > 商品详情与 SKU 选择
- 状态流转: designed → tasked
- TC 总数: 9

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API：详情含图集/brandName/categoryPath/富文本/specDimensions/skuIndex，skuId 字符串、价格整数分 | AC-011 | DU-BE-704 | |
| TC-002 | 前端表驱动：全规格组合选择 → 唯一 skuId；切换时价格/图片/三态联动 | AC-012 | DU-FE-704 | SkuSelector |
| TC-003 | API/前端：不存在与已下架商品直访详情 → 404 商品页，无加购入口 | AC-013 | DU-BE-704 | 后端码+前端页 |
| TC-004 | 前端：DISABLED SKU 组合不可点；OUT_OF_STOCK SKU 显示缺货标识且加购禁用 | AC-014 | DU-FE-704 | |
| TC-005 | 前端：availability 返回 UNKNOWN 时三态区可重试，图文仍可浏览，加购禁用 | AC-018 | DU-FE-704 | 降级态 |
| TC-006 | 前端：加载中 Loading；富文本/图集异常占位图；游客直达路由 /products/:id；三检通过 | AC-019 | DU-FE-704 | |
| TC-007 | 前端断言：金额全程整数分（priceFen），无浮点解析 | AC-020 | DU-FE-704 | |
| TC-008 | 集成：assembler 矩阵装配（维度归并顺序、组合唯一、禁用 SKU status 透传） | AC-011 | DU-BE-704 | |
| TC-009 | 集成：同一规格组合数据冲突时防御取一不 500（构造脏数据） | AC-013 | DU-BE-704 | 防御 |

## 2. 测试策略

- Integration：详情 assembler 多规格 fixture；下架/删除 404。
- Frontend：SkuSelector 全组合表（颜色×容量）vitest；MSW 三态/UNKNOWN；vue-tsc/eslint/build。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-705（availability）；DU-FE-701 状态组件复用。
