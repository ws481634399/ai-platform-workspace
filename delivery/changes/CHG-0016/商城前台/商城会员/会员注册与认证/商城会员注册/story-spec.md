---
story-id: "STORY-003-01-01-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S1]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0016
- Story ID: STORY-003-01-01-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

提供 MEMBER 用户名+密码自助注册：在 mall-identity 单库事务内创建 Identity 与凭据，成功后以事件驱动 mall-member 幂等初始化 Member Profile，失败可重试/登录懒补偿；杜绝半成品与重复会员数据。

## 2. Scope（范围）

### 2.1 包含

- [S1] POST 商城注册接口（用户名、密码）；用户名/密码规则校验；用户名唯一（大小写不敏感）；BCrypt 哈希；注册事件发布与 Profile 幂等初始化；失败补偿路径。

### 2.2 不包含

- 登录/刷新/退出与 mall-web 登录态（STORY-003-01-01-02）；资料与地址页面；验证码与通知服务。

## 3. 业务规则

- 用户名 4–20 位、字母开头、字母数字下划线；密码 8–32 位含字母与数字；错误字段级提示。
- mall-identity 内 Identity+凭据同事务；无跨库事务；不输出/记录明文密码。
- MemberRegistered 事件含 eventId/memberId/初始昵称/occurredAt；mall-member 按 eventId+memberId 双幂等消费。
- 补偿：初始化失败可重试；会员首次登录发现缺 Profile 时以注册信息幂等补建。

## 4. 接口与字段规格

- POST /api/mall/auth/register（公开，经网关匿名放行）：入参 username/password；出参 memberId（字符串）+ 基础资料视图；不返回 Token（注册成功引导登录，是否自动登录由前端设计定，默认不自动登录）。
- 事件载荷字段：eventId、memberId(string)、username、nickname、occurredAt。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 有效注册 → 成功且可立即登录；响应与日志无明文密码 |
| AC-002 | 重复用户名（含大小写变体）→ 拒绝且不产生第二条 Identity |
| AC-003 | 不合规用户名/密码 → 400 字段级提示 |
| AC-004 | 注册成功后 Profile 存在，memberId 与 Identity 一致，昵称有默认值 |
| AC-005 | 同一注册事件重放两次 → 仅一份 Profile（幂等） |
| AC-006 | 初始化失败后重试/首次登录 → Profile 补偿创建成功 |
| AC-007 | 注册中途失败 → 无半成品数据，同用户名可重新注册 |
