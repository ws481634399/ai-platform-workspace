---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-003-01-02-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0016
- Story ID: STORY-003-01-02-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed
- 需要 Migration: no（member_profile 已由注册 Story 建表）
- 数据变更概要: 无 DDL；头像对象写入 MinIO bucket mall-avatar

## 1. 模块改动（Module Changes）

### repo-1 mall-member

- `application.member.ProfileApplicationService`：getMe(currentMemberId)（缺失时调 identity profile-seed 懒补偿初始化）；updateMe(改昵称/性别/手机/邮箱)；头像上传后更新 avatarUrl。
- `infrastructure.storage.MinioStorageClient` + `infrastructure.config.MinioConfiguration`：minio 8.x SDK；`@ConfigurationProperties("mall.storage.minio")`（endpoint/accessKey/secretKey/bucket/publicBaseUrl）；启动幂等 ensureBucket + 公开读 policy；putObject(objectKey, bytes, contentType)；key 规则 `member-avatar/{memberId}/{uuid}.{ext}`。
- `interfaces.rest.mall.MemberProfileController`：
  - GET /api/mall/members/me、PUT /api/mall/members/me
  - POST /api/mall/members/me/avatar（multipart/form-data, part=file）
  - 类级 @PreAuthorize("hasRole('MEMBER')")
- 校验：昵称 1–32；gender 枚举 UNKNOWN/MALE/FEMALE；phone 可选（填则中国大陆手机号格式）；email 可选（RFC 格式，长度 ≤128）；头像图片类型白名单 image/jpeg|png|webp，≤2MB。
- member→identity client：`IdentityInternalClient.getProfileSeed(memberId)`（X-Internal-Token，直连 8101）。

### repo-2 mall-web

- `src/api/member.ts`：getMe/updateMe/uploadAvatar（FormData）。
- views `member/ProfileView.vue`：昵称/性别/手机/邮箱表单；头像组件（本地预览、大小/类型前置校验、上传中状态、错误提示）；布局入口"个人中心"。

## 2. 接口契约细化

| 方法 | 路径 | 请求 | 响应/错误 |
| --- | --- | --- | --- |
| GET | /api/mall/members/me | — | {memberId:string,username,nickname,avatarUrl,gender,phone,email} |
| PUT | /api/mall/members/me | {nickname?,gender?,phone?,email?} | 全量资料 View；400 字段校验 |
| POST | /api/mall/members/me/avatar | multipart file | {avatarUrl:string}；400 FILE_TYPE_INVALID/FILE_TOO_LARGE；503 STORAGE_UNAVAILABLE |
- memberId 永不出现在请求体；响应 ID 字符串。

## 3. 数据变更

- 无 DDL。member_profile.avatar_url 更新；MinIO 新增对象（非数据库迁移）。

## 4. 错误处理

- MinIO 不可用：捕获异常转 503 STORAGE_UNAVAILABLE，不写半成品 URL。
- 懒补偿：seed 返回 404（identity 无此会员，异常态）→ 401 处理（认证与数据不一致，强制重新登录）。
- 文件名校验在服务端重算扩展名，禁止使用客户端文件名作为 key。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-603 | repo-1 | 资料查询/修改、MinIO 集成与头像上传、profile-seed 懒补偿 | AC-016,017,018 | — |
| DU-FE-602 | repo-2 | 个人资料页与头像上传交互 | AC-016,017,018 | DU-BE-603 |

> 跨 Story 依赖：会员注册与会话由 STORY-003-01-01-01 的 DU-BE-601、STORY-003-01-01-02 的 DU-BE-602/DU-FE-601 落地（requirement-design §6：DU-BE-603 depends on DU-BE-601,DU-BE-602；DU-FE-602 depends on DU-FE-601,DU-BE-603）。

## 6. 测试策略

- 后端：Service 单测（校验矩阵/懒补偿触发与不重复）；MinIO 用 mock/测试容器断言 key、contentType、大小拒绝；Controller 切片测试 400/503；越权（无 member 入参，仅 SecurityContext）。
- 前端：组件测试（非法文件拦截、上传成功刷新头像）；vue-tsc/eslint/build。
