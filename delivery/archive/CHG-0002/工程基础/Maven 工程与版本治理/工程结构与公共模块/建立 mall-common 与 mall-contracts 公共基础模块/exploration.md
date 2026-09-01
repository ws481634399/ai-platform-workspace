# Exploration

> 阶段：sdd-explore 产物
> 输入：Requirement（requirement.md，原始文档归档于 references/ENG-BASE-002.md）
> 产出状态：exploring（推进 Change 状态）

本文档记录 sdd-explore 阶段的探索结果。

## 1. 需求理解

ENG-BASE-002 的本质是固化"技术复用层（mall-common）+ 跨服务契约层（mall-contracts）"两层公共边界并保持业务领域模型隔离。经与已归档的 CHG-0001（ENG-BASE-001）重叠分析，其 9 条验收标准中 8.5 条已由 CHG-0001 结构交付覆盖，唯一形式化增量为「mall-common-core 不反向依赖上层模块」的显式审计。因此本 Change 定位为**验收核验型**：复用既有结构、审计依赖方向、复验 AC 留证，预期零代码变更（详见下方 §1.2 对照表）。

### 1.1 需求本质

表面上是"建立 10 个公共模块"，实际意图是**固化两层公共边界**：

1. **技术复用层（mall-common，8 子模块）**——只提供横切技术能力（core/web/security/redis/mq/openfeign/log/test），承载的是"怎么用框架"的基础设施代码；
2. **跨服务契约层（mall-contracts，2 子模块）**——只承载跨服务边界的稳定数据形状（API Request/Response、内部服务 DTO、集成事件、事件公共元数据）。

两层的存在都服务于同一个架构目标：**防止业务领域模型渗入公共层，避免演化为强耦合的分布式单体**。跨服务协作必须走 API Contract / OpenFeign / Integration Event，而不是 Maven 直接依赖对方的业务实现模块。

### 1.2 与前置需求 ENG-BASE-001（CHG-0001）的重叠分析

关键事实：CHG-0001（已归档，`delivery/archive/CHG-0001/`）在搭建 Maven 多模块骨架时**已经按 ENG-BASE-001 §11~12 的边界要求交付了全部 10 个公共模块的目录结构与依赖声明**（AC-7 公共模块无业务领域 / AC-8 契约模块纯契约 / AC-9 无服务间 Maven 依赖，均已验证并留档 evidence/）。

逐条对照 ENG-BASE-002 的 9 条验收标准：

| # | ENG-BASE-002 验收标准 | CHG-0001 对应交付 | 状态 |
|---|----------------------|------------------|------|
| 1 | mall-common 8 个子模块全部存在 | mall-common/ 下 8 子模块 + 聚合 POM | ✅ 已交付 |
| 2 | mall-contracts 2 个子模块全部存在 | mall-contracts/ 下 2 子模块 + 聚合 POM | ✅ 已交付 |
| 3 | 所有模块已加入 Maven Reactor | 根 POM 聚合 24 项目，Reactor 全识别 | ✅ 已交付 |
| 4 | 根目录 Maven 全量构建成功 | mvn clean package 24/24 BUILD SUCCESS | ✅ 已交付 |
| 5 | mall-common 无具体业务领域模型 | AC-7 验证（源码仅 package-info.java） | ✅ 已交付 |
| 6 | mall-contracts 无领域和持久化实现 | AC-8 验证（零第三方依赖纯契约） | ✅ 已交付 |
| 7 | 无业务服务间直接 Maven 实现依赖 | AC-9 验证 | ✅ 已交付 |
| 8 | 不存在 Maven 循环依赖 | enforcer + 全量构建依赖解析 | ✅ 已交付 |
| 9 | 各模块职责边界明确 | design.md §2.4 模块定位依赖表 | ✅ 已交付 |

**唯一形式化增量**：ENG-BASE-002 需求要求第 6 条「`mall-common-core` 不应反向依赖 Web、Redis、MQ、OpenFeign 等上层模块」——CHG-0001 的 AC 清单未将其单列为独立验收项（当时通过"各模块仅声明定位所需依赖"的设计约定隐式满足）。本 Change 需要对该依赖方向做**显式审计并留证**。

**结论**：本 Change 定位为**验收核验型 Change**——结构交付复用 CHG-0001 成果，不重复建设；工作量为依赖方向审计 + 9 条 AC 的独立复验留证 + （若审计发现违规）最小修复。不提前实现统一响应/异常/JWT/Redis 业务等能力（明确在非本需求范围）。

### 1.3 隐含需求分析

- **mall-common-test 的特殊性**：test 模块通常依赖其他 common 模块（提供测试工具链），依赖方向是"上层聚合"而非"被上层依赖"，审计时需单独判定其合法性，不应机械套用"core 不依赖上层"。
- **空模块 ≠ 空目录**：Maven 子模块必须至少有可编译内容（当前为 package-info.java），本轮不新增任何业务/工具类。
- **约束传递**：后续任何 Change 往公共模块加代码时，本 Change 固化的边界就是 review/test 的检查依据——因此审计结论应沉淀为可复用的检查项（候选：framework-standard §7.4 已有依赖边界规则，本 Change 验证后可直接引用，预计 converge 阶段 no-update 或仅补充 core 方向细则）。

## 2. Feature 归属

- Feature ID: STORY-2
- Feature 路径: MOD-1（工程基础）> FEAT-1（Maven 工程与版本治理）> FEAT-1-01（工程结构与公共模块）> STORY-2（建立 mall-common 与 mall-contracts 公共基础模块）
- 是否新建 candidate: no（FEAT-1 已存在，STORY-2 为 explore 阶段新增 planned 节点，已通过 `openspec change bind-feature-path` 绑定）

说明：工程树已随 Harness v0.2.0 迁移为四级 schema 2 结构（L1→L2→L3→Story），保留 MOD-1/FEAT-1/STORY-1 旧 ID 以维持 CHG-0001 归档 metadata 的引用一致性。

## 3. 影响分析

- 受影响仓库: repo-1（implementation/ai-platform-backend）
- 受影响模块: mall-common（聚合 + 8 子模块）、mall-contracts（聚合 + 2 子模块）；根 POM / 业务服务 POM 预计**零改动**
- 影响范围:
  - **预期零代码变更**：10 个模块结构与依赖声明已存在且满足需求；本 Change 主要产出为审计证据
  - **唯一可能的代码变更**：若 core 依赖方向审计发现违规（如 core POM 混入 web/redis/mq/openfeign 依赖），做最小 POM 修正——基于 CHG-0001 设计约定，此为小概率事件
  - 工作区仓：CHG-0002 交付过程文档（本 Change 目录）
- 现有功能影响: 无（所有服务为空骨架，无运行时行为变化）
- 数据迁移: 无

## 4. 未知问题

- mall-common-core 当前 POM 的实际依赖集合是否严格满足"不反向依赖上层"？（CHG-0001 未做单模块方向审计，dev 阶段以 dependency:tree + POM 审计实证，若违规按最小修复处理）
- mall-common-test 依赖其他 common 模块的"测试工具链"方向是否需要在本 Change 显式留证为合法例外？（拟在 design 阶段定义为审计规则的明确豁免条款）
- ENG-BASE-002 的 AC 复验是否需要重新执行全量构建，还是引用 CHG-0001 evidence？（拟采用：引用归档证据 + 新增 core 方向审计实证 + 一次快速 validate 复验，最终以 PRD/design 阶段与用户确认为准）

## 5. 旧需求沿用判断

- 匹配进行中 Change: 无
- 匹配 archived Change: CHG-0001（ENG-BASE-001，delivered→archived；其 TASK-001~011 已交付本需求全部结构成果）
- 决策: 新建 CHG-0002（沿用不可行——CHG-0001 已归档且 Requirement 不同；ENG-BASE-002 作为独立 Requirement 需要独立交付闭环。本 Change 收敛为核验型，避免重复建设）
