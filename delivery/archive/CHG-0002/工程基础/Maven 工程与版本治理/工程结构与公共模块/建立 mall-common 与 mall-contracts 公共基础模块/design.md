---
affected-repositories: [repo-1]
---

# Design

> 阶段：sdd-design 产物
> 输入：prd.md
> 产出状态：designed

本文档制定技术方案。

## 0. 元信息

- Change ID: CHG-0002
- PRD 来源: prd.md（CHG-0002）
- 状态流转: specified → designed

## 1. 当前状态

CHG-0001 已交付 24 项目 Maven 骨架与两层公共层结构；本节以 2026-08-31 实证勘察结果记录与本 Change 直接相关的架构现状与关键事实。

### 1.1 架构现状（已实证勘察，2026-08-31）

M0 工程骨架由 CHG-0001 交付：Maven 聚合根 `backend`（24 个 Reactor 项目）+ mall-bom 版本权威 + 两层公共层 + 网关/服务骨架。与本 Change 直接相关的现状证据：

```
backend/                                # 聚合根 POM（com.ai-mall:backend）
├── mall-bom/                           # 版本唯一权威（BOM import）
├── mall-common/                        # 技术复用层聚合（packaging=pom，8 modules）
│   ├── mall-common-core/               # "纯 Java，零第三方依赖"（POM 无 <dependencies>）
│   ├── mall-common-web/
│   ├── mall-common-security/
│   ├── mall-common-redis/
│   ├── mall-common-mq/
│   ├── mall-common-openfeign/
│   ├── mall-common-log/
│   └── mall-common-test/               # 仅依赖 spring-boot-starter-test（test scope）
├── mall-contracts/                     # 契约层聚合（2 modules，纯契约零第三方依赖）
├── mall-gateway/
└── mall-services/                      # 8 个业务服务骨架
```

### 1.2 关键事实（设计依据）

1. **mall-common-core 当前 POM 零依赖**：`mall-common/mall-common-core/pom.xml` 无 `<dependencies>` 段，description 明示"纯 Java，零第三方依赖"——即当前**不存在**反向依赖 web/redis/mq/openfeign/security/log 的事实（静态层面）。
2. **公共层内部零横向依赖**：对 mall-common 全部 8 个子模块 POM 的 grep 审计显示，无任何子模块声明对其他 `mall-common-*` 模块的依赖（含 test）。
3. **根 POM enforcer 已守门**：`requireMavenVersion [3.9,)` + `requireJavaVersion [21,22)`，全模块生效。
4. **CHG-0001 归档 evidence 可引用**：AC-7（公共模块无业务领域）/ AC-8（契约纯契约）/ AC-9（无服务间实现依赖）/ 全量构建 24/24 BUILD SUCCESS 均已留档。

### 1.3 结论

结构层满足需求，静态层面预期零违规。本 Change 的设计重心不是"建结构"，而是**建立可复核的依赖方向审计方法并留证**，将隐式约定转化为显式证据。

- 当前架构模式: Maven 多模块单体仓（monorepo），聚合根 + BOM 版本权威 + 两层公共层（技术复用层/契约层）
- 相关仓库: repo-1
- 相关模块: mall-common（聚合 + 8 子模块）、mall-contracts（聚合 + 2 子模块）；根 POM 与业务服务 POM 预期零改动

## 2. 提议方案

本 Change 为验收核验型：不重建结构，而是建立"审计规则集 + 三步核验法 + 逐条留证"的可复核方案，预期零代码变更。

### 2.1 方案概要

**验收核验三步法**（零代码变更路径，仅当审计违规时触发最小修复）：

```
Step 1  静态 POM 审计   逐模块核对 POM 依赖声明 vs 审计规则集（§2.2）
Step 2  依赖树实证       mvn dependency:tree 输出 core 与 contracts 的解析后依赖（含传递依赖）
Step 3  构建复验         mvn validate 全模块快速复验（引用 CHG-0001 全量构建归档证据补强 AC-4）
```

- 方案概要: 复用既有 10 个公共模块结构；按审计规则集执行静态 POM 审计 + dependency:tree 实证 + validate 复验，AC-1~AC-10 逐条留证至 evidence/
- 关键组件: 审计规则集（4 条规则 + 1 条豁免条款）、审计留证模板（AC 复验记录表）、条件性最小修复预案
- 接口契约: 无新增对外接口（本 Change 不产生 API/Event 契约变更）

### 2.2 审计规则集（本 Change 的核心设计产物）

| # | 规则 | 判定标准 | 审计手段 |
|---|------|---------|---------|
| R1 | core 零反向依赖 | `mall-common-core` 的 POM `<dependencies>` 为空；dependency:tree 输出不含任何 `mall-common-web/security/redis/mq/openfeign/log/test` 节点 | 静态 POM 审查 + `dependency:tree -pl mall-common/mall-common-core` |
| R2 | 公共层无横向依赖 | `mall-common-web/security/redis/mq/openfeign/log` 互相之间不得依赖（避免同层耦合与循环） | 全部 8 个子模块 POM 静态审查 + Reactor 依赖解析 |
| R3 | test 豁免条款 | `mall-common-test` **允许**依赖其他 `mall-common-*` 模块（测试工具链聚合方向，scope 限 test 工具用途）；**禁止**其他 common 模块依赖 test。当前事实：test 仅依赖 spring-boot-starter-test（test scope），无 common 内部依赖，本条款为面向后续迭代的预防性规则 | POM 静态审查（方向判定） |
| R4 | 契约层纯度 | `mall-api-contracts` / `mall-event-contracts` POM 零第三方依赖、零 common 依赖（纯数据形状） | 静态 POM 审查 + dependency:tree |

**条件性最小修复预案**（仅当 R1~R4 审计违规时执行）：
- 修复范围：仅移除/修正违规的 `<dependency>` 声明，不新增任何代码；
- 修复后必须重跑 Step 2 + Step 3 复验并重新留证；
- 修复决策升级：若违规涉及跨模块依赖重构，暂停修复并向用户上报决策（当前勘察结论：该情形概率极低，core POM 已确认零依赖）。

### 2.3 AC 复验留证设计（对应 PRD §4 证据策略）

| AC | 证据来源 | 留证位置 |
|----|---------|---------|
| AC-1/2 | 模块目录 + 聚合 POM modules 清单核对 | evidence/ac-verification.md 记录表 |
| AC-3 | mvn validate 输出 Reactor 列表（24 项目） | evidence/logs/mvn-validate.txt |
| AC-4 | 本 Change validate 复验 + 引用 CHG-0001 全量构建归档证据（24/24 BUILD SUCCESS） | evidence/ac-verification.md 引用归档路径 |
| AC-5/6/7/8 | 引用 CHG-0001 归档 evidence + 本 Change POM 静态审计结论（无新增代码，基线未漂移） | evidence/ac-verification.md |
| AC-9 | R1~R4 审计执行记录 + core dependency:tree 输出 | evidence/logs/dependency-tree-core.txt |
| AC-10 | 上述全部证据汇总索引 | evidence/ac-verification.md |

## 3. 仓库影响（Repository Impact）

- 受影响仓库数: 1
- 主要修改点: repo-1（implementation/ai-platform-backend）——预期**零 POM/代码变更**；本 Change 在 repo-1 内执行审计命令并产出留证文件（审计输出与依赖树日志不入库 repo-1，归档于工作区仓 evidence/）

### 3.1 repo-1

- 技术职责: 承载 10 个公共模块结构，作为审计对象提供 POM/依赖树/构建输出等实证材料
- 修改概要: 预期零修改；条件性预案——仅当审计规则 R1~R4 违规时做最小 POM 依赖声明修正
- 涉及模块: mall-common/mall-common-core（R1 重点）、mall-common 全部子模块（R2/R3）、mall-contracts 两个子模块（R4）

## 4. 跨仓协作（Cross-Repository Contract）

- 接口契约: 无（单仓需求）
- 仓库依赖: 无
- 集成边界: 无
- 跨仓时序: 无

## 5. 数据变更

- 是否需 Migration: no
- 变更摘要: 无数据库结构变更（本 Change 仅涉及模块依赖边界核验）

## 6. 风险

- 风险等级: 低
- 主要风险:
  - 审计发现 core 反向依赖（可能性：极低，静态勘察已确认 core POM 零依赖）
  - 依赖树实证与静态审计结论不一致（传递依赖引入违规模块）
  - Maven 环境漂移导致 validate 复验失败（JDK/Maven 版本不满足 enforcer 要求）
- 缓解措施:

| 风险项 | 级别 | 缓解措施 |
|--------|------|---------|
| core 反向依赖违规 | 低 | 静态 POM 审计 + dependency:tree 双重验证；违规即触发最小修复预案（仅删依赖声明） |
| 传递依赖绕过 POM 声明 | 中 | Step 2 使用 dependency:tree 解析后依赖树留证，覆盖传递依赖路径 |
| 构建环境漂移 | 低 | 根 POM enforcer 已守门（Maven 3.9+ / JDK [21,22)），validate 失败即暴露环境问题并单独处理 |
| 证据不完整影响后续复用 | 中 | §2.3 留证设计明确每个 AC 的证据来源与位置，AC-10 汇总索引兜底 |

## 7. 待澄清问题

- 无需用户当前决策的事项。PRD §4 已确认证据策略（引用归档 + 新增 core 审计 + validate 复验）；mall-common-test 豁免条款细则已在本设计 §2.2 R3 正式定义（当前 test 模块无 common 内部依赖，条款为预防性规则）。
- 需调查的技术可行性: 无（审计手段均为 Maven 标准能力，无外部依赖）。
