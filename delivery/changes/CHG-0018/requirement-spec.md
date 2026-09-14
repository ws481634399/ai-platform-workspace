# Requirement Spec（需求级产品规格）

> 层级：Requirement 级产物——针对本次需求/Change（多 Story 统一一份）
> 业界锚点：PRD（Problem → Goals/Metrics → Scope → Requirements → AC）
> 输入：CHG Context（exploration.md + requirement.md）
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0018
- Requirement: REQ-M3-003 购物车
- 状态流转: exploring → specified
- 主要服务: mall-cart（repo-1，Redis）；mall-product/mall-inventory 内部协作；前端 mall-web（repo-2）；Redis AOF 配置（repo-4）
- target-user: MEMBER 与游客
- pain-points: 无购买意向集合；加错 skuId、信任前端价格、越权操作他人车是高风险点
- expected-value: 会员车/游客车全操作可用，实时校验商品状态，登录幂等合并，为 M4 提供选中项输入
- scope-in: Redis 会员车、实时商品/价格/库存校验、LocalStorage 游客车、mergeToken 幂等合并、购物车页面
- scope-out: 创建订单/锁库存/成交价/支付/优惠券/运费/超时关单（M4）

## 1. 背景

M3 的收口能力：消费者选定具体 SKU 后需要一个“准备买什么”的集合。购物车必须守住三条语义红线：Cart ≠ Order（不锁库存、不生订单号、不存成交价、无支付状态）、价格仅展示（成交价 M4 重算，禁止信任浏览器价格）、库存仅展示（真正锁定在 M4）。需求采用纯 Redis 临时态（用户已确认可靠性边界）：滑动 TTL 90 天、单会员 ≤100 个 SKU 条目、单 SKU ≤999 件、selected 服务端跨设备一致、接受 Redis 故障丢车并以 AOF 兜底。游客购物车经评估定为 P0 必做（解决原文“建议”与 DoD 矛盾）：LocalStorage 保存游客车，登录后用一次性 mergeToken 幂等合并。mall-cart 只通过 mall-contracts 内部契约读取商品/库存，禁止跨服务 SQL；memberId 只来自 SecurityContext。

## 2. 用户价值

- 目标用户：MEMBER（服务端 Redis 车，跨设备）与游客（本地车，登录后不丢意向）；M4 订单消费选中项。
- 痛点摘要：重复加购产生脏条目；商品调价/下架/缺货后购物车展示陈旧信息；游客登录丢失加购；重试导致合并数量反复累加。
- 预期价值：购物车始终反映“当前能不能买、现在多少钱、还剩多少展示态库存”，合并可预期、可重放、不越权。

JTBD：

- 角色：MEMBER；场景：When 我把多个 SKU 加购并反复调整数量/勾选, I want 同 SKU 自动合并、上限可控；价值：So that 购物车整洁且不会出现非法数量。
- 角色：买家；场景：When 我隔几天打开购物车, I want 看到最新价格与失效/缺货标记；价值：So that 我基于现状做购买决策，结算前预期与 M4 一致。
- 角色：游客；场景：When 我未登录先加购再登录, I want 游客车自动合并且刷新页面不会重复累加；价值：So that 登录不损失任何购买意向。

## 3. 功能范围

### 3.1 包含

- [S1] 会员购物车核心操作：加购（校验商品可售/SKU 有效/数量合法）、同 SKU 合并数量、改量、单删/批删、单选/取消/全选/取消全选；Redis 模型与滑动 TTL；条目数/数量上限；memberId 取自 SecurityContext。
- [S2] 购物车实时校验：查看时经内部契约批量获取商品/SKU 状态、最新价（整数分）、库存三态（复用 CHG-0017 聚合口径）；标记下架/失效/调价/缺货/不存在；依赖降级 UNKNOWN；展示选中金额合计（仅展示）。
- [S3] 游客购物车与登录合并：mall-web LocalStorage 游客车（加购/改量/删除/勾选，与会员车一致的本地规则与上限提示）；登录成功获取一次性 mergeToken 调合并接口；服务端按 token 幂等（同 token 重放返回当前车不重复累加）；同 SKU 数量相加，超 999 截断并在响应告知；合并成功后前端清空游客车；去结算入口占位。

### 3.2 不包含

- Checkout Preview、订单创建、锁库存、成交价确认、支付、优惠券、运费（M4）。
- 购物车 MySQL 持久化与跨端同步冲突解决（本期 selected 服务端已跨设备，条目以 Redis 为准）。
- 收藏、常买、降价提醒。

### 3.3 Story 拆分总表

| Story ID | 标题 | Scope 摘要 | 依赖 | 优先级 |
| --- | --- | --- | --- | --- |
| STORY-003-03-01-01 | 购物车核心操作 | S1：Redis 模型/TTL/上限、加购合并/改量/删除/选择、安全归属、内部选中项查询 | CHG-0015、会员认证、商品契约 | P0 |
| STORY-003-03-01-02 | 购物车实时校验 | S2：读模型聚合最新状态/价格/库存三态、失效标记、降级、金额展示 | STORY-003-03-01-01、CHG-0017 聚合 | P0 |
| STORY-003-03-02-01 | 游客购物车与登录合并 | S3：LocalStorage 游客车、mergeToken 幂等合并、截断、合并后清理、购物车页面全流程 | STORY-003-03-01-01、STORY-003-03-01-02、CHG-0016 登录 | P0 |

## 4. 业务规则总纲

- [Redis 模型]：Key `cart:member:{memberId}`；结构 Hash<skuId, CartItemJSON> 或等价（design 定）；每次写操作通过 pipeline/Lua 原子完成数据变更 + 滑动 TTL 续期 90 天；Redis 开 AOF（appendfsync everysec）。
- [条目上限]：不同 SKU 条目 ≤100，加第 101 个 → 400 CART_ITEMS_LIMIT；单 SKU 数量 1–999。
- [加购合并]：已存在同 skuId 条目时 quantity 累加；累加结果 >999 时加购请求 → 400 CART_QUANTITY_LIMIT（直接指定式加购不静默截断）；不存在则新建条目（selected 默认 true）。
- [改量]：PUT 数量必须为 1–999 整数；0/负数/非整数/溢出 → 400；不产生 0 数量残留（以 0 删除的语义如提供则等同删除）。
- [删除]：单删与批删仅作用于当前会员车；批删不存在的 skuId 幂等成功。
- [选择]：selected 存服务端；全选/取消全选对全部有效条目生效；失效条目不参与选中金额。
- [实时校验]：读车时一次性批量拉取商品/SKU/库存（禁 N+1）；条目级状态 VALID / PRODUCT_OFF_SHELF / SKU_INVALID / NOT_FOUND / PRICE_CHANGED（带 latestPriceFen）/ STOCK_LOW / OUT_OF_STOCK / UNKNOWN；校验不修改 Redis 中数量与选择。
- [价格语义]：响应价格全部来自 product 最新数据（整数分），购物车永不存储权威价格；请求体传 price/totalAmount 一律忽略。
- [库存语义]：加购不校验库存充足（可加购缺货 SKU，读车时标记 OUT_OF_STOCK，不可结算）；不锁库存。
- [越权防护]：接口路径不含 memberId；memberId 只从 SecurityContext 取；未认证访问会员车接口 401。
- [游客车]：LocalStorage 单条目结构与服务端一致（skuId/quantity/selected/addedAt）；同样执行 ≤999、≤100 的本地校验与提示；游客车不做实时校验写回，读时前端调用公开商品/可售接口展示。
- [合并幂等]：登录流程签发 mergeToken（随机串，Redis key `cart:merge:{token}`，TTL 5 分钟，一次性消费用 Lua 原子 GETDEL 语义）；合并：逐 SKU 相加，超 999 截断为 999 并在响应返回 truncated 列表；条目总数超 100 时优先保留会员车已有条目，多余游客条目标记 dropped 返回；同 token 二次请求直接返回当前整车不再次累加；合并成功前端清空本地游客车与待合并标记。
- [去结算]：M3 仅展示入口（无失效/缺货选中项时可点击但提示“结算将在后续阶段开放”，或置灰——design 定，默认置灰）。

## 5. 全局验收标准

| ID | 验收标准（可测试） | 备注 |
| --- | --- | --- |
| AC-001 | MEMBER 加购有效 SKU（skuId+quantity）→ 成功，车中出现该条目，写操作后 Key TTL 续期为 90 天 | S1 |
| AC-002 | 同 SKU 重复加购 → quantity 累加为一条；累加到 >999 → 400 且数量保持 999 | S1 合并/上限 |
| AC-003 | 加购下架商品/失效 SKU/不存在 SKU/数量非法（0、负、非整数、>999）→ 400 业务错误，车不变 | S1 校验 |
| AC-004 | 加入第 101 个不同 SKU → 400 CART_ITEMS_LIMIT，车仍为 100 条 | S1 条目上限 |
| AC-005 | 修改数量为合法值成功；非法值 400；删除单条/批删成功；批删含不存在 skuId 幂等成功 | S1 改删 |
| AC-006 | 单选/取消/全选/取消全选正确生效；重新登录（跨设备）selected 状态保持 | S1 选择 |
| AC-007 | 未带认证访问购物车接口 → 401；请求体伪造 memberId 无效，只能操作本人车（SecurityContext） | S1 安全 |
| AC-008 | 读车返回商品图/名称/SKU 属性/当前价/数量/选择/条目状态，价格为 product 最新整数分 | S2 读模型 |
| AC-009 | 后台把商品下架后读车 → 对应条目 PRODUCT_OFF_SHELF；SKU 禁用 → SKU_INVALID；商品删除 → NOT_FOUND | S2 失效 |
| AC-010 | 后台改价后读车 → PRICE_CHANGED 且展示 latestPriceFen；前端提交的 price 字段被服务端忽略 | S2 价格 |
| AC-011 | 库存 0 → OUT_OF_STOCK；1–9 → STOCK_LOW；≥10 → VALID（与 CHG-0017 同口径） | S2 库存 |
| AC-012 | product/inventory 不可用时条目级 UNKNOWN，整车 200 可展示，不白屏 | S2 降级 |
| AC-013 | 选中金额合计仅统计 VALID 且选中条目，整数分；失效/缺货条目排除 | S2 金额 |
| AC-014 | 加购不产生任何库存锁定调用（inventory lock 无调用记录） | 红线 |
| AC-015 | 游客在商品详情加购 → LocalStorage 出现条目；可改量/删除/勾选；规则与上限提示同会员车 | S3 游客车 |
| AC-016 | 游客加购后登录 → 合并成功：同 SKU 数量相加（Guest 2 + Member 1 = 3），不同 SKU 并入 | S3 合并 |
| AC-017 | 合并超 999 截断为 999 且响应含 truncated 提示；超 100 条目时多余游客条目 dropped 并告知 | S3 截断 |
| AC-018 | 同一 mergeToken 重复提交两次 → 第二次返回当前车且数量不再次累加（幂等）；失效/过期 token → 401/400 | S3 幂等 |
| AC-019 | 合并成功后 LocalStorage 游客车被清空；刷新页面不触发二次合并 | S3 清理 |
| AC-020 | mall-web 购物车页：列表/图/名称/SKU 属性/价格/数量/库存状态/有效状态/单选全选/删除/改量/选中金额/去结算占位完整 | S3 页面 |
| AC-021 | mall-cart 代码与 SQL 审计：无 product/inventory 库表直查，仅经 mall-contracts 内部 API | 边界 |
| AC-022 | mall-web build/lint/type-check 通过；Redis AOF 配置在 infra 仓生效（重启容器配置可验证） | 端到端/infra |

## 6. 非功能需求

- 性能：读车（含批量聚合，≤100 条目）P95 < 300ms；写操作 P95 < 100ms。
- 可靠性：接受 Redis 故障丢车（产品语义可接受）；AOF everysec 降低常态重启损失；降级路径不产生错误下单依据。
- 安全：MEMBER 鉴权 + 归属；mergeToken 一次性短时；无价格信任。
- 可观测：合并、上限拦截、依赖降级记录日志与指标。

## 7. 成功指标

- Integration Gate 场景三（游客加购→登录→合并→查看会员车）、场景四（调价/下架后读车识别）、场景五（越权访问）全部通过并留证。
- 合并接口重复提交零累加事故；购物车相关价格信任缺陷为零。
- 购物车核心行为自动化测试通过率 100%。
