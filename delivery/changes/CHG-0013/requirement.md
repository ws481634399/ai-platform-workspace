---
id: "REQ-M2-004"
name: "库存核心能力"
content: "按 docs/需求/M2/M2.md 中 REQ-M2-004 建立独立库存上下文，为 SKU 提供初始化、查询、调整、锁定、释放与确认扣减等库存核心能力。"
source: requirement-doc
created-at: "2026-09-13T02:40:00.000Z"
---

# Requirement

> 原始需求全文归档于 `references/M2.md`，本文件记录本 Change 的输入边界。

## 需求描述

按 `docs/需求/M2/M2.md` 中 `REQ-M2-004 库存核心能力` 执行完整 SDD。以 SKU 为库存管理最小单位，在 mall-inventory 建立独立库存上下文，负责所有真实库存状态与库存变化，覆盖：库存初始化、库存查询（单/批/后台）、库存调整、可售库存计算、库存锁定、库存释放、库存确认扣减、库存流水、幂等与防止库存为负。

核心商业规则：
- 库存模型至少表达 Total/Actual Stock、Locked Stock、Available Stock；不变量 `Available >= 0`、`Locked >= 0`，任何流程不得导致库存为负。
- 初始化需考虑重复初始化、不存在 SKU、已存在库存、初始库存非法。
- 调整保留变更记录（调整前后、变化数量、原因、操作者、时间、Trace/Business Reference），不允许裸 UPDATE。
- 锁定：库存足够才成功、不允许超卖、多用户并发正确、请求幂等。
- 释放：订单取消/创建失败/超时关闭时释放锁定；一个订单重复释放不能重复增加库存。
- 确认扣减：只有已合法锁定才能对应扣减；重复支付事件不得重复扣库存。
- 幂等：Lock/Release/Confirm Deduction 以稳定业务标识（orderId + operationType 或 reservationId）保证幂等。
- 并发安全：两个用户同时购买最后 1 件只能一个成功；实现可选 SQL 条件更新/乐观锁/Version/DB 并发控制；M2 不引入复杂分布式锁。
- 库存流水：记录 INIT/ADJUST/LOCK/RELEASE/DEDUCT，关联 skuId、quantity、businessId、operationType、before/after、occurredAt。
- Context 边界：Inventory 只依赖 skuId（通过稳定 SKU 契约验证），不复制维护 Product/Brand/Category/详情/价格；Product 服务不直接修改库存；Inventory 不维护商品主数据。
- 后台管理（mall-admin）：SKU 库存查询、库存初始化、库存调整、库存流水查看，受 RBAC 保护。

## 补充信息

- 优先级：P0
- 前置依赖：REQ-M2-002（商品与 SKU 管理 的 SKU 契约）
- 主要服务：mall-inventory
- 主要前端：mall-admin
- 重要程度：核心交易基础（M4 订单创建与支付直接使用）
- 主要仓库：repo-1、repo-2
- 非本需求范围：订单创建流程、模拟支付、RocketMQ、Outbox、延迟关闭订单、最终一致性异步改造