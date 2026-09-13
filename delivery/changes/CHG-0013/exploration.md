# Exploration（需求探索报告）

> 阶段：sdd-explore 产物
> 业界锚点：Discovery 文档（Problem → Evidence → Conflict → Recommendation）
> 输入：requirement.md（原文沉淀；本文件不复述原文，只做分析）
> 产出状态：exploring（推进 Change 状态）

本文档回答探索阶段的五个问题：需求要点是什么、归属哪个 Story（是否已存在）、证据是否充分、有无冲突点、还有什么待澄清。

## 1. 需求要点

- 做什么：在 mall-inventory 建立以 SKU 为单位的库存权威上下文，提供初始化/查询/调整/锁定/释放/确认扣减六大能力，配套库存流水、幂等控制与并发防护，为 M4 订单与支付提供库存底座。
- 给谁：mall-order（下单锁定、支付确认扣减、取消释放）；mall-admin（后台库存查询/初始化/调整/流水查看）；mall-product（仅通过契约查询可用库存，不读写库存库）。
- 解决什么问题：库存是交易正确性的核心——超卖、重复释放、重复扣减、库存为负都直接导致资损/客诉；M2 必须把库存做成独立的、可审计的、并发安全的上下文。
- 隐含需求：
  - 库存不变量（Available >= 0、Locked >= 0）必须在数据库约束与领域层双重保证；
  - Lock/Release/Confirm 必须幂等（reservationId/orderId + operationType 幂等键），释放/扣减可安全重放；
  - 并发锁定采用 SQL 条件更新（`UPDATE ... WHERE available >= ?`）或乐观锁 Version，M2 不引入分布式锁；
  - 调整业务语义为"盘点对账/人工修正"，必须落流水且前值后值可追溯（审计）；
  - 库存流水是补偿与排错的基础，INIT/ADJUST/LOCK/RELEASE/DEDUCT 全量记录；
  - Inventory 只认 skuId，通过 mall-contracts SKU 契约校验真实 SKU，不复刻商品主数据；
  - 后台库存操作受 RBAC 保护（inventory:read / inventory:adjust 等，design 定码）。
  - 库存查询暴露最小化语义（可用库存），不暴露内部实现细节。

知识检索结果（引用来源）：

- `product/06-聚合与领域模型设计.md` §10.1 Inventory 聚合：InventoryId/SkuId/TotalQuantity/LockedQuantity/Version + InventoryStatus + InventoryReservation 实体；initialize/increase/decrease/reserve/release/confirmDeduction/adjust 领域行为；reservationNo/businessNo。库存流水记录独立并归 Inventory 规则管理。
- `product/05-上下文映射图.md` §14 订单→库存映射：下单锁定（同步调用）、支付后确认扣减、取消释放、创建失败补偿、幂等规则；禁止做法（跨服务直查 DB、扣减无锁定前提等）。
- `product/07-核心业务流程.md`：下单一览图与库存联动时序（锁→扣/释放）。
- `product/04-子域与限界上下文.md` BC-06 Inventory Context（mall-inventory）。
- `product/10-API与事件契约.md`：内部接口（锁定/释放/确认扣减库存）由 mall-order 调用；RocketMQ 留 M7。

## 2. Story 归属判定

- Feature ID: FEAT-002-04（商品与库存 → 库存核心能力）
- Story 节点: STORY-002-04-01 库存初始化与查询、STORY-002-04-02 库存调整与流水、STORY-002-04-03 库存锁定与释放、STORY-002-04-04 库存确认扣减（树中不存在，本次新建）
- 是否新建 candidate: 否（归属明确，新建正式 Story 节点）
- Feature 路径: 商品与库存 → 库存核心能力 → 库存初始化与查询 / 库存调整与流水 / 库存锁定与释放 / 库存确认扣减

## 3. 证据评估

- 证据类型与来源：
  - 业务依据：`docs/需求/M2/M2.md` REQ-M2-004 验收标准（17 条含并发/幂等/不变量）；`product/06` §10.1 领域模型；`product/05` §14 与订单一致性规则；`product/07` 端到端流转；
  - 工程基础：mall-inventory 骨架（CHG-0003 创建），MySQL 事务与 MyBatis DAL 基线（CHG-0001）；mall-contracts 承担 SKU 契约。
- 结论: 充分（不变量、幂等、并发与验收均有明确依据与既有工程底座）

## 4. 冲突点检测

- 与 product/specs/ 规则冲突: 无（specs/ 无已确认高优先级规则覆盖库存）
- 与既有 Change 重叠或沿用: 沿用 CHG-0011 SKU 契约（仅校验 SKU 存在，不复制商品主数据）；与 CHG-0012 上架校验形成"库存初始化状态查询"契约依赖（方向：product → inventory 只读查询）；无功能范围重叠
- 与已规划 Story 重复: 无（库存 4 个 Story 均为本次新增，粒度按操作语义拆分）
- 处理决策: 无冲突；锁定/释放/确认扣减三个操作存在紧密状态机关系，拆 STORY-002-04-03 与 STORY-002-04-04 两个 Story 交付（锁与释放一个、确认扣减一个），流水贯穿各 Story 落地

## 5. 待澄清问题

- 幂等键的具体形态（reservationId 全局生成 or orderId+operationType 组合）需 design 与 M4 订单编号方案对齐。
- 库存锁定超时/自动释放策略（订单超时关闭的触发侧归属 M4，本 Change 只提供释放接口与幂等）。
- 乐观锁 vs SQL 条件更新取舍、是否需要 Version 列（`product/06` 有 Version，需 design 确认实现与冲突返回码）。
- 高并发下的批量锁定（一次锁定多 SKU）失败语义（全部回滚 or 部分成功）需 design 与 M4 下单流程对齐。
- 库存阈值/低库存预警不在本需求范围（product/11 功能配置有引用），design 阶段确认是否收敛进流水分析事件。
- 调整库存的 Reason 字典与操作者来源（令牌内 ADMIN 主体）需 design 明确。