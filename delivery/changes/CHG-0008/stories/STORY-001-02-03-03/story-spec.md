---
story-id: "STORY-001-02-03-03"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S9]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0008
- Story ID: STORY-001-02-03-03
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

为 RBAC 关键变更记录可追溯、脱敏的安全审计。

## 2. Scope（范围）

### 2.1 包含

- 成功/失败审计、操作者、对象、动作、前后差异摘要、结果、traceId。

### 2.2 不包含

- 审计搜索 UI、长期归档、SIEM 接入。

## 3. 业务规则

管理员/角色/菜单/权限及关系变更必须审计；密码/Token/密钥永不写审计；审计写入失败不得静默；记录不可由普通管理更新接口修改。

## 4. 接口与字段规格

SecurityAuditLog{id,operatorId,action,targetType,targetId,beforeSummary,afterSummary,result,traceId,occurredAt}；内部 AuditRecorder 接口。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 每类关键成功变更均生成包含 operator/action/target/result/traceId 的审计记录。 | |
| AC-002 | 失败的防锁死或非法分配操作也记录失败原因分类，且不含敏感值。 | |
| AC-003 | 普通管理员管理 API 无法修改或删除既有审计记录。 | |

