# Test Report — CHG-0009 M1 独立测试

> change-id: CHG-0009
> evidence-index: evidence/evidence.yaml
> from-state: developing
> proposed-state: testing
> tested-at: 2026-09-12T17:02:00+08:00
> conclusion: PARTIAL — gate blocked by TC traceability

## 1. 测试范围

### 1.1 repo-1

- DU：DU-BE-301、DU-BE-302
- 命令：`mvn -q -pl mall-gateway,mall-services/mall-identity -am test`
- 结果：JUnit/Spring/H2/Flyway/MyBatis：58/58 通过；含 DDD 分层架构与持久化集成测试。
- 环境提示：mvn clean test 曾因 mall-identity JAR 被本机进程占用而无法删除 target；清理 Surefire 报告后，非 clean 独立重跑退出码 0。

### 1.2 repo-2

- DU：DU-FE-301、DU-FE-302、DU-FE-303、DU-FE-304、DU-FE-305、DU-FE-306、DU-FE-307、DU-FE-308、DU-FE-309
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
| STORY-001-03-01-01/TC-001 | AC-001 | DU-BE-301 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-01-01/TC-002 | AC-002 | DU-FE-301 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-01-01/TC-003 | AC-003 | DU-FE-301 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-01-02/TC-001 | AC-001 | DU-BE-302 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-01-02/TC-002 | AC-002 | DU-FE-302 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-01-02/TC-003 | AC-003 | DU-FE-302 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-01-03/TC-001 | AC-001 | DU-FE-303 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-01-03/TC-002 | AC-002 | DU-FE-303 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-01-03/TC-003 | AC-003 | DU-FE-303 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-02-01/TC-001 | AC-001 | DU-FE-304 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-02-01/TC-002 | AC-002 | DU-FE-304 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-02-01/TC-003 | AC-003 | DU-FE-304 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-02-02/TC-001 | AC-001 | DU-FE-305 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-02-02/TC-002 | AC-002 | DU-FE-305 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-02-02/TC-003 | AC-003 | DU-FE-305 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-02-03/TC-001 | AC-001 | DU-FE-306 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-02-03/TC-002 | AC-002 | DU-FE-306 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-02-03/TC-003 | AC-003 | DU-FE-306 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-03-01/TC-001 | AC-001 | DU-FE-307 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-03-01/TC-002 | AC-002 | DU-FE-307 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-03-01/TC-003 | AC-003 | DU-FE-307 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-03-02/TC-001 | AC-001 | DU-FE-308 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-03-02/TC-002 | AC-002 | DU-FE-308 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-03-02/TC-003 | AC-003 | DU-FE-308 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-03-03/TC-001 | AC-001 | DU-FE-309 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-03-03/TC-002 | AC-002 | DU-FE-309 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-03-03-03/TC-003 | AC-003 | DU-FE-309 | 组件/E2E 测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |

## 4. 证据清单

- DU-BE-301 → implementation/ai-platform-backend/delivery/CHG-0009/stories/STORY-001-03-01-01/DU-BE-301/evidence/test-output.log
- DU-FE-301 → implementation/ai-platform-frontend/delivery/CHG-0009/stories/STORY-001-03-01-01/DU-FE-301/evidence/test-output.log
- DU-BE-302 → implementation/ai-platform-backend/delivery/CHG-0009/stories/STORY-001-03-01-02/DU-BE-302/evidence/test-output.log
- DU-FE-302 → implementation/ai-platform-frontend/delivery/CHG-0009/stories/STORY-001-03-01-02/DU-FE-302/evidence/test-output.log
- DU-FE-303 → implementation/ai-platform-frontend/delivery/CHG-0009/stories/STORY-001-03-01-03/DU-FE-303/evidence/test-output.log
- DU-FE-304 → implementation/ai-platform-frontend/delivery/CHG-0009/stories/STORY-001-03-02-01/DU-FE-304/evidence/test-output.log
- DU-FE-305 → implementation/ai-platform-frontend/delivery/CHG-0009/stories/STORY-001-03-02-02/DU-FE-305/evidence/test-output.log
- DU-FE-306 → implementation/ai-platform-frontend/delivery/CHG-0009/stories/STORY-001-03-02-03/DU-FE-306/evidence/test-output.log
- DU-FE-307 → implementation/ai-platform-frontend/delivery/CHG-0009/stories/STORY-001-03-03-01/DU-FE-307/evidence/test-output.log
- DU-FE-308 → implementation/ai-platform-frontend/delivery/CHG-0009/stories/STORY-001-03-03-02/DU-FE-308/evidence/test-output.log
- DU-FE-309 → implementation/ai-platform-frontend/delivery/CHG-0009/stories/STORY-001-03-03-03/DU-FE-309/evidence/test-output.log

## 5. 失败与缺口分析

- 产品代码测试失败：0。
- 阻断项：test-design 中 TC 未绑定到自动化用例名称或独立结果，evidence-trace 只能证明套件通过，不能证明 27/27 TC 完成。
- 前端 Lint 有 46 个格式 warning、0 error，不阻断代码正确性，但应在质量收敛前处理。
- 本机两次操作性失败（pnpm Node PATH、Maven clean 文件锁）均已采用不修改产品代码的方式恢复并成功重跑。

## 6. 测试结论

自动化回归为绿色，但验收证据追踪不完整。本报告建议保持 Change 为 developing，补齐 TC 编号级测试或明确可接受的替代验证后再批准进入 testing。
