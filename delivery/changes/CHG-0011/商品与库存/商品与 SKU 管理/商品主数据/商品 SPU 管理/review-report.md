# Review Report — 商品 SPU 管理 STORY-002-02-01-01

> 阶段：sdd-review 产物（Story 级检查点，状态保持 testing）
> 输入：story-spec.md / story-design.md / test-design.md + 仓内 DU-BE-304 / DU-FE-303 产物 + evidence/test-report.md + Change evidence/evidence.yaml + standards/

## 0. 元信息

- Change ID: CHG-0011
- Story ID: STORY-002-02-01-01（商品 SPU 管理）
- Test Report 来源: 本目录 evidence/test-report.md
- Evidence 索引: CHG-0011/evidence/evidence.yaml（EV-001~007 code-change，EV-011/012 test-run，EV-008/010 evidence-ref）
- 状态流转: testing（检查点，状态不变）
- 检查时间: 2026-09-13

## 1. 检查结论

四项检查 + 知识同步候选全部执行；无 blocker/major 开放项，dev 期发现的问题均已在 DU red-green 闭环并复测通过。

### 1.1 需求一致性

| AC | 需求要点 | 证据（test-run covers / 用例） | 结论 |
| --- | --- | --- | --- |
| AC-001 | 提交合法 Product → 创建成功，状态 DRAFT | EV-011 / TC-001 | 一致 |
| AC-002 | 分类/品牌不存在或非启用 → 拒绝 | EV-011 / TC-002 | 一致 |
| AC-007 | 一个 Product 仅一张主图；图集可多张 | EV-011 / TC-003（mainFlag 唯一校验） | 一致 |
| AC-008 | 修改基本信息/属性/图片后查询返回最新值 | EV-011 / TC-004 | 一致 |
| AC-009 | product_spu 无 stock 字段 | EV-011 / TC-005（V2/V3 SQL 静态检查） | 一致 |
| AC-010 | 创建商品状态 DRAFT，状态字段支持四态 | EV-011 / TC-006（ProductStatus 四态枚举） | 一致 |
| AC-012 | 商品属性键值对可增删改并保存 | EV-011 / TC-007 | 一致 |
| AC-013 | 无 product:product:* 权限直调 → 403；有权限 → 成功 | EV-011 / TC-008 | 一致 |
| AC-014 | Product 创建/更新注册领域事件 | EV-011 / TC-009 | 一致 |
| AC-011 | mall-admin 商品页可完成列表、创建、编辑、查看 | EV-012 + 页面/API 契约双侧自动化；浏览器手工走查待集成环境 | 基本一致（联调环境补手工走查） |
| AC-015 | DISABLED 商品不可被发布 | EV-011 / TC-010（聚合行为拒绝） | 一致 |

### 1.2 设计一致性

- Product 聚合不变量（主图唯一校验 replaceImages、Money 分价 long、ProductStatus 四态、图片/属性集合可变）与 story-design §2 域模型一致；ProductRepository 端口 existsBySkuCode，domain 不依赖 MyBatis-Plus。
- ProductApplicationService 创建即 DRAFT、DISABLED 不可发布、级联持久化（delete+insert SKU），与设计"聚合根统一管理 SKU 生命周期"一致。
- 接口契约 /api/admin/products + /{id}/skus 子资源、ProductView{spu, skus}、权限码 product:product:{list,create,update} / product:sku:{create,update} 与 story-design / requirement-design §6 一致。
- Flyway V2（product_spu/product_image/product_attribute）、V3（product_sku，specification_data VARCHAR + specification_hash + uk_sku_code + uk_product_spec_hash）、V4（8 个权限码 + 商品列表菜单），与设计一致。

### 1.3 跨仓一致性（Phase 2.4）

- 契约闭环：后端 ProductView/SkuView 字段 ↔ 前端 ProductItem/SkuView 类型、productApi 端点一一对应；状态枚举 DRAFT/ON_SALE/OFF_SALE/DISABLED、SkuStatus ENABLED/DISABLED 两端一致。
- 权限码闭环：V4 种子 product:product:* / product:sku:* ↔ Controller @PreAuthorize ↔ 前端 usePermission() 三处字符串一致。
- baseline/result：repo-1 7cba45e→23a1dfb、repo-2 6feacef→f14ead4，与各仓 DU metadata.yaml、implementation.md、evidence.yaml 一致。
- 偏差已记录：specification_data 列用 VARCHAR 存 JSON 字符串（避免 MyBatis-Plus 对 `_json` 列名自动套用 JacksonTypeHandler 双重序列化），在 DU implementation.md 有记录。

### 1.4 代码质量

- mall-product 36 测试全绿（Product 9 + 分类 21 + 品牌 14 - 重复计数，实际全模块 36 passed），无回归。
- 仓储 specification_data 用 Jackson ObjectMapper 手动序列化 Map<String,String>，避免 MyBatis-Plus 自动 JSON 处理；分页插件配置与租户插件无冲突。
- 前端 vue-tsc 0 error、eslint 0 error、build 成功；el-table row 类型断言、mainImageUrl 空值处理。
- 未发现有明确 standards/ 规范依据的违规。

### 1.5 知识同步候选

- 候选 1：MyBatis-Plus 3.5.12 对数据库列名以 `_json` 结尾自动套用 JacksonTypeHandler 导致双重序列化——解法是列名改用 `_data` VARCHAR + 手动序列化。
- 候选 2：Product 聚合根集合参数必须用 `new ArrayList<>(...)` 包装，否则 `List.of()`/`.toList()` 不可变集合在 addSku 时抛 UnsupportedOperationException。
- 候选 3：product_spu/product_sku 表无 DEFAULT createdAt，toPo 中须 `field != null ? field : Instant.now()`。
- 统一在 Change converge 阶段评估沉淀，本 Story 不单独落盘。

## 2. 发现清单

| EV id | target | severity | finding | resolution 状态 |
| --- | --- | --- | --- | --- |
| —（dev 期 red-green） | ProductRepositoryImpl | major→已闭环 | MyBatis-Plus 对 `_json` 列名双重序列化致 specification_data 写入失败 | 已闭环：列名改 specification_data VARCHAR + 手动 Jackson 序列化 |
| —（dev 期 red-green） | Product 构造函数 | minor→已闭环 | List.of() 不可变集合致 addSku 抛 UnsupportedOperationException | 已闭环：new ArrayList<>(skus) 包装 |
| —（dev 期 red-green） | ProductPo/SkuPo | minor→已闭环 | createdAt NULL 插入失败（表无 DEFAULT） | 已闭环：toPo 中 field != null ? field : Instant.now() |
| —（dev 期 red-green） | ProductErrorCode | minor→已闭环 | 枚举名 PRODUCT_MAIN_IMAGE_DUPLICATED vs 引用 PRODUCT_MAIN_IMAGE_MISSING 不一致 | 已闭环：统一枚举名 |
| —（评审观察，非缺陷） | TC-011 | minor | 浏览器手工联调未在本环境执行 | 记录为集成环境待办；自动化契约证据已双侧覆盖，不阻塞 converge |

无 blocker；评审中识别的 major 级问题在 dev 红绿灯阶段已修复并有回归证据，按 findings-closure 要求在此登记闭环。

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 全部 blocker/major finding 已闭环（major 一项已修复复测）
- [x] minor finding 已记录（最后一项作为集成环境待办开放跟踪）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（多仓需求）
