# Test Design（Change 级验证意图）— CHG-0011

> 阶段：sdd-task 聚合产物（多 Story Change）
> 位置：CHG-0011/test-design.md
> TC 权威明细在各 Story test-design.md（同编号在各 Story 命名空间内），本文件聚合全部 TC 供 Change 级 tc-coverage 机检。

## 0. 元信息

- Change ID: CHG-0011
- Story 数: 2（STORY-002-02-01-01 商品 SPU 管理、STORY-002-02-02-01 SKU 与规格管理）
- TC 总数: 19（SPU 11 + SKU 8）
- 状态流转: designed → tasked

## 1. 测试用例

### Story STORY-002-02-01-01 商品 SPU 管理（来源：商品与库存/商品与 SKU 管理/商品主数据/商品 SPU 管理/test-design.md）

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API 集成：product:product:create POST 合法 Product → 200，status=DRAFT | AC-001 | DU-BE-304 | |
| TC-002 | API 集成：categoryId/brandId 不存在 → INVALID_ARGUMENT | AC-002 | DU-BE-304 | |
| TC-003 | API 集成：主图+2 图集；详情仅一条 mainFlag=1 | AC-007 | DU-BE-304 | 主图唯一 |
| TC-004 | API 集成：PUT 修改名称/属性/图片；GET 返回最新值 | AC-008 | DU-BE-304 | |
| TC-005 | 静态检查+迁移断言：product_spu/product_sku 无 stock 列 | AC-009 | DU-BE-304 | |
| TC-006 | API 集成：创建后 status=DRAFT；枚举含四态 | AC-010 | DU-BE-304 | |
| TC-007 | API 集成：创建含 2 属性；修改后属性集合正确 | AC-012 | DU-BE-304 | |
| TC-008 | 安全切片：无 product:product:* 权限 → 403；有权限 → 200 | AC-013 | DU-BE-304 | |
| TC-009 | 领域单测：create/update 注册领域事件 | AC-014 | DU-BE-304 | |
| TC-010 | API 集成：DISABLED 后聚合拒绝发布 | AC-015 | DU-BE-304 | |
| TC-011 | E2E：商品列表/创建/编辑/查看页操作成功 | AC-011 | DU-FE-303 | |

### Story STORY-002-02-02-01 SKU 与规格管理（来源：商品与库存/商品与 SKU 管理/SKU 与规格/SKU 与规格管理/test-design.md）

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API 集成：Product 下新增 2 SKU → 200，详情含 2 SKU | AC-003 | DU-BE-305 | |
| TC-002 | API 集成：SKU 编码重复 → CONFLICT，无新记录 | AC-004 | DU-BE-305 | |
| TC-003 | 领域单测+API：salePrice 分（long），负数抛异常；DB BIGINT | AC-005 | DU-BE-305 | |
| TC-004 | API 集成：同 Product 规格键值相同（顺序不同）→ CONFLICT | AC-006 | DU-BE-305 | hash 相同 |
| TC-005 | API 集成：修改 SKU 价格/图片/状态；查询返回最新值 | AC-008 | DU-BE-305 | |
| TC-006 | 安全切片：无 product:sku:* 权限 → 403；有权限 → 200 | AC-013 | DU-BE-305 | |
| TC-007 | 领域单测：addSku/changeSkuPrice/enableSku/disableSku 注册事件 | AC-014 | DU-BE-305 | |
| TC-008 | API 集成：SKU 禁用/启用，不影响其他 SKU | AC-015 | DU-BE-305 | |
