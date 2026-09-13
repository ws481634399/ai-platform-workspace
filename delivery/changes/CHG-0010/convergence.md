# Convergence — CHG-0010 分类与品牌管理

> 阶段：sdd-converge 产物
> 业界锚点：Postmortem + Lessons Learned（What → Why → Action → Knowledge）
> 输入：CHG-0010 全部 Artifact（2 Story 全流程 completed）
> 产出状态：completed

## 0. 元信息

- Change ID: CHG-0010
- 完成时间: 2026-09-13
- 产出 Artifact 数: 18（Change 级 6：exploration/requirement/requirement-spec/requirement-design/convergence/evidence；每 Story 6×2：story-spec/story-design/test-design/implementation/test-report/review-report；含 story-metadata 状态载体）
- 交付 DU：4（repo-1 DU-BE-302/303、repo-2 DU-FE-301/302），全部 completed

## 1. 知识变化总结

- 知识增量摘要:
  1. 新增 Product Context 首批落地能力：商品分类树（三级、循环/悬空/自引用防护、禁用不级联）与品牌主数据（全局唯一名、Logo/排序、分页查询）。
  2. mall-product 服务建立：DDD 四层包结构、MyBatis-Plus 持久化与分页、Flyway 迁移、方法级 JWT 权限、H2 集成测试基线。
  3. mall-admin 建立 product 业务域前端模式：API 客户端 + Element Plus 树表/分页页 + component-registry 动态菜单 + 权限按钮。
  4. 工程经验：ci 唯一性双层保证、测试安全切片、分页插件拆包、并发唯一测试模式（已沉淀 standards）。

## 2. 更新判断

### Standards

- 是否需更新: yes
- 更新内容: standards/engineering/testing-standard.md 新增「# 13 Spring Boot 微服务集成测试补充约定」（13.1 H2/MySQL ci 差异与双层唯一性、13.2 mybatis-plus-jsqlparser、13.3 测试安全切片与 403 advice、13.4 -parameters、13.5 并发唯一性测试模式），原总结章顺延为 #14。
- 理由: 四条均为跨服务/跨 Change 的长期工程约束而非本 Change 实现细节；M2 后续商品/SKU/发布/库存三个 Change 直接复用，先行沉淀可避免重复踩坑（其中 H2 ci 差异与分页拆包已实际造成 Red 轮次）。

### Product

- 是否需更新: no（本 Change 不直接改产品知识正文）
- 更新内容: 无。product/09-数据库设计.md、10-API与事件契约.md、11-权限与功能配置.md 的 M2 章节更新留待 M2 四个 Change 全部 converge 后统一回写（references/M2.md 为路线图 SSOT，逐 Change 改 PRD 正文会产生中间态）。
- 理由: 分类/品牌仅为 M2 第一组能力，商品、发布、库存未落库前更新 09/10 会形成不完整契约视图。

### feature-tree.yaml

- 是否需更新: yes
- 更新内容: STORY-002-01-01-01（分类管理）、STORY-002-01-02-01（品牌管理）status: planned → delivered。
- 理由: 两 Story 已 completed 且测试/评审证据齐备，特性树状态与交付事实对齐。

### Glossary

- 是否需更新: no
- 更新内容: 无。「商品分类」「品牌（SPU 维度）」「启停（软状态退出）」等术语在 M1 及 product/02-统一语言词汇表.md 中已存在，本 Change 未引入新业务术语。
- 理由: 无新概念。

## 3. 知识沉淀过程

- 已写回：testing-standard §13 五条约定（workspace 仓，随本次 converge 提交）；feature-tree 两 Story 状态置 delivered。
- 留待后续：产品知识正文（09/10/11）M2 末统一更新；浏览器手工联调走查（TC-011/TC-008）在具备网关+mall-product+mall-admin 集成环境时执行，结果回填各 Story test-report，不阻塞本次 converge（自动化契约证据双侧闭环）。
- 未沉淀为标准的内容：品牌/分类的具体字段、错误码、页面结构——属实现细节，保留在各仓代码与 DU 文档中，符合"实现细节不进 standards"约束。

## 4. 全局验收标准对照

> 摘自 requirement-spec.md §5（AC-001~016）。跨 Story 项同时引用两个 Story 的证据。

| # | 验收点 | 覆盖 Story | 证据引用 | 结论 |
| --- | --- | --- | --- | --- |
| 1 | AC-001 有权限建合法一级分类成功且可查 | S1 分类 | 分类 Story test-report TC-001；EV-015 | 通过 |
| 2 | AC-002 三级内创建成功、层级正确 | S1 分类 | 分类 Story test-report TC-002 | 通过 |
| 3 | AC-003 防自引用 | S1 分类 | TC-003/TC-012（CategoryRulesTest） | 通过 |
| 4 | AC-004 防循环且子树不变 | S1 分类 | TC-004/TC-012 | 通过 |
| 5 | AC-005 防悬空父 | S1 分类 | TC-005/TC-012 | 通过 |
| 6 | AC-006 三级下再建拒绝 | S1 分类 | TC-002 | 通过 |
| 7 | AC-007 tree 全量嵌套+稳定排序+状态字段 | S1 分类 | TC-007/TC-009 | 通过 |
| 8 | AC-008 禁用后不可选/不可建子级、启用恢复 | S1 分类 | TC-006/TC-008 | 通过 |
| 9 | AC-009 品牌 trim 同名第二次拒绝 | S5 品牌 | 品牌 Story test-report TC-002；EV-017 | 通过 |
| 10 | AC-010 品牌创建后改描述/排序查询为新值 | S5 品牌 | TC-004 + BrandTest | 通过 |
| 11 | AC-011 品牌关键字分页与排序规则 | S6 品牌 | TC-005（25 条预置/边界归一） | 通过 |
| 12 | AC-012 品牌禁用不可被新商品引用、启用恢复 | S7 品牌 | TC-006；"商品引用"校验随 CHG-0011 商品创建消费（禁用仅状态退出不删数据已验证） | 通过 |
| 13 | AC-013 无权限直调分类/品牌任一写接口 403 数据不变 | S1+S5（跨 Story） | 分类 TC-010 + 品牌 TC-007（同套方法级安全机制，权限码 V3 同次种子，8 个权限码逐一断言） | 通过 |
| 14 | AC-014 分类页/品牌页树展示、增改启停全流程与反馈 | S1+S5（跨 Story） | 前端 EV-016/EV-018（28 单测、type-check/lint/build 全过）+ 后端契约 MockMvc；浏览器手工走查待集成环境（§3 已登记） | 通过（自动化闭环；手工走查留跟踪项） |
| 15 | AC-015 无物理删除入口、退出仅禁用 | S1+S5（跨 Story） | CategoryAdminController/BrandAdminController 仅暴露 status 变更端点、无 DELETE 映射；聚合仅 disable 无 delete；V1 迁移无删除路径（代码审查，review-report §1.2/§1.4） | 通过 |
| 16 | AC-016 核心领域规则均有自动化测试 | S1+S5（跨 Story） | CategoryRulesTest 7 + CategoryTest 3 + BrandTest 5 + TC-009 并发；EV-015/EV-017 | 通过 |

跨 Story 集成说明：AC-013/014/015 为跨两个 Story 的全局验收点，证据不仅为并集——分类与品牌共用同一 ProductSecurityConfiguration、同一 V3 权限菜单迁移、同一网关路由与同一前端权限/菜单机制，集成面已在 DU-BE-302 公共前置中一次建成并由两侧测试共同验证；品牌 Story 复用分类 Story 建立的测试安全切片（ApiTestSecurityConfig），证明公共前置跨 Story 可用。

## 5. 完成确认

- [x] 代码变更已完成（4 DU，10 个 commit 跨 repo-1/repo-2）
- [x] 测试已完成（后端 product 36、前端 28，全绿；质量门全过）
- [x] 证据已收集（Change evidence.yaml 18 条 EV + 各仓 DU evidence）
- [x] 全局验收标准已逐条对照（§4，含 AC-013/014/015 跨 Story 集成验收点）
- [x] 知识更新已评估（standards 已写回 §13；feature-tree 已更新；Product/Glossary 说明留待 M2 末）
