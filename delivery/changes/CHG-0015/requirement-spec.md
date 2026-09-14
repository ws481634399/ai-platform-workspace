# Requirement Spec（需求级产品规格）

> 层级：Requirement 级产物——针对本次需求/Change（多 Story 统一一份）
> 业界锚点：PRD（Problem → Goals/Metrics → Scope → Requirements → AC）
> 输入：CHG Context（exploration.md + requirement.md）
> 产出状态：specified
> 分层关系：本文是 Requirement 级；Story 边界见各 Story 目录 story-spec.md。

## 0. 元信息

- Change ID: CHG-0015
- Requirement: REQ-M3-READY M3 前置就绪修复
- 状态流转: exploring → specified
- 主要服务: mall-common / mall-gateway / mall-product / mall-inventory / mall-contracts（repo-1）；mall-admin 回归（repo-2）
- target-user: M3 后续开发方与商城端消费者（间接受益）
- pain-points: 网关 401、内部调用无凭证、分页 total=0、Long ID 精度丢失、列表价区为 null
- expected-value: M3 联调前两条链路（浏览器→网关→商品、服务→服务）可信
- scope-in: 统一字符串 ID 序列化、网关公开路由、内部服务凭证、库存分页修复、价区与有效 SKU 过滤
- scope-out: 新增公开分类/品牌/批量库存接口（CHG-0017）、会员/购物车功能、ES/MQ

## 1. 背景

M2（CHG-0010~0014）交付了分类品牌、商品 SKU、发布查询与库存核心能力，但 M3 商城侧联调前存在五类已实证的缺口（M3.md 文末“注意点”与“三个现实阻塞”）：经网关访问 `GET /api/mall/products` 返回 401（直连正常）；库存服务调商品内部接口无服务凭证导致初始化误报“SKU 不存在”；库存分页返回 33 行但 total=0；Snowflake ID（2099488396675276801）超出 JS 安全整数被浏览器解析为 2099488396675276800；商品列表 minPrice/maxPrice 固定 null 且无有效 SKU 的商品仍可见。

这些缺陷跨多个既有服务，若分散在 M3 各功能 Change 中修复，会造成商城页面与购物车联调反复被 M2 问题阻塞。参照 CHG-0014（M0-M2 验收缺口补全）先例，本 Change 作为 M3 前置就绪检查单独先行，只修复既有接口缺陷与跨切面契约，不实现 M3 新功能。exploration §4 冲突检测：与 specs 无冲突；沿用 CHG-0012/0013 契约，不改业务语义。

## 2. 用户价值

- 目标用户：直接用户是 M3 各功能开发方（CHG-0016/17/18）与 mall-web/mall-admin；最终受益是商城游客与 MEMBER。
- 痛点摘要：ID 精度错误会导致加购传错 skuId（静默资损级）；网关 401 使公开页面无数据；内部凭证缺失阻断库存初始化；分页 total 错误破坏分页组件；价区缺失使列表无法展示价格。
- 预期价值：M3 开工时两条基础链路一次打通——匿名浏览器经网关读商品可信、服务间凭契约互调可信；全平台业务 ID 以字符串到端，金额统一整数分。

JTBD：

- 角色：mall-web 游客页面；场景：When 我经网关匿名访问商品列表, I want 拿到与直连一致的真实数据且 ID 不丢精度；价值：So that 浏览、详情、加购全链路引用的 skuId 正确。
- 角色：mall-inventory；场景：When 初始化库存需要校验 SKU, I want 以 SERVICE 身份调用商品内部契约；价值：So that 真实 SKU 被正确识别，浏览器无法绕过网关直访 internal。
- 角色：M3 开发者；场景：When 在 M3-dev 分支开发新功能, I want 既有 M2 接口契约稳定可信；价值：So that 联调不被基础设施级缺陷打断。

## 3. 功能范围

### 3.1 包含

- [S1] 业务 ID 统一字符串序列化：在 mall-common 提供统一 Jackson Long→String 出参策略（可配开关/注解），改造 product/inventory 现有对外 DTO（商品、SKU、分类、品牌、库存记录、分页包装内 ID）；入参兼容字符串与数字；mall-admin 既有页面 ID 类型回归为 string。
- [S2] 网关商城公开路由：显式匿名放行**已存在**的商城只读接口（GET /api/mall/products、GET /api/mall/products/{id} 等）；`/api/internal/**` 仅服务间可达，外网 404/403；会员私有路由保持认证。
- [S3] 服务间内部凭证：为服务间调用补齐 SERVICE 主体凭证（内部请求头/令牌，网关注入或服务直连互信），库存→商品 SKU 校验携带凭证；修复 API 初始化库存误报“SKU 不存在”。
- [S4] 库存分页修复：定位并修复分页返回数据行正常但 total=0 的缺陷（count SQL/分页插件用法），后台库存列表分页 total 与实际一致。
- [S5] 商品列表价区与有效 SKU 过滤：既有商城列表接口返回每个商品启用 SKU 的 minPrice/maxPrice（整数分）；过滤无启用 SKU 的商品；金额禁止浮点数。

### 3.2 不包含

- 新增 `GET /api/mall/categories/tree`、`GET /api/mall/brands`、排序参数、批量 SKU 可售状态、详情库存聚合（CHG-0017）。
- 会员注册登录/资料/地址（CHG-0016）、购物车（CHG-0018）。
- Elasticsearch、RocketMQ、分布式锁；全局限流/防刷体系。
- mall-web 新页面（本 Change 只保证接口层就绪）。

### 3.3 Story 拆分总表

| Story ID | 标题 | Scope 摘要 | 依赖 | 优先级 |
| --- | --- | --- | --- | --- |
| STORY-002-03-02-01 | 商城商品列表与详情查询（M3 就绪修复） | S1~S5 全部：跨切面字符串 ID、网关放行、服务凭证、库存分页、价区/有效 SKU；mall-admin 回归 | M2 已交付能力 | P0 |

本 Change 为缺口补全类，沿用既有 Story 绑定（同 CHG-0014 模式），不新增产品 Story；S1~S5 在同一 Story 内按修复项交付与验收。

## 4. 业务规则总纲

- [ID 序列化范围]：所有**对外 REST** JSON 中的业务标识（productId/skuId/categoryId/brandId/inventoryId/分页及嵌套对象中的同源 ID）输出为字符串；后端内部领域模型与数据库仍为 bigint/long。
- [入参兼容]：接口入参中的 ID 同时接受字符串与数字（Jackson 可反序列化字符串到 Long），避免改造期间前后端错配。
- [网关放行最小化]：只匿名放行明确枚举的商城 GET 只读路径；写操作与 /api/mall/cart、/api/mall/members/me 等私有资源必须认证；`/api/internal/**` 从外网路径拒绝。
- [服务凭证]：服务间调用携带可校验的 SERVICE 凭证；内部接口拒绝无凭证的外部请求；凭证不落地浏览器。
- [分页正确]：任何分页响应 total 为满足筛选条件的总记录数，与当前页数据行同源同条件。
- [价区]：minPrice = 该商品启用状态 SKU 价格最小值，maxPrice = 最大值；单位分（整数）；无启用 SKU 的商品不出现在商城列表/首页商品位。
- [回归保护]：mall-admin 商品/SKU/分类/品牌/库存页面在字符串 ID 改造后 CRUD、分页、跳转全部正常。

## 5. 全局验收标准

| ID | 验收标准（可测试） | 备注 |
| --- | --- | --- |
| AC-001 | 经网关（8080）匿名 GET /api/mall/products 返回 200 与商品数据，无需 Token | S2 阻塞一 |
| AC-002 | 经网关匿名 GET /api/mall/products/{id} 返回 200；不存在/下架返回明确 404/不可售 | S2 |
| AC-003 | 浏览器/外部直接请求 /api/internal/** 被拒绝（403/404） | S2/S3 |
| AC-004 | mall-inventory 调商品内部接口初始化真实 SKU 库存成功，不再误报“SKU 不存在” | S3 阻塞二 |
| AC-005 | 库存后台分页查询：返回 33 行场景 total=33，翻页 total 恒定且与筛选一致 | S4 阻塞三 |
| AC-006 | 商品列表每个商品的 id 为 JSON 字符串（如 "2099488396675276801"），前端 JS 解析不丢精度 | S1 |
| AC-007 | 商品/SKU/分类/品牌/库存对外接口的全部业务 ID 均为字符串；嵌套对象与分页内一致 | S1 |
| AC-008 | 接口入参传字符串 ID（"123"）与数字 ID（123）均能正确处理 | S1 兼容 |
| AC-009 | 商品列表 minPrice/maxPrice 为启用 SKU 的真实最低/最高价，整数分，无 null | S5 |
| AC-010 | 无启用 SKU 的商品不出现在商城列表；全部 SKU 禁用后该商品从列表消失 | S5 |
| AC-011 | mall-admin 商品/SKU/分类/品牌/库存页面列表、详情、编辑、分页、跳转功能不回归 | S1 回归 |
| AC-012 | mall-web 经网关拿到的 skuId 原样回传（加购预演）与后端记录一致，无末位偏差 | S1 端到端 |

## 6. 非功能需求

- 安全：公开路由默认拒绝、白名单显式枚举；internal 隔离；服务凭证不出网关。
- 兼容：改造期入参双形态兼容；统一返回结构 UnifyResult 不变。
- 性能：序列化策略与价区聚合不得使列表 P95 恶化超过 20%（价区聚合用一条分组 SQL，禁止 N+1）。
- 可维护：序列化策略在 mall-common 一处实现，各服务只引用不自定义。

## 7. 成功指标

- 三个现实阻塞（401/误报 SKU 不存在/total=0）在修复后零复现，并在 evidence 留网关实测与接口实测记录。
- 全仓对外 DTO 抽查 Long 类型零遗漏（grep 白名单说明）。
- M3 后续 Change 联调不因上述五类问题产生阻塞工单（本期以 CHG-0016/17/18 开发过程零回改本项为观察口径）。
