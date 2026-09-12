# Test Report — CHG-0008 M1 独立测试

> change-id: CHG-0008
> evidence-index: evidence/evidence.yaml
> from-state: developing
> proposed-state: testing
> tested-at: 2026-09-12T17:02:00+08:00
> conclusion: PARTIAL — gate blocked by TC traceability

## 1. 测试范围

### 1.1 repo-1

- DU：DU-BE-201、DU-BE-202、DU-BE-203、DU-BE-204、DU-BE-205、DU-BE-206、DU-BE-207、DU-BE-208、DU-BE-209
- 命令：`mvn -q -pl mall-gateway,mall-services/mall-identity -am test`
- 结果：JUnit/Spring/H2/Flyway/MyBatis：58/58 通过；含 DDD 分层架构与持久化集成测试。
- 环境提示：mvn clean test 曾因 mall-identity JAR 被本机进程占用而无法删除 target；清理 Surefire 报告后，非 clean 独立重跑退出码 0。

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
| STORY-001-02-01-01/TC-001 | AC-001 | DU-BE-201 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-01-01/TC-002 | AC-002 | DU-BE-201 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-01-01/TC-003 | AC-003 | DU-BE-201 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-01-02/TC-001 | AC-001 | DU-BE-202 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-01-02/TC-002 | AC-002 | DU-BE-202 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-01-02/TC-003 | AC-003 | DU-BE-202 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-01-03/TC-001 | AC-001 | DU-BE-203 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-01-03/TC-002 | AC-002 | DU-BE-203 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-01-03/TC-003 | AC-003 | DU-BE-203 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-02-01/TC-001 | AC-001 | DU-BE-204 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-02-01/TC-002 | AC-002 | DU-BE-204 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-02-01/TC-003 | AC-003 | DU-BE-204 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-02-02/TC-001 | AC-001 | DU-BE-205 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-02-02/TC-002 | AC-002 | DU-BE-205 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-02-02/TC-003 | AC-003 | DU-BE-205 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-02-03/TC-001 | AC-001 | DU-BE-206 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-02-03/TC-002 | AC-002 | DU-BE-206 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-02-03/TC-003 | AC-003 | DU-BE-206 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-03-01/TC-001 | AC-001 | DU-BE-207 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-03-01/TC-002 | AC-002 | DU-BE-207 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-03-01/TC-003 | AC-003 | DU-BE-207 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-03-02/TC-001 | AC-001 | DU-BE-208 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-03-02/TC-002 | AC-002 | DU-BE-208 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-03-02/TC-003 | AC-003 | DU-BE-208 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-03-03/TC-001 | AC-001 | DU-BE-209 | Unit/集成测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-03-03/TC-002 | AC-002 | DU-BE-209 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |
| STORY-001-02-03-03/TC-003 | AC-003 | DU-BE-209 | API/安全边界测试 | PARTIAL | 自动化套件绿，但缺少 TC 编号级直接证据 |

## 4. 证据清单

- DU-BE-201 → implementation/ai-platform-backend/delivery/CHG-0008/stories/STORY-001-02-01-01/DU-BE-201/evidence/test-output.log
- DU-BE-202 → implementation/ai-platform-backend/delivery/CHG-0008/stories/STORY-001-02-01-02/DU-BE-202/evidence/test-output.log
- DU-BE-203 → implementation/ai-platform-backend/delivery/CHG-0008/stories/STORY-001-02-01-03/DU-BE-203/evidence/test-output.log
- DU-BE-204 → implementation/ai-platform-backend/delivery/CHG-0008/stories/STORY-001-02-02-01/DU-BE-204/evidence/test-output.log
- DU-BE-205 → implementation/ai-platform-backend/delivery/CHG-0008/stories/STORY-001-02-02-02/DU-BE-205/evidence/test-output.log
- DU-BE-206 → implementation/ai-platform-backend/delivery/CHG-0008/stories/STORY-001-02-02-03/DU-BE-206/evidence/test-output.log
- DU-BE-207 → implementation/ai-platform-backend/delivery/CHG-0008/stories/STORY-001-02-03-01/DU-BE-207/evidence/test-output.log
- DU-BE-208 → implementation/ai-platform-backend/delivery/CHG-0008/stories/STORY-001-02-03-02/DU-BE-208/evidence/test-output.log
- DU-BE-209 → implementation/ai-platform-backend/delivery/CHG-0008/stories/STORY-001-02-03-03/DU-BE-209/evidence/test-output.log

## 5. 失败与缺口分析

- 产品代码测试失败：0。
- 阻断项：test-design 中 TC 未绑定到自动化用例名称或独立结果，evidence-trace 只能证明套件通过，不能证明 27/27 TC 完成。
- 前端 Lint 有 46 个格式 warning、0 error，不阻断代码正确性，但应在质量收敛前处理。
- 本机两次操作性失败（pnpm Node PATH、Maven clean 文件锁）均已采用不修改产品代码的方式恢复并成功重跑。

## 6. 测试结论

自动化回归为绿色，但验收证据追踪不完整。本报告建议保持 Change 为 developing，补齐 TC 编号级测试或明确可接受的替代验证后再批准进入 testing。
