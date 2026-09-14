---
story-id: "STORY-003-01-01-02"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S2]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0016
- Story ID: STORY-003-01-01-02
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

MEMBER 用户名密码登录、双 Token 刷新轮换与退出撤销；在网关与服务端实现 MEMBER/ADMIN 路径级双向隔离；mall-web 建立统一会员登录态（恢复、并发刷新、401 收口、回跳）。

## 2. Scope（范围）

### 2.1 包含

- [S2] POST /login、/refresh、/logout（MEMBER 域）；账号状态校验；统一错误文案；Token claim subjectType=MEMBER；路径域隔离；mall-web auth store/路由守卫/拦截器。

### 2.2 不包含

- 注册（STORY-003-01-01-01）；资料地址接口；失败次数锁定（P1）。

## 3. 业务规则

- 复用 M1 Token 签发/刷新/撤销机制，仅账号体系与 subjectType 不同。
- /api/admin/** 仅 ADMIN；/api/mall/ 私有域仅 MEMBER；越界 403。
- 刷新成功轮换 refreshToken（旧的失效）；退出双 Token 失效。
- mall-web 单例刷新：并发 401 共享一次刷新，成功重放排队请求，失败清理跳登录。

## 4. 接口与字段规格

- POST /api/mall/auth/login：username/password → accessToken/refreshToken/expiresIn/member 视图。
- POST /api/mall/auth/refresh：refreshToken → 新双 Token。
- POST /api/mall/auth/logout（MEMBER 鉴权）→ 204/200。
- mall-web 存储：access/refresh 位置与 mall-admin M1 方案一致（localStorage 或设计定），内存 Pinia 维护身份。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-008 | 正确凭据登录 → 双 Token，subjectType=MEMBER、sub=memberId（字符串） |
| AC-009 | 错误密码/用户不存在 → 统一文案不可区分 |
| AC-010 | 禁用会员登录被拒 |
| AC-011 | refresh 换新双 Token，旧 refresh 失效；非法 refresh → 401 |
| AC-012 | 退出后双 Token 失效，私有接口 401 |
| AC-013 | MEMBER Token 访 /api/admin/** 403；ADMIN Token 访会员私有域 403 |
| AC-014 | mall-web 刷新恢复；过期时并发请求仅一次刷新并自动重放 |
| AC-015 | 401 收口：清理登录态、跳登录、登录后回跳原页面 |
