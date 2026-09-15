# Implementation（跨仓实施汇总）— 商城会员注册 STORY-003-01-01-01

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文位于各实现仓 DU 目录。

## 0. 元信息

- Change ID：CHG-0016（商城会员与地址）
- Story：STORY-003-01-01-01 商城会员注册
- 实施日期：2026-09-15
- 范围边界：会员注册全链路（账号库/注册接口/Outbox-Lite 开通投递/Profile 双幂等建档/profile-seed 种子端点/JWT subject_type 泛化）。
  不含：登录/刷新/退出（STORY-003-01-01-02 / DU-BE-602）、会员资料与头像（DU-BE-603）、收货地址（DU-BE-604）、网关会员路由白名单（随 DU-BE-602 登录链路一并落地）。

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-601 | repo-1（ai-platform-backend） | 完成并验证：mall-identity 67/67、mall-member 10/10，全量 24 模块 224 例全绿 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 2f70309a7834513300387327a7e7048ebbea0ab8 | DU-BE-601 | repo-1 | feat(identity,member): 会员注册全链路 outbox-lite 与 provision（V7 三表+V1 profile、注册服务、relay 重试、双幂等建档、issuer SubjectType、26 例测试） |

（repo-1 另有 SDD implementation/evidence 文档与 metadata 回填类提交，非代码变更，详见该 DU evidence/commits.md。）

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0016/商城前台/商城会员/会员注册与认证/商城会员注册/DU-BE-601/implementation.md`
  - DEV-1：outbox payload_json 列 JSON → VARCHAR(2048)（H2 MySQL 模式 JSON 列回读双编码，对齐 product_sku.specification_data 先例）
  - DEV-2：identity 迁移版本号 V2 → V7（V1~V6 已占用）
  - DEV-3：profile-seed 端点落于 identity 内部控制器（数据源 member_user；契约不变；懒补偿端到端随 DU-BE-603）

## 4. 与 Task / AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | 注册 201 返回字符串 memberId；BCrypt($2a$12$) 存储；响应/库/outbox payload 全程无明文密码 | passed（MemberRegistrationApiTest 主用例） |
| AC-002 | username_norm 小写唯一：大小写变体 409「用户名已存在」，member_user 仅一行；规则矩阵 400 | passed（TC-002/TC-003，域层 6 例 + API 6 组规则） |
| AC-003 | Bean Validation 空白字段 400 字段级提示；400 不写库、不触发投递 | passed（blankFieldsRejected、rejectionHasNoSideEffects） |
| AC-004 | 注册同事务写 member_user + member_event_outbox；afterCommit 投递 member 建 member_profile（memberId 一致、默认昵称「会员」+后 6 位、gender UNKNOWN） | passed（relay afterCommit + InternalMemberProvisionApiTest/ProfileProvisionServiceTest） |
| AC-005 | provision 双幂等：同 eventId 重放 / memberId 已存在 / 并发 uk 冲突均返回 provisioned=false 且仅一行 | passed（member 侧 6+3 例） |
| AC-006 | member 首发不可用 outbox 留 PENDING；@Scheduled 30s 重试至 DONE；20 次上限留 PENDING 打 ERROR 不 DLQ；profile-seed 种子 200/404/401 就绪 | passed（relay 3 例 + seed 3 例；删 profile 后 /me 端到端随 DU-BE-603，DEV-3） |
| AC-007 | outbox append 失败注册事务整笔回滚，无 member_user/outbox 残留，同名可立即再注册 | passed（outboxFailureRollsBackAccountAndNameIsReusable） |

## 5. Fan-in 与验证结论

- 后端：repo-1 `mvn clean package` 24 模块 BUILD SUCCESS，13 个测试模块 224/224（0 failures/0 errors/0 skipped）。
- ADMIN 零回归：AccessTokenIssuer 签名增加 SubjectType 参后，M1 认证授权套件（M1Acceptance 11、M1Security 5、M1TokenValidation 6 等）全绿。
- 跨服务契约两侧锁定：identity MemberProvisionClient（relay 测试经端口 mock）↔ member InternalMemberProvisionApiTest（真实控制器+真实安全链+X-Internal-Token）；真实两服务 HTTP 联调留待 M3 Test 五集成场景。
- 过程红基线：H2 JSON 列双编码导致 relay 反序列化失败、共享上下文 COUNT(*) 污染两处真实失败，修复后转绿（red→green 证据见 DU evidence/red-green.md）。

## 6. 后续 Story 累计代码提交（repos-coverage 机检要求）

本 Story 完成后，同 Change 后续 Story 的代码提交（各提交正文在对应 Story implementation.md）：

| Commit | Story / DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| f1367cb5617cae51a3de1c78256f6992915f5fa6 | STORY-003-01-01-02 / DU-BE-602 | repo-1 | 会员登录/刷新/退出双令牌与网关 MEMBER 隔离 |
| 97b83107636fbf9051140d591f6addcb86aad0db | STORY-003-01-01-02 / DU-FE-601 | repo-2 | mall-web 会员登录态基础设施与登录/注册页 |
| 8c5a1e690845b85e03ee839318d4bcdbce88893b | STORY-003-01-02-01 / DU-BE-603 | repo-1 | 会员资料 GET/PUT /me、MinIO 头像上传与 profile-seed 懒补偿 |
| c20c24c6230790a8bd5af70571e2165a1d67ff64 | STORY-003-01-02-01 / DU-FE-602 | repo-2 | mall-web 个人中心资料页 |
| e6068a1bf813dacf353fd509ab0535563f868230 | STORY-003-01-03-01 / DU-BE-604 | repo-1 | 收货地址 V2 生成列默认唯一 + CRUD/设默认/上限20/归属404 |
| 6a10cdd2de3d5b317bdc1022cad8382e2e4b70b5 | STORY-003-01-03-01 / DU-FE-603 | repo-2 | mall-web 收货地址管理页（列表/弹层/删除确认/乐观设默认） |
