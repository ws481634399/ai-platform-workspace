# Convergence

> 阶段：sdd-converge 产物
> 输入：completed change（全部 Artifact 已产出）
> 产出状态：completed

本文档记录本次 Change 的知识收敛过程。真正的知识更新发生在 Workspace Knowledge 中（写回 standards/product/），本文件只记录"该不该更新、更新了什么、为什么"。

## 0. 元信息

- Change ID: CHG-0003
- 完成时间: 2026-09-01T23:15:00+08:00
- 状态流转: testing → completed
- 产出 Artifact 数: 9（requirement + exploration + prd + design + tasks + implementation + test-report + review-report + convergence）

## 1. 知识变化总结

本次 Change 在 CHG-0001/0002 结构基线上补全了 Java 后端微服务工程的四能力面（Web Foundation / Persistence Foundation / Test Foundation / Skeleton 补全），带来的知识增量：

- **新规则**：统一响应结构（UnifyResult）与错误码分段约定（0/A/B/S），作为后续所有 Internal API 的公共响应规范；.gitignore 须保留 delivery/**/evidence/logs/ 例外规则，确保构建/测试日志留证不被吞掉
- **新模式**：@WebMvcTest 切片测试需显式 @ContextConfiguration + @Import(AutoConfiguration) 声明配置类与控制器，解决 Spring Boot 3 下 TestApplication 向上搜索不可达问题；WebFoundationAutoConfiguration + AutoConfiguration.imports 自动注册 Filter/Advice
- **新 Feature**：STORY-3（微服务工程基线）由 planned → delivered

## 2. 更新判断

### Standards

- 是否需更新: yes
- 更新内容:
  1. `standards/engineering/backend/framework-standard.md` — 新增「统一响应与错误码分段约定」段落（UnifyResult 五字段 + 0/A/B/S 分段 + X-Trace-Id header 约定）
  2. `standards/testing-conventions.md` — 新增「@WebMvcTest 切片测试配置约定」段落（显式 @ContextConfiguration + @Import 模式）
  3. `standards/engineering/coding-standard.md` 或 `standards/git-conventions.md` — 新增「evidence/logs/ .gitignore 例外规则」条目
- 理由: 三项约定均具备跨 Change 复用价值——后续业务服务开发将直接依赖统一响应/错误码约定、切片测试配置模式、evidence 日志保留规则

### Product

- 是否需更新: no
- 更新内容: 不适用（本 Change 为工程基础交付，无业务行为约束需晋升 Spec；无新术语需写入 Glossary）
- 理由: 本 Change 不产生产品业务规则（PRD §4 业务规则均为工程约束而非产品行为约束），无 Spec 晋升候选

### feature-tree.yaml

- 是否需更新: yes
- 更新内容: STORY-3 状态 planned → delivered
- 理由: 本 Change 全部 AC-01~AC-12 通过（38/38 测试全绿，四项 review 检查零 finding），DU-BE-001/DU-BE-002 均 completed 且 result commit 已回填

### Glossary

- 是否需更新: no
- 更新内容: 不适用
- 理由: 本 Change 未引入需要团队统一叫法的新术语（TraceId/UnifyResult 等为技术概念，已在 design.md 和代码注释中定义，不需要 Glossary 条目）

## 3. 知识沉淀过程

### Standards 写入

以下 3 项知识项已评估并执行写入：

1. **统一响应与错误码分段约定** → `standards/engineering/backend/framework-standard.md`
   - 操作: 新增段落
   - 内容: UnifyResult 五字段（success/code/message/data/traceId）+ 错误码分段（0=成功/A=参数/B=业务/S=系统）+ X-Trace-Id header 约定
   - 理由: 后续所有业务服务的 Internal API 响应应遵循此约定
   - 复用场景: M1~M4 所有业务服务开发

2. **@WebMvcTest 切片测试配置约定** → `standards/testing-conventions.md`
   - 操作: 新增段落
   - 内容: @WebMvcTest 需显式 @ContextConfiguration(classes={TestApplication.class, Controller.class}) + @Import(AutoConfiguration.class)，解决 Spring Boot 3 下测试配置类向上搜索不可达问题
   - 理由: 后续 Web 层切片测试将复用此配置模式
   - 复用场景: 所有 common-web 和业务服务 Controller 切片测试

3. **evidence/logs/ .gitignore 例外规则** → `standards/git-conventions.md`
   - 操作: 新增条目
   - 内容: .gitignore 须包含 `!delivery/**/evidence/logs/` 和 `!delivery/**/evidence/logs/**/*.log` 例外规则，确保构建/测试日志留证不被 gitignore 吞掉
   - 理由: 后续所有 Change 的 evidence/logs/ 都需要保留
   - 复用场景: 全仓所有 Change 的 evidence 留证

### No Update

以下知识项评估为 no-update：

1. **AutoConfiguration.imports 自动注册模式**
   - 理由: Spring Boot 3 标准做法，非项目特有约定，不具备跨项目复用价值

2. **具体 POM 依赖声明（mybatis-plus-spring-boot3-starter / flyway-core 等）**
   - 理由: 属实现细节，依赖版本由 BOM 统一管理，不需要在 standards 中重复

3. **application.yml 具体配置值（端口号/数据源 URL 模板等）**
   - 理由: 属实现细节，配置结构已在 design.md 固化，不需要晋升 standards

### Feature Tree 更新

STORY-3 状态变更：planned → delivered（通过 `openspec feature update` 执行）

## 4. 完成确认

- [x] 代码变更已完成（3 个 code-change commit + 1 个 test evidence commit）
- [x] 测试已完成（38/38 全绿，AC-01~12 全覆盖）
- [x] 证据已收集（evidence.yaml EV-001~EV-011：4 evidence-ref + 3 code-change + 4 test-run）
- [x] 知识更新已评估（3 项 standards 晋升 + 1 项 feature-tree 更新 + 3 项 no-update）
