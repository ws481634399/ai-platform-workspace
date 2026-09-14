---
story-id: "STORY-003-03-02-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S3]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0018
- Story ID: STORY-003-03-02-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

mall-web LocalStorage 游客购物车与登录后幂等合并：游客可加购/改量/勾选；登录签发一次性 mergeToken 完成同 SKU 相加、上限截断与结果告知；重复提交不累加；购物车页面承载全部展示与操作、去结算入口占位。

## 2. Scope（范围）

### 2.1 包含

- [S3] 游客车本地模型与上限规则；登录流程 mergeToken 签发（5 分钟一次性）；POST 合并接口（相加/截断/丢弃告知/幂等）；合并后前端清理；购物车页面（会员/游客双模）与去结算占位；build/lint/type-check；Redis AOF 配置（infra）。

### 2.2 不包含

- Checkout Preview/下单（M4）；降价提醒；多端游客车同步。

## 3. 业务规则

- 游客车本地条目 {skuId, quantity, selected, addedAt}；上限同会员（100 条目/单 SKU 999）；游客读车展示走公开商品与可售接口。
- mergeToken：随机、服务端 Redis 存 5 分钟、一次性原子消费；重复提交返回当前整车不加分；过期/伪造拒绝。
- 合并相加超 999 截断并在 truncated 列出；超 100 条目优先保会员条目，游客多余项 dropped 告知。
- 合并成功才清本地；任何失败保留游客车可重试。

## 4. 接口与字段规格

- 登录响应（CHG-0016）增加 mergeToken 字段（仅当请求要求/或独立 POST /api/mall/cart/merge-token）。
- POST /api/mall/cart/merge（MEMBER 鉴权）Header/Body 带 mergeToken + { items:[{skuId, quantity, selected}] }
- 响应：{ merged:[{skuId, quantity}], truncated:[{skuId, finalQuantity}], dropped:[{skuId, reason}], cart: <读车视图> }
- infra：docker-compose.infra.yml Redis command 加 appendonly yes / appendfsync everysec。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-015 | 游客加购写 LocalStorage，可改量/删除/勾选，上限提示同会员车 |
| AC-016 | 登录后合并：同 SKU 相加（2+1=3），不同 SKU 并入 |
| AC-017 | 超 999 截断并告知；超 100 条目时多余游客项 dropped 并告知 |
| AC-018 | 同 mergeToken 提交两次仅合并一次；过期/伪造 token 拒绝 |
| AC-019 | 合并成功清本地游客车，刷新不二次合并 |
| AC-020 | 购物车页面字段/操作/金额/去结算占位完整可用 |
| AC-022 | mall-web build/lint/type-check 通过；Redis AOF 配置生效 |
