# Test Report — STORY-006-01-01-01 配置模型、后台管理与变更审计

> 阶段：sdd-test 产物。

## 0. 元信息

- Change ID：CHG-0022（M5 系统配置）
- Story ID：STORY-006-01-01-01
- 执行时间：2026-09-19（后端全 reactor 与 mall-admin 四门均在本日实跑）
- 覆盖：AC-001~AC-008；test-design.md TC-001~TC-010
- 实施来源：repo-1 DU-BE-507（82ccf6e）、repo-2 DU-FE-503（404eb77）
- 后端执行：`mvn test -B -ntp`（全 reactor BUILD SUCCESS，482 例 0 失败），本 Story 直接相关 mall-system **19/19**（ConfigAdminApiTest 10、MallSystemApplicationSmokeTest 1；另 8 例属 STORY-006-02-01-01）
- 前端执行：mall-admin vitest **16 files 47/47**（含 config.spec.ts 12）、type-check 0 error、lint 0 error（221 warnings）、build SUCCESS

## 1. 测试范围

TC 编号与本 Story `test-design.md` §1 逐字一致；证据列映射真实测试类#方法名与 spec 文件#用例名（已逐一核对源码，无编造）。

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| TC-001 | 迁移（testcontainers MySQL mall_system）：V1 三表创建、4 种子键存在且 built_in=1/默认值与范围正确；重复迁移幂等不重复播种 | MockMvc + H2(MODE=MySQL) + Flyway V1 | passed（执行环境替代，见 §4-1） | ConfigAdminApiTest#pageSeededFeatures（2 开关、builtIn=true、version=0）、ConfigAdminApiTest#pageSeededParameters（2 参数、type=INTEGER、group=cart 过滤）、MallSystemApplicationSmokeTest#contextLoads（V1 经 Flyway 真实执行） |
| TC-002 | API：开关分页/分组列表、启停切换、新建、删除非内置全流程 200；重复 configKey 创建 → 409 B0602 | MockMvc + 真实安全链 | passed | ConfigAdminApiTest#pageSeededFeatures、#pageSeededParameters（group 过滤）、#createFeatureAndDuplicate（新建 200 + 重复键 409 B0602）、#updateFeatureCas（启停 true→false 200）、#deleteFeature（删非内置 200） |
| TC-003 | API：INTEGER 写 "abc"、JSON 写非法串、越 min/max、BOOLEAN 写 "yes" → 均 400 B0601 且库值不变 | MockMvc | partial（4 指名子例 2 精确 + 1 等价 + 1 跨层，见 §4-2） | ConfigAdminApiTest#createParameterValidation（INTEGER 999 越界 [1,100] 400 B0601；未知类型 DATETIME 值 "x" 400 B0601；JSON "{not-json" 400 B0601；重复键顺带 409 B0602）、#createFeatureInvalidName（name 空 400）；BOOLEAN 解析跨层见 ConfigFacadesTest#providerFallbacks |
| TC-004 | API：用旧 version 更新 → 409 B0604；用最新 version → 200 且 version+1 | MockMvc | passed | ConfigAdminApiTest#updateFeatureCas（v0 更新成功 version 0→1；同体再提 409 B0604） |
| TC-005 | API：DELETE 内置键 → 400 拒绝；PUT 改内置 key → 拒绝；改值允许；删非内置成功且写 history | MockMvc | passed（改 key 禁止为结构性约束，见 §4-3） | ConfigAdminApiTest#deleteFeature（内置 search.enabled 删除 400 B0601；tmp.feature 删除 200 + DELETED 历史）、#updateAndDeleteParameter（内置参数值 20→50 成功 version+1；删除内置参数 400 B0601） |
| TC-006 | API：改值/启停各产生一条 history（old/new/operator/traceId/created_at）；GET config-history 按 type+key 过滤分页；无修改/删除历史端点（404/405） | MockMvc | passed（traceId 字段未显式断言，见 §4-4） | ConfigAdminApiTest#updateFeatureCas（UPDATED、oldValue=true/newValue=false、changeReason）、#createFeatureAndDuplicate（CREATED、changedBy="2001"）、#deleteFeature（DELETED、reason="下线"）、#historyFilterAndAuth（configType+key 过滤、PARAMETER total=0、分页结构）；历史仓储只追加、Controller 仅 GET（源码核实无写/删端点） |
| TC-007 | 安全：缺 system:feature:update 的 JWT 写 → 403，读 200；config-history 需 config-history:list；identity V10 菜单/权限种子迁移断言 | MockMvc + 真实 JWT | partial（V10 种子无自动化断言，见 §4-5） | ConfigAdminApiTest#authenticationAndAuthorization（无 token 401；仅 system:feature:list 写 403；持 system:parameter:list 读 feature 403）、#historyFilterAndAuth（无 system:config-history:list 读历史 403）、#pageSeededFeatures（持权读 200）；V10__system_config_permissions.sql 静态核实 |
| TC-008 | API：不存在 id 更新/删除 → 404 B0603 | MockMvc | passed（删除不存在键无专门用例，见 §4-6） | ConfigAdminApiTest#updateFeatureCas（PUT /feature-configs/not.exist → 404 B0603） |
| TC-009 | 前端 Vitest：三页面渲染/开关切换/类型表单（number/json/bool）校验/范围提示/历史筛选/409 冲突提示 | Vitest（api 层 mock axios） | partial（仅 api/config.ts 层 12 例，无页面组件测试，见 §4-7） | mall-admin src/api/config.spec.ts 12 例：①featureConfigApi page 携带筛选与分页参数，空筛选归一化为 undefined；②page 透传 enabled 布尔与去空白后的 group；③create/update/delete 走对应端点，删除原因走 query，更新携带 version 与变更原因；④key 含特殊字符时走 encodeURIComponent；⑤systemParameterApi page 与 create 序列化参数（数值边界以字符串下发）；⑥update 携带乐观锁 version 与 changeReason，delete 不带 query；⑦configHistoryApi page 透传 configType/key/分页并解包 items；⑧优先取 UnifyResult.message（B0602 key 冲突等）；⑨B0604 版本冲突追加刷新重试引导；⑩服务端文案已含「刷新」时不重复追加；⑪无响应体的 axios 错误回退 axios.message 再回退兜底文案；⑫403 统一无权提示兜底 |
| TC-010 | 构建门禁：mall-admin type-check/lint/test/build 全绿 | pnpm 四门 | passed | 日志 `evidence/logs/mall-admin-vitest.log`（16 files 47/47，含 config.spec.ts 12）、`mall-admin-type-check.log`（0 error）、`mall-admin-lint.log`（0 error，221 warnings）、`mall-admin-build.log`（✓ built） |

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-system | 全 reactor `mvn test -B -ntp`（TESTCONTAINERS_RYUK_DISABLED=true） | mall-system **19/19**，其中本 Story ConfigAdminApiTest **10/10**、MallSystemApplicationSmokeTest **1/1**，0 失败 |
| mall-admin | `pnpm vitest run` / `vue-tsc --noEmit` / `eslint` / `pnpm build` | **47/47**（16 files，含 config.spec.ts 12）；type-check 0 error；lint 0 error（221 warnings）；build SUCCESS |
| 日志 | 后端：`../../../../../../CHG-0020/evidence/logs/backend-full-test.log`（跨 Change 引用，2026-09-19 01:42 BUILD SUCCESS）；前端：`../../../../../evidence/logs/mall-admin-vitest.log`、`mall-admin-type-check.log`、`mall-admin-lint.log`、`mall-admin-build.log` | 完整输出 |

## 3. AC 覆盖

| AC | 验收标准（摘自 story-spec §5） | 覆盖 TC | 结论 |
|----|--------------------------------|---------|------|
| AC-001 | V1 迁移成功，种子键存在且 builtIn=true、默认值/范围正确；重复启动迁移不重复播种 | TC-001 | passed（H2 替代环境，幂等由 Flyway schema_history 版本化保证） |
| AC-002 | 开关分页/分组查询、启停、新建、删除非内置流程可用；重复 key 创建被唯一约束拒绝并返回明确错误 | TC-002、TC-008 | passed |
| AC-003 | 参数类型校验四例（INTEGER 写 abc、JSON 写非法 JSON、超 min/max、BOOLEAN 写 yes）均 400 且值不变 | TC-003 | partial：越界、非法 JSON 精确覆盖；类型非法以 DATETIME/"x" 等价覆盖；INTEGER "abc"、BOOLEAN "yes" 无逐字用例 |
| AC-004 | 用过期 version 更新 → 409 CONFIG_VERSION_CONFLICT；用最新 version 成功 | TC-004 | passed |
| AC-005 | 删除/改 key 内置键被拒绝；删非内置成功且历史留痕 | TC-005、TC-008 | passed（"改 key"由路径参数 + 更新体无 key 字段结构性禁止） |
| AC-006 | 每次改值/启停产生一条历史，含旧值/新值/操作人/traceId/时间；历史按 key 过滤分页正确，无修改/删除历史的接口 | TC-006 | passed（changedBy/old/new/changeKind/时间已断言；traceId 端到端字段存在但未逐例断言） |
| AC-007 | 仅具备对应 update 权限的管理员可写（403 反向验证）；菜单与按钮权限在 mall-admin 生效 | TC-007 | partial：401/403/跨资源 403 全有断言；identity V10 菜单/权限种子仅 SQL 静态核实；mall-admin 按钮 v-permission 无组件测试 |
| AC-008 | mall-admin 三页面 CRUD/启停/历史筛选可用，构建/类型检查/lint/单测通过 | TC-009、TC-010 | partial → 门禁全绿；三页面仅 api 层 12 例，页面交互无组件测试 |

## 4. 缺口备注

1. **TC-001 执行环境替代**：test-design 指定 testcontainers MySQL，实际为 H2(MODE=MySQL) test profile；4 种子由 `@BeforeEach` 对 V1 建好的三表重播（seed SQL 本身经 Flyway 执行，冒烟测试 contextLoads 验证迁移可启动）。MySQL 方言级 DDL/DML 未做容器级验证，留待联调/部署环境。
2. **TC-003 / AC-003 两指名子例无逐字用例**：管理端 API 未直接构造 INTEGER 写 "abc"（最接近为未知类型 DATETIME 写 "x"）与 BOOLEAN 写 "yes"（ConfigType.validate 限定 BOOLEAN 仅 true/false，消费侧 ConfigFacadesTest#providerFallbacks 仅验证 "1"→true 的正向解析）。"库值不变"依赖校验在入库前抛出，未做读回断言。风险：低——校验逻辑集中于 ParameterValueValidator/ConfigType，建议后续补两例参数化测试。
3. **TC-005 "PUT 改内置 key"无反向请求用例**：键为路径参数、更新请求体不含 key 字段，改 key 在接口形态上不可能；无专门 400 断言。
4. **TC-006 traceId 未显式断言**：ConfigHistory 域对象/PO/HistoryView 均含 traceId，OperatorContext 从链路上下文取值，但现有用例只断言 changedBy/old/new/changeKind/changeReason。
5. **TC-007 identity V10 种子无迁移断言测试**：V10__system_config_permissions.sql（五权限码 + /system 目录 + 三 PAGE 菜单 + 超管授权，幂等守卫）仅静态核实，mall-identity 测试套件无 system 配置权限断言。
6. **TC-008 删除不存在键**：仅更新路径断言 404 B0603；DELETE 不存在键未单独构造（删除内置 400、删非内置 200 两路径已覆盖）。
7. **TC-009 / AC-008 前端仅 api 层覆盖**：config.spec.ts 12 例全部针对 src/api/config.ts（请求参数序列化、乐观锁 version、错误归一化 B0602/B0604/403）；FeatureConfigsView/SystemParametersView/ConfigHistoryView 三页面的渲染、开关切换、类型表单校验矩阵、范围提示、历史筛选交互无组件测试，三管理页浏览器端到端操作在联调阶段验证（与 Change 报告 §5 缺口②一致）。
