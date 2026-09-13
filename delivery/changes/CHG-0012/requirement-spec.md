# Requirement Spec（需求级产品规格）

> 层级：Requirement 级产物——针对本次需求/Change（多 Story 统一一份）
> 业界锚点：PRD（Problem → Goals/Metrics → Scope → Requirements → AC）
> 输入：CHG Context（exploration.md + requirement.md）
> 产出状态：specified
> 分层关系：本文是 Requirement 级；Story 边界与代码实现功能的持久记录见各 Story 目录 story-spec.md，两层不混写。

## 0. 元信息

- Change ID: CHG-0012
- Requirement: REQ-M2-003 商品发布与商城查询
- 状态流转: exploring → specified
- 主要服务: mall-product（repo-1）；前端 mall-admin（repo-2）

## 1. 背景

CHG-0011 已在 mall-product 建立 Product（SPU）聚合根与 SKU 聚合内实体，商品基本信息、分类/品牌绑定、图片、属性、SKU 规格/价格/状态均已可维护，商品创建即 DRAFT 状态。但 DRAFT 商品对商城不可见，平台尚无"激活可售商品"与"商城/内部查询契约"能力：后台维护的商品无法被 mall-web 浏览、无法被 mall-cart/mall-order/ai-service 通过稳定契约查询、历史订单无法锁定商品快照。

本需求在 Product Context 增加发布/上下架能力（DRAFT→ON_SALE 上架、ON_SALE→OFF_SALE 下架），建立商城商品列表/详情查询（只返回 ON_SALE 商品），并向 Cart/Order/Inventory/AI 提供稳定的内部商品查询契约与商品快照 DTO（不共享领域实体）。上架前执行完整业务校验（基本信息/分类/品牌/至少一有效 SKU/价格合法/主图存在）。上架/下架注册领域事件语义（ProductPublished/ProductUnpublished/ProductChanged），本阶段不要求 MQ 发布。exploration §4 冲突检测：与 product/specs 无冲突、与 CHG-0011 产出衔接（在 Product 聚合上增加发布行为），上架校验中"库存初始化"通过内部 API 查询状态而非直写库存库，符合 REQ-M2-003 边界。

## 2. 用户价值

- 目标用户: 后台商品管理员（发布/下架）；商城消费者（mall-web 浏览可售商品）；下游系统 mall-cart/mall-order/ai-service（消费内部查询契约构建订单快照）。
- 痛点摘要: DRAFT 商品无法上架、商城无真实可售商品列表、订单无法锁定商品快照致历史价格漂移、下游缺少稳定商品查询契约。
- 预期价值: 后台一次上架动作即激活可售商品；商城仅展示 ON_SALE 商品且详情完整；下游通过内部契约获取 SKU 快照，历史订单价格与商品名不随主数据变更而漂移。

JTBD：

- 角色：商品管理员；场景：When I 需要把草稿商品变为可售, I want to 执行上架动作并看到校验结果；价值：So that 商品立即可在商城浏览。
- 角色：商城消费者；场景：When 浏览商城, I want to 看到可售商品列表与详情；价值：So that 做出购买决策。
- 角色：系统（订单）；场景：When 创建订单, I want to 获取当时商品快照；价值：So that 历史订单价格与商品名不漂移。

## 3. 功能范围

### 3.1 包含

- [S1] 商品上架：DRAFT/OFF_SALE→ON_SALE，上架前完整业务校验（基本信息完整、分类有效、品牌有效、至少一个 ENABLED SKU、SKU 价格合法、主图存在），不满足拒绝。
- [S2] 商品下架：ON_SALE→OFF_SALE；下架后商城列表不展示、新交易不可售、历史快照不受影响。
- [S3] 商城商品列表查询：面向 mall-web，支持 keyword/categoryId/brandId 筛选、分页、排序（按创建时间倒序），只返回 status=ON_SALE 商品。
- [S4] 商城商品详情查询：返回 Product 基本信息、分类、品牌、图片、SKU 列表（含规格/价格/状态）、商品状态；不伪造库存。
- [S5] 内部商品查询契约：/api/internal/products/{id}/skus/{skuId} 返回 ProductSnapshot（productId/skuId/productName/skuName/skuAttributes/price/image/currentStatus），不暴露领域实体。
- [S6] 商品快照契约：ProductSnapshot DTO 作为订单快照标准契约，字段稳定可序列化。
- [S7] 领域事件基础：上架注册 ProductPublished、下架注册 ProductUnpublished（聚合内事件，不发布 MQ）。
- [S8] 后台上下架入口：mall-admin 商品列表/详情页提供上架/下架按钮，权限 product:product:publish。
- [S9] RBAC：product:product:publish 权限码；商城查询接口免登录或公开（mall-web 侧）。

### 3.2 不包含

- ES 搜索与索引同步（M5）。
- 购物车、下单、支付（M3/M4）。
- AI 导购（M6）。
- RocketMQ 可靠事件发布（M7）。
- 库存初始化/扣减（CHG-0013）；上架校验仅查询库存初始化状态（本阶段可放宽，不强制依赖库存）。

### 3.3 Story 拆分总表

| Story ID | 标题 | Scope 摘要 | 依赖 | 优先级 |
| --- | --- | --- | --- | --- |
| STORY-002-03-01-01 | 商品上下架与发布 | S1、S2、S7、S8、S9：Product 聚合 publish/unpublish 行为、上架校验、管理端上下架 API 与页面、领域事件 | CHG-0011 | P0 |
| STORY-002-03-02-01 | 商城商品列表与详情查询 | S3、S4：商城列表（ON_SALE 过滤）、商城详情 API | STORY-002-03-01-01 | P0 |
| STORY-002-03-03-01 | 内部查询契约与商品快照 | S5、S6：内部 SKU 查询端点、ProductSnapshot DTO | STORY-002-03-01-01 | P0 |

三 Story 同属 FEAT-002-03；发布（S1/S2）是查询（S3/S4/S5）的前置（只有 ON_SALE 商品可被商城查询），后端串行开发、前端上下架按钮与商城查询独立落地。

## 4. 业务规则总纲

- 上架校验（解决 exploration §5 待澄清 1）：上架前必须满足——商品名称/编码非空、分类存在且启用、品牌存在且启用、至少一个 ENABLED SKU、所有 ENABLED SKU 价格 >= 0、主图存在（mainImageUrl 非空）。不满足任一项拒绝上架并返回具体原因。DISABLED 商品不可上架。
- 状态流转：DRAFT→ON_SALE（上架）、ON_SALE→OFF_SALE（下架）、OFF_SALE→ON_SALE（重新上架）。DISABLED 不可上架。已下架商品可重新上架（需重新校验）。
- 商城可见性（解决 exploration §5 待澄清 2）：商城列表/详情仅返回 status=ON_SALE 商品；查询层硬过滤 status='ON_SALE'。
- 内部契约隔离（解决 exploration §5 待澄清 3）：内部查询返回 ProductSnapshot DTO，不含 Product 领域实体引用；字段固定（productId/skuId/productName/skuName/skuAttributes/price/image/currentStatus）。
- 快照语义（解决 exploration §5 待澄清 4）：ProductSnapshot 为不可变 DTO，订单侧持久化该快照；商品主数据变更不影响已保存快照。
- 领域事件：publish() 注册 ProductPublishedDomainEvent，unpublish() 注册 ProductUnpublishedDomainEvent；本阶段仅聚合内事件，不发布 MQ/Outbox。
- 价格精确性：沿用 Money.amountInCents（long），内部契约 price 字段为分。
- 下架不删历史：下架仅改 status=OFF_SALE，不删除商品/SKU 记录。

## 5. 全局验收标准

| ID | 验收标准（可测试） | 备注 |
| --- | --- | --- |
| AC-001 | DRAFT 商品满足全部上架条件 → 上架成功，状态 ON_SALE | S1 |
| AC-002 | 缺少主图/无 ENABLED SKU/DISABLED 商品 → 上架拒绝 | S1 校验 |
| AC-003 | ON_SALE 商品执行下架 → 状态 OFF_SALE | S2 |
| AC-004 | OFF_SALE 商品不出现在商城列表；重新上架需再次校验 | S2/S1 |
| AC-005 | 商城列表只返回 ON_SALE 商品，支持分类/品牌筛选与分页 | S3 |
| AC-006 | 商城详情返回 Product 信息、图片、SKU（规格/价格/状态），不含库存 | S4 |
| AC-007 | 内部 API /api/internal/products/{id}/skus/{skuId} 返回 ProductSnapshot 字段 | S5 |
| AC-008 | ProductSnapshot 不含 Product 领域实体引用，可序列化 | S6 |
| AC-009 | 上架注册 ProductPublished 领域事件；下架注册 ProductUnpublished | S7 |
| AC-010 | mall-admin 商品页可执行上架/下架动作，无权限 403 | S8/S9 |
| AC-011 | 下架商品的历史快照不受下架影响（快照字段不变） | S2/S6 |

## 6. 非功能需求

- 安全：管理端上下架接口经网关认证与权限码 product:product:publish 校验；商城查询接口公开（不需认证）；内部查询接口走网关内部认证（服务间调用）。
- 性能：商城列表 P95 < 300ms；商品详情 P95 < 200ms（M2 数据规模，DB 查询）。
- 一致性：上架校验在聚合内执行，事务保证状态变更原子；下架不级联删除。
- 兼容性：接口遵循 M1 统一返回结构 UnifyResult；状态枚举复用 CHG-0011 ProductStatus。
- 可扩展性：领域事件为 M7 MQ 发布预留；ProductSnapshot 为 M4 订单快照预留。

## 7. 成功指标

- 上架校验自动化测试通过率 100%，上线后零"不合格商品上架"事故。
- 商城列表零 OFF_SALE/DRAFT 商品泄漏（测试 + 线上巡检）。
- 内部契约 ProductSnapshot 字段稳定，M4 订单接入时零字段调整。
