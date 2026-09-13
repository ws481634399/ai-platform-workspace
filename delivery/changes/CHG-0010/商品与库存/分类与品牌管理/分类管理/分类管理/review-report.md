# Review Report — 分类管理 STORY-002-01-01-01

> 阶段：sdd-review 产物（Story 级检查点，状态保持 testing）
> 输入：story-spec.md / story-design.md / test-design.md + 仓内 DU-BE-302 / DU-FE-301 产物 + evidence/test-report.md + Change evidence/evidence.yaml + standards/

## 0. 元信息

- Change ID: CHG-0010
- Story ID: STORY-002-01-01-01（分类管理）
- Test Report 来源: 本目录 evidence/test-report.md
- Evidence 索引: CHG-0010/evidence/evidence.yaml（EV-001/002/004/005 code-change，EV-015/016 test-run，EV-011/012 evidence-ref）
- 状态流转: testing（检查点，状态不变）
- 检查时间: 2026-09-13

## 1. 检查结论

四项检查 + 知识同步候选全部执行；无 blocker/major 开放项，dev 期发现的问题均已在 DU red-green 闭环并复测通过。

### 1.1 需求一致性

| AC | 需求要点 | 证据（test-run covers / 用例） | 结论 |
| --- | --- | --- | --- |
| AC-001 | 合法一级分类创建、tree level=1/parentId=0 | EV-015 / TC-001 | 一致 |
| AC-002 | 三级内可建、第四级拒绝无落库 | EV-015 / TC-002（CategoryRules MAX_LEVEL=3） | 一致 |
| AC-003 | 防自引用 | EV-015 / TC-003、TC-012 | 一致 |
| AC-004 | 防循环、子树不变 | EV-015 / TC-004、TC-012 | 一致 |
| AC-005 | 防悬空父 | EV-015 / TC-005、TC-012 | 一致 |
| AC-006 | 禁用父下拒建子级 | EV-015 / TC-006、TC-012 | 一致 |
| AC-007 | tree 全量含禁用态、嵌套、稳定排序 | EV-015 / TC-007、TC-009 | 一致 |
| AC-008 | 禁用不级联、准入恢复 | EV-015 / TC-008 | 一致 |
| AC-009 | sort/id 稳定排序 | EV-015 / TC-009 | 一致 |
| AC-010 | 细粒度 RBAC 403/200 | EV-015 / TC-010（401/403 JSON） | 一致 |
| AC-011 | mall-admin 树页端到端操作 | EV-016 + 页面/API 契约双侧自动化；浏览器手工走查待集成环境（TC-011 备注） | 基本一致（联调环境补手工走查） |
| AC-012 | 六类不变量领域层自动化 | EV-015 / CategoryRulesTest 7 + CategoryTest 3 | 一致 |

### 1.2 设计一致性

- story-design 声明的分层（interfaces/application/domain + infrastructure 端口适配）在 DU-BE-302 code-change 中落实：Category 聚合与 CategoryRules 纯静态规则、CategoryRepository 端口、CategoryRepositoryImpl 适配 MyBatis-Plus，domain 不感知框架。
- 移动重算子树 level、应用层 DuplicateKeyException→B2106 重名兜底与设计一致。
- 接口契约 /api/admin/categories 五端点、权限码 product:category:{list,create,update,disable} 与 story-design §4、requirement-design §4 一致；前端 componentKey `CategoryTree` 与 V3 迁移菜单种子一致。
- V1 迁移（分类+品牌同文件）、identity V3 权限菜单、gateway 静态路由按公共前置设计落地。

### 1.3 跨仓一致性（Phase 2.4）

- API 契约闭环：后端 CategoryTreeView DTO（id/name/parentId/level/sort/status/children）↔ 前端 CategoryNode 类型与 tree() 调用一致；UnifyResult 解包方式与既有 http 拦截器一致。
- 权限码闭环：V3 种子 product:category:* ↔ Controller @PreAuthorize ↔ 前端 usePermission().has() 按钮显隐，三处字符串一致。
- 网关路由 categories/** → product 服务（默认直连，未引 loadbalancer），与前端 baseURL /api 同源代理配套。
- baseline/result：repo-1 57b6534→ca7eb95、repo-2 df16f31→a4e3d06，与各仓 DU metadata.yaml、implementation.md、evidence.yaml 三处一致。
- 偏差已记录：根 pom 补 `<parameters>true</parameters>`（@PathVariable 名保留）、测试安全切片 ProductSecurityExceptionAdvice（方法级 AccessDenied→403），均为设计落地必需，已在 DU implementation Deviations 说明。

### 1.4 代码质量

- 后端 22 测试全绿；DDD 分层无反向依赖；异常码 B2101~B2107 集中、错误响应走全局 UnifyResult；无硬编码凭据/越权风险。
- 前端 vue-tsc 0 error、eslint 0 error（warning 为全仓既有格式项）、生产 build 成功；ElMessage/ElMessageBox 显式导入、表格 slot row 类型断言等仓库约定均遵守。
- standards/ 工程规范：迁移可回滚意识（纯新增表/菜单）、审计时间由 DB 默认值填充，与 M1 基线一致；未发现有明确规范依据的违规。

### 1.5 知识同步候选

- 候选 1（工程知识）：MyBatis-Plus 3.5.12 分页插件需独立 mybatis-plus-jsqlparser 模块（品牌 Story 复用，建议沉淀到后端工程知识）。
- 候选 2（工程知识）：H2 2.x 字符串比较默认大小写敏感，与 MySQL ai_ci 不一致时以应用层 LOWER 比较 + 唯一索引双层保证（品牌 Story 落地）。
- 候选 3（测试约定）：@SpringBootTest 方法级安全需独立 @RestControllerAdvice 转换 AccessDeniedException，否则 @PreAuthorize 拒绝泄漏为 500；测试安全切片可跨模块共享。
- 上述候选统一在 Change converge 阶段评估是否写入 standards/product，本 Story 不单独落盘。

## 2. 发现清单

| EV id | target | severity | finding | resolution 状态 |
| --- | --- | --- | --- | --- |
| —（dev 期，DU red-green 已记录） | 根 pom maven-compiler-plugin | minor | @PathVariable 缺参数名导致 A0001 | 已闭环：补 `<parameters>true</parameters>`，TC-001 复测通过 |
| —（dev 期，DU red-green 已记录） | ProductSecurityExceptionAdvice | minor | @PreAuthorize 拒绝经全局处理器变 500 | 已闭环：product 侧方法级 AccessDenied→403 通知，TC-010 复测通过 |
| —（评审观察，非缺陷） | TC-011 | minor | 浏览器手工联调未在本环境执行 | 记录为集成环境待办；自动化契约证据已双侧覆盖，不阻塞 converge |

无 blocker / major；minor 均已记录（最后一项作为集成环境待办开放跟踪）。

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 全部 blocker/major finding 已闭环（无）
- [x] minor finding 已记录（允许开放）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（多仓需求）
