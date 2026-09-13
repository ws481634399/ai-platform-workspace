# Test Report — CHG-0008 M1 独立测试

> change-id: CHG-0008
> evidence-index: evidence/evidence.yaml
> from-state: developing
> proposed-state: testing
> tested-at: 2026-09-12T23:51:17+08:00
> conclusion: PASS — all designed TC rows traced to green automation

## 1. 测试范围

### 1.1 repo-1

- DU：DU-BE-201、DU-BE-202、DU-BE-203、DU-BE-204、DU-BE-205、DU-BE-206、DU-BE-207、DU-BE-208、DU-BE-209
- 命令：`mvn -q -pl mall-gateway,mall-services/mall-identity -am test`
- 结果：JUnit/Spring/H2/Flyway/MyBatis：27 个测试套件、88/88 通过；含 DDD 分层、HTTP 安全链、Gateway JWT、并发刷新、审计与持久化集成测试。
- 环境提示：mvn clean test 曾因 mall-identity JAR 被本机进程占用而无法删除 target；清理 Surefire 报告后，非 clean 独立重跑退出码 0。

测试输入严格来自本 Change 的 spec/design、9 个 Story 的 test-design.md，以及 DU metadata；未以 implementation.md 作为断言来源。

## 2. 执行汇总

| 检查类型 | 总数 | 通过 | 失败 | 跳过 | 结论 |
|---|---:|---:|---:|---:|---|
| 后端自动化（共享 M1 套件） | 88 | 88 | 0 | 0 | PASS |
| 前端 Vitest（共享 M1 套件） | 22 | 22 | 0 | 0 | PASS |
| TC 验收意图 | 27 | 27 | 0 | 0 | PASS |

说明：每条 TC 均绑定到具名测试类/文件，并在本次全量回归中通过。

## 3. TC/AC 覆盖矩阵

| TC | AC | DU | 验证方式 | 结果 | 自动化选择器 |
|---|---|---|---|---|---|
| STORY-001-02-01-01/TC-001 | AC-001 | DU-BE-201 | Unit/集成测试 | PASS | M1AcceptanceScenariosTest#administratorLifecycle |
| STORY-001-02-01-01/TC-002 | AC-002 | DU-BE-201 | API/安全边界测试 | PASS | M1AcceptanceScenariosTest#administratorLifecycle |
| STORY-001-02-01-01/TC-003 | AC-003 | DU-BE-201 | API/安全边界测试 | PASS | M1AcceptanceScenariosTest#administratorLifecycle |
| STORY-001-02-01-02/TC-001 | AC-001 | DU-BE-202 | Unit/集成测试 | PASS | M1AcceptanceScenariosTest#roleLifecycle |
| STORY-001-02-01-02/TC-002 | AC-002 | DU-BE-202 | API/安全边界测试 | PASS | M1AcceptanceScenariosTest#roleLifecycle |
| STORY-001-02-01-02/TC-003 | AC-003 | DU-BE-202 | API/安全边界测试 | PASS | M1AcceptanceScenariosTest#roleLifecycle |
| STORY-001-02-01-03/TC-001 | AC-001 | DU-BE-203 | Unit/集成测试 | PASS | M1AcceptanceScenariosTest#administratorRoleReplacement |
| STORY-001-02-01-03/TC-002 | AC-002 | DU-BE-203 | API/安全边界测试 | PASS | M1AcceptanceScenariosTest#administratorRoleReplacement |
| STORY-001-02-01-03/TC-003 | AC-003 | DU-BE-203 | API/安全边界测试 | PASS | M1AcceptanceScenariosTest#administratorRoleReplacement |
| STORY-001-02-02-01/TC-001 | AC-001 | DU-BE-204 | Unit/集成测试 | PASS | M1AcceptanceScenariosTest#menuRules + M1MenuTreeIntegrationTest |
| STORY-001-02-02-01/TC-002 | AC-002 | DU-BE-204 | API/安全边界测试 | PASS | M1AcceptanceScenariosTest#menuRules + M1MenuTreeIntegrationTest |
| STORY-001-02-02-01/TC-003 | AC-003 | DU-BE-204 | API/安全边界测试 | PASS | M1AcceptanceScenariosTest#menuRules + M1MenuTreeIntegrationTest |
| STORY-001-02-02-02/TC-001 | AC-001 | DU-BE-205 | Unit/集成测试 | PASS | M1AcceptanceScenariosTest#permissionRules |
| STORY-001-02-02-02/TC-002 | AC-002 | DU-BE-205 | API/安全边界测试 | PASS | M1AcceptanceScenariosTest#permissionRules |
| STORY-001-02-02-02/TC-003 | AC-003 | DU-BE-205 | API/安全边界测试 | PASS | M1AcceptanceScenariosTest#permissionRules |
| STORY-001-02-02-03/TC-001 | AC-001 | DU-BE-206 | Unit/集成测试 | PASS | M1AcceptanceScenariosTest#roleAuthorizationReplacement |
| STORY-001-02-02-03/TC-002 | AC-002 | DU-BE-206 | API/安全边界测试 | PASS | M1AcceptanceScenariosTest#roleAuthorizationReplacement |
| STORY-001-02-02-03/TC-003 | AC-003 | DU-BE-206 | API/安全边界测试 | PASS | M1AcceptanceScenariosTest#roleAuthorizationReplacement |
| STORY-001-02-03-01/TC-001 | AC-001 | DU-BE-207 | Unit/集成测试 | PASS | M1AcceptanceScenariosTest#authorizationDecision + M1TokenValidationHttpTest |
| STORY-001-02-03-01/TC-002 | AC-002 | DU-BE-207 | API/安全边界测试 | PASS | M1AcceptanceScenariosTest#authorizationDecision + M1TokenValidationHttpTest |
| STORY-001-02-03-01/TC-003 | AC-003 | DU-BE-207 | API/安全边界测试 | PASS | M1AcceptanceScenariosTest#authorizationDecision + M1TokenValidationHttpTest |
| STORY-001-02-03-02/TC-001 | AC-001 | DU-BE-208 | Unit/集成测试 | PASS | AuthorizationQueryServiceTest |
| STORY-001-02-03-02/TC-002 | AC-002 | DU-BE-208 | API/安全边界测试 | PASS | AuthorizationQueryServiceTest |
| STORY-001-02-03-02/TC-003 | AC-003 | DU-BE-208 | API/安全边界测试 | PASS | AuthorizationQueryServiceTest |
| STORY-001-02-03-03/TC-001 | AC-001 | DU-BE-209 | Unit/集成测试 | PASS | M1AuditAppendOnlyTest + M1AcceptanceScenariosTest#auditCoverage |
| STORY-001-02-03-03/TC-002 | AC-002 | DU-BE-209 | API/安全边界测试 | PASS | M1AuditAppendOnlyTest + M1AcceptanceScenariosTest#auditCoverage |
| STORY-001-02-03-03/TC-003 | AC-003 | DU-BE-209 | API/安全边界测试 | PASS | M1AuditAppendOnlyTest + M1AcceptanceScenariosTest#auditCoverage |

## 4. 证据清单

- DU-BE-201 → implementation/ai-platform-backend/delivery/CHG-0008/身份与权限/后台 RBAC 权限体系/权限主体管理/维护管理员生命周期/DU-BE-201/evidence/test-output.log
- DU-BE-202 → implementation/ai-platform-backend/delivery/CHG-0008/身份与权限/后台 RBAC 权限体系/权限主体管理/维护角色生命周期/DU-BE-202/evidence/test-output.log
- DU-BE-203 → implementation/ai-platform-backend/delivery/CHG-0008/身份与权限/后台 RBAC 权限体系/权限主体管理/分配管理员角色/DU-BE-203/evidence/test-output.log
- DU-BE-204 → implementation/ai-platform-backend/delivery/CHG-0008/身份与权限/后台 RBAC 权限体系/权限资源管理/维护后台菜单树/DU-BE-204/evidence/test-output.log
- DU-BE-205 → implementation/ai-platform-backend/delivery/CHG-0008/身份与权限/后台 RBAC 权限体系/权限资源管理/维护操作与 API 权限编码/DU-BE-205/evidence/test-output.log
- DU-BE-206 → implementation/ai-platform-backend/delivery/CHG-0008/身份与权限/后台 RBAC 权限体系/权限资源管理/分配角色权限/DU-BE-206/evidence/test-output.log
- DU-BE-207 → implementation/ai-platform-backend/delivery/CHG-0008/身份与权限/后台 RBAC 权限体系/授权执行与治理/执行后端 API 权限校验/DU-BE-207/evidence/test-output.log
- DU-BE-208 → implementation/ai-platform-backend/delivery/CHG-0008/身份与权限/后台 RBAC 权限体系/授权执行与治理/缓存并及时失效权限/DU-BE-208/evidence/test-output.log
- DU-BE-209 → implementation/ai-platform-backend/delivery/CHG-0008/身份与权限/后台 RBAC 权限体系/授权执行与治理/审计关键权限操作/DU-BE-209/evidence/test-output.log

## 5. 失败与缺口分析

- 产品代码测试失败：0；TC 追踪缺口：0。
- 独立审计发现并修复方法安全拒绝误映射为 500 的问题，BE-107/TC-003 现稳定返回统一 403。
- 前端 Lint 有 46 个格式 warning、0 error，不阻断测试门禁。
- pnpm Node PATH 操作性问题通过工程现有依赖与绑定 Node 运行时解决，未修改产品行为。

## 6. 测试结论

自动化回归、构建和 27/27 TC 追踪均为绿色，满足进入 testing 的技术门禁条件。
