---
affected-repositories: [repo-1, repo-2]
---

# Change Design（架构总设计）

> 阶段：sdd-design 产物（多 Story Change 级）
> 输入：`change-spec.md`

## 0. 元信息

- Change ID: CHG-0007
- spec 来源: `CHG-0007/change-spec.md`
- 状态流转: specified → designed

## 1. 当前状态

- 当前架构模式: repo-1 是 Java 21 / Spring Boot 3.5 多模块仓，`mall-identity` 只有应用骨架，`mall-common-security` 只有 Security starter，`mall-gateway` 为 WebFlux Gateway；repo-2 的 mall-admin 已有 Vue 3、Pinia、Vue Router、Axios 与占位登录页。
- 相关仓库: repo-1、repo-2
- 相关模块: `mall-services/mall-identity`、`mall-common/mall-common-security`、`mall-gateway`、`mall-admin/src/api|stores|views|router`

## 2. 提议方案

- 方案概要: 由 mall-identity 持有管理员凭证和 Refresh Session；Access Token 使用 RS256 JWT，Refresh Token 使用 256-bit 随机不透明值且数据库只保存 SHA-256 摘要。Gateway 与业务服务只持有公钥并独立验证 Access Token。mall-common-security 提供主体模型、JWT 到 Authentication 的转换和安全自动配置；mall-admin 只保存短期 Access Token 与刷新所需状态，并通过认证 API 建立基础会话。
- 关键组件: `AdminCredential` 聚合、`AuthSession` 聚合、`PasswordEncoder`、`TokenIssuer`、`RefreshTokenHasher`、`AuthenticationApplicationService`、认证 Controller、`SubjectType`/`AuthenticatedSubject`、`JwtAuthenticationConverter`、Gateway `AuthenticationFilter`、前端 `authApi`/`useAuthStore`/`LoginView`。
- 接口契约: `POST /api/admin/auth/login`、`POST /api/admin/auth/refresh`、`POST /api/admin/auth/logout`、`GET /api/admin/auth/session`；统一响应使用 `UnifyResult`，失败分别映射 400/401/423/429/500，不向调用者区分“账号不存在”和“密码错误”。

## 2.1 备选方案对比（Alternatives Considered）

| 方案 | 优点 | 缺点 | 结论 |
|---|---|---|---|
| 永久 HMAC JWT | 实现最少 | 无法安全撤销，所有验证方共享签名 Secret | 拒绝 |
| RS256 Access JWT + 不透明 Refresh Session | 验证方只持公钥，Refresh 可撤销轮换 | 需要密钥配置与会话表 | 采用 |
| 完整 OAuth2 Authorization Server | 标准能力最全 | M1 工程与运维复杂度过高 | 后续需要第三方授权时再评估 |

### 2.2 Token 与密钥契约

- Access Token: RS256 JWT，必含 `iss`、`aud`、`sub`、`iat`、`exp`、`jti`、`subject_type`、`username`、`auth_version`；默认 15 分钟，可配置但不得超过 24 小时。
- Refresh Token: `base64url(32 random bytes)`；客户端仅在签发时拿到明文，服务端保存 SHA-256 摘要、sessionId、subjectId、expiresAt、rotatedFrom、revokedAt 和 authVersion；默认 7 天。
- 轮换: 在单事务中锁定 session，校验未过期/未撤销/未使用，标记旧 session 已轮换并创建新 session；重放旧 Token 时撤销同一 token family。
- 密钥: 私钥仅 mall-identity 从环境变量或 Secret 文件加载；公钥提供给 Gateway/业务服务；测试使用 `src/test/resources` 专用密钥，生产密钥不入库。

### 2.3 身份与传播契约

- 主体枚举固定为 `GUEST/MEMBER/ADMIN/SERVICE`；管理 API 的 audience 为 `mall-admin-api` 且 subjectType 必须为 ADMIN。
- Gateway 先删除所有 `X-Subject-*`、`X-Auth-*` 和 `X-Internal-Identity-*` 外部头，验证 Bearer JWT 后写入规范身份头并保留 Authorization。
- 下游业务服务必须用公钥重新验证 Authorization 并建立 SecurityContext；身份头仅作 trace/诊断辅助，不单独构成认证依据。
- SecurityContext principal 统一为 `AuthenticatedSubject(subjectId, subjectType, username, authVersion, traceId)`。

## 3. 仓库影响（Repository Impact）

- 受影响仓库数: 2
- 主要修改点: repo-1 新增认证领域、迁移、JWT 与公共 Security 自动配置、Gateway Filter；repo-2 新增登录 API、认证 Store、真实登录页和基础退出/刷新入口。

### 3.1 repo-1

- `mall-identity`: 新增 `auth` 四层包、管理员与会话表 Flyway V1、MyBatis-Plus Mapper、认证 API、安全配置和测试。
- `mall-common-security`: 新增纯技术主体类型、principal、JWT claims 常量、Servlet Resource Server 转换器与自动配置；不得放入管理员业务规则。
- `mall-gateway`: 新增响应式 JWT 解码、公开路径白名单、身份头清理/传播 Filter 和 401 JSON 处理。
- `mall-bom`/模块 POM: 统一管理 OAuth2 Resource Server/Jose、Spring Data Redis 等已有 Spring BOM 依赖，不在叶子模块写第三方版本。

### 3.2 repo-2

- `mall-admin`: `api/auth.ts`、`stores/auth.ts`、`views/LoginView.vue`、HTTP Authorization 注入与最小 Refresh/退出协作；完整权限引导和动态路由留给 CHG-0009。
- Token 持久化采用 sessionStorage；Refresh Token 若后端部署支持同站安全 Cookie 则优先 HttpOnly Cookie，本地联调可使用响应字段但封装在 auth store 内，不向组件扩散。

## 4. 跨仓协作（Cross-Repository Contract）

- 接口契约: repo-2 → repo-1 调用 `/api/admin/auth/login|refresh|logout|session`；成功响应 `data={accessToken,refreshToken,tokenType,expiresIn,refreshExpiresIn}`（session 不返回 Refresh Token），错误使用统一 `code/message/traceId`。
- 仓库依赖: repo-2 依赖 repo-1 认证 DTO；Gateway 和下游公共安全组件在同一 repo-1 内共享 claims 常量，不通过服务间 Maven 依赖业务模块。
- 集成边界: `VITE_API_BASE_URL` 指向 Gateway；Gateway 路由 `/api/admin/auth/**` 到 mall-identity；CORS/HTTPS 与密钥由环境配置控制。
- 跨仓时序: 先冻结 API/claims 并实现 repo-1，再实现 repo-2；Refresh 失败由前端清理会话；任一后端失败不在前端伪造成功身份。

## 5. Story 设计分派（Story Design Assignments）

| Story ID | 技术要点摘要 | 涉及仓库 | 公共组件/契约归属 |
|---|---|---|---|
| STORY-001-01-01-01 | 管理员表、密码编码与状态不变量 | repo-1 | 凭证业务归 mall-identity，PasswordEncoder 配置可复用 |
| STORY-001-01-01-02 | 登录用例、等时失败语义与审计事件 | repo-1 | 认证错误码归公共 API 契约 |
| STORY-001-01-02-01 | RS256 Access Token 与不透明 Refresh Session | repo-1 | Claims 常量归 mall-common-security |
| STORY-001-01-02-02 | Refresh 行锁、轮换和 token-family 重放处理 | repo-1 | Session 领域归 mall-identity |
| STORY-001-01-02-03 | Logout、撤销、authVersion 与禁用失效 | repo-1 | 会话失效契约归 Change 级 |
| STORY-001-01-03-01 | SubjectType、issuer/audience/claim 校验 | repo-1 | 主体模型归 mall-common-security |
| STORY-001-01-03-02 | Servlet SecurityContext 自动配置 | repo-1 | 技术组件归 mall-common-security |
| STORY-001-01-03-03 | Gateway WebFlux 验证与身份头清理传播 | repo-1 | claims/headers 常量归 mall-common-security |
| STORY-001-01-04-01 | 登录 API client、auth store 与登录页 | repo-2 | TokenPair DTO 归跨仓 API 契约 |

### 5.1 公共组件与共享契约

- `mall-common-security` 只提供与业务域无关的主体、claims、认证转换和 Security 配置扩展点。
- 管理员状态、密码、Refresh Session 和登录策略只存在于 mall-identity。
- `Authorization: Bearer` 是下游认证事实源；内部身份头名集中定义并默认不可信。

## 6. 数据变更

- 是否需 Migration: yes
- 变更摘要: mall-identity Flyway 新增 `admin_user` 与 `auth_session`；用户名唯一，密码摘要非空；Refresh 摘要唯一；会话含过期、撤销、轮换链和乐观/悲观并发控制字段。迁移仅新增表，不破坏 M0 数据。

## 7. 风险

- 风险等级: 高
- 主要风险: 私钥泄露、Refresh 重放、Gateway 与 Servlet 栈配置分叉、禁用账号旧 Access Token 短时可用、前端存储暴露。
- 缓解措施: 私钥不入库且最小暴露；Refresh 摘要存储与 family 撤销；公共 claims 契约双端测试；Access Token 短 TTL + authVersion 校验扩展点；前端集中封装并优先 HttpOnly Refresh Cookie。

## 8. 待澄清问题

- 无阻塞问题。部署环境的正式 RSA 密钥由运维 Secret 提供；本次只交付配置契约、失败即停的启动校验和测试密钥。
