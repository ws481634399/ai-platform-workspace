# Test Report — SKU 与规格管理 STORY-002-02-02-01

> 阶段：sdd-test 产物
> 位置：Story 级 evidence/test-report.md
> 输入：test-design.md + 仓内 DU implementation.md
> 产出状态：testing

本文档记录测试执行情况与证据；仓侧测试日志正文不复制，以 evidence-ref 引用。

## 0. 元信息

- Change ID: CHG-0011
- Story ID: STORY-002-02-02-01（SKU 与规格管理）
- Implementation 来源: 同目录 implementation.md（repo-1 DU-BE-305）
- 状态流转: developing → testing
- 执行时间: 2026-09-13
- Evidence 索引: CHG-0011/evidence/evidence.yaml（EV-011 后端 test-run、EV-009 evidence-ref）

## 1. 测试范围

- 测试范围摘要：Sku 聚合行为（规格组合 SHA-256 唯一哈希、Money 分价非负、SkuStatus 启停）、Product 聚合 addSku/updateSku/enableSku/disableSku、SKU 编码唯一（uk_sku_code）、规格组合唯一（uk_product_spec_hash）、SKU 子资源端点与权限。
- 覆盖 DU: DU-BE-305

### TC 逐条执行

| TC | 归属 DU | 执行方式 | 结果 | 证据位置 |
| --- | --- | --- | --- | --- |
| TC-001 | DU-BE-305 | ProductAdminApiTest：Product 下新增 2 个 SKU → 200，详情含 2 SKU | passed | repo-1 DU-BE-305 evidence/test-output.log |
| TC-002 | DU-BE-305 | API：新增 SKU 编码与已有重复 → 409 CONFLICT，库中无新记录 | passed | 同上 |
| TC-003 | DU-BE-305 | 领域单测+API：salePrice 为分（long），负数构造抛 ProductException；DB 列为 BIGINT | passed | 同上 |
| TC-004 | DU-BE-305 | API：同 Product 下两 SKU 规格键值相同（顺序不同）→ 409 CONFLICT（hash 相同） | passed | 同上 |
| TC-005 | DU-BE-305 | API：修改 SKU 价格/图片/状态；查询返回最新值 | passed | 同上 |
| TC-006 | DU-BE-305 | API 安全切片：缺 product:sku:create/update 权限 403；有权限 200 | passed | 同上 |
| TC-007 | DU-BE-305 | 领域单测：addSku 注册 SkuAdded；changeSkuPrice 注册 SkuPriceChanged；enableSku/disableSku 注册对应事件 | passed | 同上 |
| TC-008 | DU-BE-305 | API：SKU 禁用后 status=DISABLED；启用后 ENABLED；不影响其他 SKU | passed | 同上 |

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 单元测试（后端 Sku/Product 领域） | 含于 36 | 全通过 | 0 | 0 |
| 集成测试（后端 ProductAdminApiTest MockMvc/H2，含 SKU 相关 9 例中覆盖 TC-001~008） | 9 | 9 | 0 | 0 |

- 自动化通过率: 后端 mall-product 全模块 36 passed，无回归。
- 缺陷: 无未闭环缺陷；dev 期红绿灯（不可变集合 UnsupportedOperationException、created_at NULL、MyBatis-Plus JSON 双重序列化、ProductErrorCode 枚举名不一致）均在 red-green 记录并修复。

## 3. 证据清单

- repo-1 DU-BE-305：implementation/ai-platform-backend/delivery/CHG-0011/商品与库存/商品与 SKU 管理/SKU 与规格/SKU 与规格管理/DU-BE-305/evidence/（test-output.log、evidence.yaml）
- Change 级索引：evidence/evidence.yaml EV-011（后端 product 36 passed）
