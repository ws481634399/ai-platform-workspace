# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0017
- Story ID: STORY-003-02-01-02
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- Feature Path: 商城前台 > 商品浏览 > 首页与公开分类品牌 > 公开分类与品牌查询
- 状态流转: designed → tasked
- TC 总数: 4

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 网关集成：匿名 GET /api/mall/categories/tree → 200 树；禁用父节点整枝（含启用子节点）不出现；按 sort | AC-003 | DU-BE-702 | 剪枝 |
| TC-002 | API：GET /api/mall/brands 仅启用；?keyword= 模糊过滤；size>200 收敛 200；id 字符串 | AC-004 | DU-BE-702 | |
| TC-003 | 网关：匿名访问 tree/brands 200；外部访问 /api/internal/** → denyAll 404 | AC-005 | DU-BE-702 | 隔离沿用 |
| TC-004 | API：空分类树/空品牌结果返回 [] 结构而非 null | AC-004 | DU-BE-702 | 空态 |

## 2. 测试策略

- Integration：分类三层禁用矩阵（禁根/禁枝/禁叶）；品牌分页边界。
- Gateway：8080 匿名/内网路径外拒。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- CHG-0015 DU-BE-501。
