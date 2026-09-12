# Test Report — CHG-0007 M1 独立测试

> change-id: CHG-0007
> evidence-index: evidence/evidence.yaml
> from-state: developing
> proposed-state: testing
> tested-at: 2026-09-12T23:51:17+08:00
> conclusion: PASS — all designed TC rows traced to green automation

## 1. 测试范围

### 1.1 repo-1

- DU：DU-BE-101、DU-BE-102、DU-BE-103、DU-BE-104、DU-BE-105、DU-BE-106、DU-BE-107、DU-BE-108
- 命令：`mvn -q -pl mall-gateway,mall-services/mall-identity -am test`
- 结果：JUnit/Spring/H2/Flyway/MyBatis：27 个测试套件、88/88 通过；含 DDD 分层、HTTP 安全链、Gateway JWT、并发刷新、审计与持久化集成测试。
- 环境提示：mvn clean test 曾因 mall-identity JAR 被本机进程占用而无法删除 target；清理 Surefire 报告后，非 clean 独立重跑退出码 0。

### 1.2 repo-2

- DU：DU-FE-101
- 命令：`vitest run + vue-tsc + eslint + vite build`
- 结果：Vitest 11 files / 22 tests 通过；两套 vue-tsc 通过；ESLint 0 error / 46 warnings；Vite build 通过。
- 环境提示：系统 pnpm.ps1 首次因 Node PATH/非交互重装保护失败；改用工程现有 node_modules/.bin 与绑定 Node 运行时后全部退出码 0。

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
| STORY-001-01-01-01/TC-001 | AC-001 | DU-BE-101 | Unit/集成测试 | PASS | M1SecurityScenariosTest + AdminAuthenticationApplicationServiceTest |
| STORY-001-01-01-01/TC-002 | AC-002 | DU-BE-101 | API/安全边界测试 | PASS | M1SecurityScenariosTest + AdminAuthenticationApplicationServiceTest |
| STORY-001-01-01-01/TC-003 | AC-003 | DU-BE-101 | API/安全边界测试 | PASS | M1SecurityScenariosTest + AdminAuthenticationApplicationServiceTest |
| STORY-001-01-01-02/TC-001 | AC-001 | DU-BE-102 | Unit/集成测试 | PASS | AdminAuthenticationApplicationServiceTest |
| STORY-001-01-01-02/TC-002 | AC-002 | DU-BE-102 | API/安全边界测试 | PASS | AdminAuthenticationApplicationServiceTest |
| STORY-001-01-01-02/TC-003 | AC-003 | DU-BE-102 | API/安全边界测试 | PASS | AdminAuthenticationApplicationServiceTest |
| STORY-001-01-02-01/TC-001 | AC-001 | DU-BE-103 | Unit/集成测试 | PASS | RsaAccessTokenIssuerTest + M1SecurityScenariosTest |
| STORY-001-01-02-01/TC-002 | AC-002 | DU-BE-103 | API/安全边界测试 | PASS | RsaAccessTokenIssuerTest + M1SecurityScenariosTest |
| STORY-001-01-02-01/TC-003 | AC-003 | DU-BE-103 | API/安全边界测试 | PASS | RsaAccessTokenIssuerTest + M1SecurityScenariosTest |
| STORY-001-01-02-02/TC-001 | AC-001 | DU-BE-104 | Unit/集成测试 | PASS | RefreshSessionApplicationServiceTest + M1SecurityScenariosTest |
| STORY-001-01-02-02/TC-002 | AC-002 | DU-BE-104 | API/安全边界测试 | PASS | RefreshSessionApplicationServiceTest + M1SecurityScenariosTest |
| STORY-001-01-02-02/TC-003 | AC-003 | DU-BE-104 | API/安全边界测试 | PASS | RefreshSessionApplicationServiceTest + M1SecurityScenariosTest |
| STORY-001-01-02-03/TC-001 | AC-001 | DU-BE-105 | Unit/集成测试 | PASS | M1AcceptanceScenariosTest#logoutAndStaleSession |
| STORY-001-01-02-03/TC-002 | AC-002 | DU-BE-105 | API/安全边界测试 | PASS | M1AcceptanceScenariosTest#logoutAndStaleSession |
| STORY-001-01-02-03/TC-003 | AC-003 | DU-BE-105 | API/安全边界测试 | PASS | M1AcceptanceScenariosTest#logoutAndStaleSession |
| STORY-001-01-03-01/TC-001 | AC-001 | DU-BE-106 | Unit/集成测试 | PASS | M1TokenValidationHttpTest + JwtSubjectConverterTest |
| STORY-001-01-03-01/TC-002 | AC-002 | DU-BE-106 | API/安全边界测试 | PASS | M1TokenValidationHttpTest + JwtSubjectConverterTest |
| STORY-001-01-03-01/TC-003 | AC-003 | DU-BE-106 | API/安全边界测试 | PASS | M1TokenValidationHttpTest + JwtSubjectConverterTest |
| STORY-001-01-03-02/TC-001 | AC-001 | DU-BE-107 | Unit/集成测试 | PASS | M1TokenValidationHttpTest |
| STORY-001-01-03-02/TC-002 | AC-002 | DU-BE-107 | API/安全边界测试 | PASS | M1TokenValidationHttpTest |
| STORY-001-01-03-02/TC-003 | AC-003 | DU-BE-107 | API/安全边界测试 | PASS | M1TokenValidationHttpTest |
| STORY-001-01-03-03/TC-001 | AC-001 | DU-BE-108 | Unit/集成测试 | PASS | M1GatewayTokenValidationTest + IdentityPropagationFilterTest |
| STORY-001-01-03-03/TC-002 | AC-002 | DU-BE-108 | API/安全边界测试 | PASS | M1GatewayTokenValidationTest + IdentityPropagationFilterTest |
| STORY-001-01-03-03/TC-003 | AC-003 | DU-BE-108 | API/安全边界测试 | PASS | M1GatewayTokenValidationTest + IdentityPropagationFilterTest |
| STORY-001-01-04-01/TC-001 | AC-001 | DU-FE-101 | 组件/E2E 测试 | PASS | src/stores/auth.spec.ts |
| STORY-001-01-04-01/TC-002 | AC-002 | DU-FE-101 | 组件/E2E 测试 | PASS | src/stores/auth.spec.ts |
| STORY-001-01-04-01/TC-003 | AC-003 | DU-FE-101 | 组件/E2E 测试 | PASS | src/stores/auth.spec.ts |

## 4. 证据清单

- DU-BE-101 → implementation/ai-platform-backend/delivery/CHG-0007/身份与权限/统一身份认证体系/管理员凭证认证/安全存储与校验管理员凭证/DU-BE-101/evidence/test-output.log
- DU-BE-102 → implementation/ai-platform-backend/delivery/CHG-0007/身份与权限/统一身份认证体系/管理员凭证认证/认证管理员登录凭证/DU-BE-102/evidence/test-output.log
- DU-BE-103 → implementation/ai-platform-backend/delivery/CHG-0007/身份与权限/统一身份认证体系/Token 生命周期/签发双 Token 登录会话/DU-BE-103/evidence/test-output.log
- DU-BE-104 → implementation/ai-platform-backend/delivery/CHG-0007/身份与权限/统一身份认证体系/Token 生命周期/轮换 Refresh Token/DU-BE-104/evidence/test-output.log
- DU-BE-105 → implementation/ai-platform-backend/delivery/CHG-0007/身份与权限/统一身份认证体系/Token 生命周期/撤销登录会话与状态失效/DU-BE-105/evidence/test-output.log
- DU-BE-106 → implementation/ai-platform-backend/delivery/CHG-0007/身份与权限/统一身份认证体系/身份接入与传播/隔离多类型身份主体/DU-BE-106/evidence/test-output.log
- DU-BE-107 → implementation/ai-platform-backend/delivery/CHG-0007/身份与权限/统一身份认证体系/身份接入与传播/建立统一 SecurityContext/DU-BE-107/evidence/test-output.log
- DU-BE-108 → implementation/ai-platform-backend/delivery/CHG-0007/身份与权限/统一身份认证体系/身份接入与传播/在 Gateway 验证并传播身份/DU-BE-108/evidence/test-output.log
- DU-FE-101 → implementation/ai-platform-frontend/delivery/CHG-0007/身份与权限/统一身份认证体系/管理端认证入口/接入管理端基础登录流程/DU-FE-101/evidence/test-output.log

## 5. 失败与缺口分析

- 产品代码测试失败：0；TC 追踪缺口：0。
- 独立审计发现并修复方法安全拒绝误映射为 500 的问题，BE-107/TC-003 现稳定返回统一 403。
- 前端 Lint 有 46 个格式 warning、0 error，不阻断测试门禁。
- pnpm Node PATH 操作性问题通过工程现有依赖与绑定 Node 运行时解决，未修改产品行为。

## 6. 测试结论

自动化回归、构建和 27/27 TC 追踪均为绿色，满足进入 testing 的技术门禁条件。
