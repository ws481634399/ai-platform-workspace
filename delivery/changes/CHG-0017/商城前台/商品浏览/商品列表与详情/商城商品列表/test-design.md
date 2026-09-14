# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0017
- Story ID: STORY-003-02-02-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- Feature Path: 商城前台 > 商品浏览 > 商品列表与详情 > 商城商品列表
- 状态流转: designed → tasked
- TC 总数: 9

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API：page/size 分页正确，total/页数准确；size=51 → 400，size=50 正常 | AC-006 | DU-BE-703 | |
| TC-002 | API：categoryId 筛选命中子孙分类（三层各取一件商品验证） | AC-007 | DU-BE-703 | 后代展开 |
| TC-003 | API：brandIds 多选（逗号分隔）取交集；与 category 组合取交集 | AC-007 | DU-BE-703 | |
| TC-004 | API 顺序断言：default/newest 上架时间倒序；price_asc/price_desc 按 minPrice 序，同分稳定 | AC-008 | DU-BE-703 | 派生表 |
| TC-005 | API：sort=haha 回落 default；未知参数忽略 | AC-008 | DU-BE-703 | |
| TC-006 | JSON 断言：records[].id 字符串、name/mainImageUrl、minPrice/maxPrice 整数分非 null | AC-009 | DU-BE-703 | |
| TC-007 | API：下架商品与无启用 SKU 商品不出现在任何页（翻遍全部页） | AC-010 | DU-BE-703 | |
| TC-008 | 前端组件：筛选/排序/分页交互与 URL query 同步、刷新恢复；空结果 Empty、错误 Error、加载 Loading | AC-018 | DU-FE-703 | |
| TC-009 | 前端类型：金额域模型为 number 整数分（无 parseFloat 浮点金额）；路由游客直达；三检通过 | AC-020 | DU-FE-703 | |

## 2. 测试策略

- Integration：多层分类/多品牌 fixture；排序结果全序断言；价区排序分页 total 一致性（派生表）。
- Frontend：vitest + memory history 测 query 同步；MSW 三态；vue-tsc 零 any 商品域。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-702（侧栏分类/品牌数据）；CHG-0015 价区与过滤。
