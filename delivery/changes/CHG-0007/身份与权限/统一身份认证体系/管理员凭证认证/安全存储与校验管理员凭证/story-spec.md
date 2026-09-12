---
story-id: "STORY-001-01-01-01"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S1]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0007
- Story ID: STORY-001-01-01-01
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

建立管理员凭证模型，使密码只以强哈希保存，并在认证前稳定判断账号是否具备登录资格。

## 2. Scope（范围）

### 2.1 包含

- 管理员用户名唯一；密码输入校验；bcrypt/argon2 强哈希；ENABLED/DISABLED 状态校验；响应和日志脱敏。

### 2.2 不包含

- 登录 Token 签发、角色授权、管理员管理 UI。

## 3. 业务规则

用户名去除首尾空格后长度 3~64 且唯一；密码输入 8~128 字符；只保存 passwordHash；禁用账号不具备登录资格；所有 DTO 排除密码相关字段。

## 4. 接口与字段规格

领域字段：AdminCredential{id,username,passwordHash,status,authVersion,createdAt,updatedAt}。创建/改密输入含明文 password，但明文只在请求作用域存在；输出只含 id/username/status。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 给定合法用户名和密码，当创建凭证时，数据库仅保存不可逆强哈希且能正确匹配原密码。 | |
| AC-002 | 给定 DISABLED 管理员，当校验登录资格时，返回不可登录结果且不执行 Token 签发。 | |
| AC-003 | 对管理员响应与普通日志执行敏感字段扫描时，不出现 password、passwordHash、完整 Token 或密钥。 | |

