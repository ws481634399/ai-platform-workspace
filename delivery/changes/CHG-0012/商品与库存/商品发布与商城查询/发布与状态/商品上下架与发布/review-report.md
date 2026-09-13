# Review Report — 商品上下架与发布 STORY-002-03-01-01

> 阶段：sdd-review 产物（Story 级检查点，状态保持 testing）
> 输入：story-spec.md / story-design.md / test-design.md + 仓内 DU-BE-306 / DU-FE-304 产物 + evidence/test-report.md + Change evidence/evidence.yaml + standards/

## 0. 元信息

- Change ID: CHG-0012
- Story ID: STORY-002-03-01-01（商品上下架与发布）
- Test Report 来源: 本目录 evidence/test-report.md
- Evidence 索引: CHG-0012/evidence/evidence.yaml（EV-001/002/005/006 code-change，EV-011/012 test-run，EV-007/010 evidence-ref）
- 状态流转: testing（检查点，状态不变）
- 检查时间: 2026-09-13

## 1. 检查结论

五项检查全部执行；无 blocker/major 开放项。

### 1.1 需求一致性

| AC | 需求要点 | 证据 | 结论 |
| --- | --- | --- | --- |
| AC-001 | DRAFT/OFF_SALE 商品满足条件可上架 → ON_SALE | EV-011 / TC-001, TC-006 | 一致 |
| AC-002 | 缺少主图 → 拒绝上架 | EV-011 / TC-002 | 一致 |
| AC-003 | 无 ENABLED SKU → 拒绝上架 | EV-011 / TC-003 | 一致 |
| AC-004 | ENABLED SKU 价格 < 0 → 拒绝上架 | EV-011（publish 校验 salePriceInCents >= 0） | 一致 |
| AC-005 | DISABLED 商品不可上架 | EV-011 / TC-004 | 一致 |
| AC-006 | ON_SALE 商品可下架 → OFF_SALE | EV-011 / TC-005 | 一致 |
| AC-007 | 上架/下架注册领域事件 | EV-011（ProductPublishedDomainEvent / ProductUnpublishedDomainEvent） | 一致 |
| AC-008 | 管理端商品列表增加上架/下架按钮 | EV-012 / ProductListView | 一致 |
| AC-009 | 无 product:product:publish 权限 → 403 | EV-011 / TC-007 | 一致 |

### 1.2 设计一致性

- Product 聚合 publish() 校验链（主图 → ENABLED SKU → 价格合法 → 非 DISABLED）与 story-design §2 状态机一致；成功后注册 ProductPublishedDomainEvent。
- Product 聚合 unpublish() 仅允许 ON_SALE → OFF_SALE，注册 ProductUnpublishedDomainEvent，与设计一致。
- 接口契约 POST /api/admin/products/{id}/publish、POST /{id}/unpublish，权限码 product:product:publish，与 story-design §6 一致。
- 错误码 B2150（PUBLISH_VALIDATION_FAILED）、B2151（PRODUCT_ALREADY_ON_SALE）、B2152（PRODUCT_NOT_ON_SALE）与设计一致。
- mall-identity V5 迁移插入 product:product:publish 权限编码，与设计一致。

### 1.3 跨仓一致性（Phase 2.4）

- 契约闭环：后端 publish/unpublish 端点 ↔ 前端 productApi.publish/unpublish 一一对应；状态枚举 DRAFT/ON_SALE/OFF_SALE/DISABLED 两端一致。
- 权限码闭环：V5 种子 product:product:publish ↔ Controller @PreAuthorize ↔ 前端 v-permission 三处字符串一致。
- baseline/result：repo-1 25fcddc→9ceb826、repo-2 036a77c→ef5f4df，与各仓 DU metadata.yaml、implementation.md、evidence.yaml 一致。

### 1.4 代码质量

- mall-product 全模块 61 测试全绿（含 CHG-0012 新增 17 个用例），无回归。
- Product 聚合领域事件用 `new ArrayList<>()` 包装，遵循 CHG-0011 沉淀的集合约束。
- 前端 vue-tsc 0 error、build 成功；vitest 28 passed。
- 未发现有明确 standards/ 规范依据的违规。

### 1.5 知识同步候选

- 候选 1：Product 聚合领域事件集合 domainEvents 用 `new ArrayList<>()` 包装，与 CHG-0011 集合约束一致。
- 候选 2：publish 校验顺序（主图 → SKU → 价格 → 状态）需保持稳定，避免校验信息泄露。
- 统一在 Change converge 阶段评估沉淀，本 Story 不单独落盘。

## 2. 发现清单

| EV id | target | severity | finding | resolution 状态 |
| --- | --- | --- | --- | --- |
| —（评审观察，非缺陷） | 内部接口 /api/internal/** | minor | 内部接口走统一认证（authenticated），未单独区分服务间调用凭证 | 记录为后续服务网格/mTLS 待办；当前 JWT 认证已满足最小安全要求，不阻塞 converge |

无 blocker；无 major 开放项。

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 全部 blocker/major finding 已闭环
- [x] minor finding 已记录
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（多仓需求）
