# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 位置：STORY 级 —— `CHG-0013/.../库存初始化与查询/test-design.md`
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-01-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- 状态流转: designed → tasked
- TC 总数: 10

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API 集成测试：携带 inventory:stock:init，POST /init 合法 skuId+totalQuantity>=0 → 200，total=初始值、locked=0、available=total | AC-001 | DU-BE-401 | 初始化 |
| TC-002 | API 集成测试：skuId 不存在（mock SkuClient 返回不存在）→ INVALID_ARGUMENT | AC-002 | DU-BE-401 | SKU 契约 |
| TC-003 | API 集成测试：同一 skuId 重复初始化 → CONFLICT，无重复落库 | AC-003 | DU-BE-401 | 幂等初始化 |
| TC-004 | API 集成测试：totalQuantity<0 → INVALID_ARGUMENT | AC-004 | DU-BE-401 | 非法值 |
| TC-005 | API 集成测试：GET /{skuId} 返回 total/locked/available，available=total-locked | AC-005 | DU-BE-401 | 单查 |
| TC-006 | API 集成测试：POST /batch 批量查询多个 skuId 返回各 SKU 库存 | AC-006 | DU-BE-401 | 批查 |
| TC-007 | API 集成测试：GET /stocks 分页查询库存列表 | AC-007 | DU-BE-401 | 后台分页 |
| TC-008 | 数据断言：初始化后 inventory_log 存在 INIT 记录，含 skuId/quantity/before=0/after=total | AC-018 | DU-BE-401 | INIT 流水 |
| TC-009 | 安全切片：无 inventory:stock:init/list → 403；有权限 → 200 | AC-020 | DU-BE-401 | RBAC |
| TC-010 | 静态检查+迁移断言：inventory_stock 表仅含 sku_id/total/locked/version 等字段，无 product 主数据字段 | AC-021 | DU-BE-401 | 领域边界 |

## 2. 测试策略

- Unit：Inventory 聚合不变量（total>=0、locked>=0、available=total-locked）。
- API 集成：@SpringBootTest + MockMvc + H2，安全切片注入 authorities，mock SkuClient。
- 数据准备：Flyway V1 建表后直接插入测试数据。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-401 权限码 V4 先执行；mall-product SKU 内部接口由 CHG-0012 提供（mock）。
