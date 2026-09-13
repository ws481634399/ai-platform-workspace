# Review Report — 商城商品列表与详情查询 STORY-002-03-02-01

> 阶段：sdd-review 产物（Story 级检查点，状态保持 testing）

## 0. 元信息

- Change ID: CHG-0012
- Story ID: STORY-002-03-02-01（商城商品列表与详情查询）
- Test Report 来源: 本目录 evidence/test-report.md
- Evidence 索引: CHG-0012/evidence/evidence.yaml（EV-003 code-change、EV-011 test-run、EV-008 evidence-ref）
- 状态流转: testing（检查点，状态不变）
- 检查时间: 2026-09-13

## 1. 检查结论

五项检查全部执行；无 blocker/major 开放项。

### 1.1 需求一致性

| AC | 需求要点 | 证据 | 结论 |
| --- | --- | --- | --- |
| AC-001 | 商城列表只返回 ON_SALE 商品 | EV-011 / TC-001 | 一致 |
| AC-002 | 支持分类筛选与分页 | EV-011 / TC-002 | 一致 |
| AC-003 | 列表按创建时间倒序 | EV-011 / TC-003 | 一致 |
| AC-004 | ON_SALE 商品详情返回完整信息 | EV-011 / TC-004 | 一致 |
| AC-005 | 非 ON_SALE 商品详情 404 | EV-011 / TC-005 | 一致 |
| AC-006 | 商城响应不含库存字段 | EV-011 / TC-006 | 一致 |

### 1.2 设计一致性

- MallProductController 端点 GET /api/mall/products、GET /api/mall/products/{id} 与 story-design §6 一致。
- mallPage 硬过滤 status=ON_SALE，orderByDesc(createdAt)，与设计一致。
- MallProductListItemView/MallProductDetailView 字段不含 stock，与设计一致。
- /api/mall/** permitAll 与设计"商城公开访问"一致。

### 1.3 跨仓一致性

- 本 Story 仅后端 DU，无前端依赖；商城端 API 契约待 mall-web（CHG-0013 后续）消费。
- baseline/result：repo-1 25fcddc→5df94fc，与 metadata.yaml、implementation.md、evidence.yaml 一致。

### 1.4 代码质量

- mall-product 61 测试全绿（含 MallProductApiTest 6），无回归。
- mallPage 使用 MyBatis-Plus LambdaQueryWrapper 硬过滤，无 N+1 问题。
- 未发现 standards/ 违规。

### 1.5 知识同步候选

- 候选：商城查询硬过滤 ON_SALE 是业务规则，应在仓储层而非应用层实现（已遵循）。
- 统一在 Change converge 阶段评估沉淀。

## 2. 发现清单

无 blocker/major；无开放项。

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 全部 blocker/major finding 已闭环
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对
