# Implementation（跨仓实施汇总）— 商城商品列表与详情查询 STORY-002-03-02-01

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文位于各实现仓 DU 目录。

## 0. 元信息

- Change ID：CHG-0015（M3 前置就绪修复）
- Story：STORY-002-03-02-01 商城商品列表与详情查询
- 实施日期：2026-09-15
- 范围边界：不新增产品能力；不包含 CHG-0017 的公开分类树/品牌/批量库存接口、mall-web 页面、会员与购物车。

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-501 | repo-1（ai-platform-backend） | 完成并验证（全量 197→DEV-4 后 inventory 20/20） |
| DU-FE-501 | repo-2（ai-platform-frontend） | 完成并验证（type-check/lint/vitest 31/build + 真后端五页面冒烟） |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 335c47f | DU-BE-501 | repo-1 | @StringId 元注解（仅出参字符串化） |
| 6c3d583 | DU-BE-501 | repo-1 | InternalIdentityFilter 服务间共享凭证 |
| 8c500f1 | DU-BE-501 | repo-1 | product 字符串 ID + 真实价区 GROUP BY + EXISTS + 内部凭证 |
| 78ed07b | DU-BE-501 | repo-1 | inventory 分页插件 + 字符串 ID + 凭证 + 403 |
| e050ec9 | DU-BE-501 | repo-1 | gateway 显式白名单 + internal 404 同构外拒 |
| bd309ec | DU-BE-501 | repo-1 | DEV-4：库存流水读取回填雪花 ID（联调暴露） |
| dd034e8 | DU-FE-501 | repo-2 | mall-admin 四个 api 模块业务 ID string 化 |
| ffeb468 | DU-FE-501 | repo-2 | 五业务面视图去数值化（路由/表单/筛选/行键） |

（两仓另有 SDD implementation/evidence 文档、baseline 与冒烟日志归档类提交，非代码变更，详见各仓 evidence/commits.md。）

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0015/商品与库存/商品发布与商城查询/商城查询/商城商品列表与详情查询/DU-BE-501/implementation.md`
  （DEV-1 条件装配 / DEV-2 方言自动探测 / DEV-3 库存 400·500 潜伏缺陷 / DEV-4 流水 ID 读取回填）
- repo-2：`implementation/ai-platform-frontend/delivery/CHG-0015/商品与库存/商品发布与商城查询/商城查询/商城商品列表与详情查询/DU-FE-501/implementation.md`
  （DEV-1 本地 SKU `local-<n>` 临时键 / DEV-2 浏览器冒烟 + 接口固化双证据）

## 4. 与 Task 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001/002 | 网关商城路由白名单匿名放行；product 详情无启用 SKU 404（gateway 13/13、product 70/70） | passed |
| AC-003 | `/api/internal/**` 网关匿名/持 ADMIN JWT 均 404 同构体（冒烟双 404） | passed |
| AC-004 | SkuClient 携带 X-Internal-Token；冒烟真实 SKU init 100 成功 | passed |
| AC-005 | 库存分页插件；33 行 total=33 翻页恒定回归 | passed |
| AC-006/007/008 | 五域 DTO @StringId 全字符串、入参保持 Long 兼容 "123"；前端四 api + 五视图类型清零 | passed |
| AC-009/010 | 启用 SKU 价区单条 GROUP BY MIN/MAX；mallPage EXISTS 过滤无启用 SKU 商品 | passed |
| AC-011 | mall-admin 五页面 CRUD/分页/跳转/回显零回归（vitest 31/31 + 浏览器冒烟） | passed |
| AC-012 | 冒烟商品与 SKU 的 19 位雪花 ID 全程无末位偏差；精度舍入形态 ID 反证 404（见 repo-2 smoke-api-verify.log） | passed |

## 5. Fan-in 与验证结论

- 后端：`mvn clean package` 24 模块 BUILD SUCCESS，13 个测试模块 197/197；DEV-4 追加后 inventory 20/20。
- 前端：vue-tsc 双 tsconfig 0 错误；eslint 0 error；vitest 14 文件 31/31；vite build 成功。
- 端到端：Docker 基础设施 + identity/product/inventory/gateway + vite 真实联调；
  品牌/分类三级/商品+SKU 创建→编辑回显→库存 init/adjust→日志筛选全链路通过。
- 联调额外产出：修复库存流水读取漏传持久化 ID 的潜伏缺陷（DU-BE-501 DEV-4，red→green 可审计）。
