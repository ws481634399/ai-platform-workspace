# Review Report（Change 级聚合）— CHG-0010

> 阶段：sdd-review 聚合产物（多 Story Change，状态保持 testing）
> 五查逐条记录在各 Story review-report.md，本文件仅聚合结论与跨 Story 检查。

## 0. 元信息

- Change ID: CHG-0010
- Test Report 来源: evidence/test-report.md + 两 Story evidence/test-report.md
- Evidence 索引: evidence/evidence.yaml（EV-001~018）
- 状态流转: testing（检查点，状态不变）
- 检查时间: 2026-09-13

## 1. 检查结论

### 1.1 需求一致性

- Change 全局 AC-001~016 与 Story AC（分类 12 + 品牌 9）映射核对完成，逐条对照见 convergence.md §4；全部通过（AC-014 浏览器手工走查为登记跟踪项，自动化契约证据闭环）。
- 明细：分类 Story review-report.md §1.1、品牌 Story review-report.md §1.1。

### 1.2 设计一致性

- DDD 分层在两个后端 DU 一致落地：domain 不感知框架，分页等值对象定义于 domain；五端点 REST 契约、错误码（B2101~B2107 分类、B2121~B2122 品牌）、PageView 结构与设计文档一致。
- 建表迁移 V1 一次覆盖分类+品牌两表；identity V3 一次播种 8 权限码+3 菜单；无重复/冲突迁移。

### 1.3 跨仓一致性（Phase 2.4）

- API/字段/枚举/权限码在后端 DTO、后端 @PreAuthorize、V3 菜单种子、前端 TS 类型、前端 has() 五处保持字符串级一致（category*、brand* 两组）。
- DU baseline/result 在仓内 metadata.yaml、仓内 DU implementation.md、Story/Change implementation.md、Change evidence.yaml 四处对齐；4 个 DU 状态均 completed 并经 openspec du sync-status 同步。
- 公共前置（ProductSecurityConfiguration、ApiTestSecurityConfig、网关路由、分页插件）由品牌 Story 实际复用，跨 Story 一致性成立。

### 1.4 代码质量

- 后端 36、前端 28 全绿；无 SQL 注入面（LambdaQuery + {0} 参数绑定）；401/403/404/409 状态语义稳定；无物理删除入口。
- 前端 0 type/lint error、build 成功；warning 均为全仓既有格式项。
- 无凭据硬编码（.env 模板不含真实值）；standards 规范对照无明确违规。

### 1.5 知识同步候选

1. H2 2.x vs MySQL ci 差异的双层唯一性解法 → 已沉淀 standards/engineering/testing-standard §13.1。
2. MyBatis-Plus jsqlparser 拆包 → §13.2；测试安全切片/403 advice → §13.3；-parameters → §13.4；并发唯一测试模式 → §13.5。
3. Product/PRD 正文更新留 M2 末统一执行（convergence.md §2 Product/§3 说明）。

## 2. 发现清单

| target | severity | finding | resolution |
| --- | --- | --- | --- |
| BrandRepositoryImpl.existsByName | major | H2 2.x 大小写敏感致大小写同名预判失效（TC-002 409→200） | 已闭环：LOWER 参数化比较，TC-002/003 复测通过（品牌 Story review-report §2） |
| 根 pom / mall-product pom | minor×2 | -parameters 缺失、jsqlparser 拆包 | 已闭环，复测通过 |
| BrandAdminApiTest / BrandListView | minor×2 | lambda 受检异常、URL no-undef/绑定前缀 | 已闭环 |
| TC-011 / TC-008 | minor | 浏览器手工联调待集成环境 | 开放跟踪（convergence §3 登记），自动化证据不阻塞收敛 |

无 blocker；major 1 项已修复并回归；minor 开放项 1 个（环境依赖，非代码缺陷）。

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 全部 blocker/major finding 已闭环
- [x] minor finding 已记录（1 项环境待办允许开放）
- [x] 知识同步候选已写入 §1.5 并由 convergence 落盘
- [x] 跨仓一致性已核对（多仓需求）
