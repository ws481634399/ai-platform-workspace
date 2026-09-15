# Test Report — 会员资料维护 STORY-003-01-02-01

> 阶段：sdd-test 产物（独立验证：按 test-design.md 的 6 条 TC 逐条核对，证据取自 DU-BE-603/
> DU-FE-602 evidence，不在此重复实现正文）。

## 0. 元信息

- Change ID：CHG-0016（商城会员与地址）
- Story ID：STORY-003-01-02-01
- 执行时间：2026-09-15
- 覆盖：AC-016/017/018/025（TC-001~006；TC-006 为前端）
- 测试基线：repo-1 `mvn clean package`（24 模块全量 276 例；mall-member 单模块 44/44）。
  repo-2 mall-web vitest 9 文件 37/37、vue-tsc 0 错误、eslint 0 errors、vite build 成功。
- 测试环境：
  - 后端：JDK 21、Spring Boot Test + MockMvc、H2 内存库（MODE=MySQL；NOW(6) 兼容）、
    @ActiveProfiles("test") 真实安全链（ApiTestSecurityConfig）、io.minio.MinioClient Mockito mock
    （不引 Testcontainer）、@MockitoBean 隔离 AvatarStorage 与 IdentityProfileSeedClient、
    真实 JwtEncoder 签发 MEMBER/ADMIN token。
  - 前端：Node 22 / vitest 4（node 环境逻辑切片，不挂载组件，DU-FE-601 惯例）、
    vi.mock('@/api/member'|'@/api/http')、pinia 活动实例。

## 1. TC 执行结果

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| TC-001 | GET /me 返回 memberId(字符串)/username/昵称/头像/手机/邮箱；无 memberId 入参 | MockMvc 200 全字段 + memberId textual 断言；匿名 401/ADMIN 403；控制器签名结构性无入参 ID（仅 subject 解析） | passed | MemberProfileApiTest::getMeReturnsStringIdProfile、anonymous401AndAdmin403；be-member-test-run1.log |
| TC-002 | PUT /me 昵称 1–32 成功；空/超长 400；手机邮箱格式校验 | MockMvc 校验矩阵（空昵称、33 字、坏手机、坏邮箱、坏 gender 全 400；合法 200）+ 聚合 6 例 + 应用层合并语义 3 例（null 保留/空白清空/坏 gender 不写库） | passed | updateMeValidationMatrix；MemberProfileUpdateTest 6；ProfileApplicationServiceTest::partialUpdateMergeSemantics/invalidUpdateDoesNotPersist/invalidGenderRejected |
| TC-003 | 懒补偿：物理删 profile 后 GET /me → seed 拉取重建 200；再次调用不重复建 | MockMvc：删档→GET 200，库内 initialized_event_id = UUIDv3("member-profile-seed:"+memberId)，二次 GET seedClient times(1) 且仍一行；seed 404 → 401 B0101；纯 Mockito 4 例 | passed | lazyCompensationRebuildsOnce、seedInconsistentReturns401；ProfileApplicationServiceTest::missingProfileTriggersIdempotentCompensation/compensationNotRepeatedAfterRebuilt/getProfilePresentSkipsSeed/seedInconsistentRaises401 |
| TC-004 | POST /me/avatar jpeg/png/webp ≤2MB → 200 可访问 URL，库内 avatar_url 更新 | MockMvc PNG 上传 200 + 库断言 avatar_url 等于响应；MinioClient mock 验证 key 正则 `member-avatar/72000001/<uuid>.(jpg\|png\|webp)`、contentType 魔数重算、bucket policy 含 s3:GetObject；先传后写顺序 | passed | avatarUploadSuccess；MinioAvatarStorageTest 5；ProfileApplicationServiceTest::avatarUploadThenPersist |
| TC-005 | 伪装 .gif/非图片、2.1MB → 400 无对象写入；存储故障 503 | MockMvc GIF89a 伪装（.png 文件名）400 A0101 且 verifyNoInteractions 存储+库不变；2.1MB 合法 PNG 魔数 400 A0102；upload 抛错 503 S0102 库不更新；领域/应用层同路径零存储调用断言 | passed | disguisedGifRejected、oversizedRejected、storageFailure503；AvatarFormatTest 3；avatarSizeAndEmptyRejectedBeforeStorage/disguisedGifRejectedBeforeStorage/storageFailureSkipsDbUpdate |
| TC-006 | 前端组件：ProfileView 表单改/存、头像预览上传成功/失败提示；build/lint/type-check | vitest 三切片 15 例（校验矩阵 8 + API 契约 3 + store 成败 4）；SFC 由 vue-tsc + build 锁定；四检全绿 | passed（点击链路归 M3 Test 浏览器联调，DEV-1） | profile-form.spec、member.spec(api)、profile.spec(store)；fe-test/typecheck/lint/build-run1.log |

合计：6 passed / 0 failed / 0 skipped。

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | ---: | ---: | ---: | ---: |
| repo-1 Maven 全量（24 模块全部测试） | 276 | 276 | 0 | 0 |
| └ mall-member（其中本 Story 新增 34 例） | 44 | 44 | 0 | 0 |
| └ 既有套件（identity 79/gateway 19/其他模块与注册链路回归面） | 232 | 全绿 | 0 | 0 |
| repo-2 mall-web vitest（本 Story 新增 3 切片文件） | 37 | 37 | 0 | 0 |
| └ profile-form 校验矩阵 / api member 契约 / profile store | 15 | 15 | 0 | 0 |
| └ DU-FE-601 既有 6 文件（登录态/守卫/刷新管线回归面） | 22 | 22 | 0 | 0 |

新增 34 例后端分布：AvatarFormatTest 3、MemberProfileUpdateTest 6、ProfileApplicationServiceTest 11、
MinioAvatarStorageTest 5、MemberProfileApiTest 9。
静态门禁：repo-2 vue-tsc 双 tsconfig 0 错误；eslint 0 errors（92 warnings 为已降级样式规则）；
vite build 成功（ProfileView 路由分包 6.00 kB/gzip 2.43 kB）。
日志：
- repo-1 `implementation/ai-platform-backend/delivery/CHG-0016/商城前台/商城会员/会员资料/会员资料维护/DU-BE-603/evidence/logs/`（be-member-test-run1.log、backend-full-package-run1.log）。
- repo-2 `implementation/ai-platform-frontend/delivery/CHG-0016/商城前台/商城会员/会员资料/会员资料维护/DU-FE-602/evidence/logs/`（fe-test-run1.log、fe-typecheck-run1.log、fe-lint-run1.log、fe-build-run1.log）。

## 3. 验证中发现并闭环的问题

1. **@PreAuthorize 拒绝被兜底成 500（dev 内闭环）**：ADMIN JWT PUT /me 首测实际 500——
   AuthorizationDeniedException 在 DispatcherServlet 内抛出，被 common-web 兜底
   @ExceptionHandler(Exception.class) 抢先于外层 ExceptionTranslationFilter 处理。
   修复为 `/api/mall/** hasRole MEMBER` 路径层收口 + MemberWebExceptionHandler 显式 403（DEV-4）。
2. **MockMvc 2.1MB 不触容器限制（dev 内闭环）**：multipart 经预构造请求绕过 Tomcat 解析，
   靠应用层 `content.length > MAX_AVATAR_BYTES` 显式拦截，容器路径由 advice 兜底（DEV-3）。
3. **seed 契约无 eventId（dev 内闭环）**：DU-BE-601 落地契约仅 {memberId,username,status}，
   以确定性 UUID v3 作 initializedEventId 复用幂等 provision（DEV-1），落库断言锁定。
4. 另两项为 MinioClient ObjectWriteResponse 构造器不保险（改 mock 桩）与邮箱 129 边界夹具；
   前端三处（邮箱 128/129 夹具、TS6133 未用 ref、SFC no-undef）均在开发期闭环，
   无遗留到独立验证阶段的未决缺陷。

## 4. 跨服务集成验证边界

- MinioAvatarStorageTest mock io.minio.MinioClient 验证 SDK 入参（key/contentType/policy），
  未启真实 MinIO；真实建桶、匿名公开读 GET 与 9000 不通时 503 的端到端行为纳入
  M3 Test 五集成场景（requirement-design §7 风险场景）。
- profile-seed 补偿以 @MockitoBean IdentityProfileSeedClient 模拟 identity 响应；
  真实 8101→8102 内部 X-Internal-Token HTTP 联调随 M3 Test。
- 前端以 vi.mock 切片锁定合同，未起浏览器；「登录→个人中心→改资料→选头像预览→上传
  成功/9000 不通 503→刷新页资料仍在」真实链路随 M3 Test 浏览器联调（data-testid 已预埋）。

## 5. 结论

AC-016/017/018/025 全部通过，6 条 TC 无遗留失败；identity/gateway 与 CHG-0015 既有链路、
DU-FE-601 登录态套件零回归；前后端四检/全量构建全绿。本 Story 具备进入 review 的条件。
