# Exploration（需求探索报告）

> 阶段：sdd-explore 产物
> 业界锚点：Discovery 文档（Problem → Evidence → Conflict → Recommendation）
> 输入：requirement.md（原文沉淀；本文件不复述原文，只做分析）
> 产出状态：exploring（推进 Change 状态）

## 1. 需求要点

- 做什么：在 M3 功能开发前，集中修复 M2 遗留的 5 类阻塞性缺口，让“浏览器 → 网关 → 商品/库存”与“服务 → 服务”两条链路在 M3 开工前可信。
- 给谁：M3 全部后续 Change（CHG-0016/17/18）的开发者与 mall-web/mall-admin 前端；最终受益者是商城游客与 MEMBER。
- 解决什么问题：
  - 精度问题会让购物车/详情把 skuId 传错，属于**静默资损级**缺陷，必须在 M3 前以统一机制收敛，禁止各 DTO 零散加注解；
  - 网关 401 使商城公开页面无法获取数据；
  - 内部调用无凭证使库存初始化误判，违背 M2 已定的“SKU 存在性走契约校验”；
  - 分页 total 错误直接破坏前端分页；
  - 价格区间为 null 使商品列表无法展示价格，且“无有效 SKU 商品上架可见”违反商城可售语义。
- 隐含需求：
  - Long→String 必须在 mall-common 提供可复用序列化器/配置（Jackson `ToStringSerializer` 或等价方案），并区分**对外 REST** 与**内部契约/请求入参**：出参字符串化避免精度丢失，入参能同时接受字符串/数字以保持兼容；
  - 字符串化后 mall-admin 既有页面（商品、SKU、分类、品牌、库存、管理员等）的 ID 比较、路由参数、提交体必须回归通过；
  - 网关放行规则须显式列举商城公开路径（GET /api/mall/products/** 等），`/api/internal/**` 只接受服务间凭证，浏览器不可达；
  - 服务间认证需与 M1 已建立的 SubjectType=SERVICE / SecurityContext 体系一致，不能新造一套；
  - 金额坚持整数分（M2 已立约束），价格区间取启用 SKU 聚合，无启用 SKU 的商品从商城列表/首页排除。

知识检索结果（引用来源）：

- M3.md 文末注意点 1/4/5 与“三个现实阻塞”（本 Change 的直接依据，已归档 references/M3.md）。
- `product/04-子域与限界上下文.md`：BC-01 身份上下文“商城令牌和后台令牌必须区分”、网关统一认证传播（M1 已交付 Gateway 认证）；BC-03 商品上下文为商品/SKU 权威。
- `product/10-API与事件契约.md`：内部接口与公开接口分层，内部能力不直接暴露浏览器。
- CHG-0014（M0-M2 验收缺口补全）已确立“缺口补全类 Change 单独先行、fast profile、绑定既有 Story”的先例，本 Change 沿用。

## 2. Story 归属判定

- 本 Change 不新增产品能力，不新增 Story，沿用既有 Story 归属（与 CHG-0014 同模式）。
- 主绑定 Story: STORY-002-03-02-01（商品与库存 → 商品发布与商城查询 → 商城查询 → 商城商品列表与详情查询），覆盖网关商城路由与列表价格/有效 SKU 过滤。
- 关联既有 Story（不新增节点，在 PRD 任务中体现跨 Story 缺口）：
  - STORY-002-04-01-01（库存初始化与查询）：内部调用凭证、分页 total；
  - STORY-001-01-03-03（在 Gateway 验证并传播身份）：网关公开路由放行与内部路由隔离；
  - 字符串 ID 序列化为跨切面工程基线，落在 mall-common，受益方含全部既有与 M3 新增对外 DTO。
- 是否新建 candidate: 否。
- Feature 路径: 商品与库存 → 商品发布与商城查询 → 商城查询 → 商城商品列表与详情查询。

## 3. 证据评估

- 证据类型与来源：
  - 实测阻塞：网关 /api/mall/products 401（直连正常）、库存初始化误报“SKU 不存在”、库存分页 33 行但 total=0（M3.md 记录的现场）；
  - 数据实证：商品 ID 2099488396675276801 在浏览器显示为 2099488396675276800；
  - 代码实证：MallProductDtos 的 ID 仍为 long、MallProductController 列表 minPrice/maxPrice 固定 null（M3.md 中已点名文件）；
  - 工程底座：M1 已交付多主体隔离（GUEST/MEMBER/ADMIN/SERVICE）、Gateway 认证传播、统一 SecurityContext；M2 已交付金额整数分与内部 SKU 契约。
- 结论: 充分（每个缺口都有实测或代码实证，修复方向与既有架构约束一致）。

## 4. 冲突点检测

- 与 product/specs/ 规则冲突: 无。
- 与既有 Change 重叠或沿用: 沿用 CHG-0012 商城查询契约与 CHG-0013 库存查询能力（修复其遗留缺陷，不改变业务语义）；沿用 CHG-0014 的缺口修复 Change 模式。无功能范围重叠。
- 与已规划 Story 重复: 无新增 Story，不重复。
- 处理决策:
  - ID 字符串化采用“统一序列化策略 + 既有 DTO 回归”，不在本 Change 重写业务接口；
  - 新增公开接口（分类树/品牌/批量库存）不纳入本 Change，归 CHG-0017，避免缺口修复与新功能耦合；
  - 服务间凭证方案若发现 M1 SERVICE 主体能力尚未落地实现（仅有模型设计），则在本 Change 一并补齐最小实现（内部接口鉴权过滤器/拦截器 + 网关 internal 路径隔离），并在 PRD 明确。

## 5. 待澄清问题

- Long→String 的技术落点（全局 Jackson 配置 vs 自定义注解标记 vs 封套 JsonSerializer）与“入参兼容字符串/数字”的具体策略，需 design 结合 mall-common 现有 web 模块确认。
- 网关公开路由清单的精确枚举（products 详情/列表、categories/tree、brands 是否在本 Change 预埋放行规则）需 PRD 与 CHG-0017 接口设计对齐；建议本 Change 只放行**已存在**的公开接口，新接口随 CHG-0017 同步加规则。
- 服务间凭证形态（mTLS / 内部 Token / 网关层 X-Internal 头 + Nacos 网络隔离）需 design 选定；M3 本地开发环境以“网关拒绝 /api/internal/** 外网访问 + 服务间共享内部凭证”为最小可行。
- 库存分页 total=0 的根因（MyBatis 分页插件 count SQL / wrapper 用法）需 dev 阶段定位实证。
