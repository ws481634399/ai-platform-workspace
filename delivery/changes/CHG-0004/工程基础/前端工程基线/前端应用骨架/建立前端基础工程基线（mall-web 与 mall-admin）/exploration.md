# Exploration

> 阶段：sdd-explore 产物
> 输入：Requirement（requirement.md，原文归档 references/REG-M0-002.md）
> 产出状态：exploring（推进 Change 状态）

本文档记录 sdd-explore 阶段的探索结果。

## 1. 需求理解

**需求类型**：新功能开发（全新工程建设型）——与 CHG-0003"在已交付结构上补能力"不同，前端是**零起点建设**：远程仓库 ai-platform-frontend-web 为空仓库，无任何存量代码与历史负担。

**需求本质**（表面描述 vs 实际意图）：

- 表面：建立 mall-web 与 mall-admin 两个 Vue 应用的基础工程（技术基线 + 6+6 项基础能力 + 13 AC + DoD + Evidence）。
- 实际包含三层意图：
  1. **双应用统一基线**：一个 Change 一次性覆盖两个应用，共享统一技术栈/目录规范/质量规范/HTTP 设计原则/环境变量规范，但两应用必须相互独立运行——"统一"体现在规范一致性，而非代码复用（明确禁止过早创建 frontend-common 公共包）；
  2. **M0 只建"插座"不接"电器"**：Router 守卫扩展入口、Pinia Store 目录、Axios 拦截器扩展点（Token/TraceId/401/403/业务错误码）、admin 动态菜单/RBAC 预留结构，都是为 M1+ 业务预留的接口位，M0 用最小实现验证其可用性，禁止提前实现任何正式业务（§十三 明确列禁）；
  3. **不阻塞并行**：与 REQ-M0-001/003/004 并行，Gateway 未就绪时用 Mock/基础页面验证 HTTP Client。

**隐含需求**（用户未明说但可从文档推出）：

- Node/pnpm 工具链基线需确认（Evidence 要求记录 Node/pnpm 版本，但需求未指定版本约束）；
- 两应用"统一规范"的落点——规范文档化（各自配置文件保持一致）而非抽公共包；
- mall-web 不引入大型 UI 库 → 基础页面需手写最小样式，Layout 结构要为后续独立设计留空间；
- 真实 Secret/Token/Password 不得写入 Git（.env.example 提供变量说明，.env.* 视内容决定是否入库）；
- 未实际执行的验证不得记录为 PASS（Evidence 诚信约束）。

## 2. Feature 归属

- Feature ID: STORY-4
- Feature 路径: MOD-1 工程基础 > FEAT-3 前端工程基线 > FEAT-3-01 前端应用骨架 > STORY-4 建立前端基础工程基线（mall-web 与 mall-admin）
- 是否新建 candidate: no（正式节点，探索阶段创建并绑定；归属方案经用户确认 2026-09-01：现有 MOD-1 下 FEAT-1/FEAT-2 均为 Java 后端分支，前端不属于任一现有 L2 边界，故新建 FEAT-3；保留 L3 层（FEAT-3-01）同时规避 harness bind 对 "story directly under L2" 的已知遍历缺陷）

## 3. 影响分析

- 受影响仓库:
  - **repo-2（implementation/ai-platform-frontend，新建启用）**：全部前端实现落于此仓。explore 阶段已 clone 自远程（github.com/ws481634399/ai-platform-frontend-web.git，当前为空仓库）并在 `.sdd/repositories.yaml` 启用；M0 工程基线将在 dev 阶段初始化提交并推送
  - **工作区仓**：product/feature-tree.yaml（新增 FEAT-3/FEAT-3-01/STORY-4）、.sdd/repositories.yaml（repo-2 启用）、delivery/changes/CHG-0004/ 交付文档
- 不受影响:
  - **repo-1（implementation/ai-platform-backend）零修改**：HTTP Client 目标指向 mall-gateway，M0 用 Mock/基础页面验证，不依赖后端完成（§十一）；CHG-0001/0002/0003 已交付并核验的后端基线无任何回退风险
- 影响范围: 前端为全新仓库，无存量功能受影响；无数据迁移；对 M1+ 商城/后台业务需求形成直接开发基线
- 多仓交付提示: 本 Change 为 workspace 启用 repo-2 后的**首个多仓 Change**，task 阶段 DU 物化（du materialize/sync-status）将同时涉及 repo-2（可能含工作区仓），与 CHG-0003 仅 repo-1 的情形不同

## 4. 未知问题

留待 PRD/设计阶段澄清：

1. **repo-2 内部根布局**：仓库根直接放 mall-web/ 与 mall-admin/（仓库即 frontend/），还是保留 frontend/ 一层目录？需求范围写 `frontend/mall-web/**`（相对 ai-mall-platform 组合视图的路径），仓库根布局需 Design 定
2. **pnpm 工程组织**：两应用各自独立 package.json/lockfile，还是根级 pnpm-workspace.yaml 统一管理？"可独立安装依赖"（§三）与"统一工程基线"存在两种解读，倾向 workspace（保留独立启动/构建能力）但需确认
3. **Node/pnpm 版本基线**：需求未指定；建议按当前 LTS 固化（如 Node 20/22 LTS + pnpm 9/10），是否以 package.json engines / .npmrc 约束需 Design 定
4. **ESLint 配置形态**：flat config（ESLint 9） vs .eslintrc（ESLint 8），与 eslint-plugin-vue、typescript-eslint 的版本配套；两应用配置文件是复制同步还是共享引用
5. **HTTP Client 联调形态**：Vite dev server proxy 指向 mall-gateway 的路径/端口约定（Gateway 端口已在 CHG-0001 分配）；M0 Mock 验证的载体（本地 mock 数据 / echo 式验证页 / 拦截器单元验证）
6. **Element Plus 引入方式**：全量引入 vs 按需自动导入（unplugin-auto-import / unplugin-vue-components），影响依赖清单与 vite 配置结构
7. **基础代码的最小重复边界**：在"不做 frontend-common 公共包"（§十二）约束下，两应用的 axios 封装/Layout/env 读取允许适度重复，重复内容的一致性靠规范文档保证——需 Design 明确哪些文件保持镜像一致
8. **mall-admin 静态菜单范围**：验证 Layout/Router 用的静态菜单条目数与命名（仅占位或对齐 M1 动态菜单的预演结构）

## 5. 旧需求沿用判断

- 匹配进行中 Change: 无（`openspec change list` 结果为空）
- 匹配 archived Change: 无前端相关（CHG-0001/CHG-0002/CHG-0003 均为 Java 后端工程需求，与本需求通过 mall-gateway 联调衔接但无复用关系）
- 决策: **新建 CHG-0004**（全新建设型，无历史前端 Change 可沿用）

## 参考文档

- `references/REG-M0-002.md` — 用户提供的原始需求文档（988 行，完整归档）
- `standards/engineering/frontend/README.md` — 前端工程规范入口（代码/组件/状态/路由/性能五维规范）
- `standards/engineering/frontend/state-management-standard.md` — Pinia 状态管理规范（与需求技术基线一致，无 Vuex 冲突）
- `standards/engineering/frontend/router-standard.md` — 路由组织/守卫/权限预留规范（AC-07 设计约束来源）
- `standards/engineering/frontend/coding-standard.md` — TS 优先/禁止 any 扩散/Lint 要求（§八 TypeScript 规范的规则来源）
- `product/08-系统与微服务架构.md` §3/§4/§5 — mall-web/mall-admin Vue3 蓝图、前端统一经 Gateway 原则、ai-mall-platform 仓库结构（frontend/ 位置依据）
- `product/11-权限与功能配置.md` — RBAC/动态菜单（mall-admin 预留扩展结构的 M1 目标态，记录不引用）
