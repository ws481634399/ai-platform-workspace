# Convergence — CHG-0012 商品发布与商城查询

> 阶段：sdd-converge 产物
> 业界锚点：Postmortem + Lessons Learned（What → Why → Action → Knowledge）
> 输入：CHG-0012 全部 Artifact（3 Story 全流程 completed）
> 产出状态：completed

## 0. 元信息

- Change ID: CHG-0012
- 完成时间: 2026-09-13
- 交付 DU：4（repo-1 DU-BE-306/307/308、repo-2 DU-FE-304），全部 completed

## 1. 知识变化总结

- 知识增量摘要:
  1. Product 聚合上下架发布能力：publish() 校验链（主图 → ENABLED SKU → 价格合法 → 非 DISABLED），状态流转 DRAFT/OFF_SALE → ON_SALE → OFF_SALE，注册 ProductPublishedDomainEvent / ProductUnpublishedDomainEvent。
  2. 商城公开查询：mallPage 硬过滤 status=ON_SALE，按创建时间倒序；详情非 ON_SALE 返回 404；响应不含库存字段；/api/mall/** permitAll。
  3. 内部服务间商品快照契约：GET /api/internal/products/{productId}/skus/{skuId} 返回 ProductSnapshot（productId/skuId/productName/skuName/skuAttributes/price/image/currentStatus），price 单位为分。
  4. 权限码扩展：mall-identity V5 新增 product:product:publish。

## 2. 更新判断

### Standards

- 是否需更新: no（本 Change 未引入新的工程约束，CHG-0011 沉淀的集合/JSON/Flyway 约定继续遵循）
- 更新内容: 无新增 standards 条目。

### Product

- 是否需更新: no（M2 商品域产品知识正文留待 M2 四个 Change 全部 converge 后统一回写）

### feature-tree.yaml

- 是否需更新: yes
- 更新内容: STORY-002-03-01-01（商品上下架与发布）、STORY-002-03-02-01（商城商品列表与详情查询）、STORY-002-03-03-01（内部查询契约与商品快照）status: planned → delivered。
- 理由: 三 Story 已 completed 且测试/评审证据齐备。

### Glossary

- 是否需更新: no（ProductSnapshot 属实现细节，不进术语表）

## 3. 知识沉淀过程

- 已写回：feature-tree 三 Story 状态置 delivered。
- 留待后续：产品知识正文 M2 末统一更新；商城端 /api/mall/** 与内部 /api/internal/** 的服务间认证策略（mTLS / service token）在网关/服务治理 Change 中统一设计。
- 未沉淀为标准的内容：publish 校验顺序、ProductSnapshot 字段结构——属实现细节，保留在代码与 DU 文档中。

## 4. 全局验收标准对照

> 摘自 requirement-spec.md。跨 Story 项引用对应 Story 证据。

| # | 验收点 | 覆盖 Story | 证据引用 | 结论 |
| --- | --- | --- | --- | --- |
| 1 | AC-001 DRAFT/OFF_SALE 商品满足条件可上架 → ON_SALE | S1 | Story 1 test-report TC-001, TC-006；EV-011 | 通过 |
| 2 | AC-002 缺少主图 → 拒绝上架 | S1 | Story 1 test-report TC-002 | 通过 |
| 3 | AC-003 无 ENABLED SKU → 拒绝上架 | S1 | Story 1 test-report TC-003 | 通过 |
| 4 | AC-004 ENABLED SKU 价格 < 0 → 拒绝上架 | S1 | Story 1 test-report TC-004 + publish 价格校验 | 通过 |
| 5 | AC-005 DISABLED 商品不可上架 | S1 | Story 1 test-report TC-004 | 通过 |
| 6 | AC-006 ON_SALE 商品可下架 → OFF_SALE | S1 | Story 1 test-report TC-005 | 通过 |
| 7 | AC-007 上架/下架注册领域事件 | S1 | ProductPublishedDomainEvent / ProductUnpublishedDomainEvent | 通过 |
| 8 | AC-008 管理端商品列表增加上架/下架按钮 | S1 | Story 1 test-report TC-008；EV-012 | 通过 |
| 9 | AC-009 无 product:product:publish 权限 → 403 | S1 | Story 1 test-report TC-007 | 通过 |
| 10 | AC-010 商城列表只返回 ON_SALE 商品 | S2 | Story 2 test-report TC-001 | 通过 |
| 11 | AC-011 商城支持分类筛选与分页 | S2 | Story 2 test-report TC-002 | 通过 |
| 12 | AC-012 商城列表按创建时间倒序 | S2 | Story 2 test-report TC-003 | 通过 |
| 13 | AC-013 ON_SALE 商品详情返回完整信息 | S2 | Story 2 test-report TC-004 | 通过 |
| 14 | AC-014 非 ON_SALE 商品详情 404 | S2 | Story 2 test-report TC-005 | 通过 |
| 15 | AC-015 商城响应不含库存字段 | S2 | Story 2 test-report TC-006 | 通过 |
| 16 | AC-016 内部查询返回 ProductSnapshot 完整字段 | S3 | Story 3 test-report TC-001 | 通过 |
| 17 | AC-017 商品不存在返回 404 | S3 | Story 3 test-report TC-002 | 通过 |
| 18 | AC-018 SKU 不属于商品返回 404 | S3 | Story 3 test-report TC-003 | 通过 |

## 5. 完成确认

- [x] 代码变更已完成（4 DU，跨 repo-1/repo-2）
- [x] 测试已完成（后端 61、前端 28，全绿；type-check/build 全过）
- [x] 证据已收集（Change evidence.yaml 14 条 EV + 各仓 DU evidence）
- [x] 全局验收标准已逐条对照（§4）
- [x] 知识更新已评估（feature-tree 已更新；standards/product/glossary 无新增）
