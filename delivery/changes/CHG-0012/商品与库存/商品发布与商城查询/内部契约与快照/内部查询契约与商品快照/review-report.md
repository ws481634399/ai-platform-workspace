# Review Report — 内部查询契约与商品快照 STORY-002-03-03-01

> 阶段：sdd-review 产物（Story 级检查点，状态保持 testing）

## 0. 元信息

- Change ID: CHG-0012
- Story ID: STORY-002-03-03-01（内部查询契约与商品快照）
- Test Report 来源: 本目录 evidence/test-report.md
- Evidence 索引: CHG-0012/evidence/evidence.yaml（EV-004 code-change、EV-011 test-run、EV-009 evidence-ref）
- 状态流转: testing（检查点，状态不变）
- 检查时间: 2026-09-13

## 1. 检查结论

五项检查全部执行；无 blocker/major 开放项。

### 1.1 需求一致性

| AC | 需求要点 | 证据 | 结论 |
| --- | --- | --- | --- |
| AC-001 | GET /api/internal/products/{productId}/skus/{skuId} 返回 ProductSnapshot | EV-011 / TC-001 | 一致 |
| AC-002 | 快照含 productId/skuId/productName/skuName/skuAttributes/price/image/currentStatus | EV-011 / TC-001 | 一致 |
| AC-003 | price 单位为分（long） | EV-011 / TC-001（price=9900） | 一致 |
| AC-004 | 商品不存在返回 404 | EV-011 / TC-002 | 一致 |
| AC-005 | SKU 不属于商品返回 404 | EV-011 / TC-003 | 一致 |

### 1.2 设计一致性

- InternalProductController 端点 GET /api/internal/products/{productId}/skus/{skuId} 与 story-design §6 一致。
- ProductSnapshotView 字段与设计一致，price 为分（long），skuAttributes 为 Map<String,String>。
- skuName 由规格拼接，image 取 SKU 主图或商品主图，与设计一致。

### 1.3 跨仓一致性

- 本 Story 仅后端 DU，内部契约待订单/购物车服务（后续 Change）消费。
- baseline/result：repo-1 25fcddc→f1e75f6，与 metadata.yaml、implementation.md、evidence.yaml 一致。

### 1.4 代码质量

- mall-product 61 测试全绿（含 InternalProductApiTest 3），无回归。
- ProductSnapshotView 用 Java record，不可变，适合内部契约传输。
- 未发现 standards/ 违规。

### 1.5 知识同步候选

- 候选：内部服务间调用走统一 JWT 认证，后续可考虑服务间专用凭证（mTLS 或 service token）。
- 统一在 Change converge 阶段评估沉淀。

## 2. 发现清单

无 blocker/major；无开放项。

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 全部 blocker/major finding 已闭环
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对
