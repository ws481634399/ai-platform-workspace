# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 位置：STORY 级 —— `CHG-0010/商品与库存/分类与品牌管理/品牌管理/品牌管理/test-design.md`
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0010
- Story ID: STORY-002-01-02-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- 状态流转: designed → tasked
- Feature Path: 商品与库存 > 分类与品牌管理 > 品牌管理 > STORY-002-01-02-01
- TC 总数: 9

## 1. 测试用例

> 验证意图，dev 开始前锁定：每个 AC 至少被一个 TC verified-by。

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API 集成测试：携带 product:brand:create 权限 POST 合法品牌（含全字段）→ 200，GET 列表可见，status 默认 ENABLED、sort 默认 0 | AC-001 | DU-BE-303 | |
| TC-002 | API + 领域单测：创建已存在名称（trim 前后空格差异、大小写差异）→ 业务错误，无新记录 | AC-002 | DU-BE-303 | 覆盖唯一索引 DuplicateKey 兜底路径 |
| TC-003 | API 集成测试：改名撞他人名称 → 业务错误且原值不变；改成未占用名称 → 成功 | AC-003 | DU-BE-303 | |
| TC-004 | API 集成测试：修改 logo/description/sort 后 GET /{id} 字段全部为新值；非法 logo 长度/形态 → 校验错误 | AC-004 | DU-BE-303 | |
| TC-005 | API 集成测试：预置 25 条品牌，分页 page=1&size=10 → records=10/total=25/排序 sort,id；keyword 模糊、status 过滤均命中预期；page<1 归一、size>100 截断 | AC-005 | DU-BE-303 | |
| TC-006 | API 集成测试：禁用后"商品可选品牌"不含该品牌、列表仍可见；重新启用后恢复；禁用不删除数据 | AC-006 | DU-BE-303 | |
| TC-007 | API 集成测试（安全切片）：无 product:brand:* 权限身份分别调用各接口 → 403 且无写入；有权限 → 200 | AC-007 | DU-BE-303 | 权限码由 DU-BE-301 注册，切片注入 authorities |
| TC-008 | E2E/浏览器手工验证：mall-admin 品牌页分页、关键字/状态搜索、新增、编辑、启停确认、Logo URL 表单，按钮随权限显隐 | AC-008 | DU-FE-302 | 前端构建通过 + 操作截图证据 |
| TC-009 | 并发测试：两个请求用相同名称并发创建 → 恰一成功、另一返回名称冲突业务错误，库中仅一条 | AC-009 | DU-BE-303 | 唯一索引 + 异常转换 |

## 2. 测试策略

- Unit（domain/application 层）：名称 trim/大小写规则、改名冲突、禁用行为、分页参数归一（TC-002/003/006 部分分支）。
- API 集成（mall-common-test 基线，MockMvc + H2 + 安全切片）：全链路 HTTP 语义、分页 SQL、唯一冲突转换、403/200（TC-001~007 主体）。
- 并发（TC-009）：集成测试中以两个并发事务/线程对同一名称插入，断言成功数=1；H2 同样支持唯一约束，可在测试基线内执行；若基线 H2 不适用则记录为本地 MySQL 验证证据。
- E2E（前端）：TC-008 本地联调环境人工执行，留存截图；不新增自动化框架。
- 不重复原则：名称/状态规则在 Unit 穷举，API 层验证装配与 SQL 行为；前端只验证交互与串联。
- 数据准备：Flyway V1 后 builder 批量造品牌数据，测试回滚/自清理；前端 E2E 前预置多品牌数据以便分页与搜索。
- 环境：JDK21/Maven/H2（MySQL 8 排序规则大小写不敏感为生产事实，H2 中以应用层 trim 比较 + 唯一约束双重验证）；前端 Node/pnpm build。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-302（分类 Story，含公共前置）先合入：ProductSecurityConfiguration、权限码/菜单种子、网关路由，是 TC-007 与 TC-008 的环境前提（requirement-design §6：DU-BE-303 depends on DU-BE-302）。
- TC-008 在 TC-001~007 全部通过后执行。
- 数据库迁移 V1（含 product_brand 段）必须先成功执行。
