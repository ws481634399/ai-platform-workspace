# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0017
- Story ID: STORY-003-02-01-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- Feature Path: 商城前台 > 商品浏览 > 首页与公开分类品牌 > 商城首页
- 状态流转: designed → tasked
- TC 总数: 5

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 网关集成：匿名 GET /api/mall/home → 200，含 categoryEntries/newArrivals/recommends/banners，数据真实 | AC-001 | DU-BE-701 | |
| TC-002 | 集成：商品位仅 ON_SALE 且存在启用 SKU；顺序为上架时间倒序 LIMIT 10；recommends.source=FALLBACK_NEWEST | AC-002 | DU-BE-701 | |
| TC-003 | 集成：无商品数据时 newArrivals=[]，接口 200（首页空态数据） | AC-002 | DU-BE-701 | |
| TC-004 | 前端组件：HomeView loading/empty/error/成功四态；分类入口与卡片点击路由 | AC-019 | DU-FE-701 | |
| TC-005 | 前端：banner 静态位渲染；ProductCard 价区分数展示为整数分格式、图片懒加载；三检通过 | AC-019 | DU-FE-701 | build/lint/type-check |

## 2. 测试策略

- Integration：商品/分类混合 fixture（下架、无启用 SKU、正常三类）；SQL 调用计数断言。
- Frontend：MSW/nock mock home 响应四态；vitest + 三检。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-702（分类树）、CHG-0015（价区/过滤）。
