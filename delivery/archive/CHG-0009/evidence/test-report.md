# Test Report — CHG-0009 M1 独立测试

> change-id: CHG-0009
> evidence-index: evidence/evidence.yaml
> from-state: developing
> proposed-state: testing
> tested-at: 2026-09-12T23:51:17+08:00
> conclusion: PASS — all designed TC rows traced to green automation

## 1. 测试范围

### 1.1 repo-1

- DU：DU-BE-301、DU-BE-302
- 命令：`mvn -q -pl mall-gateway,mall-services/mall-identity -am test`
- 结果：JUnit/Spring/H2/Flyway/MyBatis：27 个测试套件、88/88 通过；含 DDD 分层、HTTP 安全链、Gateway JWT、并发刷新、审计与持久化集成测试。
- 环境提示：mvn clean test 曾因 mall-identity JAR 被本机进程占用而无法删除 target；清理 Surefire 报告后，非 clean 独立重跑退出码 0。

### 1.2 repo-2

- DU：DU-FE-301、DU-FE-302、DU-FE-303、DU-FE-304、DU-FE-305、DU-FE-306、DU-FE-307、DU-FE-308、DU-FE-309
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
| STORY-001-03-01-01/TC-001 | AC-001 | DU-BE-301 | Unit/集成测试 | PASS | M1AcceptanceScenariosTest#administratorBootstrap |
| STORY-001-03-01-01/TC-002 | AC-002 | DU-FE-301 | 组件/E2E 测试 | PASS | src/api/http.spec.ts + src/bootstrap/session.spec.ts |
| STORY-001-03-01-01/TC-003 | AC-003 | DU-FE-301 | 组件/E2E 测试 | PASS | src/api/http.spec.ts + src/bootstrap/session.spec.ts |
| STORY-001-03-01-02/TC-001 | AC-001 | DU-BE-302 | Unit/集成测试 | PASS | M1AcceptanceScenariosTest#authorizationSnapshot |
| STORY-001-03-01-02/TC-002 | AC-002 | DU-FE-302 | 组件/E2E 测试 | PASS | src/bootstrap/session.spec.ts |
| STORY-001-03-01-02/TC-003 | AC-003 | DU-FE-302 | 组件/E2E 测试 | PASS | src/bootstrap/session.spec.ts |
| STORY-001-03-01-03/TC-001 | AC-001 | DU-FE-303 | 组件/E2E 测试 | PASS | src/bootstrap/session-rebuild.spec.ts |
| STORY-001-03-01-03/TC-002 | AC-002 | DU-FE-303 | 组件/E2E 测试 | PASS | src/bootstrap/session-rebuild.spec.ts |
| STORY-001-03-01-03/TC-003 | AC-003 | DU-FE-303 | 组件/E2E 测试 | PASS | src/bootstrap/session-rebuild.spec.ts |
| STORY-001-03-02-01/TC-001 | AC-001 | DU-FE-304 | 组件/E2E 测试 | PASS | src/stores/permission.spec.ts |
| STORY-001-03-02-01/TC-002 | AC-002 | DU-FE-304 | 组件/E2E 测试 | PASS | src/stores/permission.spec.ts |
| STORY-001-03-02-01/TC-003 | AC-003 | DU-FE-304 | 组件/E2E 测试 | PASS | src/stores/permission.spec.ts |
| STORY-001-03-02-02/TC-001 | AC-001 | DU-FE-305 | 组件/E2E 测试 | PASS | src/router/dynamic-routes.spec.ts |
| STORY-001-03-02-02/TC-002 | AC-002 | DU-FE-305 | 组件/E2E 测试 | PASS | src/router/dynamic-routes.spec.ts |
| STORY-001-03-02-02/TC-003 | AC-003 | DU-FE-305 | 组件/E2E 测试 | PASS | src/router/dynamic-routes.spec.ts |
| STORY-001-03-02-03/TC-001 | AC-001 | DU-FE-306 | 组件/E2E 测试 | PASS | src/router/access-policy.spec.ts + src/router/not-found.spec.ts |
| STORY-001-03-02-03/TC-002 | AC-002 | DU-FE-306 | 组件/E2E 测试 | PASS | src/router/access-policy.spec.ts + src/router/not-found.spec.ts |
| STORY-001-03-02-03/TC-003 | AC-003 | DU-FE-306 | 组件/E2E 测试 | PASS | src/router/access-policy.spec.ts + src/router/not-found.spec.ts |
| STORY-001-03-03-01/TC-001 | AC-001 | DU-FE-307 | 组件/E2E 测试 | PASS | src/directives/permission.spec.ts |
| STORY-001-03-03-01/TC-002 | AC-002 | DU-FE-307 | 组件/E2E 测试 | PASS | src/directives/permission.spec.ts |
| STORY-001-03-03-01/TC-003 | AC-003 | DU-FE-307 | 组件/E2E 测试 | PASS | src/directives/permission.spec.ts |
| STORY-001-03-03-02/TC-001 | AC-001 | DU-FE-308 | 组件/E2E 测试 | PASS | src/api/http.spec.ts + src/api/refresh-coordinator.spec.ts |
| STORY-001-03-03-02/TC-002 | AC-002 | DU-FE-308 | 组件/E2E 测试 | PASS | src/api/http.spec.ts + src/api/refresh-coordinator.spec.ts |
| STORY-001-03-03-02/TC-003 | AC-003 | DU-FE-308 | 组件/E2E 测试 | PASS | src/api/http.spec.ts + src/api/refresh-coordinator.spec.ts |
| STORY-001-03-03-03/TC-001 | AC-001 | DU-FE-309 | 组件/E2E 测试 | PASS | src/auth/clear-session.spec.ts + src/api/http.spec.ts |
| STORY-001-03-03-03/TC-002 | AC-002 | DU-FE-309 | 组件/E2E 测试 | PASS | src/auth/clear-session.spec.ts + src/api/http.spec.ts |
| STORY-001-03-03-03/TC-003 | AC-003 | DU-FE-309 | 组件/E2E 测试 | PASS | src/auth/clear-session.spec.ts + src/api/http.spec.ts |

## 4. 证据清单

- DU-BE-301 → implementation/ai-platform-backend/delivery/CHG-0009/身份与权限/后台动态菜单与权限前端/权限状态引导/加载当前管理员身份/DU-BE-301/evidence/test-output.log
- DU-FE-301 → implementation/ai-platform-frontend/delivery/CHG-0009/身份与权限/后台动态菜单与权限前端/权限状态引导/加载当前管理员身份/DU-FE-301/evidence/test-output.log
- DU-BE-302 → implementation/ai-platform-backend/delivery/CHG-0009/身份与权限/后台动态菜单与权限前端/权限状态引导/加载菜单与权限状态/DU-BE-302/evidence/test-output.log
- DU-FE-302 → implementation/ai-platform-frontend/delivery/CHG-0009/身份与权限/后台动态菜单与权限前端/权限状态引导/加载菜单与权限状态/DU-FE-302/evidence/test-output.log
- DU-FE-303 → implementation/ai-platform-frontend/delivery/CHG-0009/身份与权限/后台动态菜单与权限前端/权限状态引导/恢复并刷新权限状态/DU-FE-303/evidence/test-output.log
- DU-FE-304 → implementation/ai-platform-frontend/delivery/CHG-0009/身份与权限/后台动态菜单与权限前端/动态导航与页面访问/渲染动态侧边栏菜单/DU-FE-304/evidence/test-output.log
- DU-FE-305 → implementation/ai-platform-frontend/delivery/CHG-0009/身份与权限/后台动态菜单与权限前端/动态导航与页面访问/注册安全动态路由/DU-FE-305/evidence/test-output.log
- DU-FE-306 → implementation/ai-platform-frontend/delivery/CHG-0009/身份与权限/后台动态菜单与权限前端/动态导航与页面访问/守卫页面并区分 403 与 404/DU-FE-306/evidence/test-output.log
- DU-FE-307 → implementation/ai-platform-frontend/delivery/CHG-0009/身份与权限/后台动态菜单与权限前端/操作权限与认证异常/统一控制按钮操作权限/DU-FE-307/evidence/test-output.log
- DU-FE-308 → implementation/ai-platform-frontend/delivery/CHG-0009/身份与权限/后台动态菜单与权限前端/操作权限与认证异常/串行协调 Token 刷新/DU-FE-308/evidence/test-output.log
- DU-FE-309 → implementation/ai-platform-frontend/delivery/CHG-0009/身份与权限/后台动态菜单与权限前端/操作权限与认证异常/统一处理认证授权异常/DU-FE-309/evidence/test-output.log

## 5. 失败与缺口分析

- 产品代码测试失败：0；TC 追踪缺口：0。
- 独立审计发现并修复方法安全拒绝误映射为 500 的问题，BE-107/TC-003 现稳定返回统一 403。
- 前端 Lint 有 46 个格式 warning、0 error，不阻断测试门禁。
- pnpm Node PATH 操作性问题通过工程现有依赖与绑定 Node 运行时解决，未修改产品行为。

## 6. 测试结论

自动化回归、构建和 27/27 TC 追踪均为绿色，满足进入 testing 的技术门禁条件。
