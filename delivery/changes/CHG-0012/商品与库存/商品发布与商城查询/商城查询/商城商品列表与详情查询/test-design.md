# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 位置：STORY 级 —— `CHG-0012/.../商城商品列表与详情查询/test-design.md`
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0012
- Story ID: STORY-002-03-02-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- 状态流转: designed → tasked
- TC 总数: 6

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API 集成测试：创建 DRAFT+ON_SALE+OFF_SALE 商品，GET /api/mall/products 仅返回 ON_SALE | AC-001 | DU-BE-307 | ON_SALE 过滤 |
| TC-002 | API 集成测试：列表支持 categoryId/brandId 筛选与分页 | AC-002 | DU-BE-307 | 筛选分页 |
| TC-003 | API 集成测试：列表按 createdAt 倒序 | AC-003 | DU-BE-307 | 排序 |
| TC-004 | API 集成测试：ON_SALE 商品详情返回 Product+SKU 完整信息 | AC-004 | DU-BE-307 | 详情 |
| TC-005 | API 集成测试：DRAFT/OFF_SALE 商品详情 → 404 | AC-005 | DU-BE-307 | 非可售不可查 |
| TC-006 | 静态检查+响应断言：详情响应不含 stock/inventory 字段 | AC-006 | DU-BE-307 | 不伪造库存 |

## 2. 测试策略

- API 集成：@SpringBootTest + MockMvc + H2，商城接口公开（不需 token）。
- 数据准备：创建多状态商品验证过滤；预置分类/品牌。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-306 提供 ON_SALE 商品数据；分类/品牌/Product/SKU 表由 CHG-0010/0011 提供。
