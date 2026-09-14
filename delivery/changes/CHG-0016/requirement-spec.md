# Requirement Spec（需求级产品规格）

> 层级：Requirement 级产物——针对本次需求/Change（多 Story 统一一份）
> 业界锚点：PRD（Problem → Goals/Metrics → Scope → Requirements → AC）
> 输入：CHG Context（exploration.md + requirement.md）
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0016
- Requirement: REQ-M3-001 商城会员与地址
- 状态流转: exploring → specified
- 主要服务: mall-identity、mall-member（repo-1）；前端 mall-web（repo-2）
- target-user: 商城消费者（游客→MEMBER）；下游 M4 订单与 CHG-0018 购物车
- pain-points: M1 只有 ADMIN 身份，商城无可注册登录的消费者主体；资料与地址能力缺失
- expected-value: 打通游客→会员闭环，可信 memberId 供购物车/订单使用
- scope-in: 用户名密码注册/登录/刷新/退出、Token 隔离、事件初始化 Profile、资料与头像、地址全量管理、mall-web 统一登录态
- scope-out: 验证码注册登录、通知服务、RBAC、购物车、订单、积分等级

## 1. 背景

M1 已交付统一身份认证底座：Access/Refresh Token、SubjectType（GUEST/MEMBER/ADMIN/SERVICE）、Gateway 认证、统一 SecurityContext，但落地的主体只有 ADMIN（后台管理员 + RBAC）。M3 要把消费者侧链路跑通，第一个前置就是 MEMBER 主体：注册、登录、资料、地址。

需求必须同时守住两条边界：其一是 Identity ≠ Member Profile——mall-identity 拥有凭据/会话/锁定，mall-member 拥有昵称/头像/地址，禁止 mall-member 再存密码；其二是注册跨 mall-identity 与 mall-member 两个数据库，禁止跨库事务，必须“Identity 创建成功 → 事件 → Profile 幂等初始化 → 失败可重试/补偿”。M3.md 文末注意点已替本阶段拍板两个原需求中的悬置项：首期仅用户名+密码注册/登录（手机/邮箱是资料字段，验证码延后）；接受注册后短暂最终一致。exploration §4 检测：与 product/04 §7/§8、product/06 §6 领域模型完全同向，无冲突。

## 2. 用户价值

- 目标用户：商城消费者；下游 CHG-0018 购物车与 M4 订单（消费可信 memberId、默认地址）。
- 痛点摘要：没有消费者账号体系，商城个性化与交易前置全部无法开始；跨库注册的一致性处理不当会产生“能登录但无资料”或“重复资料”的脏数据。
- 预期价值：游客可自助成为会员并安全管理个人数据；MEMBER/ADMIN 严格隔离；地址等私有资源后端强制归属校验。

JTBD：

- 角色：游客；场景：When 我想用商城完整能力, I want 用用户名密码快速注册并立即登录；价值：So that 我有可持续的会员身份且无需等待验证码。
- 角色：MEMBER；场景：When 我在 mall-web 浏览或切设备, I want 登录态自动刷新/恢复并安全退出；价值：So that 会话不意外丢失也不被他人冒用。
- 角色：MEMBER；场景：When 我管理昵称头像与收货地址, I want 只看到和改到自己的数据；价值：So that 个人信息准确且不被越权访问。

## 3. 功能范围

### 3.1 包含

- [S1] 会员注册：用户名+密码注册；用户名唯一；密码 BCrypt 哈希、不存明文、日志脱敏；注册成功创建 Identity 并发布注册事件；Profile 按 memberId 幂等初始化，失败重试/登录懒补偿；注册接口原子失败不留半成品 Identity（用户名冲突前置校验 + 唯一约束兜底）。
- [S2] 会员登录与会话：用户名+密码登录签发双 Token（subjectType=MEMBER）；Refresh 轮换；退出撤销；MEMBER/ADMIN Token 双向隔离（MEMBER Token 访问 /api/admin/** 拒绝，反之同理）；账号禁用拦截；统一错误文案不区分“用户不存在/密码错误”；mall-web 统一登录态（memberId、Token、会员信息、刷新恢复、并发 401 串行刷新、退出清理）。
- [S3] 会员资料：查看/修改昵称、头像（MinIO 上传）、性别等基础信息；手机号/邮箱作为资料字段可维护（不做验证）；修改密码入口归 mall-identity。
- [S4] 收货地址：地址列表、新增、修改、删除、设置默认、查询默认；字段 receiverName/receiverPhone/province/city/district/detailAddress/postalCode/isDefault；后端从 SecurityContext 取 memberId 并强制 `Address.memberId == currentMemberId`；默认地址唯一（设新默认事务内复位旧默认）；删除默认后无默认（用户重新指定）；地址数量上限 20。

### 3.2 不包含

- 短信/邮件验证码注册登录、通知服务、找回密码流程（后续阶段；本期可预留接口位不实现）。
- 登录失败次数锁定/滑块验证（P1，本期仅账号状态校验 + 统一文案）。
- 会员等级、积分、成长值、收藏、浏览记录。
- 购物车（CHG-0018）、订单地址快照（M4）。

### 3.3 Story 拆分总表

| Story ID | 标题 | Scope 摘要 | 依赖 | 优先级 |
| --- | --- | --- | --- | --- |
| STORY-003-01-01-01 | 商城会员注册 | S1：注册接口、唯一校验、哈希、事件与 Profile 幂等初始化/补偿 | CHG-0015 | P0 |
| STORY-003-01-01-02 | 商城会员登录与会话 | S2：登录/刷新/退出、双向隔离、账号状态、mall-web 登录态与 401 | STORY-003-01-01-01 | P0 |
| STORY-003-01-02-01 | 会员资料维护 | S3：资料查询修改、头像 MinIO、手机邮箱资料字段、个人中心页 | STORY-003-01-01-02 | P0 |
| STORY-003-01-03-01 | 收货地址管理 | S4：地址 CRUD/默认/查询默认、资源归属、默认唯一、上限 | STORY-003-01-01-02 | P0（可与 S3 并行） |

## 4. 业务规则总纲

- [用户名规则]：4–20 位，字母/数字/下划线，字母开头；全局唯一（大小写不敏感归一存储）；注册后不可改（本期）。
- [密码规则]：8–32 位，至少含字母与数字；BCrypt 强度与 M1 管理员编码器一致；任何日志/响应不得出现明文密码。
- [注册原子性]：Identity 记录创建与凭据写入在 mall-identity 单库事务内完成；失败整体回滚，不存在无凭据 Identity。
- [Profile 一致性]：注册事务成功后发布 MemberRegistered（memberId/username/nickname 初始值/occurredAt/eventId）；mall-member 按 eventId 与 memberId 双幂等消费，重复事件不重复建资料；初始化失败可由重试任务与“登录时检测缺资料即补偿初始化”两条路径兜底；无跨库事务、无跨服务写表。
- [登录凭据校验]：用户名归一后查询；统一返回“用户名或密码错误”；账号状态非启用拒绝（文案“账号已禁用”）；成功签发 accessToken/refreshToken，claim 含 subjectType=MEMBER 与 memberId（字符串）。
- [Token 隔离]：服务端鉴权同时校验 subjectType 与路径域：/api/admin/** 仅 ADMIN，/api/mall/members/**、/api/mall/cart/** 等仅 MEMBER；越界返回 403。
- [资料归属]：所有会员资料与地址操作以 SecurityContext.memberId 为唯一归属来源，请求体中的 memberId 字段一律忽略；访问他人地址返回 404（不暴露资源存在性）。
- [地址校验]：receiverName 1–32 字；receiverPhone 中国大陆手机号格式；省/市/区与详细地址必填（1–128 字）；postalCode 可选（6 位数字）；每会员地址 ≤ 20 条，超限拒绝。
- [默认地址]：设置默认在单事务内“清旧默认 → 设新默认”；新增第一条地址自动为默认；删除默认地址后该会员无默认地址；查询默认无则返回空（不报错）。
- [头像]：图片上传走 MinIO，单文件 ≤ 2MB，仅图片类型；资料存对象 key/URL；鉴权与 Bucket 策略沿用基础设施配置。

## 5. 全局验收标准

| ID | 验收标准（可测试） | 备注 |
| --- | --- | --- |
| AC-001 | 有效用户名+密码注册 → 200/201，可立即登录；响应与日志无明文密码 | S1 |
| AC-002 | 重复用户名注册（含大小写变体）→ 409/业务错误“用户名已存在”，不产生第二条 Identity | S1 唯一 |
| AC-003 | 用户名不合规（<4 位/数字开头/非法字符）与密码不合规（<8 位/纯数字）→ 400 且字段级提示 | S1 规则 |
| AC-004 | 注册成功后 mall-member 存在对应 Member Profile；memberId 与 Identity 一致；昵称为系统默认值 | S1 事件 |
| AC-005 | 同一注册事件重放两次 → 仅一份 Profile，无异常、无重复数据（幂等） | S1 幂等 |
| AC-006 | 模拟 Profile 初始化失败后重试/首次登录 → Profile 被补偿创建，用户可正常使用资料接口 | S1 补偿 |
| AC-007 | 注册流程任一步失败 → 不存在半成品 Identity/Profile，再次以同用户名可重新注册 | S1 原子 |
| AC-008 | 正确凭据登录 → 返回 accessToken/refreshToken，Token 解析 subjectType=MEMBER、sub=memberId（字符串） | S2 |
| AC-009 | 错误密码/不存在用户 → 统一“用户名或密码错误”，文案不可区分 | S2 |
| AC-010 | 禁用会员登录 → 拒绝并提示账号禁用 | S2 状态 |
| AC-011 | 有效 refreshToken 换新双 Token；旧 refreshToken 轮换失效；过期/伪造 refresh → 401 | S2 刷新 |
| AC-012 | 退出后 access/refresh 失效，再访问私有接口 401 | S2 退出 |
| AC-013 | MEMBER Token 调 /api/admin/** → 403；ADMIN Token 调 /api/mall/members/me → 403 | S2 隔离 |
| AC-014 | mall-web 登录后刷新页面登录态恢复；access 过期时并发请求只触发一次刷新并自动重放 | S2 前端 |
| AC-015 | mall-web 401（刷新也失败）统一清理登录态并跳转登录页，登录后回跳原页面 | S2 前端 |
| AC-016 | GET /api/mall/members/me 返回本人资料（memberId 字符串、昵称、头像、手机邮箱） | S3 |
| AC-017 | 修改昵称（1–32 字）成功；非法长度 400；他人资料不可改（无成员ID入参，改自己） | S3 |
| AC-018 | 上传合规图片头像成功并返回可访问 URL；非图片/超 2MB → 400 | S3 头像 |
| AC-019 | 新增地址（全字段合法）→ 成功；第一条地址自动 isDefault=true | S4 |
| AC-020 | 地址列表仅返回本人地址，按默认优先+更新时间排序 | S4 列表 |
| AC-021 | 修改/删除自己地址成功；用他人 addressId 操作 → 404，数据不变 | S4 归属 |
| AC-022 | 设置新默认 → 旧默认自动复位，全表仅一个默认（并发设置也保持唯一） | S4 默认 |
| AC-023 | 删除默认地址 → 成功且该会员无默认地址；查询默认返回空 | S4 删除 |
| AC-024 | 地址字段非法（手机号格式、必填缺失、详细地址超长）→ 400 字段提示；满 20 条再新增 → 拒绝 | S4 校验/上限 |
| AC-025 | mall-web 注册/登录/个人资料/地址管理页面流程可用，build/lint/type-check 通过 | 端到端 |

## 6. 非功能需求

- 安全：密码 BCrypt；HTTPS 由网关承载（本地 HTTP）；私有接口全部 MEMBER 鉴权 + 归属校验；越权测试纳入自动化。
- 一致性：注册最终一致窗口 ≤ 可通过补偿立即收敛；事件至少投递一次、消费幂等。
- 性能：注册/登录 P95 < 300ms；资料/地址接口 P95 < 150ms。
- 可观测：注册/登录关键路径带 traceId；登录失败不记录密码与完整用户名以外敏感信息。
- 兼容：统一 UnifyResult；ID 全字符串（CHG-0015 约定）。

## 7. 成功指标

- 会员注册→登录→建资料→建地址主路径自动化通过率 100%；越权用例（A 访问 B 地址/购物车预留）零通过。
- 注册事件幂等与补偿：压力重放无重复 Profile。
- 本期不度量业务转化率（无埋点体系），以接口可用性与缺陷数为质量口径。
