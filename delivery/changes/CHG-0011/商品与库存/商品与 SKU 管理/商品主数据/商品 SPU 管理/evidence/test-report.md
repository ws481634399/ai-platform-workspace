# Test Report — 商品 SPU 管理 STORY-002-02-01-01

> 阶段：sdd-test 产物
> 位置：Story 级 evidence/test-report.md
> 输入：test-design.md + 仓内 DU implementation.md
> 产出状态：testing

本文档记录测试执行情况与证据；仓侧测试日志正文不复制，以 evidence-ref 引用。

## 0. 元信息

- Change ID: CHG-0011
- Story ID: STORY-002-02-01-01（商品 SPU 管理）
- Implementation 来源: 同目录 implementation.md（repo-1 DU-BE-304、repo-2 DU-FE-303）
- 状态流转: developing → testing
- 执行时间: 2026-09-13
- Evidence 索引: CHG-0011/evidence/evidence.yaml（EV-011 后端 test-run、EV-012 前端 test-run、EV-008/EV-009/EV-010 evidence-ref）

## 1. 测试范围

- 测试范围摘要：Product 聚合不变量（主图唯一、状态流转、Money 分价、图片/属性集合）、创建即 DRAFT、禁用后不可发布、管理端五端点 API 与权限、Flyway V2/V3 表结构（无 stock 列）、前端商品列表/编辑页装配与构建质量。
- 覆盖 DU: DU-BE-304 / DU-FE-303

### TC 逐条执行

| TC | 归属 DU | 执行方式 | 结果 | 证据位置 |
| --- | --- | --- | --- | --- |
| TC-001 | DU-BE-304 | ProductAdminApiTest：携带 product:product:create，POST 合法 Product（名称+分类+品牌+主图）→ 200，status=DRAFT | passed | repo-1 DU-BE-304 evidence/test-output.log |
| TC-002 | DU-BE-304 | API：categoryId 指向不存在分类 → 400；brandId 同理 | passed | 同上 |
| TC-003 | DU-BE-304 | API：创建 Product 含主图+2 张图集；查询详情 images 中仅一条 mainFlag=1 | passed | 同上 |
| TC-004 | DU-BE-304 | API：创建后 PUT 修改名称/属性/图片；GET 返回最新值 | passed | 同上 |
| TC-005 | DU-BE-304 | 迁移断言：product_spu/product_sku 表无 stock 列（Flyway V2/V3 建表 SQL 不含 stock） | passed | 同上（V2/V3 SQL 静态检查） |
| TC-006 | DU-BE-304 | API：创建 Product 后 status=DRAFT；ProductStatus 枚举含 DRAFT/ON_SALE/OFF_SALE/DISABLED | passed | 同上 |
| TC-007 | DU-BE-304 | API：创建 Product 含 2 个属性；修改后属性集合正确 | passed | 同上 |
| TC-008 | DU-BE-304 | API 安全切片：缺 product:product:create/update 权限 403 且无写入；有权限 200 | passed | 同上 |
| TC-009 | DU-BE-304 | 领域单测：Product.createNew 注册 ProductCreatedDomainEvent；updateBasicInfo 注册 ProductUpdatedDomainEvent | passed | 同上 |
| TC-010 | DU-BE-304 | API：禁用 Product（status=DISABLED）后聚合拒绝发布动作（enable 行为校验） | passed | 同上 |
| TC-011 | DU-FE-303 | 前端 product API 单测 + vue-tsc 0 error + eslint 0 error + vite build 成功 | passed（自动化部分）；浏览器手工联调待集成环境 | repo-2 DU-FE-303 evidence/logs/ |

说明：TC-011 按 test-design 原定方式为本地联调环境浏览器手工验证；当前 CI 级证据为前端 API 单测、类型检查、lint 与生产构建全通过，页面与接口契约由 API 单测与后端 MockMvc 测试双侧保证。浏览器手工走查留待集成环境（不引入 E2E 框架）。

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 单元测试（后端 Product 领域） | 含于 36 | 全通过 | 0 | 0 |
| 集成测试（后端 ProductAdminApiTest MockMvc/H2） | 9 | 9 | 0 | 0 |
| 前端自动化（vitest 全仓，含商品 API） | 28 | 28 | 0 | 0 |
| 前端质量门（vue-tsc / eslint / build） | 3 门 | 3 门通过 | 0 | 0 |
| E2E（浏览器手工联调） | 1 | 0 | 0 | 1（待集成环境） |

- 自动化通过率: 后端 mall-product 全模块 36 passed（分类 21 + 品牌 14 + Product 9 + 冒烟 1-2），无回归；前端 28 passed + 三门质量门全通过。
- 缺陷: 无未闭环缺陷；dev 期红绿灯（不可变集合 UnsupportedOperationException、created_at NULL、MyBatis-Plus JSON 双重序列化、ProductErrorCode 枚举名不一致）均在 red-green 记录并修复。

## 3. 证据清单

- repo-1 DU-BE-304：implementation/ai-platform-backend/delivery/CHG-0011/商品与库存/商品与 SKU 管理/商品主数据/商品 SPU 管理/DU-BE-304/evidence/（test-output.log、evidence.yaml）
- repo-2 DU-FE-303：implementation/ai-platform-frontend/delivery/CHG-0011/商品与库存/商品与 SKU 管理/商品主数据/商品 SPU 管理/DU-FE-303/evidence/（logs/{test,type-check,lint,build}.log）
- Change 级索引：evidence/evidence.yaml EV-011（后端 product 36 passed）、EV-012（前端 28 passed + 三门质量门）
