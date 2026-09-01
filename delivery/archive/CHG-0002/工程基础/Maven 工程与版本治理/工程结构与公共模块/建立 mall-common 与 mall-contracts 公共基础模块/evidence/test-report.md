# Test Report

> 阶段：sdd-test 产物
> 位置：<CHG>/evidence/test-report.md
> 输入：implementation.md + tasks.md
> 产出状态：testing

本文档记录测试执行情况与证据。本 Change 为验收核验型（预期零代码变更），无传统单元/集成/E2E 用例，"测试"即 DU-BE-001 定义的验收核验命令集。

## 0. 元信息

- Change ID: CHG-0002
- Implementation 来源: 工程基础/Maven 工程与版本治理/工程结构与公共模块/建立 mall-common 与 mall-contracts 公共基础模块/implementation.md
- 状态流转: developing → testing
- 执行时间: 2026-08-31T23:46:00+08:00
- Evidence 索引: evidence/evidence.yaml（EV-001 ~ EV-005）

## 1. 测试范围

- 测试范围摘要: 对 CHG-0001 交付基线（repo-1 HEAD 350304b，零漂移）执行 ENG-BASE-002 的验收核验——静态 POM 审计（R1 core 零依赖 / R2 公共层无横向互依 / R3 test 方向豁免判定 / R4 契约纯度）、mvn dependency:tree 依赖方向实证（mall-common-core + mall-api-contracts + mall-event-contracts）、mvn validate 全 Reactor 构建复验（enforcer Maven 3.9+ / Java 21 守门）
- 覆盖 DU: DU-BE-001（repo-1 / implementation/ai-platform-backend，status=completed，baseline=result=350304b）
- 测试类型: 结构核验（静态审计 + 依赖树实证 + 构建复验）；测试环境: Maven 3.9.x / Java 21 / Windows + Trae 沙箱
- 关联 PRD: CHG-0002 验收标准 AC-1 ~ AC-10 逐条映射，无遗漏

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| ---- | ---- | ---- | ---- | ---- |
| 静态审计（R1~R4 规则集分组检查，EV-005） | 5 | 5 | 0 | 0 |
| 依赖树实证（dependency:tree × 3 模块，EV-002~004） | 3 | 3 | 0 | 0 |
| 构建复验（mvn validate 24 项目 Reactor + enforcer，EV-001） | 24 | 24 | 0 | 0 |
| 合计 | 32 | 32 | 0 | 0 |

- 通过率: 100%（32/32；evidence.yaml EV-001 ~ EV-005 全部 result=passed）
- AC 覆盖矩阵: EV-005 → AC-1/AC-2/AC-5/AC-6/AC-7/AC-9/AC-10；EV-001 → AC-3/AC-4/AC-8；EV-002~EV-004 → AC-9；AC-1 ~ AC-10 全覆盖、全通过，逐条复验记录见 evidence/ac-verification.md §2

## 3. 证据清单

- evidence/evidence.yaml — 结构化证据索引（test-run × 5，全部 passed）
- evidence/ac-verification.md — AC-1~AC-10 复验记录（§1 规则执行记录 / §2 AC 复验表 / §3 审计明细）
- evidence/logs/mvn-validate.txt — mvn validate 全量输出（24 项目 BUILD SUCCESS，enforcer 守门通过）
- evidence/logs/dependency-tree-core.txt — mall-common-core 依赖树（仅自身坐标一行，零依赖，AC-9 核心证据）
- evidence/logs/dependency-tree-api-contracts.txt — mall-api-contracts 依赖树（契约纯度留证）
- evidence/logs/dependency-tree-event-contracts.txt — mall-event-contracts 依赖树（契约纯度留证）
- evidence-ref（不复制正文）: repo-1 DU-BE-001 侧 evidence → implementation/ai-platform-backend/delivery/ 下 DU-BE-001/evidence/（commits.md / changeset.md，Workspace DU metadata.evidence-ref 已登记）

## 4. 失败项分析

无失败项。执行期环境偏离 1 项（DEV-1，与 implementation.md §3 记录一致）：沙箱禁止终端写工作区外 Maven 本地仓库 D:\maven-repository，dependency:tree 改经 -Dmaven.repo.local 指向工作区内 .m2-sandbox 执行；仅影响插件下载缓存路径，不影响依赖解析结果与审计结论，不构成本 Change 验收风险。
