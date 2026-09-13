# Convergence

## 0. 元信息

- Change ID: CHG-0007
- 完成时间: 2026-09-13T00:45:00+08:00
- 产出 Artifact 数: 117

## 1. 知识变化总结

- 知识增量摘要: 完成统一身份认证、双 Token 生命周期、多主体隔离、可信身份传播和管理端基础登录的可验证实现。

## 2. 更新判断

### Standards

- 是否需更新: no
- 更新内容: 无；DDD 分层、认证授权、密码保护、API 与测试规则已由现行 standards 覆盖。
- 理由: 本 Change 是既有规范的具体落地，没有形成相互冲突的新工程规则。

### Product

- 是否需更新: no
- 更新内容: 无独立 Spec 晋升文件；长期业务能力已存在于产品需求、权限配置和 API 契约文档。
- 理由: 本次未引入超出 M1 已确认范围的新业务规则。

### feature-tree.yaml

- 是否需更新: yes
- 更新内容: 本 Change 的 9 个 Story 状态 planned → delivered。
- 理由: Story 已完成开发、测试和 Review。

### Glossary

- 是否需更新: no
- 更新内容: 无。
- 理由: ADMIN、SERVICE、Access Token、Refresh Token 等术语已有既定含义。

## 3. 知识沉淀过程

完成知识分类；无新增 standards/spec/glossary 文档，更新 Feature Tree 状态并重建知识索引。无 Conflict 或 Unresolved 项。

## 4. 全局验收标准对照

| # | 验收点 | 覆盖 Story | 证据引用 | 结论 |
|---|---|---|---|---|
| 1 | 正确凭证登录，错误凭证与禁用账号拒绝 | STORY-001-01-01-01/02 | evidence/test-report.md §3 | 通过 |
| 2 | Access Token 在 Gateway/下游验证 | STORY-001-01-03-01/02/03 | evidence/test-report.md §3 | 通过 |
| 3 | Refresh 轮换并拒绝过期、撤销与重放 | STORY-001-01-02-01/02 | evidence/test-report.md §3 | 通过 |
| 4 | 退出和禁用使会话失效 | STORY-001-01-02-03 | evidence/test-report.md §3 | 通过 |
| 5 | ADMIN/MEMBER/SERVICE 主体隔离 | STORY-001-01-03-01 | evidence/test-report.md §3 | 通过 |
| 6 | SecurityContext 提供统一身份字段 | STORY-001-01-03-02 | evidence/test-report.md §3 | 通过 |
| 7 | 外部伪造身份头被清理 | STORY-001-01-03-03 | evidence/test-report.md §3 | 通过 |
| 8 | mall-admin 登录、刷新、退出闭环 | STORY-001-01-04-01 | evidence/test-report.md §3 | 通过 |
| 9 | 自动化覆盖安全边界 | 全部 Story | 后端 88/88；前端 22/22；TC 27/27 | 通过 |

## 5. 完成确认

- [x] 代码变更已完成
- [x] 测试已完成
- [x] 证据已收集
- [x] 全局验收标准已逐条对照
- [x] 知识更新已评估
- [x] 无未解决的 Conflict 或 Unresolved 问题

