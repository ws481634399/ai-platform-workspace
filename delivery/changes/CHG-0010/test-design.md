# Test Design（Change 级验证意图）— CHG-0010

> 阶段：sdd-task 聚合产物（多 Story Change）
> 位置：CHG-0010/test-design.md
> TC 权威明细在各 Story test-design.md（同编号在各 Story 命名空间内），本文件聚合全部 TC 供 Change 级 tc-coverage 机检。

## 0. 元信息

- Change ID: CHG-0010
- Story 数: 2（STORY-002-01-01-01 分类管理、STORY-002-01-02-01 品牌管理）
- TC 总数: 21（分类 12 + 品牌 9）
- 状态流转: designed → tasked

## 1. 测试用例

### Story STORY-002-01-01-01 分类管理（来源：商品与库存/分类与品牌管理/分类管理/分类管理/test-design.md）

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API 集成：product:category:create 权限 POST 合法一级分类 → 200，tree 根 level=1、parentId=0 | AC-001 | DU-BE-302 | |
| TC-002 | API 集成：建满三级成功，第三级下再建 → "最多 3 级"且无落库 | AC-002 | DU-BE-302 | |
| TC-003 | 领域单测 + API：parentId 设自身 → 业务错误，关系不变 | AC-003 | DU-BE-302 | |
| TC-004 | 领域单测：A→B→C 链挂 A 到 C/B 下 → 循环拒绝；含移动成功对子树 level 重算对照 | AC-004 | DU-BE-302 | |
| TC-005 | API 集成：parentId 指向不存在 id → 父分类不存在 | AC-005 | DU-BE-302 | |
| TC-006 | API 集成：禁用父下建子级拒绝，启用父成功；无物理删除入口 | AC-006, AC-015 | DU-BE-302 | |
| TC-007 | API 集成：多层 tree 嵌套、禁用节点 status、全量一次返回 | AC-007 | DU-BE-302 | |
| TC-008 | API 集成：禁用后可选分类不含该节点、子级无级联禁用、启用恢复 | AC-008 | DU-BE-302 | 不级联核心断言 |
| TC-009 | API 集成：同级 sort 升序、相同按 id 升序 | AC-009 | DU-BE-302 | |
| TC-010 | API 安全切片：无权限 403 无写入、有权限 200；update/disable/list 同理 | AC-010, AC-013 | DU-BE-302 | |
| TC-011 | 前端：mall-admin 分类页渲染/新增子级/改名/排序/启停、权限按钮、接口页面一致 | AC-011, AC-014 | DU-FE-301 | 构建通过 + 自动化契约；浏览器手工走查待集成环境 |
| TC-012 | 领域参数化单测：自引用/循环/悬空/超层级/禁用父/同级重名六类拒绝与成功路径 | AC-012, AC-016 | DU-BE-302 | |

### Story STORY-002-01-02-01 品牌管理（来源：商品与库存/分类与品牌管理/品牌管理/品牌管理/test-design.md）

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API 集成：product:brand:create 权限 POST 全字段合法品牌 → 200，列表可见，默认 ENABLED/sort=0 | AC-001 | DU-BE-303 | |
| TC-002 | API + 领域：trim 空格/大小写差异同名 → 业务错误无新记录 | AC-002 | DU-BE-303 | 含唯一索引 DuplicateKey 兜底 |
| TC-003 | API：改名撞他人 → 错误且原值不变；改未占用名 → 成功 | AC-003 | DU-BE-303 | |
| TC-004 | API：改 logo/description/sort 后回读为新值；非法 logo 长度/形态 → 校验错误 | AC-004 | DU-BE-303 | |
| TC-005 | API：25 条预置分页 records/total/排序、keyword/status 命中、page<1 归一、size>100 截断 | AC-005 | DU-BE-303 | |
| TC-006 | API：禁用后列表仍可见、不可被新商品引用、启用恢复、数据不删除、无物理删除入口 | AC-006, AC-015 | DU-BE-303 | |
| TC-007 | API 安全切片：无 product:brand:* 权限各接口 403 无写入、有权限 200 | AC-007, AC-013 | DU-BE-303 | |
| TC-008 | 前端：品牌页分页/搜索/新增/编辑/启停确认/Logo 表单、权限按钮 | AC-008, AC-014 | DU-FE-302 | 构建通过 + 自动化契约；浏览器手工走查待集成环境 |
| TC-009 | 并发：双线程同名创建恰一成功一 409，库中 COUNT=1 | AC-009, AC-016 | DU-BE-303 | 唯一索引 + 异常转换 |

## 2. 跨 Story 测试策略

- 后端统一基线：@SpringBootTest + MockMvc + H2（MODE=MySQL）+ Flyway，测试安全切片共享 `support/ApiTestSecurityConfig`；分类 22 与品牌 14 个用例在同一次 `mvn -pl mall-services/mall-product -am test` 内执行，构成跨 Story 回归集（共 36）。
- 前端统一基线：vitest + vue-tsc + eslint + vite build 四件套在 mall-admin 单仓一次执行（终态 28），覆盖两个业务页面与 API 客户端。
- 全局验收 AC-013/015（RBAC、无物理删除）跨两个 Story，依赖 DU-BE-302 公共前置（安全配置、V3 权限菜单、网关路由）一次建成、两侧复用。
- 环境差异处理：ci 唯一性按 standards/engineering/testing-standard §13.1 双层保证；并发用例 §13.5 模式。

## 3. 不可测项标注

- 分类 TC-011 / 品牌 TC-008 的浏览器手工联调部分在当前无集成环境条件下标为待执行，以自动化契约/类型/构建证据替代，待集成环境补齐走查（见 convergence.md §3）。
