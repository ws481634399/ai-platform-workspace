# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 位置：STORY 级 —— `CHG-0012/.../商品上下架与发布/test-design.md`
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0012
- Story ID: STORY-002-03-01-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- 状态流转: designed → tasked
- TC 总数: 9

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API 集成测试：DRAFT 商品含主图+ENABLED SKU+价格合法 → POST publish → 200，status=ON_SALE | AC-001 | DU-BE-306 | 上架成功 |
| TC-002 | API 集成测试：无主图商品 publish → 400 INVALID_ARGUMENT | AC-002 | DU-BE-306 | 主图校验 |
| TC-003 | API 集成测试：无 ENABLED SKU 商品 publish → 400 | AC-003 | DU-BE-306 | SKU 校验 |
| TC-004 | API 集成测试：DISABLED 商品 publish → 400 | AC-004 | DU-BE-306 | 禁用不可上架 |
| TC-005 | API 集成测试：ON_SALE 商品 POST unpublish → 200，status=OFF_SALE | AC-005 | DU-BE-306 | 下架 |
| TC-006 | API 集成测试：OFF_SALE 商品满足条件重新 publish → 200，ON_SALE | AC-006 | DU-BE-306 | 重新上架 |
| TC-007 | 领域单测：Product.publish 注册 ProductPublishedDomainEvent；unpublish 注册 ProductUnpublishedDomainEvent | AC-007 | DU-BE-306 | 领域事件 |
| TC-008 | 安全切片：无 product:product:publish → 403；有权限 → 200 | AC-008 | DU-BE-306 | RBAC |
| TC-009 | E2E：mall-admin 商品页上架/下架按钮操作成功 | AC-009 | DU-FE-304 | 前端 |

## 2. 测试策略

- Unit：Product 聚合 publish/unpublish 不变量（上架校验、状态流转、领域事件注册）。
- API 集成：@SpringBootTest + MockMvc + H2，安全切片注入 authorities。
- E2E：本地联调人工验证前端页面。
- 数据准备：复用 CHG-0011 分类/品牌/Product/SKU 测试数据构造。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-306 权限码 V5 先执行；分类/品牌/Product/SKU 表由 CHG-0010/0011 提供。
