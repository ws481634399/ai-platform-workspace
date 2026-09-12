# Test Report — CHG-0007 M1 独立测试

> change-id: CHG-0007
> evidence-index: evidence/evidence.yaml
> from-state: developing
> proposed-state: testing
> tested-at: 2026-09-12T17:02:00+08:00
> conclusion: PARTIAL — gate blocked by TC traceability

## 1. 测试范围

### 1.1 repo-1

- DU：DU-BE-101、DU-BE-102、DU-BE-103、DU-BE-104、DU-BE-105、DU-BE-106、DU-BE-107、DU-BE-108
- 命令：`mvn -q -pl mall-gateway,mall-services/mall-identity -am test`
- 结果：JUnit/Spring/H2/Flyway/MyBatis：58/58 通过；含 DDD 分层架构与持久化集成测试。
- 环境提示：mvn clean test 曾因 mall-identity JAR 被本机进程占用而无法删除 target；清理 Surefire 报告后，非 clean 独立重跑退出码 0。

### 1.2 repo-2

- DU：DU-FE-101
- 命令：`vitest run + vue-tsc + eslint + vite build`
- 结果：Vitest 5 files / 10 tests 通过；vue-tsc 通过；ESLint 0 error / 46 warnings；Vite build 通过。
- 环境提示：系统 pnpm.ps1 首次因 Node PATH/非交互重装保护失败；改用工程现有 node_modules/.bin 与绑定 Node 运行时后全部退出码 0。

测试输入严格来自本 Change 的 prd/design、9 个 Story 的 test-design.md，以及 DU metadata；未以 implementation.md 作为断言来源。

## 2. 执行汇总

| 检查类型 | 总数 | 通过 | 失败 | 跳过 | 结论 |
|---|---:|---:|---:|---:|---|
| 后端自动化（共享 M1 套件） | 58 | 58 | 0 | 0 | PASS |
| 前端 Vitest（共享 M1 套件） | 10 | 10 | 0 | 0 | PASS |
| TC 验收意图 | 27 | 0（未逐条证明） | 0 | 27 | PARTIAL |

说明：自动化测试没有失败；但“测试通过”不能替代 TC→自动化用例的可追踪证据，故不虚报 TC 通过率。

## 3. TC/AC 覆盖矩阵

| TC | AC | DU | 验证方式 | 结果 | 独立测试结论 |
|---|---|---|---|---|---|
| STORY-001-01-01-01/TC-001 | AC-001 | DU-BE-101 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-01-01/TC-002 | AC-002 | DU-BE-101 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-01-01/TC-003 | AC-003 | DU-BE-101 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-01-02/TC-001 | AC-001 | DU-BE-102 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-01-02/TC-002 | AC-002 | DU-BE-102 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-01-02/TC-003 | AC-003 | DU-BE-102 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-02-01/TC-001 | AC-001 | DU-BE-103 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-02-01/TC-002 | AC-002 | DU-BE-103 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-02-01/TC-003 | AC-003 | DU-BE-103 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-02-02/TC-001 | AC-001 | DU-BE-104 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-02-02/TC-002 | AC-002 | DU-BE-104 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-02-02/TC-003 | AC-003 | DU-BE-104 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-02-03/TC-001 | AC-001 | DU-BE-105 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-02-03/TC-002 | AC-002 | DU-BE-105 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-02-03/TC-003 | AC-003 | DU-BE-105 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-03-01/TC-001 | AC-001 | DU-BE-106 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-03-01/TC-002 | AC-002 | DU-BE-106 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-03-01/TC-003 | AC-003 | DU-BE-106 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-03-02/TC-001 | AC-001 | DU-BE-107 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-03-02/TC-002 | AC-002 | DU-BE-107 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-03-02/TC-003 | AC-003 | DU-BE-107 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-03-03/TC-001 | AC-001 | DU-BE-108 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-03-03/TC-002 | AC-002 | DU-BE-108 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-03-03/TC-003 | AC-003 | DU-BE-108 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-04-01/TC-001 | AC-001 | DU-FE-101 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-04-01/TC-002 | AC-002 | DU-FE-101 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-01-04-01/TC-003 | AC-003 | DU-FE-101 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |

## 4. 证据清单

- DU-BE-101 → implementation/ai-platform-backend/delivery/CHG-0007/stories/STORY-001-01-01-01/DU-BE-101/evidence/test-output.log
- DU-BE-102 → implementation/ai-platform-backend/delivery/CHG-0007/stories/STORY-001-01-01-02/DU-BE-102/evidence/test-output.log
- DU-BE-103 → implementation/ai-platform-backend/delivery/CHG-0007/stories/STORY-001-01-02-01/DU-BE-103/evidence/test-output.log
- DU-BE-104 → implementation/ai-platform-backend/delivery/CHG-0007/stories/STORY-001-01-02-02/DU-BE-104/evidence/test-output.log
- DU-BE-105 → implementation/ai-platform-backend/delivery/CHG-0007/stories/STORY-001-01-02-03/DU-BE-105/evidence/test-output.log
- DU-BE-106 → implementation/ai-platform-backend/delivery/CHG-0007/stories/STORY-001-01-03-01/DU-BE-106/evidence/test-output.log
- DU-BE-107 → implementation/ai-platform-backend/delivery/CHG-0007/stories/STORY-001-01-03-02/DU-BE-107/evidence/test-output.log
- DU-BE-108 → implementation/ai-platform-backend/delivery/CHG-0007/stories/STORY-001-01-03-03/DU-BE-108/evidence/test-output.log
- DU-FE-101 → implementation/ai-platform-frontend/delivery/CHG-0007/stories/STORY-001-01-04-01/DU-FE-101/evidence/test-output.log

## 5. 失败与缺口分析

- 产品代码测试失败：0。
- 阻断项：test-design 中 TC 未绑定到自动化用例名称或独立结果，evidence-trace 只能证明套件通过，不能证明 27/27 TC 完成。
- 前端 Lint 有 46 个格式 warning、0 error，不阻断代码正确性，但应在质量收敛前处理。
- 本机两次操作性失败（pnpm Node PATH、Maven clean 文件锁）均已采用不修改产品代码的方式恢复并成功重跑。

## 6. 测试结论

自动化回归为绿色，但验收证据追踪不完整。本报告建议保持 Change 为 developing，补齐 TC 编号级测试或明确可接受的替代验证后再批准进入 testing。
