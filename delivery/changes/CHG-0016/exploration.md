# Exploration（需求探索报告）

> 阶段：sdd-explore 产物
> 业界锚点：Discovery 文档（Problem → Evidence → Conflict → Recommendation）
> 输入：requirement.md（原文沉淀；本文件不复述原文，只做分析）
> 产出状态：exploring（推进 Change 状态）

## 1. 需求要点

- 做什么：在 M1 统一认证底座上补齐消费者侧身份闭环——MEMBER 用户名密码注册/登录/刷新/退出、MEMBER 与 ADMIN 严格隔离、事件幂等初始化会员资料、会员资料与头像维护、收货地址全量管理，mall-web 建立统一会员登录态。
- 给谁：商城消费者（自助注册使用）；下游 CHG-0018 购物车与 M4 订单（依赖可信 memberId 与默认地址）。
- 解决什么问题：M1 只交付了 ADMIN 身份与 RBAC，商城侧没有可登录的消费者主体；M3 需要把“游客 → 会员”链路打通，并把 Identity（凭据）与 Member Profile（业务资料）的边界从第一天立住，避免后期合并域的返工。
- 隐含需求：
  - 首期注册方式已经明确（用户名+密码，手机/邮箱是资料字段，验证码延后），PRD 仍需钉死用户名/密码规则与错误文案；
  - 注册是跨 mall-identity / mall-member 两个数据库的流程，**禁止跨库事务与跨服务写表**，必须“事件 + 幂等初始化 + 失败重试/补偿”；
  - 密码安全：BCrypt（或 M1 同款编码器）哈希、不存明文、日志脱敏；注册失败不留半成品；
  - 隔离要在三层同时成立：Token claim subjectType、Gateway/服务端鉴权、前端入口（MEMBER 不能进 mall-admin 后台接口）；
  - 地址安全是“认证 + 资源归属”两层：所有地址操作从 SecurityContext 取 memberId，不信任路径/Body 中的 memberId；越权返回 404 或 403（design 定，建议 404 减少资源枚举）；
  - 默认地址唯一需要服务端事务保证（设新默认 → 旧默认复位），不能靠两次请求的顺序巧合；
  - mall-web Token 逻辑统一收敛（刷新恢复、并发刷新、401 处理可借鉴 mall-admin M1 已交付的串行刷新模式）。

知识检索结果（引用来源）：

- `product/04-子域与限界上下文.md` §7 BC-01：商城身份接口候选 `POST /api/auth/member/login|refresh|logout`；“商城令牌和后台令牌必须区分”；身份上下文可消费 MemberRegisteredIntegrationEvent；§8 BC-02：会员上下文拥有 member/member_profile/shipping_address，接口候选 `/api/mall/members/me`、`/api/mall/shipping-addresses*`；规则“会员只能访问自己的资料、每个会员最多一个默认地址、删改地址不影响历史订单”。
- `product/06-聚合与领域模型设计.md` §6：Member 聚合（MemberId/MemberAccountId/MemberStatus，register 行为，MemberRegistered 领域事件）；ShippingAddress 为独立聚合（避免 Member 聚合过大，默认地址由应用服务协调）。
- `product/05-上下文映射图.md`：身份 ↔ 会员为防腐/事件协作，非互写数据库。
- M3.md 文末注意点 2（注册方式定稿）、3（一致性定稿）——用户明确决策，见 requirement.md。

## 2. Story 归属判定

- Feature ID: FEAT-003-01（商城前台 → 商城会员）
- Story 节点（本次新建 4 个）：
  - STORY-003-01-01-01 商城会员注册（FEAT-003-01-01 会员注册与认证）
  - STORY-003-01-01-02 商城会员登录与会话（FEAT-003-01-01 会员注册与认证）
  - STORY-003-01-02-01 会员资料维护（FEAT-003-01-02 会员资料）
  - STORY-003-01-03-01 收货地址管理（FEAT-003-01-03 收货地址）
- 是否新建 candidate: 否（FEAT-003 商城前台为本次新建正式 L1，归属经用户确认）。
- Feature 路径: 商城前台 → 商城会员 → 会员注册与认证/会员资料/收货地址 → 对应 Story。

## 3. 证据评估

- 证据类型与来源：
  - 业务依据：M3.md REQ-M3-001 验收标准 14 条 + 文末注意点 2/3（注册方式、一致性为用户明确决策）；
  - 领域依据：product/04 §7/§8 上下文边界与接口候选、product/06 §6 Member/ShippingAddress 聚合；
  - 工程底座：M1 双 Token/多主体/Gateway/SecurityContext 已 delivered；mall-identity、mall-member 独立服务骨架存在；MinIO 基础设施 M0 就绪；CHG-0015 先行修复字符串 ID 与网关路由。
- 结论: 充分（注册方式等原需求中最大的模糊点已由文末注意点明确；剩余为 design 级技术选择）。

## 4. 冲突点检测

- 与 product/specs/ 规则冲突: 无（specs/ 为空，不冲突）。
- 与既有 Change 重叠或沿用:
  - 沿用 M1（CHG-0005/0006 等）认证机制：MEMBER 登录走同一套 Token 签发/刷新/撤销，仅 subjectType/账号体系不同；
  - 与 CHG-0015 强依赖：网关公开路由（注册登录放行）、字符串 ID 必须先就绪；
  - 与 CHG-0018 协作：购物车只依赖本 Change 的注册/登录与可信 memberId；地址与购物车可并行，按用户确认的推荐顺序地址不阻塞购物车。
- 与已规划 Story 重复: 无（商城会员为 FEAT-003 全新分支；M1 的 FEAT-001 节点均为后台 ADMIN 语义）。
- 处理决策:
  - 注册与登录拆为两个 Story（注册含事件初始化 Profile；登录含会话/隔离/mall-web 登录态），资料、地址各一个 Story；
  - 事件机制 M3 不引入 RocketMQ（项目既定 M7）：design 在“本地事件表 + 同步内部调用重试 + 登录懒补偿”等无 MQ 方案中选型，PRD 先钉死验收语义（注册成功可登录；Profile 最终必被初始化；重复事件不重复建资料；无跨库事务）。

## 5. 待澄清问题

- 密码策略与用户名规则的具体阈值（建议：用户名 4-20 位字母数字下划线；密码 ≥8 位含字母与数字；与 M1 admin 引导密码 ≥12 位的差异需说明）由 PRD 定稿。
- 登录失败安全策略首期范围：仅校验账号状态（启用/禁用）+ 不透露“用户名不存在/密码错误”差异，还是做失败次数锁定？建议首期做账号状态 + 统一错误文案，锁定计数列入 P1。
- 事件落地方案（outbox-lite 定时重试 / 同步调用 + 登录懒补偿 / Spring 本地事件仅同进程不适用跨服务）需 design 选定；注意注册接口是同步返回成功的，Profile 初始化失败不能让用户看到“注册失败”但账号已建的不一致体验，需定义重试与查询兜底。
- 默认地址删除策略：建议“删除默认后无默认（用户重新指定）”，需 PRD 确认；自动选最近地址为备选。
- 头像上传：后端代理上传 vs 预签名 URL 前端直传 MinIO，design 结合本地 MinIO 与 mall-system 文件能力现状选定。
- mall-web 登录/注册页面与个人中心的交互（登录后回跳、路由守卫白名单）在 design/前端任务细化。
