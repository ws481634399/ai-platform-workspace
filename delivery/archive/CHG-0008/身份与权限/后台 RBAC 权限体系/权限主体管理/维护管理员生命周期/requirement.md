---
id: "REQ-M1-002"
name: "建立后台 RBAC 权限体系"
content: "按 docs/需求/M1/需求M1.md 中 REQ-M1-002 执行完整 SDD；保留一个 Requirement 对应一个 Change，并在 Change 内细拆多个 Story。"
source: requirement-doc
created-at: "2026-09-11T13:30:00.000Z"
---

# Requirement

> 原始需求全文归档于 `references/需求M1.md`，本文件记录本 Change 的输入边界。

## 需求描述

按 `docs/需求/M1/需求M1.md` 中 `REQ-M1-002 后台 RBAC 权限体系` 执行完整 SDD。完成管理员、角色、菜单与权限模型及其分配关系；在业务服务实施真实 API 授权；通过 Redis 缓存权限并在管理员状态或授权关系变化后及时失效；记录关键权限操作审计。前端动态路由与按钮隐藏不在本 Change 内。

## 补充信息

- 优先级：P0
- 前置依赖：REQ-M1-001
- 主要仓库：repo-1
- Story 拆分要求：按权限主体、权限资源、授权执行与治理细拆。
