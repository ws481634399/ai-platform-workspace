# Review Report — 品牌管理 STORY-002-01-02-01

> 阶段：sdd-review 产物（Story 级检查点，状态保持 testing）
> 输入：story-spec.md / story-design.md / test-design.md + 仓内 DU-BE-303 / DU-FE-302 产物 + evidence/test-report.md + Change evidence/evidence.yaml + standards/

## 0. 元信息

- Change ID: CHG-0010
- Story ID: STORY-002-01-02-01（品牌管理）
- Test Report 来源: 本目录 evidence/test-report.md
- Evidence 索引: CHG-0010/evidence/evidence.yaml（EV-006~010 code-change，EV-017/018 test-run，EV-013/014 evidence-ref）
- 状态流转: testing（检查点，状态不变）
- 检查时间: 2026-09-13

## 1. 检查结论

四项检查 + 知识同步候选全部执行；无 blocker/major 开放项，dev 期发现的问题均已在 DU red-green 闭环并复测通过。

### 1.1 需求一致性

| AC | 需求要点 | 证据（test-run covers / 用例） | 结论 |
| --- | --- | --- | --- |
| AC-001 | 合法品牌创建、默认启用 | EV-017 / TC-001（默认 sort=0/status=ENABLED） | 一致 |
| AC-002 | trim+大小写同名拒绝、库中仅一条 | EV-017 / TC-002（LOWER 预判，COUNT 无增长） | 一致 |
| AC-003 | 改名撞名拒绝且原值不变 | EV-017 / TC-003 | 一致 |
| AC-004 | 资料更新回读、Logo 字符串地址、非法形态拒绝 | EV-017 / TC-004 + BrandTest 5 例 | 一致 |
| AC-005 | 关键字分页/过滤/稳定排序/参数归一 | EV-017 / TC-005（25 条预置，page/size 边界） | 一致 |
| AC-006 | 禁用保留数据、启停可见性切换 | EV-017 / TC-006 | 一致 |
| AC-007 | 细粒度 RBAC 403/200 | EV-017 / TC-007（401/403 JSON） | 一致 |
| AC-008 | mall-admin 品牌页全流程 | EV-018 + 页面/API 契约双侧自动化；浏览器手工走查待集成环境（TC-008 备注） | 基本一致（联调环境补手工走查） |
| AC-009 | 并发同名恰一成功 | EV-017 / TC-009（双线程 COUNT=1） | 一致 |

### 1.2 设计一致性

- Brand 聚合不变量（name ≤64 trim 非空、logo 可空非空须 http(s) URI ≤512、description ≤255、sort 0..9999）与 story-design §2 域模型一致；BrandRepository 端口内嵌分页值对象，domain 不依赖 MyBatis-Plus。
- BrandApplicationService 分页归一（page<1→1，size 默认 20/上限 100）、状态空白不过滤、existsByName 预判 + DuplicateKeyException 兜底，与设计"应用层预判 + 唯一索引终判"双层策略一致。
- 接口契约 /api/admin/brands 五端点、PageView{records,total,page,size}、权限码 product:brand:{list,create,update,disable} 与 story-design / requirement-design §4 一致；前端 componentKey `BrandList` 与 V3 菜单种子一致。
- 建表复用 DU-BE-302 V1 迁移（uk_product_brand_name、idx_sort_id），未产生重复迁移。

### 1.3 跨仓一致性（Phase 2.4）

- 契约闭环：后端 BrandView/PageView 字段 ↔ 前端 BrandItem/PageView 类型、brandApi.page 参数（keyword/status/page/size）一一对应；状态枚举 ENABLED/DISABLED 两端一致。
- 权限码闭环：V3 种子 product:brand:* ↔ Controller @PreAuthorize ↔ 前端 usePermission().has('product:brand:{create,update,disable}') 三处字符串一致。
- baseline/result：repo-1 db43b7b→370ce59（证据 7cba45e）、repo-2 df16f31→0789e6b（证据 6feacef），与各仓 DU metadata.yaml、implementation.md、evidence.yaml 一致。
- 偏差已记录并跨环境核对：existsByName 采用 LOWER 参数化比较对齐 MySQL ci 语义（H2 2.x 默认敏感），生产侧 ai_ci 唯一索引继续承担并发终判，TC-009 以完全同名验证索引有效；mybatis-plus-jsqlparser 独立模块补齐。

### 1.4 代码质量

- mall-product 36 测试全绿（品牌 14 + 分类 21 + 冒烟 1），无回归；并发用例使用 CountDownLatch 确保真并发、finally 关闭线程池。
- 仓储 LOWER 条件以 `{0}` 占位符参数绑定，无 SQL 注入面；分页插件配置与租户/多租户插件无冲突。
- 前端 vue-tsc 0 error、eslint 0 error（67 warning 为全仓既有格式项，新文件经 --fix）、build 成功；Logo 校验失败占位、表单保留输入便于重试、409 文案由拦截器统一呈现。
- 未发现有明确 standards/ 规范依据的违规。

### 1.5 知识同步候选

- 候选 1：MyBatis-Plus 3.5.12 PaginationInnerInterceptor 依赖 mybatis-plus-jsqlparser 独立模块（跨模块复用配置已在 MybatisPlusConfig）。
- 候选 2：H2 2.x vs MySQL ai_ci 大小写敏感性差异的标准解法（应用层 LOWER 预判 + DB 唯一索引兜底），适用于 M2 后续商品/SKU 等唯一名字段。
- 候选 3：测试安全切片 support/ApiTestSecurityConfig 已跨分类/品牌两个集成测试复用，可作为 mall-product 后续 Story（商品、库存接入）的测试基座。
- 统一在 Change converge 阶段评估沉淀，本 Story 不单独落盘。

## 2. 发现清单

| EV id | target | severity | finding | resolution 状态 |
| --- | --- | --- | --- | --- |
| —（dev 期，DU red-green 已记录） | mall-product pom | minor | 分页插件 3.5.12 拆包导致编译找不到符号 | 已闭环：补 mybatis-plus-jsqlparser，TC-005 复测通过 |
| —（dev 期，DU red-green 已记录） | BrandRepositoryImpl.existsByName | major→已降级闭环 | H2 2.x 大小写敏感致 trim/大小写同名预判失效（TC-002 期望 409 实得 200） | 已闭环：改 LOWER(name)=LOWER({0}) 参数化比较，TC-002/003 复测通过；生产 ai_ci 索引语义对齐 |
| —（dev 期，DU red-green 已记录） | BrandAdminApiTest 并发用例 | minor | Runnable lambda 内 await 受检异常编译失败 | 已闭环：try/catch 包裹，TC-009 通过 |
| —（dev 期，DU red-green 已记录） | BrandListView Logo 校验 | minor | new URL() 触发 ESLint no-undef；preview-src-list 漏绑定前缀 | 已闭环：正则初筛 + 绑定修正，type-check/lint 0 error |
| —（评审观察，非缺陷） | TC-008 | minor | 浏览器手工联调未在本环境执行 | 记录为集成环境待办；自动化契约证据已双侧覆盖，不阻塞 converge |

无 blocker；评审中识别的 1 个 major 级问题在 dev 红绿灯阶段已修复并有回归证据，按 findings-closure 要求在此登记闭环。

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 全部 blocker/major finding 已闭环（major 一项已修复复测）
- [x] minor finding 已记录（最后一项作为集成环境待办开放跟踪）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（多仓需求）
