---
story-id: "STORY-003-03-01-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S1]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0018
- Story ID: STORY-003-03-01-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

基于 Redis 建立会员购物车写模型：加购合并、改量、单/批删除、单选全选，落地 TTL/条目/数量上限与安全归属；购物车不锁库存、不信任前端价格；为实时校验与 M4 选中项查询提供数据基础。

## 2. Scope（范围）

### 2.1 包含

- [S1] Redis Key/数据结构、滑动 TTL 90 天原子续期、加购校验与合并、改量、删除、选择状态；SecurityContext 归属；内部“查询选中项”端点（M4 预留）；AOF 配置确认。

### 2.2 不包含

- 读车实时商品/价格/库存聚合（STORY-003-03-01-02）；游客车与合并（STORY-003-03-02-01）；购物车页面（随 0018-02/03）。

## 3. 业务规则

- Key cart:member:{memberId}；写操作原子改数据 + EXPIRE；条目 ≤100、单 SKU 1–999；加购累加超上限 400；selected 默认 true 且服务端存储。
- 加购前经内部契约校验 Product 可售、SKU 有效（不校验库存充足、不锁库存）。
- memberId 只从 SecurityContext；接口路径无 memberId。

## 4. 接口与字段规格

- GET /api/mall/cart（读接口由下一 Story 补聚合，本 Story 先保证条目数据）
- POST /api/mall/cart/items { skuId:string, quantity:int }
- PUT /api/mall/cart/items/{skuId} { quantity:int }
- DELETE /api/mall/cart/items/{skuId}；POST /api/mall/cart/items/batch-delete { skuIds:string[] }
- POST /api/mall/cart/items/{skuId}/select|unselect；POST /api/mall/cart/select-all|unselect-all
- 内部：GET /api/internal/carts/selected-items（M4 预留）
- 条目字段：skuId/quantity/selected/createdAt/updatedAt（不存名称价格）

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 有效加购成功且写后 TTL 续期 90 天 |
| AC-002 | 同 SKU 累加为一条；>999 → 400 且保持 999 |
| AC-003 | 下架/失效/不存在 SKU 与非法数量加购 → 400，车不变 |
| AC-004 | 第 101 个不同 SKU → 400，车保持 100 条 |
| AC-005 | 改量/单删/批删行为正确，批删不存在条目幂等成功 |
| AC-006 | 单选/全选生效，跨设备 selected 保持 |
| AC-007 | 未认证 401；伪造 memberId 无效，仅操作本人车 |
| AC-014 | 加购链路无任何库存锁定调用 |
