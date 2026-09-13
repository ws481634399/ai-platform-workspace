# Requirement Spec（需求级产品规格）

> 层级：Requirement 级产物——针对本次需求/Change（多 Story 统一一份）
> 业界锚点：PRD（Problem → Goals/Metrics → Scope → Requirements → AC）
> 输入：CHG Context（exploration.md + requirement.md）
> 产出状态：specified
> 分层关系：本文是 Requirement 级；Story 边界与代码实现功能的持久记录见各 Story 目录 story-spec.md，两层不混写。

## 0. 元信息

- Change ID: CHG-0013
- Requirement: REQ-M2-004 库存核心能力
- 状态流转: exploring → specified
- 主要服务: mall-inventory（repo-1）；前端 mall-admin（repo-2）

## 1. 背景

CHG-0011 已在 mall-product 建立 Product（SPU）与 SKU 聚合，CHG-0012 完成商品发布与商城查询，商品域具备了"卖什么"的权威模型与"能否被买"的可见性控制。但平台尚无"有多少可卖"的库存权威——若库存挂在 Product Context 内、或无锁定/释放/确认扣减状态机、或无幂等与并发防护，则 M4 订单创建与支付将面临超卖、重复扣减、重复释放、库存为负等资损风险。

本需求在 Inventory Context（mall-inventory）建立以 SKU 为最小单位的库存权威聚合，覆盖库存初始化、单/批/后台查询、调整、可售库存计算、锁定、释放、确认扣减六大能力，配套库存流水、幂等控制与并发防护。库存与商品是独立上下文：Inventory 只认 skuId（通过 mall-contracts SKU 契约校验真实 SKU 存在），不复制维护 Product/Brand/Category/价格；Product 服务不直接修改库存。exploration §4 冲突检测：与 product/specs 无冲突、与 CHG-0011/0012 无功能重叠，沿用 CHG-0011 SKU 契约（仅校验 SKU 存在）。

## 2. 用户价值

- 目标用户: 后台库存管理员；下游消费方为 M4 mall-order（下单锁定、支付确认扣减、取消释放）、mall-admin（后台库存查询/初始化/调整/流水）、mall-product（仅通过契约查询可用库存，不读写库存库）。
- 痛点摘要: 无独立库存权威；超卖、重复扣减、重复释放、库存为负直接资损；无审计流水无法排错补偿；并发锁定无防护。
- 预期价值: 库存作为独立上下文提供可审计、并发安全、幂等的六大能力；不变量 Available>=0、Locked>=0 在 DB 约束与领域层双重保证；为 M4 订单与支付提供可信库存底座。

JTBD：

- 角色：库存管理员；场景：When I 需要为新上架 SKU 建立库存或盘点修正库存, I want to 初始化或调整 SKU 库存并记录流水；价值：So that 库存数准确且可追溯。
- 角色：订单系统；场景：When 用户下单锁定库存, I want to 原子锁定可用库存且幂等；价值：So that 不超卖、并发正确、可重放。
- 角色：订单系统；场景：When 支付成功确认扣减或订单取消释放, I want to 基于锁定记录幂等扣减或释放；价值：So that 不重复扣减、不重复释放、库存不丢。

## 3. 功能范围

### 3.1 包含

- [S1] 库存初始化：为 SKU 建立初始库存（total/locked=0），考虑重复初始化、不存在 SKU、已存在库存、初始库存非法。
- [S2] 库存查询：单 SKU 查询、批量 SKU 查询、后台分页查询（含 total/locked/available）；可售库存 = total - locked。
- [S3] 库存调整：盘点/人工修正库存数量，保留前后值、变化数量、原因、操作者、时间、Trace/Business Reference；不允许裸 UPDATE。
- [S4] 库存锁定：订单创建时锁定可用库存，库存足够才成功，不超卖，并发正确，请求幂等（reservationId 或 orderId+operationType）。
- [S5] 库存释放：订单取消/创建失败/超时关闭时释放锁定；一个订单重复释放不能重复增加库存。
- [S6] 库存确认扣减：支付成功后基于锁定记录扣减真实库存；只有已合法锁定才能扣减；重复支付事件不得重复扣库存。
- [S7] 库存流水：记录 INIT/ADJUST/LOCK/RELEASE/DEDUCT，关联 skuId、quantity、businessId、operationType、before/after、occurredAt。
- [S8] 后台管理：mall-admin SKU 库存查询、库存初始化、库存调整、库存流水查看，受 RBAC 保护（inventory:read / inventory:adjust 等）。
- [S9] 幂等与并发：Lock/Release/Confirm 幂等键；SQL 条件更新（available >= ?）或乐观锁 Version 防超卖；不变量 DB 约束兜底。

### 3.2 不包含

- 订单创建流程、模拟支付、RocketMQ、Outbox、延迟关闭订单、最终一致性异步改造（M4/M7）。
- 商品主数据维护（Product/Brand/Category/价格，归 mall-product）。
- 库存阈值/低库存预警（product/11 功能配置引用，不在本需求）。
- 分布式锁（M2 不引入，用 SQL 条件更新/乐观锁）。
- 库存锁定超时自动释放（触发侧归属 M4，本 Change 只提供释放接口与幂等）。

### 3.3 Story 拆分总表

| Story ID           | 标题           | Scope 摘要                                                                 | 依赖               | 优先级 |
| ------------------ | -------------- | -------------------------------------------------------------------------- | ------------------ | ------ |
| STORY-002-04-01-01 | 库存初始化与查询 | S1、S2、S7(INIT)、S8(查询)、S9(基础幂等)：Inventory 聚合、inventory_stock/inventory_log 表、初始化与查询 API、后台查询页 | CHG-0011 SKU 契约  | P0     |
| STORY-002-04-02-01 | 库存调整与流水 | S3、S7(ADJUST)、S8(调整/流水)：库存调整、流水记录、后台调整与流水页 | STORY-002-04-01-01 | P0     |
| STORY-002-04-03-01 | 库存锁定与释放 | S4、S5、S7(LOCK/RELEASE)、S9(幂等/并发)：锁定/释放状态机、reservation 记录、幂等键、SQL 条件更新 | STORY-002-04-01-01 | P0     |
| STORY-002-04-04-01 | 库存确认扣减 | S6、S7(DEDUCT)、S9(幂等)：基于锁定确认扣减、重复支付幂等、锁定转扣减状态机 | STORY-002-04-03-01 | P0     |

四 Story 同属 FEAT-002-04；初始化与查询是基础，调整依赖初始化，锁定/释放依赖初始化，确认扣减依赖锁定。后端按 Story 串行开发，前端后台页面随对应 Story 落地。

## 4. 业务规则总纲

- 库存模型（解决 exploration §5 待澄清 3）：至少表达 Total Stock、Locked Stock、Available Stock；Available = Total - Locked；不变量 Available >= 0、Locked >= 0，任何流程不得导致库存为负。采用 SQL 条件更新（`UPDATE ... WHERE total - locked >= ?`）保证并发锁定不超卖，同时保留 version 列兜底乐观锁。
- 幂等键（解决 exploration §5 待澄清 1）：Lock/Release/Confirm Deduction 以 `reservationId`（订单侧生成的稳定业务标识）作为幂等键；同一 reservationId 的重复 Lock 返回原锁定结果、重复 Release 不重复增加库存、重复 Confirm 不重复扣减。
- 初始化：skuId 必须通过 mall-contracts SKU 契约校验存在；初始 total >= 0；重复初始化（同一 skuId 已有库存）拒绝；初始库存非法（负数）拒绝。
- 调整：必须落流水（before/after/delta/reason/operator/traceId/businessId）；不允许裸 UPDATE；调整后 total >= 0（调整不能导致负库存，除非明确允许负库存场景，本阶段不允许）。
- 锁定：available >= quantity 才成功；锁定后 locked += quantity、available 不变（available = total - locked 计算）；幂等：同一 reservationId 重复锁定返回原结果；锁定记录（inventory_reservation）状态 LOCKED。
- 释放：必须基于已存在且状态为 LOCKED 的 reservation；释放后 locked -= quantity、reservation 状态 RELEASED；幂等：同一 reservationId 重复释放不重复减少 locked。
- 确认扣减：必须基于已存在且状态为 LOCKED 的 reservation；扣减后 total -= quantity、locked -= quantity、reservation 状态 DEDUCTED；幂等：同一 reservationId 重复确认不重复扣减。
- 库存流水：INIT/ADJUST/LOCK/RELEASE/DEDUCT 全量记录，关联 skuId、quantity、businessId（reservationId 或调整单号）、operationType、before/after、occurredAt。
- Context 边界：Inventory 只依赖 skuId（通过 mall-contracts SKU 契约校验），不复制维护 Product/Brand/Category/价格；Product 服务不直接修改库存；Inventory 不维护商品主数据。
- 权限：inventory:stock:list/detail、inventory:stock:init、inventory:stock:adjust、inventory:log:list；写接口服务端真实校验。
- 并发安全：两个用户同时购买最后 1 件只能一个成功（SQL 条件更新 affected rows = 1 才成功，= 0 抛库存不足）。

## 5. 全局验收标准

| ID     | 验收标准（可测试）                                                                      | 备注               |
| ------ | --------------------------------------------------------------------------------------- | ------------------ |
| AC-001 | 为已存在 SKU 初始化库存（total>=0）→ 成功，total=初始值、locked=0、available=total       | S1 初始化          |
| AC-002 | 为不存在 SKU 初始化 → 拒绝，错误 INVALID_ARGUMENT                                       | S1 SKU 契约        |
| AC-003 | 重复初始化同一 SKU → 拒绝，错误 CONFLICT                                                | S1 幂等初始化      |
| AC-004 | 初始库存为负 → 拒绝，错误 INVALID_ARGUMENT                                              | S1 非法值          |
| AC-005 | 单 SKU 查询返回 total/locked/available；available = total - locked                      | S2 单查            |
| AC-006 | 批量 SKU 查询返回各 SKU 库存；不存在的 SKU 不返回或返回零值（设计定）                    | S2 批查            |
| AC-007 | 后台分页查询库存列表（skuId/total/locked/available）                                    | S2 后台            |
| AC-008 | 调整库存（正/负 delta）→ total 更新正确，流水记录 before/after/delta/reason/operator     | S3 调整            |
| AC-009 | 调整导致 total < 0 → 拒绝，错误 INVALID_ARGUMENT                                        | S3 防负            |
| AC-010 | 锁定库存：available >= quantity → 成功，locked += quantity，reservation 状态 LOCKED     | S4 锁定            |
| AC-011 | 锁定库存：available < quantity → 拒绝，错误 STOCK_INSUFFICIENT                          | S4 防超卖          |
| AC-012 | 同一 reservationId 重复锁定 → 返回原锁定结果，不重复增加 locked                         | S4 幂等            |
| AC-013 | 释放库存：基于 LOCKED reservation → locked -= quantity，reservation 状态 RELEASED       | S5 释放            |
| AC-014 | 同一 reservationId 重复释放 → 不重复减少 locked，返回成功                               | S5 幂等            |
| AC-015 | 确认扣减：基于 LOCKED reservation → total -= quantity、locked -= quantity，状态 DEDUCTED | S6 确认扣减        |
| AC-016 | 同一 reservationId 重复确认扣减 → 不重复扣减，返回成功                                  | S6 幂等            |
| AC-017 | 确认扣减基于非 LOCKED（已释放/已扣减）reservation → 拒绝，错误 INVALID_STATE             | S6 状态机          |
| AC-018 | 库存流水记录 INIT/ADJUST/LOCK/RELEASE/DEDUCT，含 skuId/quantity/businessId/before/after | S7 流水            |
| AC-019 | 并发锁定最后 1 件：两个请求同时锁定 quantity=1 → 仅一个成功，另一个 STOCK_INSUFFICIENT   | S9 并发            |
| AC-020 | mall-admin 库存页可查询/初始化/调整/查看流水，受 inventory:* 权限保护                   | S8 后台            |
| AC-021 | inventory_stock/inventory_reservation/inventory_log 表无 product 主数据字段（仅 skuId） | 领域边界           |

## 6. 非功能需求

- 安全：全部接口经网关认证与服务端权限码校验，默认拒绝；写操作记录操作者与 traceId。
- 性能：单 SKU 查询 P95 < 50ms；批量查询（≤100 SKU）P95 < 200ms；锁定/释放/扣减 P95 < 100ms。
- 一致性：库存不变量由 SQL 条件更新与 DB CHECK 约束双重保证；幂等由 reservation 唯一约束兜底。
- 兼容性：接口遵循 M1 统一返回结构 UnifyResult 与异常码规范；前端复用 mall-admin 布局、HTTP 客户端与权限指令。
- 可扩展性：预留 version 列支持乐观锁；流水表支持后续补偿与分析。

## 7. 成功指标

- 库存不变量（Available>=0、Locked>=0）零违反；并发锁定零超卖；幂等操作零重复扣减/释放。
- 库存六大能力自动化测试通过率 100%，上线后零资损事故。
- 后台库存管理员可在 mall-admin 完成 SKU 库存查询/初始化/调整/流水查看，单次操作平均 ≤ 30 秒。
