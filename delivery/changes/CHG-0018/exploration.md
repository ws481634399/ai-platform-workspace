# Exploration（需求探索报告）

> 阶段：sdd-explore 产物
> 业界锚点：Discovery（Problem → Evidence → Conflict → Recommendation）
> 输入：requirement.md（原文沉淀；本文件不复述原文，只做分析）
> 产出状态：exploring（推进 Change 状态）

## 1. 需求要点

- 做什么：mall-cart 基于 Redis 实现会员购物车的加购/合并/改量/删除/选择全操作与查看时实时校验，并交付 LocalStorage 游客车 + 登录后幂等合并的完整链路；mall-web 提供购物车页面与去结算入口占位。
- 给谁：MEMBER（服务端车）与游客（本地车）；M4 订单将消费“选中购物车项”内部能力。
- 解决什么问题：这是 M3 用户侧链路的收口——把 REQ-M3-001（可信 memberId）与 REQ-M3-002（skuId/价格/库存展示）串成“准备买什么”的集合，同时守住三条不可逾越的语义：Cart≠Order（不锁库存、不生订单号、不存成交价、无支付状态）、价格仅展示、库存仅展示。
- 隐含需求：
  - Redis 可靠性参数已由用户拍板：滑动 TTL 90 天、≤100 条/SKU 类条目、单 SKU ≤999 件、selected 服务端、接受丢失 + AOF 兜底；PRD 需把超限行为写成验收（加第 101 个 SKU、数量加到 1000 的返回码与提示）；
  - 游客合并 P0：幂等键是设计核心——建议登录流程签发一次性 mergeToken（短时有效、服务端标记已消费），重复合并返回当前车且不重复累加；本地车合并成功后清除/标记已合并；
  - 数量合并受上限截断（Guest 2 + Member 998 → 999，而非报错丢数据），截断需在响应中告知；
  - 越权防护只认真身：memberId 只从 SecurityContext 取，接口路径不出现 memberId；
  - 实时校验必须容忍依赖降级：product/inventory 内部调用超时/失败时购物车不应白屏，条目以“状态未知/校验失败”标记可重试；
  - 金额：服务端聚合展示金额一律整数分；前端只做展示运算，提交加购只传 skuId+quantity，绝不传价格；
  - 条目时间戳用于排序与未来结算清理；Redis 数据结构（Hash/JSON）由 design 定，要求支持按 memberId 整体读取、按 skuId 原子增减、TTL 续期原子化。

知识检索结果（引用来源）：

- M3.md REQ-M3-003 全文 19 章 + 验收 18 条 + Integration Gate 场景三/四/五；文末注意点 6（游客车矛盾）、7（Redis 可靠性参数化）、依赖微调（购物车不依赖地址）——范围与参数均为用户明确决策。
- `product/04` §10 BC-04：职责（加购/改量/删除/选择/失效/游客合并/结算清理）、Redis 为主存储、接口候选 `/api/mall/cart*`、内部能力（获取选中项、清理已结算项、合并游客车）、关键规则（不锁库存、同 SKU 合并、金额仅展示、下单前再校验、失效项不能结算、查看时实时校验避免批量更新购物车）。
- `product/06` ShoppingCart/CartItem/PurchaseQuantity/CartItemStatus 聚合候选。
- CHG-0012 内部商品契约、CHG-0013 库存查询契约、CHG-0017 面向商城的批量商品/库存聚合（本 Change 直接依赖，设计需与 0017 对齐接口形状）；CHG-0015 提供字符串 ID、内部服务凭证与网关基础。

## 2. Story 归属判定

- Feature ID: FEAT-003-03（商城前台 → 购物车）
- Story 节点（本次新建 3 个）：
  - STORY-003-03-01-01 购物车核心操作（FEAT-003-03-01 会员购物车）：加购/同 SKU 合并/改量/单批删除/单选全选/Redis 模型与 TTL/上限
  - STORY-003-03-01-02 购物车实时校验（FEAT-003-03-01）：查看时商品/SKU 有效性、最新价、库存三态聚合与失效标记，依赖降级
  - STORY-003-03-02-01 游客购物车与登录合并（FEAT-003-03-02）：LocalStorage 游客车、mergeToken 幂等合并、截断与上限、合并后清理
- 是否新建 candidate: 否。
- Feature 路径: 商城前台 → 购物车 → 会员购物车/游客购物车与合并 → 对应 Story。

## 3. 证据评估

- 业务依据：M3.md 18 条验收 + 3 个 Integration Gate 场景（游客转会员、状态变化、越权）+ 用户对两个争议点（游客车 P0、Redis 边界）的明确决策。
- 领域依据：product/04 §10 与 product/06 购物车聚合模型，规则与需求完全同向。
- 工程依据：Redis 6379 基础设施 M0 就绪；mall-cart 独立服务骨架存在；M2 商品/库存内部契约已交付；CHG-0017 将提供批量聚合能力；SecurityContext 取 MEMBER 主体由 M1 保证。
- 结论: 充分（可靠性边界与幂等要求均已参数化，无阻断性未知）。

## 4. 冲突点检测

- 与 specs 冲突: 无。
- 与既有 Change 重叠或沿用:
  - 不与 CHG-0017 重复造聚合：商品/库存批量查询归 0017 的商城适配层，mall-cart 作为内部消费者复用；若 0017 的接口面向浏览器不含内部字段，需在 design 明确 mall-cart 使用 internal 契约而非公开商城接口；
  - 与 CHG-0016 仅依赖认证子集（可信 memberId），地址不阻塞，符合用户确认的依赖微调；
  - “清理已结算购物车项 / 获取选中项”内部能力为 M4 预留接口形状，M3 实现选中项查询，结算清理在 M4 订单成功后调用（本 Change 可先提供内部端点但无调用方）。
- 与已规划 Story 重复: 无（购物车为全新 FEAT-003-03 分支）。
- 处理决策: 核心操作与实时校验拆两个 Story（Redis 写模型 vs 读模型聚合，验收点不同）；游客合并单列 Story（跨前后端、幂等语义独立）。

## 5. 待澄清问题

- 加购时库存策略：建议不阻断（可加购缺货 SKU，查看时提示缺货且不能进结算），PRD 确认；数量上限在加购阶段是截断还是报错（建议合并时截断、直接指定数量超限时 400）。
- mergeToken 签发归属：mall-identity 登录响应附带 vs mall-cart 专门换取端点，需 design 结合登录接口现状选定；Token 一次性消费的存储（Redis 短时 key）与 TTL 建议 5 分钟。
- 购物车 Key 命名与数据结构（`cart:member:{memberId}` Hash<skuId, JSON>）、滑动 TTL 的原子续期（HSET + EXPIRE pipeline/Lua）、AOF 在 docker-compose.infra.yml 的具体配置（appendfsync everysec）由 design 定稿。
- 选中金额“去结算”入口 M3 形态：按钮置灰 + “M4 开放”提示 vs 点击提示登录/不可用，PRD 给统一文案。
- 库存不足阈值需与 CHG-0017 三态口径完全一致（共用常量/配置）。
- 依赖降级（product/inventory 不可用）时的 HTTP 行为与前端展示由 PRD/design 明确，建议 200 + 条目级 status=UNKNOWN，整车不可用才 503。
