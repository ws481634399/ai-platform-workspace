---
story-id: "STORY-001-01-03-02"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S7]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0007
- Story ID: STORY-001-01-03-02
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

让 Servlet 业务服务从已验证 JWT 获得统一、类型安全的当前主体。

## 2. Scope（范围）

### 2.1 包含

- Resource Server 配置、JWT converter、AuthenticatedSubject principal、401/403 JSON handler。

### 2.2 不包含

- 具体业务 Permission Code 与资源归属规则。

## 3. 业务规则

SecurityContext 只由已验证 JWT 创建；principal 必含 subjectId/subjectType/authVersion；未认证返回 401；已认证但无权返回 403；公开端点显式白名单。

## 4. 接口与字段规格

mall-common-security 自动配置提供 SecurityFilterChain 扩展点和 CurrentSubjectAccessor；Authorization header 是认证事实源。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 给定合法 ADMIN Access Token，当访问受保护 Servlet API 时，SecurityContext principal 包含正确主体字段。 | |
| AC-002 | 给定缺失、过期或签名错误 Token，当访问受保护 API 时，返回统一 401 且上下文为空。 | |
| AC-003 | 给定已认证但无 authority 的主体，当触发方法安全时，返回统一 403 而不是 401。 | |

