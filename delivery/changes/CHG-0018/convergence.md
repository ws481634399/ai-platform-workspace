# Convergence — CHG-0018 购物车

> 阶段：sdd-converge 产物

## 0. 元信息

- Change ID：CHG-0018
- 完成时间：2026-09-16
- standards-need-update：yes（1 个文件追加）
- product-need-update：yes（Spec 晋升候选 1 篇，待人工评审）
- featuretree-need-update：yes（3 个 Story planned → delivered）
- glossary-need-update：no

## 1. 知识变化总结

本 Change 交付购物车域全部 3 个 Story（购物车核心操作 / 购物车实时校验 / 游客购物车与登录合并）、
6 个 DU（repo-1 三个：DU-BE-801/802/803；repo-2 三个：DU-FE-801/802/803），确立三类可跨 Change 复用的规则：

1. **Redis Hash 购物车存储与 Lua 原子写（BE）**：会员车 `cart:member:{memberId}` Hash（field=skuId，
   value=CartItem JSON）；写操作（加购/改量/删除/勾选）走 Lua 单脚本原子；合并 token
   `cart:merge:{token}` String（值=memberId，TTL 300s，一次性 DEL 消费）；90 天 TTL 续期；
   合并脚本单 Lua 完成 token 校验→消费→逐条合并（相加/999截断/100dropped）→续期。
   ——适用于后续优惠券、收藏夹等所有 Redis Hash 持久化 + 原子写场景。

2. **跨服务读模型实时聚合与降级（BE）**：GET 读车一次 product batch + 一次 inventory availability
   装配 CartLine；状态优先级 product 故障 UNKNOWN > NOT_FOUND > PRODUCT_OFF_SHELF > SKU_INVALID >
   PRICE_CHANGED > VALID；库存三态阈值与 CHG-0017 同口径；依赖故障条目级 UNKNOWN 整车 200；
   合计仅 VALID+selected+有货。——适用于后续订单确认页、结算页等跨域读模型。

3. **游客车 LocalStorage + 登录合并编排（FE）**：游客车 LocalStorage 持久化（999件/100条/90天）；
   双模 store（游客本地/会员 API）；登录态 watch 自动触发合并（issueToken→merge，token 失效重取一次，
   网络失败保留+pending 标记）。——适用于后续收藏夹、足迹等游客态能力。

## 2. 更新判断

### Standards 晋升

- 文件：`standards/engineering/backend/redis-usage-standard.md`（若不存在则由 sdd-knowledge 创建）
- 操作：新增「购物车 Redis 存储与 Lua 原子写模式（CHG-0018 晋升）」
- 内容：①Hash 存业务集合（field=业务 ID，value=JSON）；②写操作必须 Lua 单脚本原子（读-改-写不分离）；
  ③一次性 token 模式（String 存关联 ID，TTL 短，消费即 DEL）；④TTL 续期在写脚本内统一处理；
  ⑤Lua 返回 JSON 手写 encodeArray() 兼容 Redis 7.x cjson 空表问题；⑥金额整数分存 Redis。
- 理由：后续优惠券、收藏夹、限时购等均面临相同的 Redis 持久化+原子写+幂等消费需求。
- 复用场景：所有 Redis Hash 业务集合 + 原子写场景。

### Spec 晋升候选（人工评审后落 product/specs/）

- 文件：`product/specs/购物车.md`（评审通过后创建）
- 操作：新增
- 内容（草稿，来源 requirement-spec.md AC-001~022）：
  - 会员车：加购有效 SKU 成功，同 SKU 累加，>999 截断 400，>100 条目 400；改量/删除/勾选幂等；
    只能操作本人车（SecurityContext）。
  - 读模型：返回商品图/名称/SKU 属性/当前价（product 最新整数分）/数量/选择/条目状态；
    下架→PRODUCT_OFF_SHELF，SKU 禁用→SKU_INVALID，删除→NOT_FOUND，改价→PRICE_CHANGED；
    库存三态（0 缺货/1-9 紧张/≥10 现货）；依赖故障条目级 UNKNOWN 整车 200；
    选中合计仅 VALID+选中+有货，整数分。
  - 游客车：LocalStorage 持久化，上限同会员车（999 件/100 条）。
  - 合并：登录后自动合并，同 SKU 相加，>999 截断，>100 dropped；token 一次性（重放 400/401）；
    成功清 LocalStorage。
  - 边界：加购不锁库存；mall-cart 无 product/inventory 库表直查，仅内部 API。
- 理由：购物车为订单履约前置能力，后续结算、下单需稳定产品依据。
- 来源：requirement-spec.md AC-001~022 + 3 Story 验证结果。

### Feature Tree 更新

- 节点：STORY-003-03-01-01 购物车核心操作 / STORY-003-03-01-02 购物车实时校验 /
  STORY-003-03-02-01 游客购物车与登录合并
- 操作：planned → delivered（3 节点，全部 Story 下 DU 已 completed）
- 方式：`openspec feature update <STORY-ID> --status delivered`

### Glossary 更新

无。SKU/SPU/库存三态为电商通用概念；「合并 token」「游客车」为本 Change 业务术语，
已由 Feature Tree 节点与接口契约承载。

### No Update

- 各端点具体 JSON 字段：实现细节。
- Lua 脚本具体实现：属代码细节。
- AOF 配置（appendonly everysec）：CHG-0006 已确立，本 Change 仅验证。

## 3. 知识沉淀过程

- 通读 3 Story 全部 Artifact（requirement/spec/design、3 套 story-spec/design/test-design、
  6 个仓内 DU 的 task-design/implementation、3 份 Story test-report/review-report），
  提取技术候选 3 组、业务规则候选 1 组。
- 检索既有 standards：CHG-0017 已立公开只读口径与库存三态 → 本次补 Redis 存储与 Lua 原子写模式。
- Spec 候选只在本文件起草（§2），未直接写 product/specs/，等待人工评审。
- 无 Unresolved 问题；三个 Story review-report 无开放 blocker/major。

## 4. 全局验收标准对照

| AC | 验收点 | 证据 | 结论 |
| --- | --- | --- | --- |
| AC-001 | 会员加购有效 SKU，TTL 续 90 天 | Story 1 test-report | 通过 |
| AC-002 | 同 SKU 累加，>999 400 | Story 1 test-report | 通过 |
| AC-003 | 下架/失效/不存在/非法数量 400 | Story 1 test-report | 通过 |
| AC-004 | 第 101 个 SKU 400 CART_ITEMS_LIMIT | Story 1 test-report | 通过 |
| AC-005 | 改量/删除/批删幂等 | Story 1 test-report | 通过 |
| AC-006 | 单选/全选正确，跨设备保持 | Story 1 test-report | 通过 |
| AC-007 | 未认证 401，伪造 memberId 无效 | Story 1 test-report | 通过 |
| AC-008 | 读车返回全字段，价格整数分 | Story 2 test-report TC-001 | 通过 |
| AC-009 | 下架/禁用/删除三态 | Story 2 test-report TC-002 | 通过 |
| AC-010 | 改价 PRICE_CHANGED，前端 price 被忽略 | Story 2 test-report TC-003 | 通过 |
| AC-011 | 库存阈值 0/1-9/≥10 三态 | Story 2 test-report TC-004 | 通过 |
| AC-012 | 依赖故障 UNKNOWN，整车 200 | Story 2 test-report TC-005 | 通过 |
| AC-013 | 合计仅 VALID+选中+有货 | Story 2 test-report TC-006 | 通过 |
| AC-014 | 加购不锁库存 | Story 1 边界审计 | 通过 |
| AC-015 | 游客加购进 LocalStorage，上限提示 | Story 3 test-report TC-001 | 通过 |
| AC-016 | 登录合并同 SKU 相加/异 SKU 并入 | Story 3 test-report TC-003 | 通过 |
| AC-017 | 超 999 截断/超 100 dropped 提示 | Story 3 test-report TC-004 | 通过 |
| AC-018 | token 幂等，失效 400/401 | Story 3 test-report TC-005/007 | 通过 |
| AC-019 | 合并成功清 LocalStorage，不重复合并 | Story 3 test-report TC-010 | 通过 |
| AC-020 | 购物车页全字段/三态/合计/去结算置灰 | Story 3 test-report TC-009/012 | 通过 |
| AC-021 | mall-cart 无库表直查，仅内部 API | Story 2 边界审计 | 通过 |
| AC-022 | 前端三检通过，Redis AOF 生效 | Story 3 test-report TC-012 | 通过 |

## 5. 完成确认

- [x] 全部 3 Story Artifact 已读取
- [x] 知识分类完成（1 个 standards 文件追加、1 篇 Spec 晋升候选、3 节点 Feature Tree）
- [x] 6 个 DU 均 completed
- [x] 无未解决 Conflict、Unresolved 问题或开放的 blocker/major
