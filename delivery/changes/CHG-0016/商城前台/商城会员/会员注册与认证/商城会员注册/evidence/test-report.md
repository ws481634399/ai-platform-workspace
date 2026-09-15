# Test Report — 商城会员注册 STORY-003-01-01-01

> 阶段：sdd-test 产物（独立验证：按 test-design.md 的 9 条 TC 逐条核对，证据取自 DU-BE-601 evidence，不在此重复实现正文）。

## 0. 元信息

- Change ID：CHG-0016（商城会员与地址）
- Story ID：STORY-003-01-01-01
- 执行时间：2026-09-15
- 覆盖：AC-001～AC-007（9/9 TC）
- 测试基线：repo-1 `mvn clean package`（24 模块全量 224 例）；identity 单模块 67/67、member 单模块 10/10。
- 测试环境：JDK 21、Spring Boot Test + MockMvc、H2 内存库（MODE=MySQL；DATABASE_TO_LOWER/CASE_INSENSITIVE_IDENTIFIERS；DB_CLOSE_DELAY=-1）、@ActiveProfiles("test")、进程内 RSA 安全链。

## 1. TC 执行结果

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| TC-001 | 合规注册 → 201 memberId 字符串；响应无明文密码；afterCommit 投递 | MockMvc 全链路集成（MemberProvisioner 端口 mock，不发网络） | passed | MemberRegistrationApiTest::validRegistrationReturnsStringIdAndProvisions；identity-test-green.log |
| TC-002 | AbC/abc 大小写变体重复 → 409，member_user 仅一行 | MockMvc + JDBC 计数 | passed | duplicateUsernameCaseInsensitiveConflict（409「用户名已存在」，username_norm 计数 1） |
| TC-003 | 用户名 <4/数字开头/非法字符、密码 <8/纯数字/纯字母 → 400 字段级 | API 参数化 6 组 + 空白 1 组 + 域层规则矩阵 | passed | invalidUsernameOrPasswordRejectedWithFieldMessages、blankFieldsRejected、MemberAccountTest（Username 2 + Password 4） |
| TC-004 | 注册后 member 库 member_profile 存在、memberId 一致、默认昵称 | member 侧真实控制器/安全链集成 + 应用服务单测 | passed | InternalMemberProvisionApiTest::provisionCreatesProfileWithDefaultNickname；ProfileProvisionServiceTest 6 例 |
| TC-005 | 同 eventId provision 重放两次 → 仅一行、第二次 provisioned=false | member 侧 API + 应用层三重幂等单测 | passed | replayReturnsFalseAndKeepsSingleRow；eventId 命中/memberId 已存在/uk 冲突用例 |
| TC-006 | member 首发不可用 outbox PENDING → 定时重试 DONE；重试上限行为；seed 种子 | relay 集成（@Scheduled 手动触发路径、spy 故障注入）+ seed API | passed | MemberProvisionRelayTest 3 例（重试 DONE/20 次上限留 PENDING/回滚）；InternalMemberSeedApiTest 3 例（200/404/401）。删 profile 后 /me 懒补偿端到端随 DU-BE-603（/me 端点所在 DU），种子端点本 Story 已锁定，见 DU DEV-3 |
| TC-007 | outbox 插入失败注册事务回滚、无残留、同名可再注册 | spy 抛错 + JDBC JOIN 计数 + reset 后再注册 | passed | outboxFailureRollsBackAccountAndNameIsReusable |
| TC-008 | BCrypt 哈希存储；响应/日志/payload 无明文 | JDBC 取 password_hash 断言 `$2a$12$` 前缀；响应体与 payload_json 不含 password 键/明文 | passed（随 TC-001 同用例） |
| TC-009 | Flyway V7(identity)/V1(member) 干净库迁移成功、uk 约束存在 | @SpringBootTest 上下文启动全量 migrate；uk 经 TC-002/TC-005 冲突路径实证 | passed | 两服务全部 SpringBootTest 上下文加载成功；uk_member_username_norm、uk_profile_event、fk_member_refresh_member |

合计：9 passed / 0 failed / 0 skipped（TC-006 懒补偿端到端半句为已知跨 Story 验证安排，非跳过用例——种子与重试侧 6 个测试方法全部通过）。

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | ---: | ---: | ---: | ---: |
| repo-1 Maven 全量（13 个测试模块） | 224 | 224 | 0 | 0 |
| └ mall-identity（其中本 Story 新增 17 例） | 67 | 67 | 0 | 0 |
| └ mall-member（其中本 Story 新增 9 例） | 10 | 10 | 0 | 0 |
| └ ADMIN/M1 既有套件（issuer 泛化回归面） | 其余 | 全绿 | 0 | 0 |

日志：repo-1 `implementation/ai-platform-backend/delivery/CHG-0016/商城前台/商城会员/会员注册与认证/商城会员注册/DU-BE-601/evidence/logs/`（identity-test-green.log、member-test-green.log、backend-full-package.log）。

## 3. 验证中发现并闭环的问题

1. **outbox 载荷反序列化失败（dev 内闭环）**：H2 MySQL 模式将 VARCHAR 参数写入 JSON 列按 JSON 字符串标量处理，回读双编码导致 relay NPE、outbox 滞留 PENDING。修复为 VARCHAR(2048)（DEV-1），red→green 证据在 DU red-green.md。
2. **跨测试类共享 H2 库计数污染（dev 内闭环）**：无条件 COUNT(*) 受其他用例提交行影响；两处断言收窄到本用例 username/本会员 JOIN 范围。
3. 两项均为本 Story 开发期测试先行暴露，无遗留到独立验证阶段的未决缺陷。

## 4. 跨服务集成验证边界

- identity→member 的真实 HTTP 投递在切片层以端口 mock + member 真实控制器双侧锁定契约（请求五字段/UnifyResult/provisioned 语义/X-Internal-Token 401）。
- 真实两进程 HTTP 联调（含 member 不可用→30s 定时重试的墙钟观察）纳入 M3 Test 阶段五集成场景统一执行。

## 5. 结论

AC-001～AC-007 全部通过，9 条 TC 无遗留失败；ADMIN 认证链路零回归。本 Story 具备进入 review 的条件。
