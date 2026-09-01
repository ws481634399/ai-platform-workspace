# Tasks（Repository Delivery Decomposition Plan）

> 阶段：sdd-task 产物（Phase 2.4 升级为 Delivery Decomposition Skill）
> 位置：STORY 级 —— `<CHG>/<L1>/<L2>/<L3>/<STORY>/tasks.md`（由 metadata.feature-path 决定）
> 输入：prd.md + design.md + .sdd/repositories.yaml + feature-path
> 产出状态：tasked

本文档将设计拆解为 Delivery Unit（DU）——每个 DU 是本次 Change 在一个具体仓库中的实施交付单元（DU 1:1 Repository，跨仓交付必须拆多个 DU）。

## 0. 元信息

- Change ID: CHG-0002
- Design 来源: design.md（CHG-0002）
- 状态流转: designed → tasked
- Feature Path: MOD-1 > FEAT-1 > FEAT-1-01 > STORY-2
- DU 总数: 1

## 任务清单

本 Change 为单仓（repo-1）验收核验型交付，拆分为 1 个 DU；DU 内部 1 Commit 粒度任务由 repo 侧 task.md 细化。

### DU-BE-001: 公共模块依赖方向审计与 AC 复验留证（backend）

- 目标仓库: repo-1（implementation/ai-platform-backend）
- 目标 Goal: 按 design.md §2.2 审计规则集（R1~R4）执行"验收核验三步法"（静态 POM 审计 → dependency:tree 实证 → mvn validate 复验），完成 PRD AC-1~AC-10 逐条留证；若审计违规则执行最小 POM 修复并复验
- Scope: mall-common/mall-common-core（R1 重点）、mall-common 全部 8 子模块 POM（R2/R3）、mall-contracts 两个子模块 POM（R4）、根 POM Reactor（AC-3/AC-4 复验）；预期零 POM/代码变更
- Design References: design.md §1.2 关键事实 / §2.1 三步法 / §2.2 审计规则集 R1~R4 + 最小修复预案 / §2.3 AC 留证映射表
- Dependencies: 无
- Acceptance Criteria: PRD AC-1~AC-10 全部通过并留证——AC-1/2 模块清单完备；AC-3 Reactor 列表含 10 公共模块；AC-4 validate 复验通过（引用 CHG-0001 全量构建归档证据）；AC-5/6/7/8 复验通过（引用归档 evidence + 本 Change 静态审计）；AC-9 core 依赖方向审计通过（R1~R4 执行记录 + dependency:tree 留证）；AC-10 全部证据归档 evidence/ 并有汇总索引
- Execution Order: 1
- Parallelization: 无（单 DU）
- Implementation Sketch:
  ```text
  审计执行流程（repo-1 内）:
  1. 静态审计: 逐模块读取 mall-common/*/pom.xml + mall-contracts/*/pom.xml
     → 对照 R1(core 零依赖) / R2(公共层无横向依赖) / R3(test 方向豁免判定) / R4(契约纯度)
  2. 依赖树实证:
     mvn dependency:tree -pl mall-common/mall-common-core        → evidence/logs/dependency-tree-core.txt
     mvn dependency:tree -pl mall-contracts/mall-api-contracts   → 契约纯度留证
     mvn dependency:tree -pl mall-contracts/mall-event-contracts → 契约纯度留证
  3. 构建复验: mvn validate（根目录，全 24 项目 Reactor）→ evidence/logs/mvn-validate.txt
  4. 留证汇总: evidence/ac-verification.md（AC-1~AC-10 复验记录表 + CHG-0001 归档证据引用）
  条件分支: 任一规则违规 → 仅删除/修正违规 dependency 声明 → 重跑步骤 2+3 → 重新留证；
           跨模块依赖重构级违规 → 暂停并上报用户决策
  ```
- Pseudocode: N/A（审计/留证型任务，未命中 business-flow/algorithm/state-transition/orchestration 任一触发器；执行步骤已在 Implementation Sketch 中以命令级粒度给出）
- Verification:
  - Verification（静态）: grep 审计 mall-common 8 子模块 POM 无 `mall-common-*` 互依声明；core POM `<dependencies>` 为空
  - Verification（实证）: dependency-tree-core.txt 输出不含 mall-common-web/security/redis/mq/openfeign/log/test 节点
  - Verification（构建）: mvn validate 输出 Reactor Summary 24 项目全 BUILD SUCCESS
  - Error Case: validate 失败（enforcer 环境守门触发）→ 记录环境问题单独处理，不视为 AC 失败；审计违规 → 走最小修复预案分支
