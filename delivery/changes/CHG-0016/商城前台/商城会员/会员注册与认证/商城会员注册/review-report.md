# Review Report — 商城会员注册 STORY-003-01-01-01

> 阶段：sdd-review 产物（同态检查点，状态保持 testing）

## 0. 元信息

- Change ID：CHG-0016（商城会员与地址）
- Test Report 来源：`商城前台/商城会员/会员注册与认证/商城会员注册/evidence/test-report.md`
- Evidence 索引：`evidence/evidence.yaml`（EV-001 code-change、EV-003 test-run、EV-002 evidence-ref）
- 检查时间：2026-09-15T10:20:00+08:00

## 1. 检查结论

无开放 blocker/major/minor。dev 期两项失败（H2 JSON 双编码、共享库计数污染）在开发闭环内修复并留有 red→green 证据；三项 Deviations 理由均成立（详见 §1.2）。

### 1.1 需求一致性

| AC | test-run 证据（EV-003 covers AC-001~007） | 结论 |
| --- | --- | --- |
| AC-001 | TC-001/TC-008：201 字符串 ID、BCrypt(12)、全程无明文密码 | passed |
| AC-002 | TC-002/TC-009：username_norm 大小写唯一 409、uk 约束实证 | passed |
| AC-003 | TC-003：用户名/密码规则矩阵 + 字段级 400 + 无副作用 | passed |
| AC-004 | TC-004：provision 建档 memberId 一致、默认昵称、gender UNKNOWN | passed |
| AC-005 | TC-005：eventId/memberId/uk 三重幂等，重放 provisioned=false | passed |
| AC-006 | TC-006：afterCommit + 定时重试 DONE、20 次上限留 PENDING 告警、seed 端点；/me 半句随 DU-BE-603（DEV-3 明示） | passed（跨 Story 安排已登记） |
| AC-007 | TC-007：outbox 失败整笔回滚、同名可再注册 | passed |

7 条 AC 均被 covers 包含其的 test-run 条目覆盖，追踪链 AC→TC（9 条）→测试方法→DU evidence 无断链。

### 1.2 设计一致性（Design → DU → Implementation）

- **注册单事务 + Outbox-Lite**：MemberRegistrationService 在同一 @Transactional 内完成规则校验→BCrypt→member_user insert（DuplicateKey 捕获转 409）→outbox append；afterCommit 经 TransactionSynchronization 触发且异常吞掉不影响注册结果——与 requirement-design §2.1 方案 A、story-design §1 逐项对应。
- **重试模型**：relay @Scheduled fixedDelay/initialDelay 30s、BATCH_LIMIT 100、MAX_RETRIES 20，达上限保留 PENDING 打 ERROR 不 DLQ，与 story-design §4「满 20 次 ERROR 告警」一致；outbox 列结构（无 next_attempt_at）与 story-design §3 DDL 一致。
- **双幂等建档**：ProfileProvisionService eventId→memberId→insert catch DuplicateResource 三重防线，uk_profile_event 兜底，provisioned 语义与 §2 契约表一致。
- **接口契约**：POST /api/auth/member/register 匿名→201 {memberId:string}、400/409 文案；两个 internal 端点 X-Internal-Token + 同构 401；profile-seed 响应字段与契约表一致（DEV-3 归属调整但 URL/鉴权/载荷不变）。
- **安全边界**：密码仅 BCrypt($2a$12$) 落 identity，事件载荷五字段不含密码；issuer subject_type 参数化拒绝 null/GUEST，ADMIN 调用点显式 ADMIN、行为不变（M1 套件 22 例回归佐证）；密钥经 `${MALL_INTERNAL_SHARED_SECRET:dev-internal-secret}` 占位注入，无硬编码生产密钥。
- **Deviations 复核**：DEV-1（payload_json 改 VARCHAR(2048)）有 H2 探针实证与项目先例（product_sku.specification_data），应用层 ObjectMapper 兜底 JSON 合法性；DEV-2（V2→V7）为 Flyway 版本占用的必然调整；DEV-3（profile-seed 归 identity）与 requirement-design §2 关键组件清单一致。三项三要素齐全，未发现未记录偏离。

### 1.3 跨仓一致性（Phase 2.4）

- 本 Story 仅 repo-1 一个 DU（DU-BE-601），已 completed，baseline/result commit 回填且与仓内 HEAD 祖先链一致。
- 跨服务契约双侧锁定：identity MemberProvisionClient（UnifyResult 解析 + 默认 X-Internal-Token + 失败抛错驱动重试）↔ member InternalMemberProvisionController（@Valid Long memberId 吃字符串、provisioned 布尔、401 凭证）；真实 HTTP 联调按计划归 M3 Test 五集成场景，无提前消项。
- 范围克制：member_refresh_token 仅建表（登录族 DU-BE-602）；网关白名单/路由、MinIO、地址表、mall-web 均未提前实现。

### 1.4 代码质量

- `mvn clean package` 24 模块 BUILD SUCCESS，224 测试全绿；issuer 签名变更的 ADMIN 回归面零失败。
- 抽查：MemberUsername/PasswordPolicy 规则以域对象承载（控制器不重复正则）；relay 无状态、调度与 afterCommit 共用同一投递路径；PO 手写 getter/setter、Mapper 显式 AS camelCase，符合本仓既有持久化约定。
- 无依据 standards 明确条文的新增违规；无未 catch 的异步错误（afterCommit 与定时投递均吞错并落库重试态）。

### 1.5 知识同步候选

- 候选经验（供后续 Story/converge 决策，本次不沉淀）：
  1. 「H2 MySQL 模式 JSON 列对 VARCHAR 绑定参数双编码」——本项目第二次遇到（product_sku 后），可考虑沉淀为测试/迁移约定：跨 H2/MySQL 的 JSON 载荷统一 VARCHAR + 应用层 ObjectMapper。
  2. 「共享 mem 库 + Spring context 复用时测试断言必须按本用例数据域过滤（username_norm/JOIN），禁止无条件 COUNT(*)」。
  3. Outbox-Lite 同事务写 + afterCommit 投递 + 定时扫描重试上限的最小组合（无 MQ、无 next_attempt_at 列），可供 M7 事件化迁移时参照。

## 2. 发现清单

| EV | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| — | — | — | 无开放发现（dev 期两项失败均已在开发期闭环并记入 DU red-green.md/DEV-1） | — |

## 3. 完成确认

- [x] 四项检查全部执行（需求/设计/跨仓/质量 + 知识候选）
- [x] 无未闭环 blocker/major/minor
- [x] Deviations 三要素齐全且经复核合理（DEV-1/2/3）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（DU completed、result commit 回填、契约两侧锁定）
- [x] 追踪链 AC→TC→EVD 完整，红绿灯证据可追溯
