---
affected-repositories: [repo-1, repo-2]
---

# Requirement Design（需求级方案设计）

> 层级：Requirement 级产物——本次 Change 的技术方案骨架
> 业界锚点：ADR（Context → Decision → Alternatives → Consequences）+ 跨仓影响面
> 输入：requirement-spec.md + product/04 §7/§8、product/06 §6
> 产出状态：designed
> 分层关系：本文是 Requirement 级；Story 内部的详细设计见各 Story 目录 story-design.md。

## 0. 元信息

- Change ID: CHG-0016
- spec 来源: requirement-spec.md（REQ-M3-001 商城会员与地址）
- 相关仓库: repo-1（ai-platform-backend）、repo-2（ai-platform-frontend）
- 受影响仓库数: 2
- 需要 Migration: yes（mall-identity V2 会员账号/会话/outbox；mall-member V1 资料/地址）

## 1. 当前状态

- M1 认证底座：`mall-identity` 仅有 ADMIN 主体。`admin_user` 与 `auth_refresh_token`（外键强绑 admin_id）在 Flyway V1；`TokenPairApplicationService`/`RefreshSessionApplicationService` 直接依赖 `AdminUserRepository`；`RsaAccessTokenIssuer` 将 `subject_type=ADMIN` 硬编码入 claim。
- 身份模型已预留：`SubjectType` 含 GUEST/MEMBER/ADMIN/SERVICE；`JwtSubjectConverter` 已能为任意非 GUEST 主体生成 `ROLE_<TYPE>` 权限；`SecurityContextFacade.currentSubject()` 可取 subjectId（字符串）。即下游资源服务器接 MEMBER 零改造，差异在网关授权与身份签发。
- 网关：`/api/admin/**` 要求 ROLE_ADMIN；其余路径 anyExchange authenticated；无 MEMBER 专属授权规则与会员认证路由。
- mall-member 服务：仅 `MallMemberApplication` 骨架；application.yml 端口 8102、MySQL/Nacos；pom 含 mybatis-plus/flyway/mysql/mall-common-web；无安全配置、无迁移。
- mall-web：axios http.ts 仅 M0 透传拦截器（TODO 锚点）；pinia app store、MallLayout、空 router；无登录态。
- 对象存储：infra 有 MinIO 9000，但**后端全仓无 MinIO SDK/上传代码**（CHG-0014 商品图片仅存 objectKey/imageUrl 字段）。
- 事件设施：无 MQ、无 outbox；`mall-contracts` 两子模块仅有 package-info；既有跨服务模式 = RestClient 直连 + UnifyResult（inventory SkuClient）。

## 2. 提议方案

- 方案概要:
  1. **会员账号与会话（identity 独立表，零侵入 ADMIN）**：mall-identity 新增 `member_user`（用户名归一化唯一）、`member_refresh_token`（结构对齐 admin refresh 表，FK 指向 member_user）；新增 `MemberAuthenticationApplicationService`、`MemberTokenPairApplicationService`、`MemberRefreshSessionService`（复用 Refresh token family 轮换/重放撤销算法，以独立 service 类承载，不改动 ADMIN 链路）；`AccessTokenIssuer` 端口方法增加 `SubjectType subjectType` 入参（admin 调用点同步传 ADMIN，行为不变）。
  2. **跨库一致性 = Outbox-Lite + 双幂等 + 懒补偿（不引入 MQ）**：identity 注册单库事务内写 member_user + `member_event_outbox`(eventId, type, memberId, payload, status)；事务提交后同步 RestClient 调 mall-member `POST /api/internal/members/provision`（X-Internal-Token，CHG-0015），成功置 DONE，失败留 PENDING；`@Scheduled` 每 30s 重试 PENDING；member 侧 provision 以 eventId 唯一约束 + memberId 双幂等。懒补偿：会员调 `/api/mall/members/me` 且 profile 缺失时，member 反向调 identity `GET /api/internal/members/{id}/profile-seed` 取种子数据初始化（internal 凭证互信）。无跨库事务、无 MQ。
  3. **Token 双向隔离**：网关新增 `/api/auth/member/register,login,refresh` 白名单；`/api/mall/members/**`、`/api/mall/shipping-addresses/**` 要求 `ROLE_MEMBER`（ADMIN 不可越界，反向隔离维持现状）；下游服务方法级 `@PreAuthorize("hasRole('MEMBER')")` 纵深防御。
  4. **资料与 MinIO 头像**：mall_member V1 建 member_profile / shipping_address；头像上传在 mall-member 引入 `io.minio:minio` SDK，新增配置 `mall.storage.minio.*`，bucket `mall-avatar`（不存在则初始化、读策略公开），`POST /api/mall/members/me/avatar` multipart 上传，服务端校验图片类型与 2MB，存 objectKey，头像 URL 经固定公开读前缀拼接。
  5. **地址归属与默认唯一**：memberId 仅从 `SecurityContextFacade.currentSubject().subjectId()` 取；默认唯一用 MySQL 8 无 partial unique 的等效技巧——生成列 `default_member_flag BIGINT GENERATED ALWAYS AS (IF(is_default=1, member_id, NULL)) STORED` + UNIQUE；设默认 = 事务内清旧+设新；删除默认后无默认；越权访问他人地址统一 404。
  6. **mall-web 登录态**：http.ts 注入 Bearer 与 X-Trace-Id；401 串行刷新协调器（移植 mall-admin refresh-coordinator 模式）；pinia member store（access/refresh localStorage）；登录/注册/个人资料/地址页；路由守卫与登录后回跳。
- 关键组件:
  - mall-identity：`domain.member.MemberAccount`、`MemberUserRepository`、`MemberRegisteredEvent`/outbox PO+Mapper、`application.member.{MemberRegistrationService,MemberAuthenticationApplicationService,MemberTokenPairApplicationService,MemberRefreshSessionService,MemberProvisionRelay}`、`interfaces.rest.mall.MemberAuthController`、`interfaces.rest.internal.InternalMemberController`(profile-seed)、`infrastructure.client.MemberProvisionClient`、Flyway V2。
  - mall-common-security：无新增（JwtSubjectConverter/ROLE_MEMBER 已就绪）；使用 CHG-0015 的 InternalIdentityFilter。
  - mall-member：DDD 四层；`domain.member.{MemberProfile,ShippingAddress}`；`application.member.{ProfileApplicationService,AddressApplicationService,ProfileProvisionService}`；`interfaces.rest.mall.{MemberProfileController,ShippingAddressController}`、`interfaces.rest.internal.InternalMemberProvisionController`；`infrastructure.config.{MemberSecurityConfiguration,MinioConfiguration,MybatisPlusConfig}`；Flyway V1。
  - mall-gateway：会员认证路由（→8101）、会员资料/地址路由（→8102）、白名单与 ROLE_MEMBER 授权。
  - mall-web：`api/http.ts` 增强、`api/auth.ts`/`api/member.ts`/`api/address.ts`、`stores/member.ts`、`utils/refresh-coordinator.ts`、views（Login/Register/Profile/Addresses）、router 守卫、MallLayout 登录区。
- 关键不变量:
  - 密码只在 identity：BCrypt strength 对齐 ADMIN 编码器；日志禁明文。
  - member_user / member_refresh_token 与 admin 表物理隔离；同一用户名空间仅会员侧唯一（与 admin 互不冲突，符合两类主体语义）。
  - profile 初始化双幂等：同 eventId 重放一次效果；补偿永不重复建行。
  - 所有私有资源归属以 SecurityContext 为准；地址越权 404。

## 2.1 备选方案对比（Alternatives Considered）

| 方案 | 描述 | 优点 | 缺点 | 是否采纳 |
| ---- | ---- | ---- | ---- | -------- |
| A（选中）独立 member 表 + 复制 refresh 服务 + Outbox-Lite | 不动 ADMIN 稳定链路；注册同库事务写 outbox；同步投递+定时重试+懒补偿 | ADMIN 零回归；无 MQ 依赖；最终一致可收敛；幂等可证 | identity/member 各多一套会话类；补偿路径需测试 | 是 |
| B 复用 admin_user/auth_refresh_token 加 subject_type 列 | 表与服务少 | ADMIN 已上线链路被改，回归风险；外键/权限快照逻辑混入会员语义 | 否 |
| C 注册时同步 HTTP 建 Profile，失败即回滚注册 | 实现最简 | 跨库一致性靠"反向删除"，失败留垃圾；违背禁止跨库事务决策 | 否 |
| D 引入 RocketMQ 事件 | 标准事件驱动 | infra 与学习成本高，M3 无其他事件消费者 | 否（M7 事件化阶段再迁） |
| E 头像仅支持外链 URL 不接 MinIO | 零新依赖 | 与 spec AC-018 冲突，M4 订单侧也需要真实图片能力 | 否 |

## 3. 仓库影响（Repository Impact）

- 受影响仓库数: 2

### 3.1 repo-1（ai-platform-backend）

- `mall-services/mall-identity`：member 域全套（见 §2）；Flyway `V2__create_member_account.sql`（member_user、member_refresh_token、member_event_outbox）；JWT issuer 增加 subjectType 入参（同步修改 admin 调用点）；application.yml 增加 member service uri 与 MinIO 无关配置；网关路由。
- `mall-services/mall-member`：从骨架建成 DDD 服务；Flyway `V1__create_member_tables.sql`；安全配置（JWT 资源服务器 + InternalIdentityFilter）；MinIO 配置与 client；mybatis-plus 分页插件；application.yml（数据源 mall_member、internal secret、minio）。
- `mall-gateway`：新增路由 `mall-identity-member`（/api/auth/member/** →8101）、`mall-member`（/api/mall/members/**,/api/mall/shipping-addresses/** →8102）、internal seed 路由不经网关（denyAll 已覆盖）；白名单 register/login/refresh；ROLE_MEMBER 授权。
- `mall-common/mall-common-security`：预期零改动（若 InternalIdentityFilter 在 CHG-0015 落于 common-web 则按需对齐）。

### 3.2 repo-2（ai-platform-frontend）

- `mall-web`：登录态基础设施（http 拦截器/刷新协调/store/守卫）与四个页面（登录、注册、个人资料含头像上传、地址管理）；布局登录状态区。

## 4. 跨仓协作（Cross-Repository Contract）

- 接口契约（浏览器→网关）：
  - `POST /api/auth/member/register` {username,password} → 201 {memberId}
  - `POST /api/auth/member/login` → {accessToken, accessExpiresAt, refreshToken(cookie 同 admin 模式优先 HttpOnly Cookie；M3 前端 localStorage 双轨以 admin 现状为准——dev 阶段对齐 admin 实际实现）, memberId}
  - `POST /api/auth/member/refresh`、`POST /api/auth/member/logout`
  - `GET/PUT /api/mall/members/me`；`POST /api/mall/members/me/avatar`(multipart)
  - `GET/POST /api/mall/shipping-addresses`；`PUT/DELETE /api/mall/shipping-addresses/{id}`；`PUT /api/mall/shipping-addresses/{id}/default`；`GET /api/mall/shipping-addresses/default`
  - 错误：400 字段校验 / 401 未认证或凭证失效 / 403 主体越界 / 404 资源不存在或越权 / 409 用户名冲突。
- 内部契约（服务间，X-Internal-Token）：
  - identity → member：`POST /api/internal/members/provision`，{eventId,memberId,username,nickname,occurredAt}，200 {provisioned:boolean}，重复 eventId 返回 200+provisioned=false。
  - member → identity：`GET /api/internal/members/{memberId}/profile-seed`，{memberId,username,status}（供懒补偿；仅在 profile 缺失时调用）。
- Event Contract（逻辑事件，outbox 表为载体）：MemberRegistered v1，at-least-once 投递 + 消费双幂等；M7 可平滑替换为 MQ 投递而消费侧契约不变。
- Data Contract：member 凭据只在 mall-identity；昵称/头像/手机/邮箱/地址只在 mall-member；两边均不跨库写表。
- 仓库依赖: repo-2 → repo-1 HTTP；identity ↔ member 双向 internal HTTP（注册正向 + 懒补偿反向）。
- 集成边界: member 服务直连 identity 8101（profile-seed）、identity 直连 member 8102（provision）；MinIO 9000；密钥经环境变量。
- 跨仓时序: 注册：identity 事务 → provision → DONE；登录：JWT 签发，member 侧首次 /me 时懒补偿收敛。

## 5. Story 设计分派（Story Design Assignments）

| Story ID | 技术要点摘要 | 涉及仓库 | 公共组件/契约归属 |
| -------- | ------------ | -------- | ----------------- |
| STORY-003-01-01-01 | member_user/refresh/outbox DDL；注册服务；issuer subjectType 泛化；provision relay + 定时重试；member profile 表与 internal provision 双幂等 | repo-1 | MemberRegistered v1 事件契约、provision 内部端点、member 安全配置由本 Story 奠基 |
| STORY-003-01-01-02 | member 登录/刷新/退出服务与 Controller；网关白名单+ROLE_MEMBER 隔离；mall-web 登录态基础设施与登录/注册页 | repo-1、repo-2 | 网关 MEMBER 授权规则、http 刷新协调器为后续页面公共依赖 |
| STORY-003-01-02-01 | /me 资料 GET/PUT；MinIO 集成与头像上传；懒补偿 seed 端点；个人中心页 | repo-1、repo-2 | MinioConfiguration 为后续图片能力复用 |
| STORY-003-01-03-01 | shipping_address DDL（生成列默认唯一）；地址 CRUD/默认/查询默认；归属 404；地址管理页 | repo-1、repo-2 | — |

### 5.1 公共组件与共享契约

- 路径 SSOT：会员认证 `/api/auth/member/**`；资料 `/api/mall/members/me`；地址 `/api/mall/shipping-addresses`。
- 事件 SSOT：MemberRegistered{eventId(UUID), memberId, username, nickname, occurredAt}；outbox status PENDING/DONE。
- 内部头：复用 CHG-0015 `X-Internal-Token`。
- ID：全部字符串出参（CHG-0015 @StringId）。

## 6. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-601 | repo-1 | 注册全链路：member_user/refresh/outbox DDL、注册服务与校验、issuer 泛化、provision relay+重试、member profile 表/provision 双幂等、member 安全配置 | AC-001~007 | DU-BE-501 |
| DU-BE-602 | repo-1 | 登录/刷新/退出、双 Token、状态拦截、网关白名单与 MEMBER/ADMIN 双向隔离 | AC-008~013 | DU-BE-601 |
| DU-FE-601 | repo-2 | mall-web 登录态（http 拦截/刷新协调/store/守卫）+ 登录/注册页 | AC-014,015,025 | DU-BE-602 |
| DU-BE-603 | repo-1 | 资料 GET/PUT、MinIO 头像上传、profile-seed 懒补偿 | AC-016,017,018 | DU-BE-601, DU-BE-602 |
| DU-FE-602 | repo-2 | 个人资料页（含头像上传 UX） | AC-025 | DU-FE-601, DU-BE-603 |
| DU-BE-604 | repo-1 | 地址表 DDL + CRUD/默认/查询默认 + 归属 404 + 上限校验 | AC-019~024 | DU-BE-602 |
| DU-FE-603 | repo-2 | 地址管理页（列表/新增/编辑/删除/设默认） | AC-025 | DU-FE-601, DU-BE-604 |

## 7. 风险

- ADMIN 链路回归：issuer 端口签名变化是唯一触达点；以 admin 登录/刷新全量既有测试保护，参数化后 admin claim 逐字节不变。
- 注册最终一致窗口：同步 provision 失败时用户可能立刻登录；懒补偿保证 /me 可用；定时重试 30s 收敛；可观测上记录 outbox lag。
- 用户名大小写归一：唯一索引建在 username_norm；登录/注册均走归一；冲突错误不泄露已存在用户名的原始大小写。
- MinIO 本地依赖：MinIO 9000 未启动时头像上传明确 503 业务错误（不影响注册登录主链）；bucket 初始化做幂等 create。
- 地址默认唯一并发：生成列唯一索引兜底；并发设默认导致唯一键冲突时返回 409 并提示重试。
- 前端 token 存储：沿用 mall-admin 既有方案保持一致（其风险接受结论 M1 已评审）。

## 8. 待澄清问题

- refresh token 投递形态：dev 阶段与 mall-admin 现状对齐（其实现以 cookie 或 body 为准）；M7 安全加固阶段统一评估 HttpOnly Cookie。
- MinIO 公开读策略仅用于头像 bucket；生产域名/CDN 前缀经环境变量 `MALL_MINIO_PUBLIC_BASE_URL` 注入，本地默认 http://localhost:9000。
