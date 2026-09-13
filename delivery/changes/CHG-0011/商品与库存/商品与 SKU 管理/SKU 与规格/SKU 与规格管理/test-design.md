# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 位置：STORY 级 —— `CHG-0011/.../SKU 与规格管理/test-design.md`
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0011
- Story ID: STORY-002-02-02-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- 状态流转: designed → tasked
- TC 总数: 8

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API 集成测试：Product 下新增 2 个 SKU → 200，详情含 2 SKU | AC-003 | DU-BE-305 | |
| TC-002 | API 集成测试：新增 SKU 编码与已有重复 → CONFLICT，库中无新记录 | AC-004 | DU-BE-305 | 编码唯一 |
| TC-003 | 领域单测+API：salePrice 为分（long），负数构造抛异常；DB 列为 BIGINT | AC-005 | DU-BE-305 | 价格边界 |
| TC-004 | API 集成测试：同 Product 下两 SKU 规格键值相同（顺序不同）→ CONFLICT（hash 相同） | AC-006 | DU-BE-305 | 组合唯一 |
| TC-005 | API 集成测试：修改 SKU 价格/图片/状态；查询返回最新值 | AC-008 | DU-BE-305 | 一致性 |
| TC-006 | 安全切片：无 product:sku:create/update → 403；有权限 → 200 | AC-013 | DU-BE-305 | RBAC |
| TC-007 | 领域单测：addSku 注册 SkuAdded；changeSkuPrice 注册 SkuPriceChanged；enableSku/disableSku 注册对应事件 | AC-014 | DU-BE-305 | 领域事件 |
| TC-008 | API 集成测试：SKU 禁用后 status=DISABLED；启用后 ENABLED；不影响其他 SKU | AC-015 | DU-BE-305 | SKU 启停 |

## 2. 测试策略

- Unit：Sku 聚合行为（hash 计算、价格非负、启停、事件注册）；并发同编码用 DB uk 兜底。
- API 集成：@SpringBootTest + MockMvc + H2；复用 ApiTestSecurityConfig。
- 哈希稳定性：用相同规格不同顺序构造，断言 hash 相同。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-304（Product 聚合与表）先完成；product_sku V3 迁移执行。
- TC-004 依赖 TC-001 先创建 Product。
