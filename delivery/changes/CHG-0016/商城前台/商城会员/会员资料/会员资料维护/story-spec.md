---
story-id: "STORY-003-01-02-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S3]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0016
- Story ID: STORY-003-01-02-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

MEMBER 查看与维护本人业务资料：昵称等基础信息、头像（MinIO）、手机号/邮箱资料字段；mall-web 提供个人中心；mall-member 不持有任何凭据字段。

## 2. Scope（范围）

### 2.1 包含

- [S3] GET/PUT /api/mall/members/me；头像上传（MinIO，≤2MB 图片）；手机/邮箱资料字段维护（不验证）；mall-web 个人中心资料页。

### 2.2 不包含

- 密码修改（归 mall-identity，可在页面提供入口但后端不在本 Story）；地址（STORY-003-01-03-01）；等级/积分/收藏。

## 3. 业务规则

- memberId 只取自 SecurityContext；接口无 memberId 入参。
- 昵称 1–32 字；手机号/邮箱做格式校验但不做验证码真实性校验；空值允许清空。
- 头像仅图片、≤2MB；存储对象 key，返回可访问 URL；覆盖上传旧资源处理由设计定。

## 4. 接口与字段规格

- GET /api/mall/members/me → { memberId(string), username(只读), nickname, avatar, phone, email, gender?, createdAt }
- PUT /api/mall/members/me → 可变资料子集。
- POST /api/mall/members/me/avatar（multipart）→ { avatarUrl }。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-016 | /me 返回本人资料，memberId 为字符串，含昵称/头像/手机/邮箱 |
| AC-017 | 修改昵称成功；非法长度 400；接口不接受外部 memberId |
| AC-018 | 合规图片头像上传成功返回可访问 URL；非图片/超 2MB → 400 |
| AC-025 | mall-web 个人中心资料查看/修改流程可用，build/lint/type-check 通过（资料部分） |
