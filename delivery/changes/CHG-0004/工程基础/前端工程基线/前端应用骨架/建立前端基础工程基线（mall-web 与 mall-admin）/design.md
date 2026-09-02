---
affected-repositories: [repo-2] # Phase 2.4：受影响仓库 id 列表（对应 .sdd/repositories.yaml，供 task 阶段 du-coverage 机检）
---

# Design

> 阶段：sdd-design 产物
> 输入：prd.md
> 产出状态：designed

本文档制定技术方案。

职责边界（硬约束）：Design 回答"系统如何实现、哪些仓受影响、跨仓如何协作"；不产生正式交付单元（正式拆分是 sdd-task 的职责，本文 §8 仅保留 Requirement 建议的任务域映射）。

## 0. 元信息

- Change ID: CHG-0004
- PRD 来源: CHG-0004/prd.md（STORY 目录）
- 状态流转: specified → designed
- PRD 决策映射：repo-2 根布局=仓库根即应用根（§2.2）、两应用完全独立（§2.1/§2.2）、Node 22 + pnpm 10（§2.3）、4 个占位菜单（§2.5/§2.7）、ESLint flat config（§2.9）、Vite proxy + Mock 验证（§2.4/§2.8）、Element Plus 按需导入（§2.3）、镜像文件清单（§2.2）

## 1. 当前状态

repo-2 为空仓库（explore 阶段 clone 自远程并登记 repositories.yaml），无任何存量代码——本设计是**从零初始化**方案，无迁移负担、无兼容性问题。前端规范体系已在 standards/engineering/frontend/ 固化（五维标准），后端集成锚点已由 CHG-0001 分配（mall-gateway=8080，业务服务=8101~8108）。

### 1.1 repo-2 现状与约束

- 当前架构模式: 空仓库（main 分支，零提交）——探索阶段经本地代理 clone 验证过网络可达性
- 相关仓库: repo-2（implementation/ai-platform-frontend，远程 github.com/ws481634399/ai-platform-frontend-web.git）
- 已固化约束: 前端五维标准（coding/component/state-management/router/performance）——Pinia 选型、路由组织、TS 优先、组件职责；PRD 11 条业务规则（应用独立性/无公共包/业务零实现/类型安全/API 层纪律等）

## 2. 提议方案

设计原则落地：单一职责（src 十目录各司其职）、开闭原则（HTTP 拦截器/路由守卫/Store/菜单均为数据驱动 + 扩展入口）、依赖倒置（View/Store → api 抽象层 → HTTP Client）、复用优先（复用 Vue 生态标准方案，不造轮子；**不抽 frontend-common 公共包**——独立性优先，统一性靠规范与镜像清单）。

### 2.1 方案概要

**两应用完全独立的镜像式基线**：mall-web 与 mall-admin 各自持有完整工程（package.json/lockfile/配置/依赖），内容对齐统一规范；差异面收敛为三处——mall-admin 增加 Element Plus、AdminLayout（Sidebar+Header）、/login 路由与登录占位页；mall-web 使用 MallLayout（Header/Main/Footer）、无 UI 库。

- 方案概要: repo-2 根直接放置两个完全独立应用 + 根 README/.gitignore；十目录 src 规范、统一 HTTP Client、Router/Pinia 最小验证、环境变量三件套、ESLint 9 flat config + Prettier + vue-tsc 质量基线

### 2.2 工程结构（repo-2 根布局与目录规范）

```
ai-platform-frontend/            # repo-2 仓库根（即应用根层）
├── README.md                    # 双应用结构说明 + 各自快速开始
├── .gitignore                   # node_modules/ dist/ .env.*（保留 .env.example）等
├── mall-web/                    # 商城用户端（完全独立工程）
│   ├── package.json             # engines: { node: ">=22", pnpm: ">=10" }
│   ├── pnpm-lock.yaml           # 版本权威（前端对应 mall-bom 的角色）
│   ├── vite.config.ts / index.html
│   ├── tsconfig.json / tsconfig.node.json
│   ├── eslint.config.js / .prettierrc.json / .npmrc
│   ├── .env.development / .env.production / .env.example
│   └── src/
│       ├── main.ts / App.vue
│       ├── api/http.ts          # 统一 Axios Client（唯一 HTTP 出口）
│       ├── assets/  components/  composables/  utils/
│       ├── layouts/MallLayout.vue        # Header / Main(router-view) / Footer
│       ├── router/index.ts
│       ├── stores/              # Pinia 目录 + 最小示例 store
│       ├── types/               # 项目级通用类型
│       └── views/               # HomeView（基础测试页）+ NotFoundView
└── mall-admin/                  # 后台管理端（完全独立工程，同构）
    └── （同上结构，差异见 §2.5/§2.7）
```

**镜像文件清单**（两应用各自持有、内容保持一致，review 阶段对照检查）：

- `src/api/http.ts`（Axios 封装结构与扩展点位）
- `tsconfig.json` / `tsconfig.node.json` / `eslint.config.js` / `.prettierrc.json` / `.npmrc`
- `.env.example` / `package.json` 的 scripts 段（dev/build/preview/lint/type-check/format）
- 目录骨架（十目录规范一致）

允许自然差异：package.json 依赖清单（admin 多 element-plus 及 unplugin 系）、vite.config.ts（admin 多按需导入插件）、views/layouts 内容。

### 2.3 技术栈与版本策略

- 栈: Vue 3（Composition API + `<script setup>`）+ TypeScript + Vite + pnpm 10 + Node 22 LTS（engines 约束）
- 路由/状态/HTTP: vue-router 4 / pinia / axios
- 质量: ESLint 9 flat config（eslint-plugin-vue + typescript-eslint 官方配套）+ Prettier + vue-tsc（type-check）
- mall-admin 专属: element-plus 按需自动导入（unplugin-auto-import + unplugin-vue-components，含 ElementPlusResolver 类型声明）
- 版本权威: **pnpm-lock.yaml 即前端版本权威**（对齐后端 mall-bom 唯一权威原则）；具体 minor 版本由 dev 阶段安装时锁定，Evidence 记录实测版本（Node/pnpm/Vite/Vue/TS）
- 源策略: 两应用 `.npmrc` 统一 `registry=https://registry.npmmirror.com`（网络环境适配，初稿决策可调）

### 2.4 统一 HTTP Client 设计（src/api/http.ts）

- 实例: `axios.create({ baseURL: import.meta.env.VITE_API_BASE_URL, timeout: 10000 })`
- Request 拦截器: M0 仅透传，**预留 header 扩展位**（Authorization / X-Trace-Id 注释锚点，M1 填充）
- Response 拦截器: 统一错误处理入口——响应错误进入统一日志 + `Promise.reject` 透传；**预留 401/403/业务错误码处理位**（M1 填充，M0 不实现 Token 刷新）
- 出口纪律: 业务代码禁止直接 import axios，一律经本实例（未来经 src/api/ 业务模块）
- M0 Mock 验证载体（PRD 定向）: 不引入 MSW 等测试框架——验证页提供按钮触发 `http.get('/__ping')` 请求，可观测两条路径即验证通过：目标可达 → 正常响应路径；目标不可达 → 错误进入统一错误入口。Evidence 记录请求发起与拦截器行为

### 2.5 Router 设计

- mall-web: `routes = [/ → MallLayout → HomeView（懒加载）, /:pathMatch(.*) → NotFoundView]`；`router.beforeEach` 空实现占位（守卫扩展入口）
- mall-admin: `routes = [/login → LoginView（占位页）, / → AdminLayout → 工作台（重定向默认）, /users /products /settings 三个占位页, 404]`；静态菜单数组驱动（`meta: { title }` 与渲染分离），为 M1 动态菜单/RBAC 预留结构
- 404: 两应用均有 catch-all；懒加载全部页面级组件
- 接口契约（前端内部）: 路由命名采用 kebab-case path + PascalCase 组件名；无真实后端调用（AC-07 仅本地验证）

### 2.6 Pinia 设计

- `stores/` 目录 + 最小示例 store（`app.ts`：应用名/标题状态 + 一个计数器动作）——验证跨组件读写（AC-08）
- 不建 UserStore/CartStore/OrderStore/权限 Store（M1+）
- Store 组织约定: defineStore setup 语法、按域一文件（规范固化，业务留白）

### 2.7 Layout 设计

- MallLayout: `Header`（VITE_APP_TITLE 应用名占位）/ `Main`（router-view）/ `Footer`（版权占位）；无 UI 库，最小手写样式（为 M1 商城视觉设计留白）
- AdminLayout: `Sidebar`（el-menu 渲染静态菜单 4 项：工作台/用户管理/商品管理/系统设置）+ `Header`（占位）/ `Main`（router-view）；菜单项为静态数组，数据与渲染分离（M1 换数据源即得动态菜单）
- 接口契约（组件内部）: Layout 不承载业务逻辑，仅布局与导航

### 2.8 环境变量设计

- 变量: `VITE_API_BASE_URL`（dev 默认 `/api` 经 Vite proxy 转发，避免 CORS；prod 留空由部署注入）、`VITE_APP_TITLE`（应用名）
- 文件: `.env.development` / `.env.production` / `.env.example`（仅说明变量含义，不含真实凭据）
- Vite dev proxy 预留: `server.proxy['/api'] → http://localhost:8080`（mall-gateway，CHG-0001 分配；M0 后端无需在线，仅预留转发配置）
- 接口契约（配置层）: 业务代码零硬编码地址，全部经 `import.meta.env`

### 2.9 质量基线

- scripts: `dev` / `build`（vite build）/ `preview` / `lint`（eslint . --fix? → 仅检查，不带 --fix）/ `type-check`（vue-tsc --noEmit）/ `format`（prettier）
- ESLint 9 flat config: eslint + eslint-plugin-vue（vue3-recommended）+ typescript-eslint；**不关闭核心规则**（PRD 规则保真）
- build 与 type-check 分离：build 保持快速，类型门禁由 type-check 承担（AC-12 要求 lint + type-check 双通过）
- 接口契约（命令层）: 两应用命令名完全一致（镜像 scripts）

### 2.10 关键组件清单

- 关键组件: 根 README/.gitignore / mall-web 全套工程（package.json+vite.config+tsconfig+eslint+prettier+.npmrc+.env 三件套+src 十目录）/ mall-admin 同构全套（+Element Plus 按需导入）+ LoginView/4 占位页/AdminLayout / 两应用 `api/http.ts` / `router/index.ts` / `stores/app.ts` / 验证页（Home/工作台内 HTTP+Pinia 最小验证入口）

## 3. 仓库影响（Repository Impact）

- 受影响仓库数: 1
- 主要修改点: repo-2 从空仓库初始化为双应用结构——全部前端工程资产、验证页与质量基线；工作区仓交付文档与 feature-tree/repositories.yaml 已在 explore 阶段变更（不计入 affected-repositories）

### 3.1 repo-2（implementation/ai-platform-frontend）

- 技术职责: 承载两应用全部工程基线实现与 AC-01~AC-13 验证
- 修改概要: 首次提交建立仓库根（README/.gitignore）+ mall-web 完整工程 + mall-admin 完整工程；无存量代码修改、无删除
- 涉及模块: mall-web/**、mall-admin/**、根 README.md、根 .gitignore

## 4. 跨仓协作（Cross-Repository Contract）

- 接口契约: M0 无真实跨仓调用（HTTP 验证走 Mock 路径）。**预留契约**：mall-web/mall-admin → mall-gateway（http://localhost:8080），统一前缀 `/api/**`；响应结构遵循后端 UnifyResult `{success, code, message, data, traceId}`（CHG-0003 §2.3 已定），TraceId header=`X-Trace-Id`——前端 Response 拦截器的错误码处理位按此契约设计
- 仓库依赖: repo-2 逻辑依赖 repo-1 的 mall-gateway（**M0 不阻塞**：后端未在线时走 Mock/错误路径验证）
- 集成边界: 网关地址 `http://localhost:8080`（仅出现在 vite proxy 目标与生产部署说明，业务代码零硬编码）；环境变量清单 `VITE_API_BASE_URL` / `VITE_APP_TITLE`；dev proxy `/api → 8080`
- 跨仓时序: 本 Change（M0）先于后端联调——工程基线完成后，M1 联调需求在 gateway 路由可用后进行

## 5. 数据变更

- 是否需 Migration: no
- 变更摘要: 纯前端工程初始化，无数据库/数据文件变更

## 6. 风险

- 风险等级: 中
- 主要风险与缓解:

| 风险项 | 级别 | 缓解措施 |
|--------|------|---------|
| Node 22/pnpm 10 环境在执行环境不可用 | 中 | dev 阶段先做环境核验并记录 Evidence；不可用时如实记录 FAIL/Pending，不伪称 PASS |
| npm 源网络不可达/超时 | 中 | .npmrc 统一 npmmirror 镜像源；必要时沿用本地代理（explore 已验证可达路径） |
| 两应用完全独立导致规范漂移 | 中 | §2.2 镜像文件清单固化 + review 阶段对照检查项 |
| ESLint 9 flat config 与 vue/typescript 插件兼容性 | 低 | 采用官方文档推荐配套版本组合，安装后以 lint 冒烟验证 |
| Element Plus 按需导入与 TS 类型配合问题 | 低 | unplugin 官方配置模式 + Components dts 声明，type-check 验证 |
| 空仓库首次推送权限/网络失败 | 低 | 推送时机由用户掌控；本地提交与远程推送解耦 |
| AC-13 边界回退（提前实现业务） | 低 | 占位页/示例命名显式 placeholder 语义 + review 静态检查 |

## 7. 待澄清问题

- 无阻塞性待澄清。npm 镜像源选择（npmmirror）、dev proxy 目标写死 localhost:8080、验证页具体形态（按钮触发的 /__ping 请求）均为设计内初稿决策，任务拆解与开发阶段可微调

## 8. 任务域建议（Requirement §九 建议映射，正式拆分由 sdd-task 产出）

- TASK-001 前端工程规范与基础配置 → §2.2 镜像清单/§2.3 版本策略/§2.9 质量基线
- TASK-002 mall-web 工程基线 → §2.2 结构 + §2.4~§2.8 全量（不含 Element Plus）
- TASK-003 mall-admin 工程基线 → §2.2 结构 + §2.4~§2.8 + Element Plus 按需导入（§2.3）
- TASK-004 HTTP·Router·Pinia 基础 → §2.4/§2.5/§2.6（随 TASK-002/003 交付，验证载体见 §2.4）
- TASK-005 ESLint·Prettier·TypeScript → §2.9（随 TASK-001/002/003 交付）
- TASK-006 Build 与运行验证 → AC-01~AC-13 逐项验证与 Evidence 归档（install/dev/lint/type-check/build）
