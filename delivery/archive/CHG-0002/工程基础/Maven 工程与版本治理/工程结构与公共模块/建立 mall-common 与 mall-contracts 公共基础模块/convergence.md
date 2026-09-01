# Convergence

> 阶段：sdd-converge 产物
> 输入：completed change（全部 Artifact 已产出）
> 产出状态：completed

本文档记录本次 Change 的知识收敛过程。真正的知识更新发生在 Workspace Knowledge 中（写回 standards/product/），本文件只记录"该不该更新、更新了什么、为什么"。

## 0. 元信息

- Change ID: CHG-0002
- 完成时间: 2026-08-31T23:58:00+08:00
- 状态流转: testing → completed
- 产出 Artifact 数: 8（exploration / prd / design / tasks / implementation / test-report / review-report / convergence）

## 1. 知识变化总结

- 知识增量摘要:
  1. **能力状态**：STORY-2（mall-common 与 mall-contracts 公共基础模块）经验收核验确认 delivered——复用 CHG-0001 交付基线（350304b）零漂移，AC-1~AC-10 复验全部通过，新增 ENG-BASE-002 唯一增量要求"mall-common-core 依赖方向审计"获得实证（依赖树零依赖，无 Web/Redis/MQ/OpenFeign 反向依赖）。
  2. **可复用交付模式**：验收核验型 Change 以 test-run 条目记录验证命令（mvn validate / dependency:tree / 静态审计分组），复用 evidence-coverage 机检通道，无需传统测试用例——该模式在本次交付中闭环验证可行。
  3. **环境运行知识（非规则）**：沙箱禁止终端写工作区外 Maven 本地仓库，Maven 命令需以 -Dmaven.repo.local 指向工作区内临时仓库；harness CLI v0.2.0 存在 workflow run 上下文装配崩溃、du sync-status meta 缺陷、gate check 不含 review 同态阶段——以核心引擎（TransitionService / gate-validator）直接调用为合法绕过路径。

## 2. 更新判断

四项知识载体逐一判断（Standards / Product / feature-tree.yaml / Glossary），结论：Product 与 feature-tree.yaml 需写回（已在 §3 执行），Standards 与 Glossary 明确不更新；逐项依据如下。

### Standards

- 是否需更新: no <!-- yes/no -->
- 更新内容: 无
- 理由: 本次为零代码变更的核验型交付，未产生新的编码/架构/流程长期约束；沙箱适配与 CLI 缺陷属环境与工具运行知识，已按"规则世界只放长期约束"原则记录于 Change 证据（implementation.md §3 DEV-1）与项目记忆，不写入 standards/。

### Product

- 是否需更新: yes <!-- yes/no -->
- 更新内容: `product/features/工程基础/Maven 工程与版本治理/工程结构与公共模块/建立 mall-common 与 mall-contracts 公共基础模块/README.md`——front-matter status: planned → delivered，补充 CHG-0002 核验结论（AC-1~AC-10 全过、core 零反向依赖实证、基线零漂移）及证据索引，保持 CHG-* 关联引用。
- 理由: Story 能力状态由计划变为已交付，且本次核验产生了可长期引用的边界结论（core 零依赖、契约纯度），属于产品知识增量，应回写能力 README。

### feature-tree.yaml

- 是否需更新: yes <!-- yes/no -->
- 更新内容: STORY-2 节点 status: planned → delivered（对齐 STORY-1 的状态约定 planned / in-progress / delivered）。
- 理由: 树是能力交付状态的唯一权威源，Change completed 前必须同步。

### Glossary

- 是否需更新: no <!-- yes/no -->
- 更新内容: 无
- 理由: "验收核验型 Change"属 SDD 交付方法论语境词汇（已在 exploration/design/review 留痕），非业务统一语言范畴，2-统一语言词汇表面向业务概念，不引入交付术语。

## 3. 知识沉淀过程

- 已写回：product/feature-tree.yaml（STORY-2 → delivered）；product/features/ 下 STORY-2 README（status → delivered + 核验结论与证据索引）。
- 不写回：standards/（无长期规则增量）、glossary/（无业务术语增量）——判断依据见 §2。
- 留待后续：沙箱 Maven 本地仓库适配、harness CLI v0.2.0 已知缺陷（workflow run 崩溃 / du sync-status meta / review 同态阶段缺 CLI 入口）登记在项目记忆与本次 Change 证据中；待 harness 升级修复后复核绕过路径是否可撤销。

## 4. 完成确认

- [x] 代码变更已完成（核验型：预期零代码变更成立，HEAD 与 baseline 一致）
- [x] 测试已完成（验收核验 32/32 通过，test-report.md 双门禁通过）
- [x] 证据已收集（evidence.yaml EV-001~EV-005 + logs/ 4 文件 + ac-verification.md）
- [x] 知识更新已评估（四项判断完成：Product/feature-tree 写回，Standards/Glossary 明确不更新）
