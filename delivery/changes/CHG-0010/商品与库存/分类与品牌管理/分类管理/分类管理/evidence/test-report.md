# Test Report — 分类管理 STORY-002-01-01-01

> 阶段：sdd-test 产物
> 位置：Story 级 evidence/test-report.md
> 输入：test-design.md + 仓内 DU implementation.md
> 产出状态：testing

本文档记录测试执行情况与证据；仓侧测试日志正文不复制，以 evidence-ref 引用。

## 0. 元信息

- Change ID: CHG-0010
- Story ID: STORY-002-01-01-01（分类管理）
- Implementation 来源: 同目录 implementation.md（repo-1 DU-BE-302、repo-2 DU-FE-301）
- 状态流转: developing → testing
- 执行时间: 2026-09-13
- Evidence 索引: CHG-0010/evidence/evidence.yaml（EV-015 后端 test-run、EV-016 前端 test-run、EV-011/EV-012 evidence-ref）

## 1. 测试范围

- 测试范围摘要：分类树领域不变量（层级/自引用/循环/悬空父/禁用父/同级重名）、管理端五端到端链路与方法级权限、前端分类树维护页 API 装配与构建质量。
- 覆盖 DU: DU-BE-302 / DU-FE-301

### TC 逐条执行

| TC | 归属 DU | 执行方式 | 结果 | 证据位置 |
| --- | --- | --- | --- | --- |
| TC-001 | DU-BE-302 | CategoryAdminApiTest：合法一级分类 200，tree 根 level=1/parentId=0 | passed | repo-1 DU-BE-302 evidence/test-output.log |
| TC-002 | DU-BE-302 | CategoryRulesTest + API：建满三级成功，第四级拒绝且无落库 | passed | 同上 |
| TC-003 | DU-BE-302 | CategoryTest：parentId 设为自身被拒，关系不变 | passed | 同上 |
| TC-004 | DU-BE-302 | CategoryRulesTest：A→B→C 链下挂 A 到 C/B 均拒绝；移动成功对子树 level 重算 | passed | 同上 |
| TC-005 | DU-BE-302 | API：parentId 指向不存在 id → 父分类不存在 | passed | 同上 |
| TC-006 | DU-BE-302 | API：禁用父下建子级拒绝，启用父成功 | passed | 同上 |
| TC-007 | DU-BE-302 | API：多层 tree 嵌套关系、禁用节点 status、一次全量返回 | passed | 同上 |
| TC-008 | DU-BE-302 | API：禁用不级联子节点、启停状态字段正确 | passed | 同上 |
| TC-009 | DU-BE-302 | API：同级 sort 升序、同 sort 按 id 升序 | passed | 同上 |
| TC-010 | DU-BE-302 | API 安全切片：缺权限 403 且无写入、有权限 200；无令牌 401 | passed | 同上 |
| TC-011 | DU-FE-301 | 前端 category API 单测（3）+ vue-tsc 0 error + eslint 0 error + vite build 成功 | passed（自动化部分）；浏览器手工联调待集成环境 | repo-2 DU-FE-301 evidence/logs/ |
| TC-012 | DU-BE-302 | CategoryRulesTest 参数化六类不变量拒绝/成功路径（7 例） | passed | repo-1 DU-BE-302 evidence/test-output.log |

说明：TC-011 按 test-design 原定方式为本地联调环境浏览器手工验证；当前 CI 级证据为前端组件/API 自动化测试、类型检查、lint 与生产构建全通过，页面与接口契约（路径、载荷、UnifyResult 解包）由 API 单测与后端 MockMvc 测试双侧保证。浏览器手工走查留待集成环境（与 M1 同策略，不引入 E2E 框架）。

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | --- | --- | --- | --- |
| 单元测试（后端 JUnit：domain + rules） | 10 | 10 | 0 | 0 |
| 集成测试（后端 @SpringBootTest MockMvc/H2，含冒烟） | 12 | 12 | 0 | 0 |
| 前端自动化（vitest 全仓，含分类 API 3 例） | 25 | 25 | 0 | 0 |
| 前端质量门（vue-tsc / eslint / build） | 3 门 | 3 门通过 | 0 | 0 |
| E2E（浏览器手工联调） | 1 | 0 | 0 | 1（待集成环境） |

- 自动化通过率: 50/50 = 100%
- 缺陷: 无未闭环缺陷；dev 期红绿灯问题（@PathVariable 参数名、测试安全切片 AccessDenied 500）已在 DU-BE-302 red-green 记录并修复。

## 3. 证据清单

- repo-1 DU-BE-302：implementation/ai-platform-backend/delivery/CHG-0010/商品与库存/分类与品牌管理/分类管理/分类管理/DU-BE-302/evidence/（test-output.log、red-green.md、changeset.md、evidence.yaml）
- repo-2 DU-FE-301：implementation/ai-platform-frontend/delivery/CHG-0010/商品与库存/分类与品牌管理/分类管理/分类管理/DU-FE-301/evidence/（logs/{test,type-check,lint,build}.log、red-green.md、changeset.md）
- Change 级索引：evidence/evidence.yaml EV-015（后端 22 passed）、EV-016（前端 25 passed + 三门质量门）
