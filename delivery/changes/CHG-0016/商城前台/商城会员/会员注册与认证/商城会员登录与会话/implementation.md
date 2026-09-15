# Implementation（跨仓实施汇总）— 商城会员登录与会话 STORY-003-01-01-02

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文位于各实现仓 DU 目录。

## 0. 元信息

- Change ID：CHG-0016（商城会员与地址）
- Story：STORY-003-01-01-02 商城会员登录与会话
- 实施日期：2026-09-15
- 范围边界：会员登录认证、双 Token 签发、refresh family 旋转/重放整族撤销、logout 撤族+
  auth_version+1、网关会员白名单与 MEMBER/ADMIN 双向隔离。
  不含：前端登录态（DU-FE-601）、会员资料/头像（DU-BE-603/FE-602）、收货地址（DU-BE-604/FE-603）；
  无新数据库迁移（member_refresh_token 已由 DU-BE-601 V7 建好）。

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-602 | repo-1（ai-platform-backend） | 完成并验证：mall-identity 79/79（新增 12）、mall-gateway 19/19（新增 5），全量 24 模块 242 例全绿 |
| DU-FE-601 | repo-2（ai-platform-frontend / mall-web） | 完成并验证：vitest 6 文件 22/22（新增），vue-tsc 0 错误、eslint 0 errors、vite build 成功 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| f1367cb5617cae51a3de1c78256f6992915f5fa6 | DU-BE-602 | repo-1 | feat(identity,gateway): 会员登录/刷新/退出双令牌与网关 MEMBER 隔离（会话域/三服务/持久化/三端点/网关角色与路由，17 例测试） |
| 97b83107636fbf9051140d591f6addcb86aad0db | DU-FE-601 | repo-2 | feat(web): 会员登录态基础设施与登录/注册页（http Bearer/单飞刷新、member store、守卫回跳、22 例测试） |

（repo-1 另有 SDD implementation/evidence 文档与 metadata 回填两个非代码提交；repo-2 另有
docs(sdd) 与 chore(sdd) metadata 两个非代码提交，详见各 DU evidence/commits.md。）

基线说明：本 Story 构建于 STORY-01 DU-BE-601 代码提交 2f70309 之上——member_user 与
member_refresh_token 两表均由其 V7 迁移建好，本 Story 无新迁移。

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0016/商城前台/商城会员/会员注册与认证/商城会员登录与会话/DU-BE-602/implementation.md`
  - DEV-1：整族撤销 revokeFamily/revokeAllForMember 改 REQUIRES_NEW 独立事务（否则 rotate 抛 401 回滚连带撤销回滚，重放后 r2 实测仍 200 暴露）
  - DEV-2：test-scope 自动配置 TestTokenIssuerAutoConfiguration 兜底 JwtEncoder/AccessTokenIssuer（会员令牌服务不带 @Profile("!test")，5 个既有测试上下文需要 issuer）
  - DEV-3：403 语义在 identity 自有 UseCaseException.Kind 增 FORBIDDEN（替代调研设想的控制器局部 BusinessException），异常处理器加 403 映射
- repo-2：`implementation/ai-platform-frontend/delivery/CHG-0016/商城前台/商城会员/会员注册与认证/商城会员登录与会话/DU-FE-601/implementation.md`
  - DEV-1：refresh token 不落 localStorage，走后端双发的 HttpOnly cookie + access 内存态
    （requirement-design §8 裁决「对齐 admin 实际实现」，mall-admin 即 cookie 方案）
  - DEV-2：RegisterView 按 story-design §1 并入本 DU（注册 Story 无 FE TC），不虚增前端用例

## 4. 与 Task / AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-008 | login 200 响应体双 Token+memberId（@StringId），同时双发 HttpOnly/Secure/SameSite=Strict cookie；JWT sub=memberId 字符串、subject_type=MEMBER、username、auth_version=1 | passed（MemberSessionApiTest::loginIssuesTokenPairAndMemberClaims，JwtDecoder 验签解 claim） |
| AC-009 | 用户不存在/错密码/用户名格式非法/密码长度越界统一 401「用户名或密码错误」，不可区分账号存在性 | passed（invalidCredentialsUnifiedMessage + MemberAuthenticationApplicationServiceTest 4 例） |
| AC-010 | DISABLED 账号密码正确 → 403「账号已禁用」（Kind.FORBIDDEN） | passed（disabledAccountRejectedWith403 + disabledAccountGives403） |
| AC-011 | refresh 旋转出新双 Token（r2≠r1、a2≠a1 且可验签）；旧 token 再用 401 且整族撤销（r2 随之 401，库内全行 revoked_at 非空）；伪造/缺失 401 | passed（refreshRotatesAndReplayRevokesFamily、invalidRefreshTokenRejected） |
| AC-012 | logout 204 清 cookie；全族 refresh revoked；auth_version 原子 1→2；旧 refresh 再用 401 | passed（logoutRevokesFamilyAndBumpsAuthVersion，查库断言） |
| AC-013 | 网关矩阵：会员 register/login/refresh 匿名放行；/api/mall/members/**、/api/mall/shipping-addresses/** 仅 MEMBER（匿名 401、MEMBER 200、ADMIN 403）；MEMBER 访问 /api/admin/** 403；identity 服务内同规则再锁一层 | passed（CHG0016GatewaySecurityChainTest 5 例 + MemberSessionApiTest 切片；CHG0015 既有 7 例零回归） |
| AC-014 | 刷新页面 restore 登录态（cookie /refresh，整轮仅试一次）；并发 3 个 401 仅一次 refresh 且三请求全部重放成功；请求带 Bearer 与 X-Trace-Id | passed（http.spec 6 例：并发单飞/失败清理/防循环/登录豁免/403 不动/头注入；member.spec restore 3 例；coordinator.spec 2 例） |
| AC-015 | refresh 也失败 → 集中清态跳 /login?redirect=原路径；登录后回跳；redirect 仅接受同源相对路径（拒绝 //host、/\host、绝对 URL） | passed（clear-session.spec 2 例 + access-policy.spec 5 例；LoginView safeRedirect 回跳） |

## 5. Fan-in 与验证结论

- 后端：repo-1 `mvn clean package` 24 模块 BUILD SUCCESS，全部测试模块 242/242（0 failures/0 errors/0 skipped）。
- ADMIN/CHG-0015 零回归：网关 converter 扩展为 ADMIN/MEMBER 双角色后 CHG0015GatewaySecurityChainTest（7）与 M1GatewayTokenValidationTest（3）全绿；UseCaseException 增 FORBIDDEN 枚举后 identity M1 全套件零回归；register 端点 201/409/400 行为不变。
- 契约要点：refreshToken 在响应体返回同时双发 HttpOnly cookie；DU-FE-601 按
  requirement-design §8 裁决走 cookie 轨道（withCredentials），响应体 refreshToken 仅透传不落盘。
- 前端：repo-2 mall-web vitest 6 文件 22/22、vue-tsc 0 错误、eslint 0 errors、vite build 成功；
  首跑 2 例测试断言失败（mock 层断言错位、logout 重抛惯例）修正后转绿（DU-FE-601 red-green.md）。
- 过程红基线：后端多构造器注入、重放撤销被事务回滚、测试上下文缺 issuer bean、claim Long/Integer 断言四处真实失败，修复后转绿（red→green 证据见 DU evidence/red-green.md）。
- 真实两服务/浏览器 HTTP 联调留待 M3 Test 五集成场景；mall-member 8102 会员域端点（/me、地址）未实现，网关 /api/mall/members 路由与 MEMBER 规则为后续 DU 预置（切片下游为 200 桩）。

## 6. 后续 Story 累计代码提交（repos-coverage 机检要求）

本 Story 完成后，同 Change 后续 Story 的代码提交（各提交正文在对应 Story implementation.md）：

| Commit | Story / DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 8c5a1e690845b85e03ee839318d4bcdbce88893b | STORY-003-01-02-01 / DU-BE-603 | repo-1 | 会员资料 GET/PUT /me、MinIO 头像上传与 profile-seed 懒补偿 |
| c20c24c6230790a8bd5af70571e2165a1d67ff64 | STORY-003-01-02-01 / DU-FE-602 | repo-2 | mall-web 个人中心资料页 |
| e6068a1bf813dacf353fd509ab0535563f868230 | STORY-003-01-03-01 / DU-BE-604 | repo-1 | 收货地址 V2 生成列默认唯一 + CRUD/设默认/上限20/归属404 |
| 6a10cdd2de3d5b317bdc1022cad8382e2e4b70b5 | STORY-003-01-03-01 / DU-FE-603 | repo-2 | mall-web 收货地址管理页（列表/弹层/删除确认/乐观设默认） |
