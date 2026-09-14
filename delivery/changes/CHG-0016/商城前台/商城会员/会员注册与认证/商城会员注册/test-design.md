# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0016
- Story ID: STORY-003-01-01-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- Feature Path: 商城前台 > 商城会员 > 会员注册与认证 > 商城会员注册
- 状态流转: designed → tasked
- TC 总数: 9

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API：POST /api/auth/member/register 合规则 → 201 memberId(字符串)，可立即登录；响应/日志无明文密码 | AC-001 | DU-BE-601 | |
| TC-002 | API：重复用户名（AbC 与 abc 大小写变体）→ 409，member_user 仅一行 | AC-002 | DU-BE-601 | username_norm |
| TC-003 | API 参数化：用户名 <4/数字开头/非法字符、密码 <8/纯数字 → 400 字段级提示 | AC-003 | DU-BE-601 | 规则矩阵 |
| TC-004 | 跨服务集成：注册成功后 member 库 member_profile 存在，memberId 一致、默认昵称 | AC-004 | DU-BE-601 | provision 同步路径 |
| TC-005 | API：同 eventId provision 重放两次 → 仅一行 profile，第二次 provisioned=false | AC-005 | DU-BE-601 | 双幂等 |
| TC-006 | 故障注入：member 首次不可用（outbox PENDING）→ 定时重试 DONE；删 profile 后首次 /me 触发 seed 懒补偿重建 | AC-006 | DU-BE-601 | 双兜底 |
| TC-007 | 事务测试：provision 前注册事务回滚（如 outbox 插入失败）→ 无 member_user 残留，同名可再注册 | AC-007 | DU-BE-601 | 原子性 |
| TC-008 | 静态/日志断言：BCrypt 哈希存储；日志输出不含 password 字面量 | AC-001 | DU-BE-601 | 安全 |
| TC-009 | 迁移测试：Flyway V2(identity)/V1(member) 在干净库 migrate 成功，uk 约束存在 | AC-002 | DU-BE-601 | DDL |

## 2. 测试策略

- Unit：MemberAccount 注册规则与哈希；归一化。
- Integration：两服务 test slice + MockRestServiceServer 模拟 internal 对端；outbox/relay 用可控时钟；@Scheduled 手动触发。
- Migration：Testcontainers MySQL（或项目既有 H2 模式）执行全部 V。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- CHG-0015 DU-BE-501（@StringId、X-Internal-Token）。
