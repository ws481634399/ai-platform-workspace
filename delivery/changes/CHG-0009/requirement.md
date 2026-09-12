---
id: "REQ-M1-003"
name: "建立后台动态菜单与权限前端"
content: "按 docs/需求/M1/需求M1.md 中 REQ-M1-003 执行完整 SDD；保留一个 Requirement 对应一个 Change，并在 Change 内细拆多个 Story。"
source: requirement-doc
created-at: "2026-09-11T13:30:00.000Z"
---

# Requirement

> 原始需求全文归档于 `references/需求M1.md`，本文件记录本 Change 的输入边界。

## 需求描述

按 `docs/需求/M1/需求M1.md` 中 `REQ-M1-003 后台动态菜单与权限前端` 执行完整 SDD。mall-admin 从后端加载当前管理员、菜单树和 Permission Codes，生成动态菜单与安全白名单路由，统一控制页面与按钮访问，正确区分 401/403，并串行协调并发 Refresh；权限变化和退出后及时刷新或清理状态。前端能力只改善体验，后端授权仍是真正安全边界。

## 补充信息

- 优先级：P0
- 前置依赖：REQ-M1-001，以及 REQ-M1-002 的菜单/权限契约
- 主要仓库：repo-2（联调依赖 repo-1）
- Story 拆分要求：按权限状态、动态导航、操作权限与认证异常细拆。
