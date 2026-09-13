# Test Report — 品牌管理 STORY-002-01-02-01

> 阶段：sdd-test 产物
> 位置：Story 级 evidence/test-report.md
> 输入：test-design.md + 仓内 DU implementation.md
> 产出状态：testing

本文档记录测试执行情况与证据；仓侧测试日志正文不复制，以 evidence-ref 引用。

## 0. 元信息

- Change ID: CHG-0010
- Story ID: STORY-002-01-02-01（品牌管理）
- Implementation 来源: 同目录 implementation.md（repo-1 DU-BE-303、repo-2 DU-FE-302）
- 状态流转: developing → testing
- 执行时间: 2026-09-13
- Evidence 索引: CHG-0010/evidence/evidence.yaml（EV-017 后端 test-run、EV-018 前端 test-run、EV-013/EV-014 evidence-ref）

## 1. 测试范围

- 测试范围摘要：品牌聚合不变量（名称 trim/长度、Logo http(s) 形态与长度、描述长度、排序区间）、分页查询与参数归一、重名预判 + 唯一索引并发兜底、五端到端链路与方法级权限、前端品牌维护页装配与构建质量。
- 覆盖 DU: DU-BE-303 / DU-FE-302

### TC 逐条执行

| TC | 归属 DU | 执行方式 | 结果 | 证据位置 |
| --- | --- | --- | --- | --- |
| TC-001 | DU-BE-303 | BrandAdminApiTest：全字段合法创建 200，列表可见，默认 ENABLED/sort=0 | passed | repo-1 DU-BE-303 evidence/test-output.log |
| TC-002 | DU-BE-303 | API：trim + 大小写差异同名 → 409 且 COUNT 无增长（LOWER 预判） | passed | 同上 |
| TC-003 | DU-BE-303 | API：改名撞他人 409 且原值不变；改为未占用名成功 | passed | 同上 |
| TC-004 | DU-BE-303 | API + BrandTest：资料更新回读全为新值；ftp/超长 logo → 400 | passed | 同上 |
| TC-005 | DU-BE-303 | API：25 条预置下分页 records/total、keyword/status 过滤、sort,id 排序、page=-5→1/size=999→100 归一 | passed | 同上 |
| TC-006 | DU-BE-303 | API：禁用后列表仍可见数据不删除、启停切换生效 | passed | 同上 |
| TC-007 | DU-BE-303 | API 安全切片：缺 product:brand:* 权限 403 且无写入、无令牌 401、有权限 200 | passed | 同上 |
| TC-008 | DU-FE-302 | 前端 brand API 单测（3）+ vue-tsc 0 error + eslint 0 error + vite build 成功 | passed（自动化部分）；浏览器手工联调待集成环境 | repo-2 DU-FE-302 evidence/logs/ |
| TC-009 | DU-BE-303 | 双线程 CountDownLatch 并发同名创建：恰一 200、一 409，库中 COUNT=1（唯一索引兜底） | passed | repo-1 DU-BE-303 evidence/test-output.log |

另含 404 B2121 详情不存在用例与 BrandTest 共 5 例领域单测（名称规范化、logo 形态/长度、描述/排序、更新与启停、非法状态）。

说明：TC-008 按 test-design 原定方式为本地联调环境浏览器手工验证；当前 CI 级证据为前端 API 单测、类型检查、lint 与生产构建全通过，页面与接口契约（PageView、路径、状态枚举）由 API 单测与后端 MockMvc 测试双侧保证。浏览器手工走查留待集成环境（不引入 E2E 框架）。

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 单元测试（后端 BrandTest 领域） | 5 | 5 | 0 | 0 |
| 集成测试（后端 BrandAdminApiTest MockMvc/H2，含 TC-009 并发） | 9 | 9 | 0 | 0 |
| 前端自动化（vitest 全仓，含品牌 API 3 例） | 28 | 28 | 0 | 0 |
| 前端质量门（vue-tsc / eslint / build） | 3 门 | 3 门通过 | 0 | 0 |
| E2E（浏览器手工联调） | 1 | 0 | 0 | 1（待集成环境） |

- 自动化通过率: 45/45 = 100%；同次 `mvn -pl mall-services/mall-product -am test` 全模块 36 passed（分类 21 + 品牌 14 + 冒烟 1），无回归。
- 缺陷: 无未闭环缺陷；dev 期红绿灯（jsqlparser 独立模块编译、H2 2.x 大小写敏感、lambda 受检异常、URL no-undef）均在 red-green 记录并修复。

## 3. 证据清单

- repo-1 DU-BE-303：implementation/ai-platform-backend/delivery/CHG-0010/商品与库存/分类与品牌管理/品牌管理/品牌管理/DU-BE-303/evidence/（test-output.log、red-green.md、changeset.md、evidence.yaml）
- repo-2 DU-FE-302：implementation/ai-platform-frontend/delivery/CHG-0010/商品与库存/分类与品牌管理/品牌管理/品牌管理/DU-FE-302/evidence/（logs/{test,type-check,lint,build}.log、red-green.md、changeset.md）
- Change 级索引：evidence/evidence.yaml EV-017（后端 product 36 passed）、EV-018（前端 28 passed + 三门质量门）
