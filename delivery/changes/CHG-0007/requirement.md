---
id: "REQ-M1-001"
name: "建立统一身份认证体系"
content: "按 docs/需求/M1/需求M1.md 中 REQ-M1-001 执行完整 SDD；保留一个 Requirement 对应一个 Change，并在 Change 内细拆多个 Story。"
source: requirement-doc
created-at: "2026-09-11T13:30:00.000Z"
---

# Requirement

> 原始需求全文归档于 `references/需求M1.md`，本文件记录本 Change 的输入边界。

## 需求描述

按 `docs/需求/M1/需求M1.md` 中 `REQ-M1-001 统一身份认证体系` 执行完整 SDD。完成后台管理员账号认证、Access Token/Refresh Token 生命周期、退出与撤销、ADMIN/MEMBER/SERVICE 主体隔离、Gateway 初步认证、下游 SecurityContext、可信身份传播以及 mall-admin 基础登录流程；不包含完整 RBAC、动态菜单、按钮权限和商城会员完整能力。

## 补充信息

- 优先级：P0
- 前置依赖：REQ-M0-001、REQ-M0-004
- 主要仓库：repo-1、repo-2
- Story 拆分要求：按领域边界细拆，保持本 Requirement 仍对应单一 Change。
