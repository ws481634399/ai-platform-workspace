# Standards 知识索引

> 最后更新: 2026-09-02T16:05:00Z
> 关联 Change: CHG-0001, CHG-0003, CHG-0004

## 导航
- [规则知识说明](README.md) — Workspace 规则世界的目的、结构和使用指南
- [工程规范总入口](engineering/README.md) — 工程规范分类导航：后端/前端/AI/通用/SDD
- [SDD Standards 总入口](sdd/README.md) — SDD 流程标准：生命周期、知识管理、Skill 执行

## 编码规范
- [编码规范](coding-standards.md) — 命名约定、文件组织、格式化、注释规则、错误处理
- [工程代码规范](engineering/coding-standard.md) — 软件开发过程中的代码质量和代码维护规范

## 架构原则
- [架构原则](architecture-principles.md) — 分层架构、SOLID 原则、Repository/Factory/Strategy 模式、API 设计规范

## 测试规范
- [测试规范](testing-conventions.md) — 测试金字塔、AAA 模式、边界值分析、覆盖率要求
- [工程测试规范](engineering/testing-standard.md) — 测试要求、验证流程和测试证据管理规范

## 版本控制
- [Git 规范](git-conventions.md) — 分支命名、Commit 消息格式、PR 流程、.gitignore 基线

## 安全实践
- [安全指南](security-guidelines.md) — 输入校验、认证授权、密码存储、数据保护、OWASP Top 10

## API 规范
- [工程 API 规范](engineering/api-standard.md) — 软件系统 API 设计和管理规范

## 数据库规范
- [工程数据库规范](engineering/database-standard.md) — 数据库设计、变更、迁移和维护规范

## 后端工程规范（engineering/backend/）
- [后端工程规范入口](engineering/backend/README.md) — 后端系统开发过程中的通用工程规范
- [后端架构规范](engineering/backend/architecture-standard.md) — 后端系统架构设计规范
- [后端框架使用规范](engineering/backend/framework-standard.md) — **（CHG-0001 已晋升 §7.3/§7.4）** 后端技术框架、基础设施组件和工程配置使用规范；含 Java 21 + Spring Boot 3.5.15 + Spring Cloud 2025.0.3 + SCA 2025.0.0.0 唯一基线版本组合、四层 POM 体系 / mall-bom 无 parent / enforcer 守门 / BOM 版本权威 / 依赖边界单向规则
- [后端接口设计规范](engineering/backend/api-design-standard.md) — 后端 API 接口实现规范
- [后端数据库访问规范](engineering/backend/database-access-standard.md) — 后端 DAL 设计和实现规范
- [后端服务设计规范](engineering/backend/service-standard.md) — 后端服务层设计规范

## 前端工程规范（engineering/frontend/）
- [前端工程规范入口](engineering/frontend/README.md) — 前端工程开发过程中的通用技术规范
- [前端代码规范](engineering/frontend/coding-standard.md) — **（CHG-0004 已晋升 §13/§14）** 前端项目代码开发规范；含 ESLint 10 flat config + @eslint/js 显式声明与已验证版本组合、TypeScript 5 固定（TS7 peer 冲突）、双 tsconfig 串联 type-check、多应用镜像文件对齐约定
- [前端组件设计规范](engineering/frontend/component-standard.md) — **（CHG-0004 已晋升 §14）** 前端组件拆分、复用和维护规范；含 Element Plus 按需导入（unplugin + ElementPlusResolver）与生成 dts 入库约定
- [前端路由规范](engineering/frontend/router-standard.md) — **（CHG-0004 已晋升 §15）** 前端路由设计、权限控制和维护规范；含 vue-router 5 返回值式守卫签名约定
- [前端状态管理规范](engineering/frontend/state-management-standard.md) — 状态管理设计原则和维护要求
- [前端性能规范](engineering/frontend/performance-standard.md) — 前端性能设计、开发和优化规范

## AI 应用工程规范（engineering/ai/）
- [AI 应用工程规范入口](engineering/ai/README.md) — AI 应用开发过程中的工程规范
- [AI Agent 设计规范](engineering/ai/agent-standard.md) — AI Agent 的设计、实现和运行规范
- [Prompt 工程规范](engineering/ai/prompt-standard.md) — AI 应用中 Prompt 的设计、管理和维护规范
- [Tool Calling 规范](engineering/ai/tool-calling-standard.md) — AI Agent 工具调用的设计、实现和管理规范
- [AI 知识管理规范](engineering/ai/knowledge-standard.md) — AI 应用中的知识管理规范
- [AI 评估规范](engineering/ai/evaluation-standard.md) — AI 应用能力的评估、测试和持续优化规范

## SDD 流程规范（sdd/）
- [Change Lifecycle](sdd/change-lifecycle.md) — Change 从需求到归档的生命周期管理规则
- [Knowledge Management](sdd/knowledge-management.md) — 项目知识的创建、管理、更新与治理规则
- [Skill Execution](sdd/skill-execution.md) — OpenSpec Skill 的执行规则与标准化
