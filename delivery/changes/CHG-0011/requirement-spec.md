# Requirement Spec（需求级产品规格）

> 层级：Requirement 级产物——针对本次需求/Change（多 Story 统一一份）
> 业界锚点：PRD（Problem → Goals/Metrics → Scope → Requirements → AC）
> 输入：CHG Context（exploration.md + requirement.md）
> 产出状态：specified
> 分层关系：本文是 Requirement 级；Story 边界与代码实现功能的持久记录见各 Story 目录 story-spec.md，两层不混写。

## 0. 元信息

- Change ID: CHG-0011
- Requirement: REQ-M2-002 商品与 SKU 管理
- 状态流转: exploring → specified
- 主要服务: mall-product（repo-1）；前端 mall-admin（repo-2）

## 1. 背景

CHG-0010 已在 mall-product 建立分类与品牌主数据，商品域具备了"挂到哪个分类/品牌"的可信前提，但平台尚无"卖什么"的商品权威模型。M2 商品与库存阶段的商品 SPU/SKU（REQ-M2-002）、发布与商城查询（REQ-M2-003）、库存（REQ-M2-004）都依赖一份稳定的商品聚合与 SKU 子实体数据契约：若 Product 不区分 SPU 与 SKU、SKU 编码不唯一、价格用浮点、图片存二进制、或 Product 直接持有库存字段，则商城浏览、购物车、订单快照与库存扣减都会失去可信基础。

本需求在 Product Context（mall-product）建立 Product 聚合根与 SKU 聚合内实体，覆盖商品基本信息、分类/品牌绑定、商品图片、商品属性、SKU 规格/编码/价格/状态，并在 mall-admin 提供后台整体维护页面。状态生命周期至少表达 DRAFT/ON_SALE/OFF_SALE/DISABLED，创建即 DRAFT、创建≠商城可见，正式发布/上下架动作由 REQ-M2-003 完成。exploration §4 冲突检测：与 product/specs 无冲突、与已归档 Change 无功能重叠，沿用 CHG-0010 分类/品牌产出与 CHG-0006 MinIO 基础设施（仅引用 Object Key/URL）。

## 2. 用户价值

- 目标用户: 后台商品管理员；下游消费方为 REQ-M2-003 发布与商城查询、M4 订单、M6 AI 导购。
- 痛点摘要: 平台没有商品权威模型，无法支撑"卖什么"；缺少 SPU/SKU 两级模型、SKU 编码唯一与规格组合唯一约束、价格浮点误差风险、图片落库风险、库存越界风险。
- 预期价值: 商品管理员可在一个页面完整维护一个 Product 及其全部 SKU；系统保证 SKU 编码与规格组合唯一、价格为精确金额、Product Context 不含真实库存，为下游提供可信商品契约。

JTBD：

- 角色：商品管理员；场景：When I 需要录入一个可售商品, I want to 在一个表单里填写 SPU 信息并配置多个 SKU（规格/价格/图片）；价值：So that 一次提交即形成完整可售商品数据。
- 角色：系统（订单/库存）；场景：When 引用商品价格与规格, I want to 通过 SKU 精确获取金额与规格；价值：So that 订单快照与库存锁定精确无误。

## 3. 功能范围

### 3.1 包含

- [S1] 创建 Product：名称、副标题、描述、分类、品牌、主图、图集、商品属性，创建后状态 DRAFT。
- [S2] 编辑 Product：基本信息、图片、属性修改；分类/品牌变更需引用合法。
- [S3] 查询 Product：分页列表（keyword/categoryId/brandId/status）与详情（含 SKU、图片、属性）。
- [S4] 商品状态：DRAFT/ON_SALE/OFF_SALE/DISABLED 字段；本阶段仅支持创建 DRAFT 与禁用/启用 Product（发布归 REQ-M2-003）。
- [S5] SKU 管理：在 Product 下新增/编辑 SKU，含 SKU Code、规格组合、销售价（分）、主图、启停。
- [S6] 图片：Product 主图唯一、图集多图；图片存 object_key+image_url，不落二进制。
- [S7] 商品属性：非规格键值对可维护。
- [S8] 后台页面：mall-admin 商品列表/创建/编辑/查看整体表单，含分类/品牌选择、图片、SKU 规格/价格编辑。
- [S9] RBAC：product:product:_ 与 product:sku:_ 权限码，写接口服务端真实校验。

### 3.2 不包含

- 商品正式发布/上下架（DRAFT→ON_SALE）动作（REQ-M2-003）。
- 商城商品列表/详情、购物车、订单、ES 索引。
- 库存数量、锁定、扣减（REQ-M2-004，mall-inventory）；Product Context 禁止 stock 权威字段。
- MinIO 上传服务（图片仅引用 Object Key/URL）。
- 商品物理删除（仅禁用）。

### 3.3 Story 拆分总表

| Story ID           | 标题           | Scope 摘要                                                                                                              | 依赖               | 优先级 |
| ------------------ | -------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------ | ------ |
| STORY-002-02-01-01 | 商品 SPU 管理  | S1、S2、S3、S4、S6、S7、S8(SPU 区块)、S9(product:\*)：Product 聚合、图片、属性、状态生命周期、SPU 管理端 API 与页面骨架 | CHG-0010           | P0     |
| STORY-002-02-02-01 | SKU 与规格管理 | S5、S8(SKU 区块)、S9(sku:\*)：SKU 实体、规格组合唯一、Money 价格、SKU API 与前端表单                                    | STORY-002-02-01-01 | P0     |

两 Story 同属 FEAT-002-02；SPU 先于 SKU（SKU 挂在 Product 聚合内），后端可串行开发、前端整体表单同时落地。

## 4. 业务规则总纲

- 状态生命周期（解决 exploration §5 待澄清 1）：ProductStatus = DRAFT / ON_SALE / OFF_SALE / DISABLED。创建商品默认 DRAFT；本 Change 仅开放"禁用/启用 Product"（DRAFT↔DISABLED 或 OFF_SALE↔DISABLED），发布（DRAFT→ON_SALE）与上下架（ON_SALE↔OFF_SALE）归 REQ-M2-003。已 DISABLED 商品不可被发布。
- 商品属性建模（解决 exploration §5 待澄清 2）：规格（决定 SKU 差异）存 product_sku.specification_json + specification_hash；商品非规格属性存 product_attribute 独立表。
- 图片上限（解决 exploration §5 待澄清 3）：一个 Product 仅一张主图（main_flag=1 唯一）；图集数量不设硬上限，前端建议 ≤ 10；按 sort_order 排序。
- 改价约束（解决 exploration §5 待澄清 4）：SKU 销售价可直接修改；历史订单价格由订单快照保证，Product Context 不阻断改价，也不级联改历史订单。
- SKU 停用约束（解决 exploration §5 待澄清 5）：本阶段 SKU 可独立启停（ENABLED/DISABLED）；不做物理删除；存在库存锁定的 SKU 能否删除由 CHG-0013 联动，本阶段不提供删除入口。
- 价格精确性：Money.amountInCents（long），DB BIGINT；禁止 double/BigDecimal 浮点计算；SKU 售价 >= 0。
- 唯一性：product_code 全局唯一；sku_code 全局唯一；同 Product 内 specification_hash 唯一（DB uk 兜底）。
- 引用合法：Product 绑定的 category_id/brand_id 必须存在且启用态，否则拒绝。
- 库存边界：product_spu/product_sku 均无 stock 字段；库存权威在 Inventory Context。
- 领域事件：Product 创建/更新、SKU 增/改/价格变更/启停均在聚合内注册领域事件（本阶段不发布 MQ/Outbox）。

## 5. 全局验收标准

| ID     | 验收标准（可测试）                                                                      | 备注         |
| ------ | --------------------------------------------------------------------------------------- | ------------ |
| AC-001 | 提交合法 Product（名称+分类+品牌+至少一 SKU）→ 创建成功，状态 DRAFT                     | S1 创建≠可见 |
| AC-002 | Product 绑定的分类/品牌不存在或非启用 → 拒绝，错误 INVALID_ARGUMENT                     | S2 引用合法  |
| AC-003 | 一个 Product 可创建一个或多个 SKU，SKU 含编码/规格/价格                                 | S5           |
| AC-004 | SKU Code 全局唯一；重复编码拒绝且无落库                                                 | S5 编码唯一  |
| AC-005 | SKU 销售价为分（long）且 >= 0；代码与 DB 无浮点金额字段                                 | S5 价格边界  |
| AC-006 | 同一 Product 内 SKU 规格组合唯一（specification_hash），重复拒绝                        | S5 组合唯一  |
| AC-007 | 商品图片以 object_key+image_url 关联；一个 Product 仅一张主图；图集可多张               | S6           |
| AC-008 | 修改 Product 基本信息/SKU/价格/图片/属性后，查询返回最新值且事务一致                    | S2/S5 一致   |
| AC-009 | product_spu/product_sku 均无 stock 等真实库存权威字段                                   | 领域边界     |
| AC-010 | 创建商品状态为 DRAFT，状态字段支持 DRAFT/ON_SALE/OFF_SALE/DISABLED；创建不对商城可见    | S4           |
| AC-011 | mall-admin 商品页可完成列表、创建、编辑、查看，含分类/品牌选择、图片、SKU 规格/价格编辑 | S8 端到端    |
| AC-012 | 商品属性（非规格键值对）可增删改并随商品保存                                            | S7           |
| AC-013 | 无 product:product/sku 写权限直调对应接口 → 403 且数据不变；有权限 → 成功               | S9 RBAC      |
| AC-014 | Product/SKU 变更注册对应领域事件语义（聚合内事件，不要求 MQ 发布）                      | 领域事件     |
| AC-015 | DISABLED 商品不可被发布；SKU 可独立 ENABLED/DISABLED                                    | S4 状态      |

## 6. 非功能需求

- 安全：全部接口经网关认证与服务端权限码校验，默认拒绝；写操作记录操作者。
- 性能：商品分页列表 P95 < 300ms；商品详情 P95 < 200ms（M2 数据规模）。
- 一致性：product_code/sku_code/specification_hash 唯一由 DB 约束与服务端校验双重保证；SKU 集合随 Product 同事务持久化。
- 兼容性：接口遵循 M1 统一返回结构 UnifyResult 与异常码规范；前端复用 mall-admin 布局、HTTP 客户端与权限指令。
- 可扩展性：Product/SKU 模型预留 status、version、published_at 字段，为 REQ-M2-003 发布与库存联动打基础。

## 7. 成功指标

- SKU 编码唯一、规格组合唯一、价格精确（分）等核心规则自动化测试通过率 100%，上线后零重码、零重复规格组合、零浮点价格事故。
- Product Context 不含真实库存字段（静态检查 + 测试双重验证），为库存域独立演进扫清边界。
- 商品管理员可在 mall-admin 无协助完成一个含多 SKU 商品的完整录入，单次录入平均 ≤ 2 分钟。
