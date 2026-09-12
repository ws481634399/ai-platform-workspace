---
story-id: "STORY-001-01-03-01"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S6]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0007
- Story ID: STORY-001-01-03-01
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

定义统一主体类型并在 Token 边界阻止 ADMIN、MEMBER、SERVICE 混用。

## 2. Scope（范围）

### 2.1 包含

- SubjectType、issuer/audience/subject_type 校验、管理 API 主体约束。

### 2.2 不包含

- 会员注册、服务账号签发流程、RBAC 权限。

## 3. 业务规则

主体类型只允许 GUEST/MEMBER/ADMIN/SERVICE；已认证 Token 不得为 GUEST；管理 API 只接受 ADMIN + mall-admin-api audience；未知类型默认拒绝。

## 4. 接口与字段规格

AuthenticatedSubject{subjectId:string,subjectType:SubjectType,username?:string,authVersion:long,traceId?:string}；JWT claim subject_type 使用大写枚举值。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | ADMIN Token 访问管理 API 可完成认证，MEMBER 或 SERVICE Token 使用相同接口时返回 401/403。 | |
| AC-002 | Token 缺少 subject_type、包含未知类型或 audience 不匹配时，验证失败且不建立 SecurityContext。 | |
| AC-003 | SubjectType 序列化和反序列化对四个定义值稳定，未知值默认拒绝。 | |

