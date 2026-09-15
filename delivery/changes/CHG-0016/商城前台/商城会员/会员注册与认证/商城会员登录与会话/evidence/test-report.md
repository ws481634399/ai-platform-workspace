# Test Report — 商城会员登录与会话 STORY-003-01-01-02

> 阶段：sdd-test 产物（独立验证：按 test-design.md 的 8 条 TC 逐条核对，证据取自 DU-BE-602 evidence，不在此重复实现正文）。

## 0. 元信息

- Change ID：CHG-0016（商城会员与地址）
- Story ID：STORY-003-01-01-02
- 执行时间：2026-09-15
- 覆盖：AC-008～AC-015（10/10 TC；DU-FE-601 fan-in 后补 TC-009/010）
- 测试基线：repo-1 `mvn clean package`（24 模块全量 242 例）；identity 单模块 79/79、gateway 单模块 19/19。
  repo-2 mall-web vitest 6 文件 22/22、vue-tsc 0 错误、eslint 0 errors、vite build 成功。
- 测试环境：
  - 后端：JDK 21、Spring Boot Test + MockMvc/WebTestClient、H2 内存库（MODE=MySQL；DB_CLOSE_DELAY=-1）、
    @ActiveProfiles("test")、进程内 RSA 安全链（身份切片）与网关真实 SecurityWebFilterChain（下游 200 桩）。
  - 前端：Node 22 / vitest 4、axios 自定义 adapter 注入 401/403/200 计划、vi.mock 隔离 auth API、
    pinia 活动实例/共享实例分场景使用。

## 1. TC 执行结果

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| TC-001 | 正确凭据登录 → 200 双 Token（body）+ memberId 字符串 + HttpOnly cookie；JWT claim sub=memberId/subject_type=MEMBER/auth_version | MockMvc 全链路（注册→登录→JwtDecoder 验签解 claim + Set-Cookie 四属性断言）+ 应用服务单测（大小写/空格归一） | passed | MemberSessionApiTest::loginIssuesTokenPairAndMemberClaims；MemberAuthenticationApplicationServiceTest::validCredentialsReturnAuthenticatedMember；identity-test-green.log |
| TC-002 | 错密码/不存在用户 → 同 401「用户名或密码错误」 | MockMvc 两组 + 单测覆盖格式非法/短密码/null 共 5 个分支 | passed | invalidCredentialsUnifiedMessage；unknownUserGivesUnified401/wrongPasswordGivesUnified401/malformedInputGivesUnified401 |
| TC-003 | DISABLED（密码正确）→ 403「账号已禁用」 | JDBC 置 DISABLED 后 MockMvc + 单测 Kind.FORBIDDEN 断言 | passed | disabledAccountRejectedWith403；disabledAccountGives403 |
| TC-004 | refresh 换新双 Token；伪造/缺失 → 401 | MockMvc 旋转（r2≠r1、a2≠a1、a2 验签 sub 一致）；伪造 token/空 body 两组 | passed | refreshRotatesAndReplayRevokesFamily；invalidRefreshTokenRejected |
| TC-005 | 旧 refresh 重放 → 401 且整族撤销（旋转后的新令牌也 401） | MockMvc 三连刷 + JOIN member_user 按唯一用户名查库：全行 revoked_at 非空、总数≥2 | passed | refreshRotatesAndReplayRevokesFamily（REQUIRES_NEW 独立提交，DEV-1） |
| TC-006 | logout（MEMBER）→ 204 清 cookie；全族撤销；auth_version+1；旧 refresh 401 | Bearer access 调 logout，JDBC 断言 auth_version=2 与 revoked 行数，旧 refresh 再刷 | passed | logoutRevokesFamilyAndBumpsAuthVersion |
| TC-007 | 网关会员 register/login/refresh 匿名放行；products 公开例外保持 | 网关真实 SecurityWebFilterChain + WebTestClient 下游 200 桩 | passed | CHG0016GatewaySecurityChainTest::memberAuthEndpointsWhitelisted、mallProductsStillPublic |
| TC-008 | 会员域仅 MEMBER（匿名 401/MEMBER 200/ADMIN 403）；MEMBER→admin 403（双向） | 网关切片 4 方法（members/me、shipping-addresses 两路径）+ identity 切片（MEMBER→/api/admin 403、匿名 logout 401） | passed | memberScopeRequiresAuthentication/memberTokenAcceptedForMemberScope/adminTokenForbiddenForMemberScope/memberTokenForbiddenForAdminScope；MemberSessionApiTest::memberTokenCannotReachAdminScopeAndLogoutRequiresAuth；CHG-0015 既有 7 例零改动全绿 |
| TC-009 | 刷新页面 restore 登录态；并发 3 个 401 仅一次 refresh 且全部重放成功（AC-014） | vitest：axios adapter 计划注入三 URL 401→刷新后 200；store restore 成功/失败/生命周期单次；coordinator 单飞原语 | passed | http.spec「并发 3 个 401…」（refresh 调用=1、各 URL attempts=2、新 access 落 store）；member.spec 3 例；refresh-coordinator.spec 2 例；另含头注入断言（Bearer 格式/X-Trace-Id UUID） |
| TC-010 | refresh 也失败 → 清态跳 /login?redirect=；登录后回跳原页面（AC-015） | vitest：refresh reject 时两等待者全拒绝、clearSession 恰一次；clearSession 真实跳转断言；accessPolicy 纯矩阵；safeRedirect 开放重定向变体 | passed | http.spec「TC-010…」；clear-session.spec 2 例（query 保留/登录页不重复跳）；access-policy.spec 5 例（`//host`、`/\host`、绝对 URL 均回首页） |

合计：10 passed / 0 failed / 0 skipped。

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | ---: | ---: | ---: | ---: |
| repo-1 Maven 全量（全部测试模块） | 242 | 242 | 0 | 0 |
| └ mall-identity（其中本 Story 新增 12 例） | 79 | 79 | 0 | 0 |
| └ mall-gateway（其中本 Story 新增 5 例） | 19 | 19 | 0 | 0 |
| └ 既有套件（CHG-0015 网关矩阵/M1 认证授权/注册链路回归面） | 其余 | 全绿 | 0 | 0 |
| repo-2 mall-web vitest（本 Story 新增 6 文件） | 22 | 22 | 0 | 0 |
| └ http 401 管线 / member store / coordinator | 11 | 11 | 0 | 0 |
| └ 守卫与回跳 / clearSession / 表单规则 | 11 | 11 | 0 | 0 |

静态门禁：repo-2 vue-tsc 双 tsconfig 0 错误；eslint 0 errors（56 warnings 为已降级样式规则）；
vite build 成功。日志：
- repo-1 `implementation/ai-platform-backend/delivery/CHG-0016/商城前台/商城会员/会员注册与认证/商城会员登录与会话/DU-BE-602/evidence/logs/`（identity-test-green.log、gateway-test-green.log、backend-full-package.log）。
- repo-2 `implementation/ai-platform-frontend/delivery/CHG-0016/商城前台/商城会员/会员注册与认证/商城会员登录与会话/DU-FE-601/evidence/logs/`（fe-test-run1.log、fe-typecheck-run1.log、fe-lint-run1.log、fe-build-run1.log）。

## 3. 验证中发现并闭环的问题

1. **重放撤销被事务回滚（dev 内闭环）**：rotate @Transactional 内 revokeFamily 后抛 401，同事务撤销 UPDATE 被回滚，r2 再刷仍 200。修复为仓储撤销方法 REQUIRES_NEW 独立提交（DEV-1），并补「r2 也 401 + 全行 revoked_at」查库断言。
2. **测试上下文缺 AccessTokenIssuer（dev 内闭环）**：会员令牌服务不带 profile 开关，5 个既有 @SpringBootTest 上下文装配失败。test-scope 自动配置 @ConditionalOnMissingBean 兜底（DEV-2），既有测试类零改动。
3. 另两项为构造器注入声明缺失（@Autowired）与 JWT claim Long 断言类型修正，均在开发期闭环；无遗留到独立验证阶段的未决缺陷。
4. **前端首跑 2 例测试断言失败（dev 内闭环）**：mock 层误断言真实清态、logout try/finally
   重抛惯例未接 rejection；修正断言层级并补 clear-session 独立规格后 22/22 转绿，
   产品代码行为本就正确（DU-FE-601 red-green.md）。

## 4. 跨服务集成验证边界

- 网关切片下游为进程内 200 桩（不启动路由/Nacos），验证的是授权矩阵本身；
  真实「网关 8080→identity 8101/member 8102」HTTP 路由联调纳入 M3 Test 五集成场景。
- AC-012 中「旧 access 在 auth_version 陈旧后被下游拒绝」依赖服务端版本校验过滤器（M1 已有机制），
  本 Story 验证了 logout 后版本确实 +1 且旧 refresh 不可用；access 陈旧的端到端拒绝随 M3 Test 联调观察。
- 前端以 axios adapter/vi.mock 切片锁定合同行为，未起浏览器与真实后端；
  「登录→刷新页 restore→过期单飞刷新→退出回登录」真实浏览器链路随 M3 Test 五集成场景联调。

## 5. 结论

AC-008～AC-015 全部通过，10 条 TC 无遗留失败；ADMIN 与 CHG-0015 既有链路零回归；
前端四检全绿。本 Story 具备进入 review 的条件。
