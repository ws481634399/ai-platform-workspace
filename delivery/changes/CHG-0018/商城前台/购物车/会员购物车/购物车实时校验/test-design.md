# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0018
- Story ID: STORY-003-03-01-02
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- Feature Path: 商城前台 > 购物车 > 会员购物车 > 购物车实时校验
- 状态流转: designed → tasked
- TC 总数: 9

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API：GET 车返回图/名/skuName/specs/priceFen/quantity/selected 等，价格来自 product 整数分 | AC-008 | DU-BE-802 | 读模型 |
| TC-002 | API：下架 → PRODUCT_OFF_SHELF；SKU 禁用 → SKU_INVALID；商品/快照缺失 → NOT_FOUND | AC-009 | DU-BE-802 | 失效矩阵 |
| TC-003 | API：后台改价后读车 → itemStatus 含 PRICE_CHANGED 且展示 priceFen 最新值；请求传 price 字段被忽略 | AC-010 | DU-BE-802 | 调价 |
| TC-004 | API：库存 0/1/9/10 → OUT_OF_STOCK/LOW_STOCK/LOW_STOCK/IN_STOCK | AC-011 | DU-BE-802 | 阈值 |
| TC-005 | 故障注入：product 5xx → 全部条目 itemStatus=UNKNOWN，HTTP 200；inventory 5xx → 仅 stockStatus=UNKNOWN | AC-012 | DU-BE-802 | 条目级降级 |
| TC-006 | API：selectedTotalFen 仅计 VALID+选中+有货条目，整数分；selectedCount 正确 | AC-013 | DU-BE-802 | 合计 |
| TC-007 | 调用计数：一次读车 product batch 一次、inventory 一次（≤100 条目无 N+1） | AC-008 | DU-BE-802 | |
| TC-008 | 数据断言：读车后 Redis 条目 quantity/selected/priceFenAtAdded 未被校验改写 | AC-009 | DU-BE-802 | 只读校验 |
| TC-009 | 边界审计：mall-cart 无 product/inventory 数据源/JDBC 依赖，仅 RestClient 内部调用 | AC-021 | DU-BE-802 | 跨库禁令 |

## 2. 测试策略

- Assembler 表驱动：状态优先级×依赖可用性矩阵；金额合计算例（失效/缺货/未选中排除、调价按新价）。
- Mock client 计数与异常注入；空车快照；grep 边界审计。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-801；CHG-0017 availability 端点（mock）。
