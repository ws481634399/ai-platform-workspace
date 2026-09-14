# Test Design（Change 级聚合）— CHG-0016 会员与地址

> 阶段：sdd-task 聚合产物（4 Story Change）；各 Story 明细见对应目录 test-design.md。

- Change ID: CHG-0016
- Feature Path: 商城前台/商城会员
- 覆盖 Story: STORY-003-01-01-01 注册（9）、STORY-003-01-01-02 登录会话（10）、STORY-003-01-02-01 资料（6）、STORY-003-01-03-01 地址（11），共 36 TC。

## 1. 测试用例

### S1 商城会员注册（DU-BE-601）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S1-TC-001 | 注册 201 字符串 memberId，可立即登录，无明文密码 | AC-001 |
| S1-TC-002 | AbC/abc 重复 409，member_user 一行 | AC-002 |
| S1-TC-003 | 用户名/密码规则矩阵 → 400 | AC-003 |
| S1-TC-004 | 注册后 member_profile 存在且 memberId 一致 | AC-004 |
| S1-TC-005 | 同 eventId provision 重放仅一行 | AC-005 |
| S1-TC-006 | member 宕机 outbox 重试 DONE + seed 懒补偿 | AC-006 |
| S1-TC-007 | outbox 失败回滚无残留可重注册 | AC-007 |
| S1-TC-008 | BCrypt 存储/日志无 password | AC-001 |
| S1-TC-009 | V2/V1 迁移与 uk 约束 | AC-002 |

### S2 商城会员登录与会话（DU-BE-602 / DU-FE-601）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S2-TC-001 | 登录双 Token，claim subjectType=MEMBER | AC-008 |
| S2-TC-002 | 错密码/不存在统一文案 | AC-009 |
| S2-TC-003 | 禁用会员拒绝 | AC-010 |
| S2-TC-004 | refresh 旋转；过期/伪造 401 | AC-011 |
| S2-TC-005 | 重放 refresh 整族撤销 | AC-011 |
| S2-TC-006 | logout 后旧令牌再用 401 | AC-012 |
| S2-TC-007 | MEMBER→/api/admin 403 | AC-013 |
| S2-TC-008 | ADMIN→/api/mall/members/me 403 | AC-013 |
| S2-TC-009 | 并发 401 单飞刷新重放（前端） | AC-014 |
| S2-TC-010 | refresh 失败清态跳登录并回跳（前端） | AC-015 |

### S3 会员资料维护（DU-BE-603 / DU-FE-602）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S3-TC-001 | GET /me 字段齐全无入参 ID | AC-016 |
| S3-TC-002 | PUT /me 昵称/手机/邮箱校验 | AC-017 |
| S3-TC-003 | 删 profile 后 seed 重建不重复 | AC-016 |
| S3-TC-004 | 头像 jpeg/png/webp ≤2MB 上传 200 | AC-018 |
| S3-TC-005 | 伪装 gif/2.1MB → 400 无对象 | AC-018 |
| S3-TC-006 | ProfileView 表单/头像交互三检（前端） | AC-025 |

### S4 收货地址管理（DU-BE-604 / DU-FE-603）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S4-TC-001 | 新增 201；首条默认 | AC-019 |
| S4-TC-002 | 列表仅本人，双字段排序 | AC-020 |
| S4-TC-003 | 改他人地址 404 且数据不变 | AC-021 |
| S4-TC-004 | 删他人 404/自己 204 | AC-021 |
| S4-TC-005 | 设默认全表仅一条 | AC-022 |
| S4-TC-006 | 并发设默认其一 409 最终唯一 | AC-022 |
| S4-TC-007 | 删默认后 getDefault {item:null} | AC-023 |
| S4-TC-008 | 字段校验矩阵 400 | AC-024 |
| S4-TC-009 | 第 21 条 409 ADDRESS_LIMIT | AC-024 |
| S4-TC-010 | V2 生成列与 uk 迁移 | AC-024 |
| S4-TC-011 | 地址页全流程三检（前端） | AC-025 |

## 2. 测试策略

- 后端两服务 slice + MockRestServiceServer 模拟 internal 对端；@Scheduled 手动触发；Testcontainers MySQL 迁移；family 状态查库；地址并发 CountDownLatch；MinIO Testcontainer/mock。
- 前端 vitest（单飞/组件）+ vue-tsc/eslint/build；网关角色矩阵经 8080。
- 明细见各 Story 级 test-design.md。
