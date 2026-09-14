---
affected-repositories: [repo-1]
story-id: "STORY-003-01-01-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0016
- Story ID: STORY-003-01-01-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed
- 需要 Migration: yes（mall-identity V2；mall-member V1 仅 member_profile）
- 数据变更概要: 新建 member_user / member_refresh_token / member_event_outbox / member_profile

## 1. 模块改动（Module Changes）

### repo-1 mall-identity

- `domain.member.MemberAccount`：聚合根（id/username/usernameNorm/passwordHash/status/authVersion），工厂 `register(rawUsername, rawPassword)` 承载用户名/密码规则校验与 BCrypt 哈希；`ensureCanSignIn()`。
- `domain.member.MemberRepository`（端口）+ `infrastructure.persistence.member.{MemberUserPo,MemberUserMapper,MemberRepositoryImpl}`。
- `domain.event.MemberRegisteredEvent`（eventId/memberId/username/nickname/occurredAt）；outbox PO `MemberEventOutboxPo`（event_id PK、type、member_id、payload JSON、status PENDING/DONE、retry_count、created_at、sent_at）+ Mapper。
- `application.member.MemberRegistrationService`：`@Transactional` 归一校验唯一 → 建聚合 → insert member_user + insert outbox（同事务）；TransactionSynchronization afterCommit 触发 relay（失败不影响注册结果）。
- `application.member.MemberProvisionRelay`：取出 PENDING → MemberProvisionClient 投递 → DONE；`@Scheduled(fixedDelay=30s)` 重试（retry_count++，上限 20 次后告警日志）。
- `infrastructure.client.MemberProvisionClient`：RestClient base `http://localhost:8102`，默认头 X-Internal-Token（CHG-0015 凭证）。
- `infrastructure.security.RsaAccessTokenIssuer`：issue 增加 SubjectType 入参（admin 调用点传 ADMIN，行为不变）；`application.port.AccessTokenIssuer` 同步签名。
- Flyway `V2__create_member_account.sql`（见 §3）。

### repo-1 mall-member

- `domain.member.MemberProfile`（memberId/username/nickname/avatarUrl/gender/phone/email/initializedEventId）；`MemberProfileRepository`。
- `infrastructure.persistence.member.{MemberProfilePo,Mapper,RepositoryImpl}`；`infrastructure.config.{MybatisPlusConfig,MemberSecurityConfiguration}`（JWT 资源服务器 + JwtSubjectConverter + InternalIdentityFilter 注册）。
- `application.member.ProfileProvisionService`：provision(eventId,...) 双幂等——先按 eventId 查 initialized_event_id，命中即返回 provisioned=false；insert 靠 uk_event_id 兜底并发；默认昵称 `"会员" + memberId 后6位`。
- `interfaces.rest.internal.InternalMemberProvisionController`：`POST /api/internal/members/provision`；另在本 Story 提供 `GET /api/internal/members/{memberId}/profile-seed`（懒补偿种子，供后续 Story 与本 Story 测试使用）。
- Flyway `V1__create_member_tables.sql`（本 Story 仅 member_profile；地址表由地址 Story 追加 V2）。

## 2. 接口契约细化

| 方法 | 路径 | 鉴权 | 请求 | 响应/错误 |
| --- | --- | --- | --- | --- |
| POST | /api/auth/member/register | 匿名（网关白名单） | {username:string, password:string} | 201 {memberId:string}；400 字段校验；409 USERNAME_EXISTS |
| POST | /api/internal/members/provision | X-Internal-Token | {eventId,memberId,username,nickname,occurredAt} | {provisioned:boolean}；401 凭证错误 |
| GET | /api/internal/members/{memberId}/profile-seed | X-Internal-Token | — | {memberId,username,status}；404 不存在 |

注册响应不含密码/Token（登录由下一 Story 提供）。

## 3. 数据变更

```sql
-- mall_identity V2
CREATE TABLE member_user (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(64) NOT NULL,
  username_norm VARCHAR(64) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'ENABLED',
  auth_version BIGINT NOT NULL DEFAULT 1,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT uk_member_username_norm UNIQUE (username_norm)
);
CREATE TABLE member_refresh_token (
  digest CHAR(64) PRIMARY KEY,
  family_id CHAR(36) NOT NULL,
  member_id BIGINT NOT NULL,
  auth_version BIGINT NOT NULL,
  expires_at TIMESTAMP(6) NOT NULL,
  used_at TIMESTAMP(6) NULL, revoked_at TIMESTAMP(6) NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  INDEX idx_member_refresh_family (family_id),
  INDEX idx_member_refresh_member (member_id),
  CONSTRAINT fk_member_refresh_member FOREIGN KEY (member_id) REFERENCES member_user(id)
);
CREATE TABLE member_event_outbox (
  event_id CHAR(36) PRIMARY KEY,
  event_type VARCHAR(64) NOT NULL,
  member_id BIGINT NOT NULL,
  payload_json JSON NOT NULL,
  status VARCHAR(16) NOT NULL DEFAULT 'PENDING',
  retry_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  sent_at TIMESTAMP(6) NULL,
  INDEX idx_outbox_status (status, created_at)
);
-- mall_member V1
CREATE TABLE member_profile (
  member_id BIGINT PRIMARY KEY,
  username VARCHAR(64) NOT NULL,
  nickname VARCHAR(32) NOT NULL,
  avatar_url VARCHAR(512) NULL,
  gender VARCHAR(16) NOT NULL DEFAULT 'UNKNOWN',
  phone VARCHAR(20) NULL,
  email VARCHAR(128) NULL,
  initialized_event_id CHAR(36) NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT uk_profile_event UNIQUE (initialized_event_id)
);
```

## 4. 错误处理

- 注册校验：USERNAME_INVALID / PASSWORD_INVALID（400，字段级 message）；归一后唯一冲突 → USERNAME_EXISTS(409)，统一文案"用户名已存在"。
- relay 失败：outbox 保 PENDING + 错误日志（含 eventId，不含敏感信息）；定时重试；满 20 次 ERROR 告警。
- provision 并发重放：uk_profile_event 冲突 → 查询既存记录返回 provisioned=false，不抛错。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-601 | repo-1 | 注册全链路（账号/outbox DDL、注册服务、issuer 泛化、relay+重试、member provision 双幂等与安全配置） | AC-001,002,003,004,005,006,007 | — |

> 跨 Change 依赖：@StringId、InternalIdentityFilter（X-Internal-Token）由 CHG-0015 的 DU-BE-501 先行落地（requirement-design §6 依赖图：DU-BE-601 depends on DU-BE-501）。

## 6. 测试策略

- 领域单测：用户名/密码规则矩阵；BCrypt 不落明文。
- 集成测试（两服务 test slice + MockRestServiceServer）：注册成功 profile 建立；outbox 同事务回滚；relay 失败 PENDING→定时重试→DONE；eventId 重放仅一行；模拟 member 不可用后懒补偿 seed 路径；大小写变体 409；日志脱敏断言。
- 迁移：Flyway migrate 在 H2/MySQL testcontainer 成功（沿用项目既有测试方式）。
