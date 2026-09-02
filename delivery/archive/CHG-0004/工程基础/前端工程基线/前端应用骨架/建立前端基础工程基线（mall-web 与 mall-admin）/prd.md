# PRD

> 阶段：sdd-prd 产物
> 输入：CHG Context（exploration.md + requirement.md）
> 产出状态：specified

本文档将需求转化为产品规格。

## 0. 元信息

- Change ID: CHG-0004
- Requirement: REQ-M0-002（原始文档 988 行归档于 references/REG-M0-002.md）
- Feature ID: STORY-4（MOD-1 工程基础 > FEAT-3 前端工程基线 > FEAT-3-01 前端应用骨架）
- 状态流转: exploring → specified

## 1. 背景

CHG-0001/0002/0003 已交付并核验了 Java 后端工程基线（Maven 四层体系、mall-common/contracts 边界、Gateway + 8 服务骨架、数据访问与 Web/测试基础），但前端侧为零起点：远程仓库 ai-platform-frontend-web 是空仓库，无任何工程资产。M1 商城业务（首页/商品/购物车/订单/AI 导购）与后台业务（登录/RBAC/动态菜单/商品库存管理）即将进入实施，若 M0 不建立统一前端工程基线，mall-web 与 mall-admin 将各自搭建 Router/Pinia/HTTP/规范配置，产生实现漂移与重复劳动。

本 Change 在 explore 阶段已启用 repo-2（clone 自远程并登记 repositories.yaml），作为**启用 repo-2 后首个多仓 Change**，一次性建立两个前端应用的统一工程基线（Requirement 明确禁止拆成两个独立 Change）。与 CHG-0003"在已交付结构上补能力"不同，本 Change 为全新建设型——无存量代码、无迁移负担、对后端零修改（HTTP 联调目标 mall-gateway 仅做预留）。

## 2. 用户价值

- 目标用户: M1+ 前端业务需求的实施者（前端开发 Agent / 工程师）、商城终端用户（间接受益于稳定基线）、平台构建/运维角色
- 痛点摘要: 前端工程完全空白；两个应用若独立摸索将产生技术栈、目录结构、HTTP 封装、Lint 规则的四重漂移；每开发一个业务页面都要重复解决工程问题
- 预期价值:
  - 前端实施者: When I 开始开发 M1 商城或后台业务需求, I want to 在具备 Router/Pinia/HTTP/Layout/环境变量/Lint 统一基线的应用骨架上直接编写业务代码, So that 不再重复处理工程问题、两应用行为一致
  - 平台: When 我需要校验前端工程健康度, I want to 通过 pnpm install/dev/lint/build 四个入口一键验证, So that 工程质量可度量、可验收

## 3. 范围

### 3.1 包含

- 包含范围摘要（P0 全部必须，单 Change 交付 mall-web + mall-admin 两应用）:
  1. **建立 repo-2 工程规范与基础配置**：统一技术基线（Vue 3 + TypeScript + Vite + pnpm + Vue Router + Pinia + Axios + ESLint + Prettier）落地到两个独立应用；Node 22 LTS + pnpm 10 版本约束（engines）
  2. **建立 mall-web 工程基线**：可安装/可启动/可构建；Router（`/` + 基础测试页 + 404 + 懒加载 + 守卫扩展入口）；Pinia（初始化 + Store 目录 + 最小示例）；统一 Axios HTTP Client（baseURL/timeout/拦截器/错误处理入口）；MallLayout（Header/Main/Footer）可扩展结构；.env.development/.env.production/.env.example
  3. **建立 mall-admin 工程基线**：可安装/可启动/可构建；Router（/login、/、404）；AdminLayout（Sidebar/Header/Main/RouterView）+ 4 个静态占位菜单（工作台/用户管理/商品管理/系统设置，仅验证 Layout 与跳转）；Element Plus 接入（注册/全局配置/基础组件可渲染）；Pinia 初始化；统一 Axios HTTP Client（与 mall-web 同一设计原则）；.env 三件套
  4. **落地目录规范**：两应用统一 src/ 职责目录（api/assets/components/composables/layouts/router/stores/types/utils/views + App.vue + main.ts）
  5. **落地 API 层纪律**：统一 HTTP 基础设施为唯一出口（View/Store → API Module → HTTP Client → Backend）；M0 不创建业务 API 文件，不阻止后续扩展
  6. **落地 TypeScript 规范**：src/types/ 建立项目级通用类型；类型检查开启不得关闭
  7. **建立代码质量基线**：pnpm lint / pnpm build 可执行并通过；可增加 pnpm type-check / pnpm format
  8. **落地环境变量规范**：VITE_API_BASE_URL、VITE_APP_TITLE 等走环境变量；.env.example 说明所需变量
  9. **预留 Gateway 联调能力**：HTTP Client 目标指向 mall-gateway（dev 场景经 Vite proxy 预留），M0 用简单 Mock 或基础页面完成最小请求验证，不因后端未就绪阻塞
  10. **形成 Evidence**：两应用 install/lint/build 结果与工具链版本（Node/pnpm/Vite/Vue/TS）归档

### 3.2 不包含

- 不包含范围摘要:
  - 一切商城业务页面：首页、分类、搜索、商品详情、SKU 选择、登录注册、购物车、收货地址、订单、支付、AI 导购/对比/客服/订单助手页面
  - 一切后台业务功能：管理员正式登录、JWT、RBAC、动态菜单、动态路由、用户/角色/菜单管理、商品/库存/订单管理、系统配置、AI 知识库管理、运维管理
  - 完整业务 Store（UserStore/CartStore/OrderStore/权限 Store）与业务 API 文件（auth/product/cart/order.ts）
  - 业务模型类型（Product/Order/Member/Inventory）——待后端接口稳定后逐步建立
  - frontend-common 公共前端包（Requirement §十二明确禁止过早创建）
  - Access/Refresh Token 完整逻辑、401/403 完整处理（仅预留拦截器扩展点）
  - Java Backend、Docker、Nacos、MySQL、Redis、MinIO、AI Service（REQ-M0-001/003/004 及后续）
  - pnpm workspace / monorepo 工程组织（已决策：两应用完全独立）
  - CI/CD 流水线、浏览器兼容性矩阵、移动端适配、i18n、单元测试框架接入（Vitest 等，属后续 Requirement）

## 4. 业务规则

- [应用独立性] mall-web 与 mall-admin 互不依赖对方源码 → 各自可独立 install/dev/build；一方损坏不得阻塞另一方
- [无公共包] 出现为复用而创建的 frontend-common 类公共包 → 违反 Requirement §十二 → 禁止；稳定重复能力走独立 Requirement 决策
- [业务零实现] 代码中出现商品/购物车/订单/RBAC/AI 等业务逻辑 → 违反 AC-13 → 禁止提前实现
- [类型安全] 业务代码大量使用 any 规避类型设计 → 禁止；关闭 TypeScript 类型检查规避问题 → 禁止
- [API 层纪律] 业务页面/组件直接调用 axios.get/post → 禁止；必须经统一 HTTP Client（未来经 api 模块）
- [凭据安全] 真实 Secret/Token/Password 写入 Git → 禁止；环境变量含义由 .env.example 说明
- [硬编码禁止] API Base URL、应用名称等部署相关参数硬编码在业务代码中 → 禁止；必须走 VITE_ 环境变量
- [核心规则保真] 通过关闭 ESLint 核心规则或 TS 检查掩盖明显错误 → 禁止
- [版本基线] Node 22 LTS + pnpm 10 → package.json engines 约束；Evidence 记录实际使用版本
- [预留不实现] Router 守卫/Pinia Store 目录/HTTP 拦截器只建扩展入口与最小验证 → 不实现完整 Token 刷新、401/403 流程、权限 Store（属 M1）
- [证据真实性] 未实际执行的验证不得记录为 PASS → Evidence 必须来自真实命令输出

## 5. 验收标准

> 编号沿用需求文档 AC-01~AC-13（保持稳定，供 task 阶段 DU 引用），Smart 化表述：

- [ ] AC-01: frontend/mall-web 目录执行 pnpm install → 安装成功（Evidence: 安装日志）
- [ ] AC-02: mall-web 执行 pnpm dev → 开发服务器正常运行，基础页面可访问（Evidence: 启动日志 + 页面验证）
- [ ] AC-03: mall-web 执行 pnpm build → 构建成功（Evidence: 构建日志）
- [ ] AC-04: frontend/mall-admin 目录执行 pnpm install → 安装成功（Evidence: 安装日志）
- [ ] AC-05: mall-admin 执行 pnpm dev → 后台基础页面与 AdminLayout 正常显示（Evidence: 启动日志 + 页面验证）
- [ ] AC-06: mall-admin 执行 pnpm build → 构建成功（Evidence: 构建日志）
- [ ] AC-07: 两项目 Router 核验——初始化正常、基础路由可访问、无路由异常告警、404 路由生效（访问不存在路径 → 404 页面）
- [ ] AC-08: 两项目 Pinia 核验——初始化成功、最小状态可读取与更新（最小示例/验证页形态）
- [ ] AC-09: 两项目 HTTP Client 核验——统一 Axios Client 存在、最小 HTTP 请求验证通过（Mock 或真实目标，Evidence 记录验证方式）
- [ ] AC-10: mall-admin Element Plus 核验——正确接入，基础组件（如按钮/表单控件）在验证页正常渲染
- [ ] AC-11: 环境变量核验——development/production 配置区分生效、API Base URL 来自环境变量（业务代码无硬编码地址）
- [ ] AC-12: 两应用执行 pnpm lint → 通过；如提供 pnpm type-check → 同样通过（Evidence: 检查日志）
- [ ] AC-13: 静态检查核验——代码中不存在为完成 M0 提前实现的大量商品/购物车/订单/RBAC/AI 业务逻辑

### 未知问题定向决策（承接 exploration §4，8 项全部闭环）

1. **repo-2 根布局**（用户确认 2026-09-01）：仓库根即应用根——repo-2 根直接放 mall-web/ 与 mall-admin/（对齐后端"仓库根即层根"先例），根 README 说明双应用结构；`frontend/mall-web/**` 为组合视图路径
2. **pnpm 组织**（用户确认 2026-09-01）：**两应用完全独立**——各自 package.json/lockfile，不建 pnpm workspace；统一性靠目录/规范文档 + 镜像文件清单约束
3. **版本基线**（用户确认 2026-09-01）：Node 22 LTS + pnpm 10，engines 字段约束；具体小版本以 Evidence 实测为准
4. **ESLint 配置形态**：定向 flat config（ESLint 9 + eslint-plugin-vue + typescript-eslint）；两应用各自持有配置文件、内容保持一致；具体规则集留设计阶段
5. **HTTP Client 联调形态**：VITE_API_BASE_URL 环境变量 + Vite dev proxy 预留指向 mall-gateway（端口沿用 CHG-0001 分配）；M0 最小验证用 Mock/基础页面，载体细节留设计阶段
6. **Element Plus 引入方式**：定向按需自动导入倾向（unplugin-auto-import / unplugin-vue-components），最终方案（含与 TS 类型配合）留设计阶段确认
7. **镜像文件边界**：axios 封装、env 读取、目录结构在两应用各自持有（独立原则），内容对齐同一规范；需保持镜像一致的文件清单由设计阶段列出
8. **mall-admin 静态菜单**（用户确认 2026-09-01）：4 个占位菜单项（工作台/用户管理/商品管理/系统设置），仅验证 Layout 渲染与 Router 跳转，不承载页面内容
