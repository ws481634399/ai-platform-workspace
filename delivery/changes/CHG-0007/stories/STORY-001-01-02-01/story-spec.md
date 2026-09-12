---
story-id: "STORY-001-01-02-01"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S3]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0007
- Story ID: STORY-001-01-02-01
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

为成功认证的 ADMIN 建立有界、可验证、可撤销的双 Token 会话。

## 2. Scope（范围）

### 2.1 包含

- RS256 Access Token、随机 Refresh Token、Session 摘要持久化、TTL 与 claims。

### 2.2 不包含

- Refresh 轮换、主动撤销、前端并发刷新。

## 3. 业务规则

Access Token 默认 15 分钟且不超过 24 小时；Refresh 默认 7 天；Refresh 明文只返回一次，数据库只存 SHA-256 摘要；claims 必含 iss/aud/sub/iat/exp/jti/subject_type/username/auth_version。

## 4. 接口与字段规格

登录成功 data={accessToken,refreshToken,tokenType:'Bearer',expiresIn,refreshExpiresIn}；AuthSession{id,subjectId,tokenHash,familyId,expiresAt,revokedAt,rotatedTo,authVersion}。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 成功登录后同时获得 Access Token 与 Refresh Token，二者过期时间符合配置。 | |
| AC-002 | Access Token 使用 RS256 验签且包含全部必需 claims，subject_type=ADMIN、aud=mall-admin-api。 | |
| AC-003 | 数据库中找不到 Refresh Token 明文，只存在固定长度摘要和会话元数据。 | |

