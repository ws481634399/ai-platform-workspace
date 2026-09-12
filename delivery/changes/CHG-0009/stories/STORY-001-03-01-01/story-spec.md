---
story-id: "STORY-001-03-01-01"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S1]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0009
- Story ID: STORY-001-03-01-01
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

登录后从后端加载可信的当前管理员基本信息并维护统一身份状态。

## 2. Scope（范围）

### 2.1 包含

- bootstrap 用户字段、identity loading/success/error、重新加载。

### 2.2 不包含

- 菜单权限、动态路由、管理员资料编辑。

## 3. 业务规则

用户信息只来自后端 session bootstrap；Token 解析结果不替代用户 API；401 清会话，403 保留会话；组件只读 store。

## 4. 接口与字段规格

GET /api/admin/session/bootstrap 的 user={id,username,displayName}；permission store identity 状态 idle/loading/ready/error。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 持有合法 Token 调用 bootstrap 后，store 保存与后端一致的管理员 id、username、displayName。 | |
| AC-002 | bootstrap 返回 401 时触发集中会话清理且进入登录页。 | |
| AC-003 | bootstrap 网络失败时进入可重试 error 状态，不伪造用户或覆盖仍可恢复的 Token。 | |

