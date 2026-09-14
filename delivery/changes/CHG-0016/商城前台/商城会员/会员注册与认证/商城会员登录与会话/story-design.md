---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-003-01-01-02"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0016
- Story ID: STORY-003-01-01-02
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed
- 需要 Migration: no
- 数据变更概要: 复用 STORY-003-01-01-01 已建 member_user / member_refresh_token

## 1. 模块改动（Module Changes）

### repo-1 mall-identity

- `application.member.MemberAuthenticationApplicationService`：signIn(username,password) 归一查询 → BCrypt 比对 → 状态校验，返回 AuthenticatedMember；失败统一 INVALID_CREDENTIALS 文案。
- `application.member.MemberRefreshSessionService`：移植 admin RefreshSession 的 family 旋转/重放检测/全量撤销算法，落 member_refresh_token 表（独立类，不改 admin 代码）。
- `application.member.MemberTokenPairApplicationService`：issue/refresh/revokeAll；claim subjectType=MEMBER。
- `interfaces.rest.mall.MemberAuthController`：`/api/auth/member/login|refresh|logout`；refresh 与 cookie 处理对齐 AdminAuthController 现状。
- `infrastructure.security`：issuer 已在上一 Story 参数化，本 Story 接 MEMBER 入参。

### repo-1 mall-gateway

- application.yml 新增路由：`mall-identity-member` Path=/api/auth/member/** → 8101；`mall-member` Path=/api/mall/members/**,/api/mall/shipping-addresses/** → 8102。
- `GatewaySecurityConfiguration`：白名单增加 `/api/auth/member/register`、`/login`、`/refresh`；`.pathMatchers("/api/admin/**").hasRole("ADMIN")` 之后增加 `.pathMatchers("/api/mall/members/**","/api/mall/shipping-addresses/**").hasRole("MEMBER")`；converter 已为 MEMBER claim 生成 ROLE_MEMBER。

### repo-2 mall-web

- `src/api/http.ts`：请求注入 Authorization（member store）与 X-Trace-Id；响应 401 进入刷新协调。
- `src/utils/refresh-coordinator.ts`：单飞 Promise 串行刷新；刷新期间请求挂起重放；刷新失败清会话。
- `src/stores/member.ts`：accessToken/refreshToken/memberInfo 持久化（与 mall-admin 存储策略对齐）、login/logout/restore。
- `src/api/auth.ts`；views `auth/LoginView.vue`、`auth/RegisterView.vue`；router 公开路由与登录后回跳 redirect query；MallLayout 用户区（昵称/退出）。

## 2. 接口契约细化

| 方法 | 路径 | 鉴权 | 请求 | 响应/错误 |
| --- | --- | --- | --- | --- |
| POST | /api/auth/member/login | 匿名 | {username,password} | {accessToken,accessExpiresAt,refreshToken,memberId}；401 统一"用户名或密码错误"；禁用 403/业务码 ACCOUNT_DISABLED |
| POST | /api/auth/member/refresh | 匿名（refresh 凭据） | refreshToken（body/cookie 对齐 admin） | 新双 Token；401 失效/重放 |
| POST | /api/auth/member/logout | MEMBER | — | 204；撤销 family |
- JWT claim：sub=memberId（字符串）、subject_type=MEMBER、username、auth_version。
- 隔离：MEMBER→/api/admin/** = 403；ADMIN→/api/mall/members/me = 403（网关 + 下游 @PreAuthorize 双保险）。

## 3. 数据变更

- 无新表；仅读写 member_refresh_token。

## 4. 错误处理

- 统一凭据错误文案（不区分不存在/错密码）；禁用账号独立文案。
- refresh 重放：撤销整个 family 并 401（对齐 M1 admin 安全语义）。
- 前端：刷新失败 → 清 store/存储 → 跳 /login?redirect=原路径。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-602 | repo-1 | 会员登录/刷新/退出服务与 Controller、网关白名单与双向隔离 | AC-008,009,010,011,012,013 | — |
| DU-FE-601 | repo-2 | mall-web 登录态基础设施 + 登录/注册页 + 守卫回跳 | AC-014,015 | DU-BE-602 |

> 跨 Story 依赖：会员账号/注册能力由 STORY-003-01-01-01 的 DU-BE-601 落地（requirement-design §6：DU-BE-602 depends on DU-BE-601）。

## 6. 测试策略

- 后端：登录成功 claim 断言；错误密码/不存在用户同文案；禁用拦截；refresh 轮换后旧 token 失效、重放撤销 family；logout 后 401；网关层 MEMBER↔ADMIN 越界 403 双向用例。
- 前端：refresh-coordinator 单测（并发 401 只刷新一次、重放顺序、刷新失败清理）；pinia store 持久化/恢复测试；vue-tsc/eslint/build。
