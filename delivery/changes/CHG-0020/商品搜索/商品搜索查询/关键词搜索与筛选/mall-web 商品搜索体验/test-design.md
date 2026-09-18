# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0020
- Story ID: STORY-005-01-02-03
- Feature Path: 商品搜索 > 商品搜索查询 > 关键词搜索与筛选 > mall-web 商品搜索体验
- 状态流转: designed → tasked
- TC 总数: 7

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 组件测试+浏览器：搜索框输入回车 → router push /search?keyword=；SearchView 回显关键词、渲染卡片（图/名/价/品牌） | AC-001 | DU-FE-501 | [S1] |
| TC-002 | 组件测试：分类/品牌/价格/排序控件触发请求参数正确；分页翻页；URL→状态回填（刷新还原）；状态→URL 同步 | AC-002 | DU-FE-501 | [S1] |
| TC-003 | 组件测试：空结果空态（含分类浏览引导出口）、loading 骨架、mock 503/网络错误 Error 态+重试按钮（点击重发） | AC-003 | DU-FE-501 | [S1] |
| TC-004 | 浏览器 E2E：点击卡片进入 /product/:id 详情页正常渲染并可返回 | AC-004 | DU-FE-501 | Integration Gate |
| TC-005 | 组件测试：价格输入"120"元 → 请求 minPriceFen=12000；min>max 前端即时提示且不发请求 | AC-005 | DU-FE-501 | [S1] |
| TC-006 | Vitest：stores/search.ts 成功/空/失败三态 action；快速连续查询仅最后一次落屏（竞态） | AC-006 | DU-FE-501 | [S1] |
| TC-007 | 构建门禁：pnpm type-check、lint、test、build 全绿 | AC-006 | DU-FE-501 | [S1] evidence 记录 |

## 2. 测试策略

- Vitest（mount + pinia + router mock + msw/vi.mock 请求）；浏览器验证放 Integration Gate（搜索→筛选→详情路径）。
- 价格换算与 URL 同步为纯函数/store 逻辑，单测重点覆盖。

## 3. 不可测项标注

- 无。

## 4. 依赖与前置条件

- DU-BE-502 搜索接口契约冻结；商品详情页为既有页面。
