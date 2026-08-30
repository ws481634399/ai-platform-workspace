# 探索分析（Exploration）

> Change: CHG-0001
> 需求来源: ENG-BASE-001（M0，P0，工程基础需求）
> Feature: STORY-1（Product → MOD-1 工程基础 → FEAT-1 Maven 工程与版本治理 → STORY-1 建立 Java Maven 多模块工程并统一版本基线）
> 涉及仓库: repo-1（后端 Monorepo `ai-platform-backend`，Maven 根=仓库根，见技术决策 3）
> 匹配历史 Change: 无（首个 Change）
> 复用决策: 新建 CHG-0001
> is-new-candidate: 是（Feature Tree 原为空，经用户确认方案 A 后新建三级节点）

---

## 参考文档

| 文档                             | 用途                                      | 归档                         |
| -------------------------------- | ----------------------------------------- | ---------------------------- |
| `docs/需求/M0/ENG-BASE-001.md`   | 需求原文（目标/约束/AC/DoD）              | `references/ENG-BASE-001.md` |
| `product/08-系统与微服务架构.md` | 模块结构权威定义（知识检索命中）          | product 知识库               |
| `product/14-开发计划.md`         | M0 阶段计划（需求来源之一）               | product 知识库               |
| `product/13-部署方案.md`         | 构建/部署对工程基线的要求（需求来源之一） | product 知识库               |

---

## 知识检索结果（sdd-knowledge 能力 D）

**关键词：** `Maven 多模块`、`Spring Boot`、`Spring Cloud Alibaba`、`微服务`、`工程基线`

| 命中文档                                       | 得分                     | 处理 |
| ---------------------------------------------- | ------------------------ | ---- |
| product/08-系统与微服务架构.md                 | 高（title+tags+summary） | 引用 |
| product/04-子域与限界上下文.md                 | 中                       | 记录 |
| product/00-项目总览.md                         | 低                       | 记录 |
| product/14-开发计划.md、product/13-部署方案.md | 来源文档                 | 参考 |

**关键结论（来自 product/08-系统与微服务架构.md）：**

该文档已定义后端 Maven 模块结构：`backend/` 下包含 `mall-bom`、`mall-common`（8 个技术子模块）、`mall-contracts`（`mall-api-contracts`、`mall-event-contracts`）、`mall-gateway`、`mall-services`（8 个业务服务：identity/member/product/cart/order/inventory/search/system），并已明确 Gateway 采用 Spring Cloud Gateway、服务间通过 OpenFeign + 集成事件协作。

**冲突检查：** ENG-BASE-001 第 3 节的模块层级与 product/08 的结构完全一致，**无冲突**。本需求可视为将 product/08 的架构决策落实到 Maven 工程基线。

---

## 1. 需求理解

本节从 ENG-BASE-001 的表面描述出发，提炼需求本质，并归纳原文未明说但影响实现的隐含约束。

### 需求本质

表面描述是"创建 Maven 多模块工程"，实际要建立的是**工程治理约束**，核心不是目录而是规则：

1. **版本权威唯一化** — `mall-bom` 成为 Spring Boot / Spring Cloud / Spring Cloud Alibaba / MyBatis-Plus 及公共依赖的唯一版本来源，业务模块 POM 只表达"需要什么能力"，不表达版本（消除版本漂移，见需求 §6-9）；
2. **模块边界 = 架构边界** — `mall-common` 只放公共技术能力、`mall-contracts` 只放跨服务契约、领域模型留在各业务服务内部（用 Maven 依赖关系固化 product/08 的 DDD 上下文边界，见需求 §11-12）；
3. **多模块 ≠ 单体** — 统一 Reactor 构建只用于工程治理，每个微服务必须保持独立编译、运行、打包、出 Docker Image 的能力（见需求 §13-14）；
4. **一次基线，处处复用** — 后续任何服务开发只需声明依赖，不再决定框架版本（需求 §23 的最终效果）。

### 隐含需求（原文未明说，已随技术决策确认）

- **版本兼容组合是关键设计决策**：Spring Boot 3.x 小版本、Spring Cloud Release Train、Spring Cloud Alibaba 三者必须取官方兼容矩阵的同一组合——已由技术决策 2 给定；
- **构建失败显式化**：需求 §5 要求"非 Java 21 环境应明确构建失败"，隐含需要 `maven-enforcer-plugin`（requireJavaVersion / requireMavenVersion）等守门机制；
- **编码与编译配置**：需求 §16 要求 UTF-8 编码统一，隐含 `project.build.sourceEncoding` 与 `maven.compiler.release=21` 的集中配置；
- **空模块可构建性**：8 个业务服务当前为占位模块，其形态（可启动应用 vs 纯聚合占位）直接影响 AC-02（全量构建）与 AC-10（独立打包）的验证方式——已由技术决策 4 给定。

## 2. Feature 归属

- **匹配过程**：Feature Tree 原为空（`modules: []`），按 sdd-feature-tree 匹配策略无任何可复用节点，需从 Module 层新建；
- **方案确认**：经用户确认采用方案 A——新建 Module「工程基础」→ Feature「Maven 工程与版本治理」→ Story「建立 Java Maven 多模块工程并统一版本基线」；
- **创建结果**：`MOD-1 工程基础` → `FEAT-1 Maven 工程与版本治理` → `STORY-1 建立 Java Maven 多模块工程并统一版本基线（planned）`；
- **归属理由**：ENG-BASE-001 是工程基础需求而非业务域功能，归入独立的"工程基础" Module，后续 ENG-BASE 系列需求（统一响应、TraceId、日志等）可继续挂到 FEAT-1 或同级 Feature 下；
- **复用决策**：新建 CHG-0001（delivery/archive 无历史 Change，无可沿用对象）。

## 3. 影响分析

本节界定本 Change 的影响范围与下游依赖，并记录探索阶段未知问题的用户决策闭环。

### 影响范围

- **现有功能影响：无**。`implementation/` 尚无代码，属绿地工程，本 Change 只新建 `backend/` 目录及 POM，不修改任何现有内容；
- **数据迁移：无**；
- **下游阻塞关系**：需求 §17 列出的统一响应、异常处理、TraceId、日志、OpenAPI、Flyway、Nacos 注册、MySQL/Redis 连接等 M0 后续需求均依赖本基线，本需求是 **M0 的阻塞型前置需求**；
- **仓库归属**：repo-1 = 后端 Monorepo `ai-platform-backend`（独立 Git 仓库，Maven 根=仓库根），与 SDD 工作区（`ai-platform-workspace`）分离（`.sdd/repositories.yaml` 已同步更新）。

### 未知问题 → 技术决策（用户确认，2026-08-28）

探索阶段提出的 6 个未知问题已全部由用户决策关闭：

| #   | 决策项          | 决策                                                                                                                                                                                                | 关闭的未知问题 |
| --- | --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- |
| 1   | Java 基线       | Java 21                                                                                                                                                                                             | —              |
| 2   | Spring 版本组合 | Spring Boot 3.5.15 + Spring Cloud 2025.0.3 + Spring Cloud Alibaba 2025.0.0.0                                                                                                                        | 问题 1         |
| 3   | 仓库策略        | 【2026-08-28 修订】后端独立 Git 仓库 `ai-platform-backend`（Monorepo，Maven 根=仓库根）；SDD 工作区独立为 `ai-platform-workspace` 仓库；前端 M1 起另建仓库。原决策"不拆独立 Git 仓库"经用户复议作废 | 问题 2         |
| 4   | 微服务骨架      | mall-gateway 及 8 个业务服务均创建独立 Spring Boot Application 主类，能够独立打包和启动，M0 不实现业务功能                                                                                          | 问题 3         |
| 5   | mall-common     | 一次建立全部 8 个规划子模块，M0 主要完成模块骨架和依赖边界，具体技术能力按后续 Requirement 逐步实现                                                                                                 | 问题 4         |
| 6   | mall-bom        | 导入 Spring Boot、Spring Cloud、Spring Cloud Alibaba BOM；第一批额外统一管理 MyBatis-Plus、MapStruct、Springdoc；Lombok 使用 Spring Boot BOM 管理版本，不重复声明                                   | 问题 5         |
| 7   | Maven           | 使用 Maven 3.9+，不提交 Maven Wrapper                                                                                                                                                               | 问题 6         |

### 对后续阶段的输入

- 设计阶段（sdd-specify/sdd-design）以决策 2 的版本组合为技术基线，`mall-bom` 按决策 6 组织 dependencyManagement；
- 决策 4 意味着 AC-02（全量构建）与 AC-10（独立打包）在 M0 即可以 9 个可启动应用验证；
- 决策 5 与需求 §17 一致：mall-common 子模块 M0 只建骨架与依赖边界，不提前实现技术能力；
- 仓库配置已同步：`.sdd/repositories.yaml` 中 repo-1 指向 `../ai-platform-backend`（后端独立仓库）。

> **修订记录（2026-08-28）**：原技术决策 3 为"后端不拆独立 Git 仓库，backend 位于 ai-mall-platform 的 backend/ 目录"。实施前用户复议仓库治理策略，确定"工作区与代码仓分离"：SDD 工作区独立为 `ai-platform-workspace` 仓库，后端独立为 `ai-platform-backend` 仓库（Maven 根=仓库根）。原 ai-mall-platform 目录为废弃版本，不作为实现参考。本修订同步更新 design.md 与 tasks.md。

---

## 质量自检

- [x] 需求标题 10-30 字，独立表达需求意图（取自需求原文标题）
- [x] requirement.md 保持需求原文，未做主观改写
- [x] Feature 归属已经用户确认（方案 A：工程基础 → Maven 工程与版本治理）
- [x] 需求本质分析超出需求复述（治理约束 / 边界固化 / 多模块非单体）
- [x] 影响分析覆盖绿地特性与下游阻塞关系
- [x] 未知问题 6 项已全部由用户技术决策关闭
- [x] 引用了 product/08 历史知识并完成冲突检查（无冲突）
