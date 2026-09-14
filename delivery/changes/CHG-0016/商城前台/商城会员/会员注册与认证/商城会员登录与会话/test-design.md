# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0016
- Story ID: STORY-003-01-01-02
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- Feature Path: 商城前台 > 商城会员 > 会员注册与认证 > 商城会员登录与会话
- 状态流转: designed → tasked
- TC 总数: 10

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API：正确凭据登录 → 双 Token；解码 claim subjectType=MEMBER、sub=memberId 字符串 | AC-008 | DU-BE-602 | |
| TC-002 | API：错误密码与不存在用户均返回同一文案"用户名或密码错误" | AC-009 | DU-BE-602 | 不可区分 |
| TC-003 | API：禁用会员登录 → 拒绝且文案"账号已禁用" | AC-010 | DU-BE-602 | |
| TC-004 | API：refresh 换新双 Token；旧 refresh 已轮换失效；过期/伪造 refresh → 401 | AC-011 | DU-BE-602 | 旋转 |
| TC-005 | API：重放已使用 refresh → 整个 family 撤销并 401 | AC-011 | DU-BE-602 | 重放检测 |
| TC-006 | API：logout 后旧 access（撤销版本/auth_version 场景按 M1 语义）与 refresh 再用 → 401 | AC-012 | DU-BE-602 | |
| TC-007 | 网关集成：MEMBER Token 调 /api/admin/products → 403 | AC-013 | DU-BE-602 | 双向隔离 |
| TC-008 | 网关集成：ADMIN Token 调 /api/mall/members/me → 403 | AC-013 | DU-BE-602 | |
| TC-009 | 前端单测+组件：刷新页面 restore 登录态；并发 3 个 401 仅一次 refresh 且全部重放成功 | AC-014 | DU-FE-601 | coordinator |
| TC-010 | 前端组件：refresh 也失败 → 清态跳 /login?redirect=，登录后回跳原页面 | AC-015 | DU-FE-601 | |

## 2. 测试策略

- API：@SpringBootTest + MockMvc；JWT claim 用解码库断言；refresh family 状态查库。
- Gateway：8080 带不同 subject_type Token 的矩阵用例。
- Frontend：vitest（fake timer + axios mock adapter）测单飞刷新；组件测守卫跳转；vue-tsc/eslint/build。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-601（注册账号）；测试 fixture 直接插入 member_user + BCrypt 密码。
