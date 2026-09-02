# Tasks

> 阶段：sdd-task 产物（Phase 2.4/2.5：Delivery Decomposition + DU Specification）
> 输入：CHG-0004/design.md
> 产出状态：tasked

本文档将设计拆为 Delivery Unit（DU 1:1 Repository），并为每个 DU 提供 Implementation Guidance（Sketch + Pseudocode + Verification）。

## 0. 元信息

- Change ID: CHG-0004
- Design 来源: CHG-0004/design.md（STORY 目录）
- 状态流转: designed → tasked
- Feature Path: 工程基础 > 前端工程基线 > 前端应用骨架 > 建立前端基础工程基线（mall-web 与 mall-admin）
- DU 总数: 3（全位于 repo-2，仓库名别名 FE，ID=repo-2）

### 执行总览

三个 DU 全部在 repo-2（前端）仓内：DU-FE-001 建立"规范底座"（根 README/.gitignore + 镜像文件清单的源模板），DU-FE-002 基于底座实例化 mall-web，DU-FE-003 基于底座实例化 mall-admin（差异面：Element Plus 按需导入 + AdminLayout + LoginView + 4 占位菜单）。顺序上 DU-FE-001 先交付底座文件，DU-FE-002 与 DU-FE-003 可**并行实例化**（均引用底座文件复制/差异增量），无实际执行依赖，但 Acceptance 最终需 AC-12（lint/type-check/build）全绿后才算闭环。

| DU | 顺序 | 并行组 | 仓库 | 核心职责 |
|---|---|---|---|---|
| DU-FE-001 | 1 | A | repo-2 | 仓库根 + 规范底座（镜像源文件）+ 质量基线模板 |
| DU-FE-002 | 2 | B | repo-2 | mall-web 工程基线实例化 + HTTP/Router/Pinia/Layout 最小验证 |
| DU-FE-003 | 2 | B | repo-2 | mall-admin 工程基线实例化 + Element Plus/AdminLayout/4 菜单 + HTTP/Router/Pinia 最小验证 |

---

## 任务清单

### DU-FE-001: 前端规范底座与仓库根初始化

- 目标仓库: repo-2（frontend，id=repo-2，路径 implementation/ai-platform-frontend）
- Goal: 建立仓库根（README/.gitignore）与规范底座（版本策略、质量基线、镜像源文件模板），使 mall-web/mall-admin 两个实例化 DU 可直接复用
- Scope（范围）:
  - 仓库根: README.md（双应用结构说明 + 各自快速开始）、.gitignore（node_modules/ dist/ .env.* 除 .env.example）
  - 镜像源文件模板（位于仓库根 `/templates/` 目录，供两个应用复制；内容见 design.md §2.2 清单与 §2.9 规范）：
    - `src/api/http.ts`（Axios Client 统一模板，拦截器扩展锚点完整）
    - `eslint.config.js`（ESLint 9 flat config：eslint + eslint-plugin-vue vue3-recommended + typescript-eslint 官方配套；规则关闭策略：核心规则不得关闭，按需调整样式规则为 warn）
    - `tsconfig.json` / `tsconfig.node.json`（strict 开启，模块与 target 按 Vue 3 + Vite 生态建议值）
    - `.prettierrc.json`（与 eslint 无冲突的格式化规则集；分号/缩进/引号标准）
    - `.npmrc`（`registry=https://registry.npmmirror.com` 网络环境适配）
    - `.env.example`（`VITE_API_BASE_URL=` + `VITE_APP_TITLE=` 两项注释说明）
    - `package.json` scripts 段模板（dev/build/preview/lint/type-check/format + engines node>=22 pnpm>=10）
    - `src/` 十目录占位骨架（api/assets/components/composables/layouts/router/stores/types/utils/views）
  - npm 源与版本策略文档化（README 内含"版本权威=pnpm-lock.yaml，不使用 workspace"说明）
- Design References: design.md §2.1 方案概要 / §2.2 工程结构 / §2.3 技术栈与版本策略 / §2.9 质量基线 / §2.2 镜像文件清单
- Dependencies: 无（首个 DU，建立底座）
- Acceptance Criteria:
  - 仓库根存在 README.md（含双应用快速开始指引）与 .gitignore（不忽略 .env.example）
  - `templates/` 下镜像源文件 8 份齐全（http.ts / eslint.config.js / tsconfig*2 / prettierrc / npmrc / env.example / scripts 模板 + src 十目录骨架）
  - eslint.config.js 使用 flat config 形态，引入 eslint-plugin-vue（vue3-recommended）与 typescript-eslint
  - package.json 模板含 engines 字段声明 node>=22 且 pnpm>=10；scripts 含 dev/build/preview/lint/type-check/format
  - .npmrc 设定 registry 为 npmmirror（或评审同意的源）
  - 模板文件无任何业务代码残留，纯可复用结构
- Execution Order: 1
- Parallelization: 组 A
- Implementation Sketch:
  ```text
  repo-2 root
  ├── README.md（总览 + mall-web 快速开始 + mall-admin 快速开始）
  ├── .gitignore（node_modules/ dist/ .env.* except .env.example / DS_Store）
  └── templates/                       （所有镜像源文件的单一事实源，避免两应用手动对齐漂移）
      ├── base-files/
      │   ├── eslint.config.js        ESLint 9 flat + vue3-recommended + typescript-eslint
      │   ├── tsconfig.json           严格模式；types/vite-env.d.ts typeRoots 指向
      │   ├── tsconfig.node.json      vite config 使用的 Node TS
      │   ├── .prettierrc.json        无冲突格式化
      │   ├── .npmrc                  npmmirror 镜像
      │   ├── .env.example            VITE_API_BASE_URL / VITE_APP_TITLE 注释
      │   └── package-scripts.json    engines + scripts 清单（供两应用 pnpm init 后合并）
      ├── http.ts                     Axios 实例 + baseURL VITE_API_BASE_URL + 拦截器锚点注释
      └── src-skeleton/               十目录骨架（含 package.json 模板中的 import alias @ → src）
  ```
- Pseudocode: N/A（纯工程结构与配置模板的创建，无业务流程/算法/状态转换/编排逻辑）
- Verification:
  - 静态检查: 根目录 ls 确认 README.md/.gitignore 存在；templates/base-files 列出 7 文件 + http.ts + src-skeleton 齐全
  - ESLint 兼容性验证（作为 DU-FE-002/003 的依赖前提）：在模板文件中随 DU-FE-002 的首次 lint 验证通过
  - 对齐检查: DU-FE-002/003 的镜像文件 diff templates/base-files 应一致（允许声明的自然差异：package.json 依赖清单/admin unplugin 插件）
  - Error Case: 若 templates 缺失任一文件，阻塞 DU-FE-002/003 开始

### DU-FE-002: mall-web 商城前端工程基线

- 目标仓库: repo-2
- Goal: 从零实例化完整 mall-web Vue3 + TS + Vite 工程，验证 AC-01 安装/AC-02 启动/AC-03 构建/AC-07 Router/AC-08 Pinia/AC-09 HTTP/AC-11 环境变量/AC-12 lint+type-check/AC-13 零业务逻辑
- Scope（范围）:
  - 项目根: mall-web/
    - package.json（从模板 scripts 合并，依赖：vue 3 / vue-router / pinia / axios / vite / typescript / vue-tsc / eslint@9+ 插件套装 / prettier）
    - pnpm-lock.yaml（安装后锁文件，版本权威）
    - vite.config.ts（@ → /src alias；dev server proxy `/api → http://localhost:8080`）
    - index.html（`<div id="app">` + `VITE_APP_TITLE` 插值）
    - tsconfig.json + tsconfig.node.json（从模板复制，paths 指 @）
    - eslint.config.js + .prettierrc.json + .npmrc（从模板复制）
    - .env.development（`VITE_API_BASE_URL=/api`；`VITE_APP_TITLE=AI Mall 商城`）
    - .env.production（`VITE_API_BASE_URL=` 空值由部署注入；`VITE_APP_TITLE=AI Mall 商城`）
    - .env.example（从模板复制）
  - src/:
    - main.ts: `createApp(App).use(router).use(pinia).mount('#app')`
    - App.vue: `<router-view />` 一层（Layout 由路由承载）
    - api/http.ts: 从模板复制 → http.get 实例 + 拦截器锚点注释
    - router/index.ts: routes[/(MallLayout→HomeView 懒加载), /:pathMatch(.*)→NotFoundView]；beforeEach 空实现（守卫扩展入口）
    - stores/app.ts: 最小 AppStore（应用名 + 计数器 action）
    - stores/index.ts: createPinia 导出
    - layouts/MallLayout.vue: Header（应用名）/ Main(router-view) / Footer（版权占位）；最小手写 CSS
    - views/HomeView.vue: 基础测试页（展示 VITE_APP_TITLE + Pinia 计数器按钮 + Pinia 值显示 + /__ping HTTP 触发按钮 + 请求结果显示）
    - views/NotFoundView.vue: 404 页面（文字 + 返回首页链接）
    - types/index.ts: 项目级通用类型占位（如 `interface ApiResponse<T>` 对齐后端 UnifyResult 预留）
    - composables/ utils/ assets/ components/ 目录（空，可放 index.ts 占位）
- Design References: design.md §2.4 HTTP / §2.5 Router（mall-web 分支）/ §2.6 Pinia / §2.7 MallLayout / §2.8 环境变量 / §2.9 质量基线
- Dependencies: DU-FE-001（必须先交付镜像源文件模板，本 DU 用复制方式复用）
- Acceptance Criteria:
  - AC-01: `mall-web` 执行 `pnpm install` → 成功安装且无 WARN 级依赖冲突
  - AC-02: `pnpm dev` → 开发服务器启动，访问 Home 页可渲染且无控制台 JS 错误
  - AC-03: `pnpm build` → dist/ 产出，无类型/构建错误
  - AC-07: Router 验证——`/` 正确渲染 HomeView；访问不存在路径如 `/no-such` → 渲染 NotFoundView；路由懒加载通过 network 面板观察 chunks
  - AC-08: Pinia 验证——HomeView 计数器按钮点击 → 值更新正确；刷新页面（非持久化）重置
  - AC-09: HTTP Client 验证——按钮触发 `http.get('/__ping')` →
    - 若目标不可达：统一错误入口抛出并在页面展示请求失败（验证错误路径）
    - 若通过 proxy 转发到后端：显示正常响应体（验证成功路径）
    - Evidence 中明确记录实际走哪条路径
  - AC-11: env 验证——development 的 `VITE_APP_TITLE` 在 HomeView 标题显示；.env.production 中 `VITE_API_BASE_URL` 是空字符串（由部署注入，而非硬编码地址）
  - AC-12: `pnpm lint` 通过（0 error）；`pnpm type-check` 通过
  - AC-13: 静态扫描 views/stores/api → 无商品/购物车/订单/RBAC/AI 业务类型或流程
- Execution Order: 2
- Parallelization: 组 B（与 DU-FE-003 并行）
- Implementation Sketch:
  ```text
  mall-web/
  ├── package.json (pnpm create vite 初始化后按模板合并)
  ├── vite.config.ts ── alias @ → /src + server.proxy /api → 8080
  ├── env files (dev/prod/example)
  └── src
      ├── main.ts          createApp + router + pinia
      ├── App.vue          <router-view />
      ├── layouts/MallLayout.vue   Header/Main/Footer（不依赖 UI 库）
      ├── router/index.ts  routes 2 条 + beforeEach 锚点
      ├── stores/app.ts    AppStore(name + counter + increment)
      ├── api/http.ts      Axios instance（从 templates/http.ts 复制）
      ├── views/HomeView.vue      测试聚合页：
      │                          标题显示 env title
      │                          + 计数器（绑定 pinia AppStore）
      │                          + 发起 /__ping 按钮 → 调用 http.get
      │                          + 渲染响应或错误
      ├── views/NotFoundView.vue    catch-all 页面
      └── types/index.ts    ApiResponse<T> 占位
  ```
- Pseudocode: N/A（初始化与装配型工程任务，无复杂业务流程/算法/状态机/多组件编排；组件间数据流为 props + pinia store + axios promise 的标准形式）
- Verification:
  - Command Verification（逐次执行并保留日志）:
    - `pnpm install` 退出码 0（AC-01）
    - `pnpm lint` 退出码 0 + 输出 0 error（AC-12 lint）
    - `pnpm type-check` 退出码 0（AC-12 type-check）
    - `pnpm build` 退出码 0 + dist/ 非空（AC-03）
  - Dev Server Verification:
    - `pnpm dev` 启动，headless 或 curl 访问 `/` 得到 200 + 正确标题；访问 `/no-such` 得到 404 页内容（AC-02/AC-07）
  - Runtime Verification（通过验证页或 devtools）:
    - Pinia: 点击计数 → 显示从 0 到 N（AC-08）
    - HTTP: 点击 /__ping → 捕获并展示请求路径与响应/错误（AC-09，Evidence 记录验证方式）
  - Static Scan（AC-13）:
    - 全局搜索关键字：Product / 购物车 cart / 订单 order / 登录 login / 注册 register / 权限 permission role / AI / RAG → 命中数=0
  - Error Case:
    - 若 vite dev server 启动时未设置 proxy 目标 8080 → 构建也会失败，lint/type-check 先行校验阻塞
    - 若 pinia 未注册使用 → 控制台 "getActivePinia()" 警告，验收失败

### DU-FE-003: mall-admin 后台管理工程基线 + Element Plus

- 目标仓库: repo-2
- Goal: 从零实例化完整 mall-admin Vue3 + TS + Vite 工程，额外引入 Element Plus 按需自动导入，构建 AdminLayout（4 占位菜单）与 /login 占位页，验证 AC-04 安装/AC-05 启动/AC-06 构建/AC-07 Router/AC-08 Pinia/AC-09 HTTP/AC-10 Element Plus/AC-11 env/AC-12 lint+type-check/AC-13 零业务
- Scope（范围）:
  - 项目根: mall-admin/
    - package.json（从模板 scripts 合并，差异依赖：element-plus / unplugin-auto-import / unplugin-vue-components / @element-plus/icons-vue；其余同 DU-FE-002）
    - pnpm-lock.yaml（独立 lockfile）
    - vite.config.ts（@ alias + server proxy `/api → 8080`，差异：AutoImport + Components 两个 Vite 插件启用，Components 加 ElementPlusResolver，dts=true 生成类型声明文件）
    - index.html / tsconfig*2 / eslint.config.js / prettierrc / npmrc / env files（从模板复制，env title=`AI Mall 后台`）
  - src/:
    - main.ts: `createApp(App).use(router).use(pinia).mount('#app')`（Element Plus 按需由 Vite 插件自动导入组件，不全局注册）；`Components.d.ts` 由 unplugin 生成，在 tsconfig 类型声明路径中指向
    - App.vue: `<router-view />` 一层
    - api/http.ts: 从模板复制（与 mall-web 同构；拦截器锚点相同）
    - router/index.ts: routes[/login → LoginView, / → AdminLayout → 重定向 /dashboard, /dashboard → WorkbenchView, /users → UsersPlaceholderView, /products → ProductsPlaceholderView, /settings → SettingsPlaceholderView, catch-all NotFoundView]；beforeEach 空实现（权限扩展入口）
    - stores/app.ts: 最小 AppStore（应用名 + 折叠侧栏状态 isCollapsed + 切换动作）
    - stores/index.ts: createPinia
    - layouts/AdminLayout.vue: Sidebar（el-menu 渲染静态菜单数组 items: {dashboard, users, products, settings}）+ Header（el-dropdown 占位用户菜单）+ Main（router-view）；用 Element Plus 组件构成
    - layouts/MenuItems.ts: 静态菜单数组（4 项 + icon 使用 @element-plus/icons-vue）
    - views/LoginView.vue: 占位登录页（el-card + 用户名/密码输入框 + 提交按钮；**仅验证 Element Plus 组件正常渲染，不调真实接口，不实现 Token**）
    - views/WorkbenchView.vue: 验证聚合页（展示 env APP_TITLE + Pinia 侧栏状态 + HTTP /__ping 触发按钮 + ElButton/ElInput 基础组件渲染）
    - views/*PlaceholderView（users/products/settings）: 3 个最小占位页（仅文字提示）
    - views/NotFoundView.vue: 404 页面
    - types/index.ts: 同 mall-web 留 ApiResponse<T> 预留；额外 `MenuItem` 类型定义
    - composables/ utils/ assets/ components/ 目录（空）
- Design References: design.md §2.3 技术栈（Element Plus 按需导入）/ §2.5 Router（admin 分支）/ §2.6 Pinia / §2.7 AdminLayout / §2.8 环境变量 / §2.9 质量基线
- Dependencies: DU-FE-001（镜像源文件模板）；与 DU-FE-002 并行但无先后依赖
- Acceptance Criteria:
  - AC-04: `pnpm install` → mall-admin 成功安装
  - AC-05: `pnpm dev` → 开发服务器启动；`/` 重定向 → `/dashboard` → AdminLayout 正常渲染，Element Plus 组件（el-menu、el-card 等）可见无样式异常
  - AC-06: `pnpm build` → dist/ 产出成功
  - AC-07: Router 验证——访问 `/login` → LoginView；访问 `/` → 重定向 `/dashboard`；访问 `/users/products/settings` → 对应占位页；不存在路径 → NotFoundView
  - AC-08: Pinia 验证——点击侧栏折叠按钮 → isCollapsed 在 Header 与 Sidebar 组件间同步
  - AC-09: HTTP Client 验证——WorkbenchView 触发 /__ping → 成功或错误统一走拦截器（与 mall-web 同一验证逻辑）
  - AC-10: Element Plus 验证——登录页的 el-card/el-input/el-button 正常渲染；侧栏 el-menu 正常；WorkbenchView 基础组件正常
  - AC-11: env 验证——`VITE_APP_TITLE` 在 WorkbenchView 显示；.env.production 中 `VITE_API_BASE_URL` 未硬编码
  - AC-12: `pnpm lint` 通过；`pnpm type-check` 通过（含 unplugin 生成的 Components.d.ts 类型声明）
  - AC-13: 静态扫描 → 无 JWT/RBAC/动态菜单/动态路由/用户/角色/商品/库存/订单/系统配置/AI 业务逻辑或类型
- Execution Order: 2
- Parallelization: 组 B（与 DU-FE-002 并行）
- Implementation Sketch:
  ```text
  mall-admin/
  ├── package.json    差异：element-plus + unplugin-auto-import + unplugin-vue-components + icons-vue
  ├── vite.config.ts  差异：AutoImport / Components(ElementPlusResolver({ dts: true }))
  ├── env files       title = AI Mall 后台
  └── src
      ├── main.ts     createApp + router + pinia（Element Plus 不全局注册）
      ├── App.vue     <router-view />
      ├── layouts/AdminLayout.vue
      │   ├── Sidebar   el-menu 渲染 MenuItems（4 项 + icons）
      │   ├── Header    el-dropdown 占位 + Pinia 侧栏折叠按钮
      │   └── Main      router-view
      ├── layouts/MenuItems.ts   静态菜单数组 + MenuItem 类型定义
      ├── router/index.ts        6 条路由 + beforeEach 权限扩展入口
      ├── stores/app.ts          name + isCollapsed + toggleSidebar()
      ├── api/http.ts            从 templates/http.ts 复制
      └── views
          ├── LoginView.vue           el-card 登录占位（不实现逻辑）
          ├── WorkbenchView.vue       验证聚合页：env title + Pinia 折叠 + http __ping 按钮 + ElButton/ElInput
          ├── UsersPlaceholderView    最小占位
          ├── ProductsPlaceholderView 最小占位
          ├── SettingsPlaceholderView 最小占位
          └── NotFoundView.vue        catch-all
  ```
- Pseudocode: N/A（装配型工程任务，路由/菜单/布局为静态声明式配置，无复杂业务流程/算法/状态转换/多组件编排；静态菜单数组只是常量声明，不是 orchestration 级复杂度）
- Verification:
  - Command Verification:
    - `pnpm install` 退出码 0（AC-04）
    - `pnpm lint` 0 error；`pnpm type-check` 通过（AC-12，含 Components.d.ts 类型）
    - `pnpm build` 退出码 0 + dist/ 非空（AC-06）
  - Dev Server Verification:
    - 访问 `/login` → 登录页 + Element Plus 组件渲染（AC-10 入口验证）
    - 访问 `/` → 302/客户端重定向 `/dashboard`（AC-05/AC-07）
    - 侧栏菜单点击 4 项 → 对应占位页（AC-07）
  - Runtime Verification:
    - 折叠按钮切换 → Sidebar 宽度/折叠状态在 Header 与 Sidebar 同步（AC-08，绑定 Pinia）
    - WorkbenchView 按钮 + 输入框 + El 基础组件正常（AC-10 基础）
    - HTTP 按钮触发 → 请求路径/结果或错误展示（AC-09）
    - env title 显示（AC-11）
  - Static Scan（AC-13）: 与 DU-FE-002 同关键字集 + JWT/Token/RBAC/dynamic-menu → 命中数=0
  - Error Case:
    - Element Plus 按需导入未生成 Components.d.ts → vue-tsc 失败；验收阻塞
    - AutoImport 与类型冲突 → eslint 报类型/命名错误，验收失败

---

## 覆盖率矩阵

### 2.1 设计变更点覆盖

design.md §2.x 的每个变更点均落入且仅落入一个 DU：

| 设计变更点（§2） | 归属 DU |
|---|---|
| §2.2 工程结构（仓库根、十目录规范、镜像文件清单） | DU-FE-001（模板）+ DU-FE-002/003（实例化） |
| §2.3 技术栈与版本策略（Vue/TS/Vite/pnpm/Node）、npmmirror 源、Element Plus 按需导入 | DU-FE-001（模板）+ DU-FE-002（无 EP）+ DU-FE-003（含 EP） |
| §2.4 统一 HTTP Client（拦截器锚点 + Mock /__ping 验证） | DU-FE-001（模板 http.ts）+ DU-FE-002/003（验证页触发） |
| §2.5 Router（mall-web 2 路由 + admin 6 路由 + 守卫入口） | DU-FE-002 / DU-FE-003 分别 |
| §2.6 Pinia 最小 AppStore 示例 | DU-FE-002（计数器） / DU-FE-003（侧栏折叠） |
| §2.7 Layout（MallLayout vs AdminLayout + 4 菜单） | DU-FE-002 / DU-FE-003 分别 |
| §2.8 环境变量 + Vite proxy → localhost:8080 | DU-FE-001（.env.example 模板）+ DU-FE-002/003（dev/prod 三件套） |
| §2.9 质量基线（ESLint 9 flat + vue-tsc + Prettier + scripts） | DU-FE-001（模板文件）+ DU-FE-002/003（实际执行） |
| §2.10 关键组件清单（根 README/.gitignore） | DU-FE-001 |

### 2.2 仓库覆盖

affected-repositories: **[repo-2]** → DU-FE-001 ✓ / DU-FE-002 ✓ / DU-FE-003 ✓（全 3 个 DU 归属 repo-2；每个仓至少 1 DU 满足）

### 2.3 PRD 验收标准覆盖

| AC | 归属 DU |
|---|---|
| AC-01 mall-web install | DU-FE-002 |
| AC-02 mall-web dev | DU-FE-002 |
| AC-03 mall-web build | DU-FE-002 |
| AC-04 mall-admin install | DU-FE-003 |
| AC-05 mall-admin dev | DU-FE-003 |
| AC-06 mall-admin build | DU-FE-003 |
| AC-07 Router 全 2 应用 | DU-FE-002 / DU-FE-003 各自 |
| AC-08 Pinia 全 2 应用 | DU-FE-002 / DU-FE-003 各自 |
| AC-09 HTTP Client 全 2 应用 | DU-FE-002 / DU-FE-003 各自（http.ts 基础模板来自 DU-FE-001） |
| AC-10 Element Plus 基础 | DU-FE-003 |
| AC-11 env 变量 全 2 应用 | DU-FE-002 / DU-FE-003 各自（.env.example 模板来自 DU-FE-001） |
| AC-12 lint+type-check 全 2 应用 | DU-FE-002 / DU-FE-003 各自（模板来自 DU-FE-001） |
| AC-13 零业务 全 2 应用 | DU-FE-002 / DU-FE-003 各自（静态扫描关键字） |

## 依赖与跨仓契约

- 接口契约: 本 Change 无真实跨仓调用（M0 HTTP Mock 验证）。预留 frontend → mall-gateway `/api/**`，响应对齐 UnifyResult `{success, code, message, data, traceId}`（CHG-0003 design §2.3）；TraceId header=`X-Trace-Id`
- 仓库依赖: 三个 DU 都属于 repo-2（单仓）；执行依赖：DU-FE-002/003 依赖 DU-FE-001 的模板文件交付（不 materialize 到单独目录，仅在同一仓内按文件路径复制）
- 集成边界: Vite dev proxy `/api → localhost:8080`（mall-gateway CHG-0001 分配端口）；后端未在线时 HTTP 验证走错误路径或 Mock，不阻塞任何 DU
- 跨仓时序: 本 Change 完成后，M1 业务需求需等待 gateway 路由契约冻结后再做联调；此时序不影响本 DU

## 风险缓解映射到 DU

| 风险项（design §6） | 缓解归属 DU | 验收中的验证点 |
|---|---|---|
| Node 22/pnpm 10 环境不可用 | DU-FE-002/003 首次 install 前做环境核验 | AC-01/04 安装前记录 `node -v / pnpm -v` 到 Evidence；不可用 FAIL/Pending 不伪 |
| npm 网络超时 | DU-FE-001 .npmrc 统一镜像源 + 必要时复用本地代理 | AC-01/04 install 超时 Evidence |
| 两应用规范漂移 | DU-FE-001 单一事实源模板 + review 对照镜像文件清单 | AC-12 lint 规则相同 + 模板 diff |
| ESLint 9 与插件兼容 | DU-FE-001 官方配套版本组合；安装后 lint 冒烟 | DU-FE-002/003 首次 `pnpm lint` 0 error |
| EP 按需导入类型配合 | DU-FE-003 unplugin dts=true + Components.d.ts 生成 | `pnpm type-check` 通过 |
| 空仓库首次推送权限/网络 | dev 阶段后段由用户掌控；提交与推送解耦 | 不属于本阶段，不阻塞验收 |
| AC-13 边界回退（提前实现业务） | DU-FE-002/003 静态扫描关键字 | 关键字命中数=0 写入 Evidence |
