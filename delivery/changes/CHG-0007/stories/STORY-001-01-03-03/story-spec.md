---
story-id: "STORY-001-01-03-03"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S8]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0007
- Story ID: STORY-001-01-03-03
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

在统一入口初验 Access Token、移除伪造身份头，并向下游传播规范身份信息。

## 2. Scope（范围）

### 2.1 包含

- 公开路径白名单、WebFlux JWT decoder、GlobalFilter、身份头清理、401 JSON。

### 2.2 不包含

- 业务授权、资源归属判断、服务间签发。

## 3. 业务规则

客户端提供的内部身份头一律先删除；仅合法 Token 可产生新身份头；Authorization 原样向下游保留供二次验证；Gateway 不判断具体业务权限。

## 4. 接口与字段规格

内部头：X-Subject-Id、X-Subject-Type、X-Subject-Name、X-Auth-Version、X-Trace-Id；公开路径限 login/refresh/health；非法 Bearer 返回 401 UnifyResult。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 携带合法 ADMIN Token 经 Gateway 请求时，下游同时收到 Authorization 与由 claims 生成的规范身份头。 | |
| AC-002 | 客户端伪造 X-Subject-* 头且无合法 Token 时，伪造头被删除且受保护请求返回 401。 | |
| AC-003 | 过期、签名错误或 audience 不匹配 Token 在 Gateway 被拒绝，且请求不转发到下游。 | |

