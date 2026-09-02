---
id: "REQ-M0-002"
name: "建立前端基础工程基线（mall-web 与 mall-admin）"
content: "建立 AI 智能电商微服务平台统一的前端工程基线：一次性完成 mall-web 商城用户端与 mall-admin 后台管理端两个 Vue3 + TypeScript + Vite 应用的基础工程（安装/启动/构建、Router、Pinia、HTTP、环境配置、Layout、代码规范检查），作为单个完整 Change 管理（M0，P0，repo-2 frontend/**）"
source: user
created-at: "2026-09-01T23:32:00+08:00"
---

# Requirement

> 本文件记录需求来源原文，由 sdd-explore 在探索阶段写入。
> 与 exploration.md 分离：本文件是输入沉淀，exploration.md 是分析产物（Feature 归属/影响分析）。
> 原始需求文档（988 行）已完整归档至 `references/REG-M0-002.md`，未做改写；本文件为结构化导航摘录。

## 需求描述

> 以下为需求文档关键内容的忠实摘录（保持原话，未做改写），完整原文以 `references/REG-M0-002.md` 为准。

**Requirement ID**：REQ-M0-002；**名称**：前端基础工程；**Stage**：M0 项目初始化；**Priority**：P0；**前置依赖**：无强依赖，可与 REQ-M0-001、REQ-M0-003、REQ-M0-004 并行开发；**实现范围**：frontend/mall-web/**、frontend/mall-admin/**；**远程仓库**：https://github.com/ws481634399/ai-platform-frontend-web.git

**管理方式**：本 Requirement 作为一个完整 SDD Change 一次性建立 mall-web + mall-admin 两个前端应用的统一工程基线，不拆成两个独立 Change。

### 一、需求目标

建立 AI 智能电商微服务平台统一的前端工程基线，同时完成 mall-web（商城用户端）与 mall-admin（后台管理端）两个 Vue 应用的基础工程。完成后两个应用都应具备独立：安装依赖、本地启动、TypeScript 编译、路由管理、状态管理、HTTP 请求、环境配置、Layout 布局、代码规范检查、生产构建等基础能力，使 M1 及后续商城、后台业务需求可直接在该工程基线上开发。本需求只建立前端工程能力，不开发正式商城和后台业务功能。

### 二、技术基线

统一采用：Vue 3、TypeScript、Vite、pnpm、Vue Router、Pinia、Axios、ESLint、Prettier。后台管理端额外使用 Element Plus。商城端 UI 层暂不强制引入大型组件库，保持商城页面后续可独立设计的能力。

### 三、应用结构

frontend/ 下至少包含 mall-web/ 与 mall-admin/；两个项目必须可独立安装依赖、独立启动、独立构建，不互相依赖对方源码才能运行。

### 四、mall-web 商城前端工程（6 项基础能力）

1. **Vue3 + TypeScript + Vite**：TS 正常工作、Vite 开发服务器可启动、Production Build 可执行、禁止关闭 TypeScript 类型检查规避问题。
2. **Vue Router**：路由配置、页面懒加载、404 页面、基础路由守卫扩展入口；M0 只提供 `/` 与基础测试页面，不提前建商品详情/购物车/订单/用户中心等业务路由。
3. **Pinia**：正常初始化、建立 Store 目录、为用户/购物车状态提供扩展位置；允许最小示例验证，不提前实现完整 UserStore/CartStore/OrderStore。
4. **HTTP 请求基础**：基于 Axios 的统一 HTTP Client（baseURL、timeout、Request/Response Interceptor、Header 扩展、错误统一处理入口）；为 Access/Refresh Token、TraceId、401 处理、业务错误码预留扩展点；M0 不要求完整 Token 刷新逻辑。
5. **环境变量**：.env.development / .env.production / .env.example，可配置 API Base URL、应用名称等；真实 Secret/Token/Password 不得写入 Git。
6. **基础 Layout**：App → MallLayout（Header/Main/Footer）可扩展布局结构；不要求正式商城视觉设计。

### 五、mall-admin 后台管理工程（6 项基础能力）

1. **Vue3 + TypeScript + Vite**：与 mall-web 保持一致，可启动/可构建/TS 正常/Vite 配置结构清晰。
2. **Element Plus**：基础注册、必要全局配置、基础组件可正常使用；不开发正式业务表单或管理页面。
3. **Vue Router**：至少 /login、/、404；/ 对应基础后台 Layout；为动态菜单/动态路由/RBAC/页面权限预留扩展结构（正式功能属 M1）。
4. **后台 Layout**：AdminLayout（Sidebar/Header/Main/RouterView）；可提供静态菜单验证 Layout 和 Router，不实现正式动态菜单。
5. **Pinia**：为登录用户/Token/权限/菜单/应用状态提供统一状态管理基础；不实现完整权限 Store。
6. **HTTP 请求基础**：与商城端统一思想（Axios Instance → Request/Response Interceptor → 统一错误处理），预留 Authorization/Refresh Token/TraceId/401/403/业务错误码扩展；具体 JWT 登录流程由 M1 实现。

### 六、工程规范要求（目录/API/TS/质量/环境）

- **目录规范**：统一清晰目录（api/assets/components/composables/layouts/router/stores/types/utils/views/App.vue/main.ts），额外目录（constants/directives/plugins/styles）由 Design 阶段决定；目录按职责组织，不得在 M0 创建大量无实际用途的空目录空文件。
- **API 层规范**：后续所有后端调用统一经过 src/api/ 或统一 HTTP 基础设施层（View/Store → API Module → HTTP Client → Backend）；禁止业务页面大量直接 axios.get/post；M0 不提前创建业务 API 文件。
- **TypeScript 规范**：业务数据优先定义明确类型，建立 src/types/；禁止大量使用 any；M0 不提前定义 Product/Order/Member/Inventory 等业务模型。
- **代码质量**：统一 ESLint/Prettier/TypeScript 检查，至少提供 pnpm lint、pnpm build（可增 pnpm type-check、pnpm format）；lint/build 可正常执行，不得通过关闭核心规则掩盖明显错误。
- **环境配置**：部署相关参数走环境变量（VITE_API_BASE_URL、VITE_APP_TITLE），禁止硬编码散落业务代码，必须提供 .env.example。

### 七、联调与共享原则

- **Backend 联调**：为 Gateway 调用做好准备（mall-web/mall-admin → mall-gateway → Java Services）；REQ-M0-001 未完成时可用简单 Mock 或基础页面验证 HTTP Client，不因后端未完成阻塞前端工程初始化。
- **共享原则**：统一技术栈/目录规范/代码质量规范/HTTP Client 设计原则/环境变量规范；但不要为"复用"过早创建复杂的 frontend-common 公共包——M0 优先保证 mall-web 独立、mall-admin 独立；后续出现稳定明确的大量重复能力，再通过独立 Requirement 决定是否抽取公共前端 Package。

### 八、禁止提前实现的内容

商城业务（用户注册/登录/首页/分类/商品列表/详情/SKU/购物车/地址/订单/支付/AI 页面）与后台业务（管理员正式登录/JWT/RBAC/动态菜单/动态路由/用户管理/角色管理/菜单管理/商品管理/库存管理/订单管理/系统配置）均属 M1～M6 Requirement。

### 九、建议 Task / Delivery Unit 划分（单 Change 内）

TASK-001 前端工程规范与基础配置 / TASK-002 mall-web 工程基线 / TASK-003 mall-admin 工程基线 / TASK-004 HTTP·Router·Pinia 基础 / TASK-005 ESLint·Prettier·TypeScript / TASK-006 Build 与运行验证；DU 可拆 DU-FE-001 Frontend Convention、DU-FE-002 Mall Web Foundation、DU-FE-003 Mall Admin Foundation、DU-FE-004 Frontend Verification，具体由 Design 阶段最终决定。

### 十、验收标准（AC-01 ~ AC-13）

AC-01 mall-web 可安装；AC-02 mall-web 可启动（基础页面可访问）；AC-03 mall-web 可构建；AC-04 mall-admin 可安装；AC-05 mall-admin 可启动（后台基础页面和 Layout 正常显示）；AC-06 mall-admin 可构建；AC-07 Router 正常（两项目初始化/基础路由可访问/无明显路由异常/404 可用）；AC-08 Pinia 正常（两项目初始化成功、状态可读写）；AC-09 HTTP Client 正常（两项目统一 Axios Client、最小请求验证）；AC-10 mall-admin Element Plus 正常（正确接入、基础组件可渲染）；AC-11 环境变量正常（Development/Production 区分、API Base URL 不硬编码）；AC-12 代码质量检查（pnpm lint 通过、如有 pnpm type-check 同样通过）；AC-13 不提前实现业务（无大量商品/购物车/订单/RBAC/AI 业务逻辑）。

### 十一、Definition of Done 与 Evidence

DoD：两应用 Vue3+TS+Vite 工程完成、pnpm 配置完成、Router/Pinia/Axios/Layout 完成、mall-admin Element Plus 接入完成、环境变量/TS/ESLint/Prettier 规范完成、两应用 build PASS + lint PASS、可独立启动、未提前实现正式业务、测试和构建结果形成 Evidence。

Evidence：至少记录 mall-web 与 mall-admin 的 pnpm install / lint / build 结果（PASS/FAIL）及 Node/pnpm/Vite/Vue/TypeScript 版本；mall-admin 需验证 Router/Pinia/Axios/Element Plus/Layout 基础能力正常；**未实际执行的测试不得记录为 PASS**。

### 十二、非本需求范围

Java Backend、Docker Infrastructure、AI Service、Nacos、MySQL、Redis、MinIO 及任何正式业务功能（分别由 REQ-M0-001 / REQ-M0-003 / REQ-M0-004 及 M1 以后 Requirement 负责）。

## 补充信息

- 需求来源：`docs/需求/M0/REG-M0-002.md`（原始文档已归档至本 Change `references/REG-M0-002.md`；文件名前缀 REG- 为需求文档命名习惯，文档内部自标识为 REQ-M0-002）
- 关联历史：无前端相关已归档 Change（CHG-0001/0002/0003 均为 Java 后端工程需求）；本需求与后端基线（CHG-0001/0002/0003 交付）通过 mall-gateway 联调衔接，M0 不强依赖后端完成
