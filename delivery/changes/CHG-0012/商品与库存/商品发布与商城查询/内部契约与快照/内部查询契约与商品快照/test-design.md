# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 位置：STORY 级 —— `CHG-0012/.../内部查询契约与商品快照/test-design.md`
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0012
- Story ID: STORY-002-03-03-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- 状态流转: designed → tasked
- TC 总数: 5

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API 集成测试：GET /api/internal/products/{id}/skus/{skuId} 返回全部 8 个字段 | AC-001 | DU-BE-308 | 完整快照 |
| TC-002 | 静态检查：ProductSnapshotView 为独立 record，不引用 Product/Sku 领域类 | AC-002 | DU-BE-308 | 领域隔离 |
| TC-003 | API 集成测试：商品不存在 → 404；SKU 不属于该商品 → 404 | AC-003 | DU-BE-308 | 404 场景 |
| TC-004 | API 集成测试：price 字段等于 SKU salePriceInCents（long） | AC-004 | DU-BE-308 | 价格为分 |
| TC-005 | API 集成测试：skuAttributes 等于 SKU 规格键值对 | AC-005 | DU-BE-308 | 规格映射 |

## 2. 测试策略

- API 集成：@SpringBootTest + MockMvc + H2，内部接口走测试安全配置。
- 静态检查：ProductSnapshotView 源码不 import Product/Sku 领域类。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- 分类/品牌/Product/SKU 表由 CHG-0010/0011 提供。
