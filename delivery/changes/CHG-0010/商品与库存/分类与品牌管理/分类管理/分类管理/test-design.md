# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 位置：STORY 级 —— `CHG-0010/商品与库存/分类与品牌管理/分类管理/分类管理/test-design.md`
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0010
- Story ID: STORY-002-01-01-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- 状态流转: designed → tasked
- Feature Path: 商品与库存 > 分类与品牌管理 > 分类管理 > STORY-002-01-01-01
- TC 总数: 12

## 1. 测试用例

> 验证意图，dev 开始前锁定：每个 AC 至少被一个 TC verified-by。

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API 集成测试：携带 product:category:create 权限，POST 合法一级分类 → 200，tree 根节点出现且 level=1、parentId=0 | AC-001 | DU-BE-302 | |
| TC-002 | API 集成测试：依次在根下建到第三级均成功；在第三级下再建 → 业务错误"最多 3 级"，库中无新记录 | AC-002 | DU-BE-302 | |
| TC-003 | 领域单测 + API：将分类 parentId 设为自身 → 业务错误，原关系不变 | AC-003 | DU-BE-302 | |
| TC-004 | 领域单测：A→B→C 链下把 A 挂到 C 下 → 循环错误；挂到 B 下同样拒绝；A/B/C 数据不变 | AC-004 | DU-BE-302 | 含移动后子树 level 重算的成功对照用例 |
| TC-005 | API 集成测试：创建/移动时 parentId 指向不存在 id → 父分类不存在错误 | AC-005 | DU-BE-302 | |
| TC-006 | API 集成测试：禁用某分类后在其下建子级 → 拒绝；换启用父级 → 成功 | AC-006 | DU-BE-302 | |
| TC-007 | API 集成测试：构造多层多节点后 GET tree，断言嵌套关系、含禁用节点 status 字段、全量一次返回 | AC-007 | DU-BE-302 | |
| TC-008 | API 集成测试：禁用分类后"商品可选分类"查询不含该节点；子分类未被级联禁用；重新启用后恢复 | AC-008 | DU-BE-302 | 不级联规则核心断言 |
| TC-009 | API 集成测试：同级设置不同 sort 后 tree 次序按 sort 升序；sort 相同按 id 升序 | AC-009 | DU-BE-302 | |
| TC-010 | API 集成测试（安全切片）：JWT 无 product:category:create 权限 → 403 且无写入；有权限 → 200；update/disable/list 同理 | AC-010 | DU-BE-302 | 权限码由 DU-BE-301 注册，本 TC 用切片 authorities 验证服务端判定 |
| TC-011 | E2E/浏览器手工验证：mall-admin 分类页渲染树、新增子级、编辑改名、改排序、启停，按钮随权限显隐，接口与页面一致 | AC-011 | DU-FE-301 | 前端构建通过 + 操作录屏/截图证据 |
| TC-012 | 领域单测（参数化）：自引用/循环/悬空父/超层级/禁用父/同级重名六类不变量各自的拒绝路径与成功路径 | AC-012 | DU-BE-302 | |

## 2. 测试策略

- Unit（domain 层，无 Spring）：聚合根行为与全部层级/名称不变量（TC-003/TC-004/TC-012 主体），用构造内存数据驱动，速度快、覆盖边界。
- API 集成（@SpringBootTest + MockMvc/H2 或 mall-common-test 既定基线）：Controller → Service → Mapper 全链路 + 安全切片（TC-001/002/005/006/007/008/009/010）；通过给模拟 JWT 注入不同 authorities 验证 403/200，不依赖 identity 服务在线。
- E2E（前端）：TC-011 在本地联调环境（网关 + mall-product + mall-admin）人工执行，留存截图与操作记录到 evidence；不引入新 E2E 自动化框架。
- 不重复原则：领域不变量在 Unit 穷举，API 层只验证装配/事务/HTTP 语义，不重复断言全部分支。
- 数据准备：Flyway 迁移后每个测试自清理/回滚；树数据用 builder 构造；前端 E2E 前预置三级示例分类。
- 环境：JDK21/Maven；后端测试默认 H2（与 M1 基线一致），MySQL 特有语法（如无）需避免；前端 Node/pnpm build。

## 3. 不可测项标注

无。全部 AC 均可自动化或浏览器手工验证。

## 4. 依赖与前置条件

- DU-BE-302 内部公共前置先完成：安全配置、权限码与菜单种子、网关路由，是 TC-010 与 TC-011 的环境前提。
- TC-002 依赖 TC-001 的创建能力；TC-004 依赖三级数据；TC-011 依赖 TC-001~010 全部通过后执行。
- 数据库迁移 V1 必须先成功执行（Flyway），测试库与本地 mall_product 库结构一致。
