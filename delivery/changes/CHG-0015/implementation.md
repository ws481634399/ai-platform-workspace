# Implementation（Change 跨仓聚合兼容层）

## 0. 元信息

- Change ID：CHG-0015（M3 前置就绪修复：雪花 ID 字符串化 + 网关白名单 + 服务间凭证 + 库存分页 + 真实价区）
- Task 来源：两个实现仓的 DU task-design.md / task-spec.md
- 主仓库：repo-1
- 权威 Story：`商品与库存/商品发布与商城查询/商城查询/商城商品列表与详情查询/`（STORY-002-03-02-01）

## 1. Delivery Unit 状态总览

| DU | 仓库 | 状态 |
| --- | --- | --- |
| DU-BE-501 | repo-1（ai-platform-backend） | completed（197→198 全绿；DEV-4 冒烟回归 20/20） |
| DU-FE-501 | repo-2（ai-platform-frontend） | completed（type-check/lint/vitest/build 全绿 + 五页面冒烟） |

## 2. Commit 记录

### repo-1（分支 M3-dev，代码提交）

| Commit | DU | 说明 |
| --- | --- | --- |
| 335c47f | DU-BE-501 | feat(common-web): @StringId 元注解 |
| 6c3d583 | DU-BE-501 | feat(common-security): InternalIdentityFilter 共享凭证 |
| 8c500f1 | DU-BE-501 | feat(product): 字符串 ID + 真实价区 + EXISTS + 内部凭证 |
| 78ed07b | DU-BE-501 | fix(inventory): 分页 + 字符串 ID + 凭证 + 403 |
| e050ec9 | DU-BE-501 | feat(gateway): 显式白名单 + internal 404 外拒 |
| bd309ec | DU-BE-501 | fix(inventory): 流水读取回填雪花 ID（DEV-4，DU-FE-501 冒烟暴露） |

（另有 SDD implementation/evidence、baseline 修正等文档类提交，非代码变更，详见 repo-1 evidence/commits.md。）

### repo-2（分支 M3-dev，代码提交）

| Commit | DU | 说明 |
| --- | --- | --- |
| dd034e8 | DU-FE-501 | refactor(admin-api): 四个 api 模块业务 ID string 化 |
| ffeb468 | DU-FE-501 | refactor(admin-views): 五业务面视图去数值化 |

（另有 SDD evidence 与冒烟日志归档类提交，非代码变更，详见 repo-2 evidence/commits.md。）

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0015/商品与库存/商品发布与商城查询/商城查询/商城商品列表与详情查询/DU-BE-501/implementation.md`
  （含 DEV-1~DEV-4：条件装配、方言自动探测、库存潜伏 400/500 修复、流水 ID 读取回填）
- repo-2：`implementation/ai-platform-frontend/delivery/CHG-0015/商品与库存/商品发布与商城查询/商城查询/商城商品列表与详情查询/DU-FE-501/implementation.md`
  （含 DEV-1~DEV-2：本地 SKU `local-<n>` 临时键、浏览器冒烟 + 接口固化双证据）

## 4. 与 Task / AC 对应关系

| AC | 内容（摘要） | 承载 DU | 证据 |
| --- | --- | --- | --- |
| AC-001 | 网关匿名 GET /api/mall/products 200 | DU-BE-501 | gateway 白名单 + 安全链测试 13/13 |
| AC-002 | 网关匿名详情 200；不可售 404 | DU-BE-501 | product 70/70（无启用 SKU 404） |
| AC-003 | /api/internal/** 外网拒绝 | DU-BE-501 | 网关匿名/持 JWT 均 404 同构体；冒烟双 404 |
| AC-004 | 库存初始化真实 SKU 成功 | DU-BE-501 + 联调 | SkuClient 携带 X-Internal-Token；冒烟 init 100 |
| AC-005 | 库存分页 total 准确 | DU-BE-501 | InventoryAdminApiTest 33 行 total 回归 |
| AC-006 | 商品 id JSON 字符串不丢精度 | DU-BE-501/501 | 冒烟商品 19 位雪花 ID 全链路完整 |
| AC-007 | 五域业务 ID 全部字符串化 | DU-BE-501 + DU-FE-501 | DTO @StringId + 前端类型/视图全绿 |
| AC-008 | 入参字符串/数字 ID 均兼容 | DU-BE-501 | 入参保持 Long（Jackson 原生收 "123"），冒烟字符串入参 |
| AC-009 | 真实价区（整数分、无 null） | DU-BE-501 | 单条 GROUP BY 分组 SQL，product 测试 |
| AC-010 | 无启用 SKU 商品不出现 | DU-BE-501 | mallPage EXISTS 过滤 + 详情 404 |
| AC-011 | mall-admin 五页面零回归 | DU-FE-501 | vitest 31/31 + 五页面真实冒烟 |
| AC-012 | skuId 原样回传无末位偏差 | DU-BE-501 + DU-FE-501 | 冒烟 19 位雪花 SKU ID 全程完整；精度舍入形态反证 404（repo-2 smoke-api-verify.log） |

12 条 AC 全部完成。跨仓联调额外修复 1 个潜伏缺陷（库存流水读取漏传持久化 ID，DEV-4）。
