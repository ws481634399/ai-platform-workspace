# Exploration（需求探索报告）

> 阶段：sdd-explore 产物
> 业界锚点：Discovery 文档（Problem → Evidence → Conflict → Recommendation）
> 输入：requirement.md（原文沉淀；本文件不复述原文，只做分析）
> 产出状态：exploring（推进 Change 状态）

本文档回答探索阶段的五个问题：需求要点是什么、归属哪个 Story（是否已存在）、证据是否充分、有无冲突点、还有什么待澄清。

## 1. 需求要点

- 做什么：在 mall-product 建立 Product/SPU 与 SKU 两级核心模型，支持后台创建/编辑一个真实可售商品及其多个 SKU（规格、编码、图片、价格），为商城浏览、购物车、订单和 AI 推荐提供商品权威数据。
- 给谁：后台商品管理员；下游消费方为 REQ-M2-003 发布与商城查询、M4 订单、M6 AI 导购。
- 解决什么问题：平台没有商品权威模型，无法支撑"卖什么"这一基础问题；M2 需建立商品聚合与 SKU 子实体的权威数据契约。
- 隐含需求：
  - SKU Code 全局唯一、同一商品内 SKU 规格组合唯一；
  - 价格精确金额（Decimal/Money 值对象），禁止 double；SKU 售价 >= 0；
  - 一个商品仅一张主图；图片仅存 Object Key/URL，不落二进制；
  - 商品状态必须通过领域行为流转（DRAFT 起步，可创建但不能商城可见）；上架动作留给 REQ-M2-003；
  - Product 聚合内维护 SKU 集合，不维护真实库存字段（领域边界）；
  - 后台商品维护页面为"一个 Product 及其全部 SKU"的整体表单式编辑；
  - RBAC 权限保护（product:* 相关权限码 design 确定）。
  - 商品与 SKU 变更需具备领域事件语义（ProductCreated/Updated、SkuAdded/Updated 等），为后续缓存失效/ES/AI 同步打基础（本阶段不要求 MQ 发布）。

知识检索结果（引用来源）：

- `product/06-聚合与领域模型设计.md` §7.1 Product 聚合：SKU 作为聚合内实体、价格 Money 值对象（amountInCents，禁 double）、上架不变量（至少一个启用 SKU、价格合法、规格组合唯一）、图片 Object Key；§7.1.12 领域事件（ProductCreated/SkuAdded/SkuPriceChanged 等）；§7.1.13 ProductRepository。
- `product/04-子域与限界上下文.md` BC-03 Product Context：商品权威数据由 mall-product 持有。
- `product/09-数据库设计.md`：mall-product 数据归属 mall_product_db，价格/图片/属性表设计基础。
- `product/08-系统与微服务架构.md`：mall-product 使用 MySQL+Redis+MinIO，路由 /api/admin/products/** 等。
- `product/05-上下文映射图.md`：商品为上游 Supplier，购物车/订单通过 OHS+ACL 获取商品契约。

## 2. Story 归属判定

- Feature ID: FEAT-002-02（商品与库存 → 商品与 SKU 管理）
- Story 节点: STORY-002-02-01 商品 SPU 管理、STORY-002-02-02 SKU 与规格管理（树中不存在，本次新建）
- 是否新建 candidate: 否（归属明确，新建正式 Story 节点）
- Feature 路径: 商品与库存 → 商品与 SKU 管理 → 商品 SPU 管理 / SKU 与规格管理

## 3. 证据评估

- 证据类型与来源：
  - 业务依据：`docs/需求/M2/M2.md` REQ-M2-002 验收标准（12 条）与领域边界（§8）；`product/01-产品需求文档.md` 商品域；`product/06` Product/SKU 聚合不变量；`product/09` 数据表设计；
  - 工程基础：M1 RBAC/动态菜单基线与 mall-product 工程骨架（CHG-0003）可直接复用；MinIO 本地基础设施（CHG-0006）已就绪。
- 结论: 充分（验收标准、边界与前置基础明确；可进入产品规格阶段）

## 4. 冲突点检测

- 与 product/specs/ 规则冲突: 无（specs/ 无更高优先级已确认规则）
- 与既有 Change 重叠或沿用: 无功能重叠；沿用 CHG-0010 的分类/品牌产出与 M1 RBAC 权限基线、CHG-0006 MinIO 基础设施（图片地址引用，不实现上传服务）
- 与已规划 Story 重复: 无（SPU/SKU Story 均为本次新增）
- 处理决策: 无冲突；SPU 与 SKU 拆两个 Story 交付（一个对齐 Product 聚合与后台商品信息维护，一个对齐 SKU/规格/价格/图片），后台页面作为贯穿式实现随两个 Story 落地

## 5. 待澄清问题

- Product 状态枚举最终命名与完整生命周期（DRAFT/ON_SALE/OFF_SALE 之外是否含 DISABLED、上架后能否回草稿）需 prd/design 明确。
- 商品"属性"的建模粒度（规格键值 JSON / 独立属性字典表；SKU 规格 vs 搜索属性）需 design 决定。
- 图片关联数量上限（主图唯一性已定，其余图数量、多图排序）需 design 细化。
- Product 编辑时对已上架/已产生历史快照商品的改价约束（"不影响历史订单"由快照保证，但改价是否阻断）需 prd 确认。
- SKU 增删约束（存在库存锁定的 SKU 能否停用/删除）需 design 与 REQ-M2-004 联动设计。