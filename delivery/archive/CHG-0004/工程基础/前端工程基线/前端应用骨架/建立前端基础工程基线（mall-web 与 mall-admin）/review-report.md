# Review Report

> 阶段：sdd-review 产物（Phase 2.2 同态检查点；Phase 2.4 扩展跨仓审查）
> 位置：CHG-0004/review-report.md（STORY 目录）
> 输入：prd.md + design.md + implementation.md + evidence/test-report.md + evidence/evidence.yaml + standards/engineering/frontend/* + DU 状态（跨仓）
> 产出状态：testing（检查点，不推进 Change 状态）

本文档记录 converge 前的四项独立检查结论与发现清单。

## 0. 元信息

- Change ID: CHG-0004
- Test Report 来源: CHG-0004/evidence/test-report.md（STORY 目录）
- Evidence 索引: CHG-0004/evidence/evidence.yaml（EV-001~EV-027）
- 状态流转: testing（检查点，状态不变）
- 检查时间: 2026-09-02T15:20:00+08:00

## 1. 检查结论

四项检查全部通过。发现 3 个 finding（major ×2 + minor ×1），**全部已在评审阶段闭环**（resolution 均已回填）；blocker = 0。代码抽查 6 个关键文件（两应用 router/index.ts、stores/app.ts、package.json + vite.config.ts + env 三件套）+ 镜像文件 7 份 diff 复核，全部合规。

### 1.1 需求一致性

PRD AC-01~AC-13 逐条对照 evidence.yaml test-run covers 字段：

| AC | test-run 证据（covers 字段） | 结论 |
|----|------------------------------|------|
| AC-01 | EV-019（mall-web install，dev 日志直接留证） | ✅ 通过 |
| AC-02 | EV-020（mall-web dev 启动 + 页面访问） | ✅ 通过（评审中补 covers） |
| AC-03 | EV-013（mall-web build → dist 9 文件 + 懒加载 chunk） | ✅ 通过 |
| AC-04 | EV-022（mall-admin install，间接证据链如实标注） | ✅ 通过（评审中补 covers） |
| AC-05 | EV-023（mall-admin dev + AdminLayout 渲染） | ✅ 通过（评审中补 covers） |
| AC-06 | EV-017（mall-admin build → dist 23 文件 + EP chunk） | ✅ 通过 |
| AC-07 | EV-021 + EV-024（两应用 Router：/login、/ 重定向、占位页、404 catch-all、无路由告警） | ✅ 通过（评审中补 covers） |
| AC-08 | EV-021 + EV-024（mall-web counter 同步 / mall-admin isCollapsed 折叠同步） | ✅ 通过（评审中补 covers） |
| AC-09 | EV-021 + EV-024（两应用 /__ping 统一拦截器 + 网关不在线错误路径） | ✅ 通过（评审中补 covers） |
| AC-10 | EV-024（mall-admin el-menu/el-card/el-input/el-button 按需渲染） | ✅ 通过（评审中补 covers） |
| AC-11 | EV-021 + EV-024（env 标题区分生效 + 业务代码零硬编码） | ✅ 通过（评审中补 covers） |
| AC-12 | EV-011/012 + EV-015/016（两应用 lint 0 error + type-check 双 tsconfig 通过） | ✅ 通过 |
| AC-13 | EV-014 + EV-018（两应用业务关键字扫描：命中均为 M1 锚点注释/PRD 占位文案/术语误报） | ✅ 通过 |

需求一致性结论：13/13 AC 全部有 test-run covers 覆盖（EV-019~EV-024 为评审阶段补录的同基线 dev 执行记录，finding EV-025 已闭环），无缺口。

### 1.2 设计一致性（Design → DU → Implementation Traceability）

**检查 a：DU ↔ Design**

| DU | Design 引用 | Sketch 一致性 | 结论 |
|----|------------|---------------|------|
| DU-FE-001 | §2.2 结构 / §2.3 版本策略 / §2.9 质量基线 | 模板七件套 + http.ts + src-skeleton 十目录与 design §2.2 一致；engines/scripts 与 §2.3/§2.9 一致 | ✅ 通过 |
| DU-FE-002 | §2.4~§2.8 全量（不含 EP） | Router 2 条 + 守卫占位、app store（appName+counter）、MallLayout（Header/Main/Footer）、HomeView 验证聚合页均与 design 一致 | ✅ 通过 |
| DU-FE-003 | §2.2~§2.8 + EP（§2.3） | Router 6 条、AdminLayout（el-menu×4 静态菜单）、LoginView 占位、EP 按需导入（unplugin + ElementPlusResolver）与 design §2.5/§2.7/§2.3 一致 | ✅ 通过 |

**检查 b：Implementation ↔ DU**

| 设计声明组件 | code-change 证据 / 源码抽查 | 结论 |
|-------------|------------------------------|------|
| 镜像文件清单 7 份（http.ts/tsconfig×2/eslint/prettier/.npmrc/.env.example） | diff 复核全部 SAME（无一行差异） | ✅ 对应 |
| scripts 镜像（lint 不带 --fix） | 两应用 package.json scripts 六项逐字一致 | ✅ 对应 |
| engines node>=22 / pnpm>=10 | 两应用 package.json 一致 | ✅ 对应 |
| Router 结构（§2.5） | mall-web 2 条 / mall-admin 6 条，path kebab-case + meta.title + 全懒加载 + catch-all 404 + beforeEach 返回值式占位 | ✅ 对应 |
| HTTP Client（§2.4） | baseURL=VITE_API_BASE_URL、timeout 10000、Request/Response 拦截器 M1 锚点注释、出口纪律 | ✅ 对应 |
| Vite proxy（§2.8） | 两应用 proxy['/api'] → http://localhost:8080 预留 + 注释 | ✅ 对应 |
| env 三件套（§2.8） | dev=/api + title 差异化、prod 留空、.env.example 模板 | ✅ 对应 |
| EP 按需导入（§2.3） | unplugin-auto-import/components + ElementPlusResolver + dts 生成入库，main.ts 零全局注册 | ✅ 对应 |

偏离记录检查：9 项 Deviations 原已记录（beforeEach 返回值式 ×2、typescript@5 固定 ×2、双 tsconfig type-check ×2、.gitignore 证据例外、@eslint/js 显式声明、unplugin dts 入库）。评审新发现 2 项未记录偏差（版本选型 vue-router 4→5.3.x / ESLint 9→10.9.1；mall-admin store 形态演进），**已在评审中补记**（DU-FE-002 DEV-4、DU-FE-003 DEV-5/DEV-6），finding EV-026/EV-027 闭环。

**检查 c：AC 满足**

偏离后 AC 全覆盖：vue-router 5 / ESLint 10 升级不改变对外契约（路由 API、flat config 结构、命令语义均兼容，全链路验证通过）；store 形态演进完全满足 AC-08。无 blocker。

设计一致性结论：三层链路（Design → DU → Implementation → AC）完整，无 unresolved 偏差。

### 1.3 跨仓一致性（Phase 2.4）

不适用跨仓协作测试。本 Change 为单仓交付（repo-2），design.md §4 声明 affected-repositories: [repo-2]，DU 清单（3 DU）与之一致，全部 DU 的 code-change/test-run 证据均指向 repo-2（evidence-ref 可追溯）。§4 预留契约（→ mall-gateway:8080、/api/**、UnifyResult 结构、X-Trace-Id）已在 http.ts 错误处理锚点注释与 vite proxy 配置中按契约预留，M0 无真实跨仓调用（Mock/错误路径验证符合设计）。

### 1.4 代码质量

对照 `standards/engineering/frontend/` 五维规范抽查 code-change 涉及的关键文件：

| 文件 | 检查项 | 规范依据 | 结论 |
|------|--------|---------|------|
| mall-web/src/router/index.ts | path kebab-case / meta.title / 懒加载 / 404 / name 唯一 | router-standard.md §4/§6/§8 | ✅ 合规 |
| mall-admin/src/router/index.ts | 同上 + 6 条路由结构稳定 + meta 预留 | router-standard.md §4/§6/§8 | ✅ 合规 |
| mall-web/src/stores/app.ts | defineStore setup 语法 / 按域一文件 / 状态分类清晰（appName 全局态 + counter 验证态） | state-management-standard.md §3/组织约定 | ✅ 合规 |
| mall-admin/src/layouts/AdminLayout.vue | 单一职责（仅布局与导航，零业务逻辑）/ 菜单数据与渲染分离 | component-standard.md §2.1 + design §2.7 | ✅ 合规 |
| 两应用 package.json | engines 约束 / scripts 镜像 / 类型安全（无 any 逃逸配置） | coding-standard.md + design §2.3/§2.9 | ✅ 合规 |
| 两应用 vite.config.ts + env | 零硬编码网关地址（仅 proxy 目标与 env 文件）/ @ alias | security 凭据安全 + design §2.8 | ✅ 合规 |

环境变量化检查：业务代码零 VITE_ 之外的环境读取、零硬编码地址——符合「硬编码禁止」规则。ESLint 核心规则未关闭（0 error，19+35 warnings 均为设计降级的样式规则并已记录）。

代码质量结论：抽查无违规，无 finding。

### 1.5 知识同步候选

供 sdd-converge 参考的候选知识项：

1. **ESLint 10 flat config 配套模式**（候选 standards/engineering/frontend/）
   - ESLint 10 不再随附 @eslint/js，eslint.config.js 需显式声明 devDependency
   - 两应用已验证版本组合：eslint 10.9.1 + eslint-plugin-vue 10.10.0 + typescript-eslint 8.69.0 + @eslint/js 10.0.1
   - 候选规范条目：前端 Lint 工具链版本配套约定

2. **vue-router 5 返回值式守卫**（候选 standards/engineering/frontend/router-standard.md）
   - vue-router 5 弃用守卫 next() 回调（运行时 R0025 deprecation 警告），统一返回值式签名
   - 占位守卫写法：`router.beforeEach(() => true)`
   - 候选规范条目：路由守卫签名约定（替代 next() 回调写法）

3. **unplugin 按需导入 + 生成 dts 入库模式**（候选 standards/engineering/frontend/component-standard.md）
   - Element Plus 按需导入（unplugin-auto-import + unplugin-vue-components + ElementPlusResolver），main.ts 零全局注册
   - auto-imports.d.ts / components.d.ts 随代码入库，保证新克隆环境 type-check 可直接通过
   - 候选规范条目：UI 库按需导入与生成类型入库约定

4. **双 tsconfig 串联 type-check 模式**（候选 standards/engineering/frontend/coding-standard.md）
   - app/node 双 tsconfig（无 references 组合）场景下：`vue-tsc --noEmit -p tsconfig.json && vue-tsc --noEmit -p tsconfig.node.json`
   - 候选规范条目：前端类型门禁命令约定

5. **前端镜像文件对齐策略**（候选 standards/engineering/frontend/ 或 sdd/）
   - 单一事实源模板（templates/base-files）+ 复制实例化 + 镜像清单 diff 复核（review 检查项）
   - 替代 frontend-common 公共包的独立性约束下的统一性手段
   - 候选规范条目：多应用镜像文件清单与复核约定

6. **TypeScript 5.9 固定约定**（候选 standards/engineering/frontend/coding-standard.md）
   - TypeScript 7 与 typescript-eslint 8 peer 范围冲突，需显式固定 `typescript@5`
   - 候选规范条目：前端 TS 版本与插件 peer 兼容约定

## 2. 发现清单

review-finding 条目 3 个（与 evidence.yaml 一一对应）：

- **EV-025（major，已闭环）**：9 条 AC 无 workspace 侧 test-run covers → 已补录 EV-019~EV-024 同基线 dev 执行记录，AC-01~13 全覆盖
- **EV-026（major，已闭环）**：版本选型偏差未记录（vue-router 4→5.3.x / ESLint 9→10.9.1）→ 已补记 DU-FE-002 DEV-4 / DU-FE-003 DEV-5
- **EV-027（minor，已闭环）**：mall-admin store 形态演进未记录（计数器→折叠开关）→ 已补记 DU-FE-003 DEV-6，意图等价接受

- blocker: 0（全部闭环）
- major: 2（EV-025 / EV-026，resolution 均非空）
- minor: 1（EV-027，resolution 非空，接受闭环）

## 3. 完成确认

- [x] 四项检查全部执行（需求一致性 / 设计一致性 / 跨仓一致性 / 代码质量）
- [x] PRD 每条 AC 均做了对照（AC-01~13 全覆盖，见 §1.1 矩阵）
- [x] design.md 关键声明均核对了实现证据（镜像 7 份 diff / scripts / router / http / proxy / env / EP，见 §1.2）
- [x] 每个 DU 均有 code-change/test-run 证据（EV-007~010 code-change + EV-011~024 test-run，evidence-ref 可追溯 repo-2）
- [x] design.md §4 跨仓协作契约核对（单仓交付 + 预留契约按设计落地，见 §1.3）
- [x] 代码质量 finding 均有明确规范依据（零 finding，抽查 6 文件全部合规）
- [x] 全部 blocker/major 已闭环（EV-025/EV-026 resolution 非空）
- [x] review-finding 条目与 §2 发现清单一一对应（3 条）
- [x] 知识同步候选已写入 §1.5（6 项候选）
