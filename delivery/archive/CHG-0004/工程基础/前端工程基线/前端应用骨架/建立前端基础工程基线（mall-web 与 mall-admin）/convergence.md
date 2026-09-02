# Convergence — CHG-0004

> 阶段：sdd-converge 产物
> 位置：CHG-0004/review-report.md 同级（STORY 目录，feature-path 绑定投影）
> 输入：completed change（全部 Artifact 已产出）
> 产出状态：completed

本文档记录本次 Change 的知识收敛过程。真正的知识更新发生在 Workspace Knowledge 中（写回 standards/product/），本文件只记录"该不该更新、更新了什么、为什么"。

## 0. 元信息

- Change ID: CHG-0004
- 完成时间: 2026-09-02T16:05:00+08:00
- 状态流转: testing → completed
- 产出 Artifact 数: 9（requirement + exploration + prd + design + tasks + implementation + test-report + review-report + convergence）

## 1. 知识变化总结

本次 Change 一次性建立了 mall-web 商城端与 mall-admin 后台端两个 Vue3 + TS + Vite 前端应用的统一工程基线，带来的知识增量：

- **新规则**：前端 Lint/类型门禁工具链版本配套约定（ESLint 10 flat config + @eslint/js 显式声明、TypeScript 5 固定、双 tsconfig 串联 type-check）；多应用镜像文件对齐约定（替代 frontend-common 公共包）；路由守卫返回值式签名（vue-router 5）；UI 库按需导入与生成 dts 入库约定
- **新模式**：模板复制实例化 + 镜像清单 diff 复核，实现"应用独立可构建 + 配置统一"双目标
- **新 Feature**：STORY-4（前端工程基线）由 planned → delivered
- **无新业务术语**：mall-web / mall-admin 已在词汇表 §2（商品百科条目 120-121 行）定义，本次无新增术语

## 2. 更新判断

### Standards

- 是否需更新: yes
- 更新内容（review-report §1.5 六条候选全部晋升，合并为 4 个规范段落）:
  1. `standards/engineering/frontend/coding-standard.md` — 新增 §13「前端工具链版本配套约定」（13.1 ESLint 10 flat config 配套 + 已验证版本组合表；13.2 TypeScript 版本固定 typescript@5；13.3 双 tsconfig 串联 type-check 命令）与 §14「多应用镜像文件对齐约定」（单一事实源模板复制 + 镜像清单 diff 复核）
  2. `standards/engineering/frontend/router-standard.md` — 新增 §15「路由守卫签名约定」（vue-router 5 弃用 next() 回调 → 返回值式签名，占位守卫 `router.beforeEach(() => true)`）
  3. `standards/engineering/frontend/component-standard.md` — 新增 §14「UI 库按需导入与生成类型入库约定」（unplugin 按需导入 + auto-imports.d.ts/components.d.ts 入库 + main.ts 零全局注册）
- 理由: 六项均具备跨 Change 复用价值——M1 后台 RBAC 前端、M3 商城会员前端及后续所有前端 Change 将直接依赖工具链版本组合、镜像对齐策略、守卫签名与 UI 库导入模式；且均为本次实测踩坑后验证的有效模式（R0025 弃用警告、TS7 peer 冲突、ESLint 10 拆包）

### Product

- 是否需更新: no
- 更新内容: 不适用（本 Change 为工程基础交付，无业务行为约束需晋升 Spec）
- 理由: PRD 13 条 AC 均为工程验收约束（构建/路由/状态/HTTP/UI/质量门禁），不产生产品业务规则；mall-web/mall-admin/前端工程基线等术语已在词汇表定义，无新增术语

### feature-tree.yaml

- 是否需更新: yes
- 更新内容: STORY-4 状态 planned → delivered
- 理由: 本 Change 全部 AC-01~AC-13 通过（17/17 测试证据全绿，四项 review 检查零未闭环 finding），DU-FE-001/002/003 均 completed 且 result commit（122fca9）与 repo-2 HEAD 一致

### Glossary

- 是否需更新: no
- 更新内容: 不适用
- 理由: mall-web（商城端）/ mall-admin（后台管理端）已在 `product/02-统一语言词汇表.md` §2 定义；本次未引入需要团队统一叫法的新业务术语（unplugin/Vite proxy 等为技术概念，已在 design.md 定义）

## 3. 知识沉淀过程

### Standards 写入

以下 4 个知识项（覆盖 6 条候选）已评估并执行写入：

1. **前端工具链版本配套约定** → `standards/engineering/frontend/coding-standard.md` §13
   - 操作: 新增章节（13.1/13.2/13.3 三小节）
   - 内容: ESLint 10 flat config + @eslint/js 显式声明 + 已验证版本组合（eslint 10.9.1 / eslint-plugin-vue 10.10.0 / typescript-eslint 8.69.0 / @eslint/js 10.0.1）；TypeScript 显式固定 typescript@5（TS7 与 typescript-eslint 8 peer 冲突）；双 tsconfig 串联 type-check 命令
   - 理由: 后续前端 Change 的依赖选型与质量门禁命令直接复用
   - 复用场景: M1 后台 RBAC 前端、M3 商城会员前端及所有前端工程变更
   - 对应候选: review-report §1.5 第 1、4、6 条

2. **多应用镜像文件对齐约定** → `standards/engineering/frontend/coding-standard.md` §14
   - 操作: 新增章节
   - 内容: 单一事实源模板复制实例化 + 镜像清单维护 + 评审 diff 复核；替代 frontend-common 公共包的独立性约束下统一性手段
   - 理由: 后续新增前端应用（如 M1 的 mall-admin 扩展）时保证配置一致性
   - 复用场景: 所有前端多应用工程治理
   - 对应候选: review-report §1.5 第 5 条

3. **路由守卫签名约定** → `standards/engineering/frontend/router-standard.md` §15
   - 操作: 新增章节
   - 内容: vue-router 5 返回值式守卫签名（弃用 next() 回调，运行时 R0025 deprecation 警告验证）；占位守卫 `router.beforeEach(() => true)`
   - 理由: M1 登录/权限守卫扩展时直接按返回值式实现
   - 复用场景: 所有 vue-router 5 项目的守卫开发
   - 对应候选: review-report §1.5 第 2 条

4. **UI 库按需导入与生成类型入库约定** → `standards/engineering/frontend/component-standard.md` §14
   - 操作: 新增章节
   - 内容: unplugin-auto-import + unplugin-vue-components + ElementPlusResolver 按需导入；auto-imports.d.ts / components.d.ts 随代码入库；main.ts 零全局注册
   - 理由: 后续所有使用 Element Plus 的页面开发复用此模式
   - 复用场景: M1 后台管理端全部页面
   - 对应候选: review-report §1.5 第 3 条

### No Update

以下知识项评估为 no-update：

1. **具体依赖版本号全表（vue 3.5.42 / vite 8.2.2 / pinia 4.0.3 等）**
   - 理由: 版本权威源是各应用 pnpm-lock.yaml，standards 只沉淀版本配套规则（major 约束），不重复记录具体 minor/patch 版本

2. **Vite proxy 配置细节（/api → localhost:8080）**
   - 理由: 属实现细节，已在 design.md §2.8 固化且代码注释留锚点，M0 无真实跨仓调用

3. **/__ping 验证聚合页、HomeView 计数器等验证载体实现**
   - 理由: 仅本次 Change 特有的验证脚手架，不具备跨 Change 复用价值

4. **store 示例形态（counter / isCollapsed）**
   - 理由: 已有 `state-management-standard.md` 覆盖 Pinia 组织约定，示例形态属实现细节（DEV-6 演进已在 DU 记录）

### Feature Tree 更新

STORY-4 状态变更：planned → delivered（通过 `openspec feature update STORY-4 --status delivered` 执行）

## 4. 完成确认

- [x] 全部前序 Artifact 已读取（requirement/exploration/prd/design/tasks/implementation/test-report/review-report + 各仓 DU 证据）
- [x] 知识分类完成（4 项 standards 晋升覆盖 6 条候选 + 4 项 no-update）
- [x] standards 更新已写入（3 个文件、4 个新章节，保留原有 §1~§12/§13/§14 全部历史内容）
- [x] product 更新已写入（无需更新，判断理由见 §2）
- [x] Feature Tree Story 状态已更新（STORY-4 → delivered）
- [x] 索引已重建（standards/INDEX.md + product/INDEX.md + .sdd/knowledge-index.json）
- [x] 无未解决的 Conflict 或 Unresolved 问题（6 条候选与现有规范无冲突，均为新增章节补充）
