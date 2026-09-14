# Requirement Spec（需求级产品规格）

> 层级：Requirement 级产物——针对本次需求/Change（多 Story 统一一份）
> 业界锚点：PRD（Problem → Goals/Metrics → Scope → Requirements → AC）
> 输入：CHG Context（exploration.md + requirement.md）
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0017
- Requirement: REQ-M3-002 商城商品浏览体验
- 状态流转: exploring → specified
- 主要服务: mall-product、mall-inventory、mall-gateway（repo-1）；前端 mall-web（repo-2）
- target-user: 商城游客（主）与 MEMBER
- pain-points: M2 商城查询是半成品（价区 null、分类品牌仅后台接口、无库存聚合），mall-web 无真实浏览路径
- expected-value: 游客可经网关逛真实商城：首页→分类→列表→详情选 SKU→看价格与可售状态
- scope-in: 首页、公开分类树/品牌、列表分页筛选排序、详情 SKU 矩阵、批量可售状态聚合、完整异常空态
- scope-out: ES 全文搜索（M5）、收藏评论推荐、加购物车（CHG-0018）、下单支付

## 1. 背景

M2 建立了 Product/SKU/分类/品牌与库存的权威数据与后台管理，但消费者侧还“翻不过面来”：商城只读接口经网关 401、列表价区为 null、分类与品牌只有后台鉴权接口、库存没有面向商城的批量可售语义，mall-web 仍是 M0 骨架。CHG-0015 修复既有接口缺陷（401/ID/价区修复），本 Change 在其之上**新增消费者侧接口装配与页面**：公开分类树/品牌、列表排序、详情 SKU 矩阵、库存三态批量聚合，以及首页与全套 Loading/Empty/Error 状态。库存聚合由 mall-product 经服务间 Java API 调 mall-inventory 完成，浏览器只认 product 域，杜绝 N+1 与 internal 暴露。exploration §4 检测：与 CHG-0015 边界清晰（修缺陷 vs 加能力），与 CHG-0018 共享批量查询设计但不重复建设。

## 2. 用户价值

- 目标用户：游客（M3 浏览不强制登录）与会员；CHG-0018 购物车是批量商品/库存聚合的第二个消费者。
- 痛点摘要：商城无真实可逛路径；库存逐 SKU 查询会产生 N+1；下架/失效商品静默可见会把错误带进加购。
- 预期价值：用户无需注册即可完成选品决策；看到的价格是真实 SKU 价格（整数分）、可售状态来自实时库存（仅展示，交易校验在 M4）。

JTBD：

- 角色：游客；场景：When 我打开 mall-web, I want 看到真实新品与分类入口；价值：So that 我能快速开始逛商城。
- 角色：买家；场景：When 我按分类/品牌筛选并排序商品, I want 准确的分页与价区；价值：So that 我能在预算内找到目标商品。
- 角色：买家；场景：When 我在详情选择颜色/容量规格, I want 价格图片可售状态随 SKU 切换；价值：So that 我确认要买的具体 SKU 及其状态。

## 3. 功能范围

### 3.1 包含

- [S1] 商城首页：分类导航入口、新品/推荐商品区（首期新品=按上架/创建时间取前 N，推荐/热门取相同数据占位并标注）、Banner 位静态占位；全部真实数据；游客可访问。
- [S2] 公开分类树与品牌：GET /api/mall/categories/tree（仅启用、按排序返回有效树，禁用分类及其子树不展示）；GET /api/mall/brands（仅启用品牌，支持关键字/分页，首期可返回全量有效品牌列表供下拉）；网关匿名放行。
- [S3] 商品列表：分页（page/pageSize，pageSize ≤ 50）、分类筛选（含子孙分类）、品牌筛选（多选）、排序（default=综合、price_asc、price_desc、newest）；返回启用 SKU 聚合价区（整数分）、主图、名称；无启用 SKU/下架商品不返回。
- [S4] 商品详情与 SKU：详情含名称/主图与图集/品牌/分类/富文本介绍/SKU 矩阵（规格名→规格值→可组合 SKU）；规格选择定位唯一 skuId；切换 SKU 联动价格/图片/可售状态；下架商品详情 404/不可售；失效 SKU 不可选；明确加购目标是 skuId。
- [S5] SKU 可售状态聚合：mall-product 新增商城侧批量可售查询（一次传 ≤100 个 skuId），经内部契约调 mall-inventory 批量库存，按统一阈值映射 IN_STOCK / LOW_STOCK / OUT_OF_STOCK；供详情与购物车（内部消费）复用；不暴露精确数字到商城公开接口。
- [S6] 异常与空状态：商品不存在/已下架/SKU 失效/无库存/网络错误/空分类/空列表均有 Empty/Error 视图与 Loading；路由级 404 商品页。

### 3.2 不包含

- 全文检索/ES/复杂聚合筛选（M5）；关键词搜索首期不提供（或仅前端禁用入口）。
- AI 推荐、个性化、收藏、评论、营销、优惠券。
- 加购物车按钮的写操作（CHG-0018；本 Change 详情页可渲染按钮但登录/加购行为接 0018）。
- 库存精确数字对外展示、库存预警配置。

### 3.3 Story 拆分总表

| Story ID | 标题 | Scope 摘要 | 依赖 | 优先级 |
| --- | --- | --- | --- | --- |
| STORY-003-02-01-01 | 商城首页 | S1 + S6 首页部分：布局、分类入口、新品/推荐区、Banner 占位、异常态 | CHG-0015、S2 接口 | P0 |
| STORY-003-02-01-02 | 公开分类与品牌查询 | S2：categories/tree、brands 公开接口与网关放行 | CHG-0015 | P0 |
| STORY-003-02-02-01 | 商城商品列表 | S3 + S6 列表部分：分页/筛选/排序/价区/空态 | CHG-0015 | P0 |
| STORY-003-02-02-02 | 商品详情与 SKU 选择 | S4 + S6 详情部分：详情/SKU 矩阵/规格定位/联动/下架失效态 | S3、S5 | P0 |
| STORY-003-02-03-01 | SKU 可售状态聚合 | S5：批量三态查询，product→inventory 内部聚合，阈值统一 | CHG-0015 | P0（详情前置） |

## 4. 业务规则总纲

- [游客开放]：首页、分类树、品牌、列表、详情、可售状态全部匿名可访问；网关白名单显式枚举 GET 路径。
- [有效数据]：仅 status=启用/上架 的分类、品牌、商品、SKU 对外可见；禁用分类子树整棵不可见；无启用 SKU 的商品在所有商品位（首页/列表）不可见。
- [分类筛选]：按某分类筛选时包含其全部后代分类下商品。
- [排序]：default（综合=上架时间倒序兜底）、price_asc/desc（按 minPrice）、newest（上架时间倒序）；非法排序参数回落 default 并忽略未知参数。
- [价区与金额]：minPrice/maxPrice 来自启用 SKU 价格 MIN/MAX，整数分；任何商城金额字段禁止浮点。
- [SKU 矩阵]：服务端返回规格维度与 SKU 索引（specKey 组合 → skuId/price/image/status）；前端禁用不存在或失效组合；选中组合必须解析到唯一 skuId。
- [库存三态]：available=0 → OUT_OF_STOCK；0 < available < 阈值 N → LOW_STOCK；≥ N → IN_STOCK；N 本期为常量 10（product 配置类常量，购物车共用同口径）；只返回三态不返回数字。
- [聚合约束]：批量可售接口单次 ≤100 skuId；product→inventory 一次批量调用，禁止循环单查；inventory 不可用时可售接口降级为 UNKNOWN/503（设计定，整车浏览不可长时间白屏）。
- [ID 约定]：所有 ID 字符串到端（CHG-0015）。
- [图片]：主图/图集返回完整可访问 URL（MinIO 基址由配置拼接）；无图使用统一占位图。

## 5. 全局验收标准

| ID | 验收标准（可测试） | 备注 |
| --- | --- | --- |
| AC-001 | 匿名经网关访问首页数据接口 → 200，返回分类入口与新品/推荐商品（真实数据，非 Mock） | S1 |
| AC-002 | 首页商品区仅含上架且有启用 SKU 的商品；空数据时显示空态而非报错 | S1/S6 |
| AC-003 | GET /api/mall/categories/tree 匿名 200，仅含启用分类且为树形排序；禁用分类及其子树不出现 | S2 |
| AC-004 | GET /api/mall/brands 匿名 200，仅启用品牌，支持关键字过滤 | S2 |
| AC-005 | 分类树/品牌接口经外部直接访问 internal 路径不可达（沿用 CHG-0015 隔离） | S2 安全 |
| AC-006 | 商品列表分页正确：page/pageSize 生效，total/页数准确，pageSize>50 被收敛或 400 | S3 |
| AC-007 | 分类筛选包含后代分类商品；品牌多选筛选正确；条件组合取交集 | S3 |
| AC-008 | 排序 price_asc/price_desc/newest/default 结果顺序正确；非法参数回落 default | S3 |
| AC-009 | 列表 records 含 id（字符串）、名称、主图、minPrice/maxPrice（真实整数分，无 null） | S3 |
| AC-010 | 下架商品与无启用 SKU 商品在列表与首页均不返回 | S3/S1 |
| AC-011 | 商品详情匿名 200，含图集/品牌名/分类路径/富文本介绍/规格维度/SKU 索引 | S4 |
| AC-012 | 选择规格组合能定位唯一 skuId；切换时价格/图片/可售状态随该 SKU 联动 | S4 |
| AC-013 | 不存在/已下架商品直访详情 → 明确 404/不可售页，不泄露可加入购物车入口 | S4/S6 |
| AC-014 | 失效/禁用 SKU 的规格组合不可选中；可售状态为 OUT_OF_STOCK 的 SKU 有明确缺货标识 | S4/S5 |
| AC-015 | 批量可售接口一次传多个 skuId（≤100）返回各 SKU 三态；后端日志显示仅一次 inventory 调用（无 N+1） | S5 |
| AC-016 | 三态阈值正确：available=0 缺货、<10 库存不足、≥10 有货；公开响应不含精确库存数字 | S5 |
| AC-017 | inventory 不可用时可售状态优雅降级（UNKNOWN 或可重试提示），商城页不白屏 | S5/S6 |
| AC-018 | 空分类、空筛选结果、网络错误、加载中分别有 Empty/Error/Loading 视图 | S6 |
| AC-019 | mall-web 首页/列表/详情路由游客可直接访问；build/lint/type-check 通过 | 端到端 |
| AC-020 | 全链路金额字段均为整数分（列表价区/SKU 价格），前端无浮点金额解析 | 金额 |

## 6. 非功能需求

- 性能：列表 P95 < 300ms（价区聚合一条 SQL）；详情 P95 < 300ms；批量可售（100 SKU）P95 < 200ms。
- 安全：公开接口白名单制；无 internal 泄漏；不返回未发布数据。
- 兼容：UnifyResult 包装；ID 字符串；与 mall-admin 商品后台共用数据层不共用 DTO。
- SEO/前端：首期 SPA，路由懒加载；图片懒加载。

## 7. 成功指标

- Integration Gate 场景一（游客：首页→分类→列表→详情→选 SKU→看价格库存）一次走通并留证。
- 商品列表/详情接口零 N+1（评审 + 日志实证）。
- mall-web 类型检查零 any 逃逸到商品域模型；金额相关缺陷为零。
