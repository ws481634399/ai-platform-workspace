# Review Report — SKU 与规格管理 STORY-002-02-02-01

> 阶段：sdd-review 产物（Story 级检查点，状态保持 testing）
> 输入：story-spec.md / story-design.md / test-design.md + 仓内 DU-BE-305 产物 + evidence/test-report.md + Change evidence/evidence.yaml + standards/

## 0. 元信息

- Change ID: CHG-0011
- Story ID: STORY-002-02-02-01（SKU 与规格管理）
- Test Report 来源: 本目录 evidence/test-report.md
- Evidence 索引: CHG-0011/evidence/evidence.yaml（EV-004/005 code-change，EV-011 test-run，EV-009 evidence-ref）
- 状态流转: testing（检查点，状态不变）
- 检查时间: 2026-09-13

## 1. 检查结论

四项检查 + 知识同步候选全部执行；无 blocker/major 开放项，dev 期发现的问题均已在 DU red-green 闭环并复测通过。

### 1.1 需求一致性

| AC | 需求要点 | 证据（test-run covers / 用例） | 结论 |
| --- | --- | --- | --- |
| AC-003 | 一个 Product 可创建一个或多个 SKU | EV-011 / TC-001（2 个 SKU 创建） | 一致 |
| AC-004 | SKU Code 全局唯一，重复拒绝且无落库 | EV-011 / TC-002（409 CONFLICT） | 一致 |
| AC-005 | 销售价为分（long）且 >= 0，无浮点金额字段 | EV-011 / TC-003（Money.amountInCents long，负数抛异常） | 一致 |
| AC-006 | 同 Product 内规格组合唯一，重复拒绝 | EV-011 / TC-004（规格顺序不同 hash 相同 → 409） | 一致 |
| AC-008 | SKU 价格/图片/状态修改后查询一致 | EV-011 / TC-005 | 一致 |
| AC-013 | 无 product:sku:* 权限 → 403；有权限 → 成功 | EV-011 / TC-006 | 一致 |
| AC-014 | SKU 增/改/价格变更/启停注册领域事件 | EV-011 / TC-007 | 一致 |
| AC-015 | SKU 可独立 ENABLED/DISABLED | EV-011 / TC-008 | 一致 |

### 1.2 设计一致性

- Sku 聚合（SpecificationHash 按 name 字典序拼接 name=value 后 SHA-256、Money 分价、SkuStatus 启停）与 story-design §2 域模型一致；SpecificationHash 保证规格组合唯一性（顺序无关）。
- Product 聚合 addSku/updateSku/enableSku/disableSku 行为，SKU 随 Product.update() 全量替换（delete+insert），与设计"SKU 作为 Product 聚合内实体，统一持久化"一致。
- 接口契约 /api/admin/products/{id}/skus 子资源（POST/PUT/PATCH）、SkuView、权限码 product:sku:{create,update} 与 story-design / requirement-design §6 一致。
- Flyway V3 product_sku 表（specification_data VARCHAR、specification_hash CHAR(64)、uk_sku_code、uk_product_spec_hash），与设计一致。

### 1.3 跨仓一致性（Phase 2.4）

- 本 Story 仅 repo-1（DU-BE-305），前端 SKU 区块由 DU-FE-303（Story 1）实现。
- 契约闭环：后端 SkuView 字段（skuCode/salePrice/mainImageUrl/specifications/status）↔ 前端 SkuView 类型一致；SpecificationHash 仅后端计算，前端不感知。
- baseline/result：repo-1 7cba45e→23a1dfb（同 DU-BE-304 commit，SKU 与 SPU 同 commit 交付），与 DU metadata.yaml、implementation.md、evidence.yaml 一致。
- 跨 Story 依赖：DU-BE-305 依赖 DU-BE-304（Product 聚合根与仓储），在 requirement-design §6 声明，已在 implementation.md 注明。

### 1.4 代码质量

- mall-product 36 测试全绿（含 SKU 相关 TC-001~008），无回归。
- SpecificationHash 使用 HexFormat（Java 17+），SHA-256 按 name 字典序拼接保证顺序无关。
- SKU 持久化随 Product.update() 全量替换（delete+insert），事务内保证一致性。
- 未发现有明确 standards/ 规范依据的违规。

### 1.5 知识同步候选

- 候选 1：SpecificationHash 规格组合唯一哈希模式（按 name 字典序拼接 name=value 后 SHA-256），适用于 M2 后续多规格实体。
- 候选 2：Money 分价模式（long amountInCents，DB BIGINT，禁止浮点），贯穿商品/订单/支付。
- 候选 3：聚合内实体全量替换持久化模式（delete+insert），适用于 SKU 等弱实体。
- 统一在 Change converge 阶段评估沉淀，本 Story 不单独落盘。

## 2. 发现清单

| EV id | target | severity | finding | resolution 状态 |
| --- | --- | --- | --- | --- |
| —（dev 期 red-green） | ProductRepositoryImpl | major→已闭环 | MyBatis-Plus 对 `_json` 列名双重序列化致 specification_data 写入失败 | 已闭环：列名改 specification_data VARCHAR + 手动 Jackson 序列化 |
| —（dev 期 red-green） | Product 构造函数 | minor→已闭环 | List.of() 不可变集合致 addSku 抛 UnsupportedOperationException | 已闭环：new ArrayList<>(skus) 包装 |
| —（dev 期 red-green） | SkuPo | minor→已闭环 | createdAt NULL 插入失败（表无 DEFAULT） | 已闭环：skuToPo 中 field != null ? field : Instant.now() |
| —（评审观察，非缺陷） | — | minor | SKU 与 SPU 同 commit 交付（23a1dfb），跨 Story DU 共用 code-change 证据 | 已在 evidence.yaml EV-002/EV-004 分别登记，便于追溯 |

无 blocker；评审中识别的 major 级问题在 dev 红绿灯阶段已修复并有回归证据，按 findings-closure 要求在此登记闭环。

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 全部 blocker/major finding 已闭环（major 一项已修复复测）
- [x] minor finding 已记录
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（跨 Story 依赖已声明）
