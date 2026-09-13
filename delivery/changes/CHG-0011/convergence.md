# Convergence — CHG-0011 商品与 SKU 管理

> 阶段：sdd-converge 产物
> 业界锚点：Postmortem + Lessons Learned（What → Why → Action → Knowledge）
> 输入：CHG-0011 全部 Artifact（2 Story 全流程 completed）
> 产出状态：completed

## 0. 元信息

- Change ID: CHG-0011
- 完成时间: 2026-09-13
- 产出 Artifact 数: 14（Change 级 6：exploration/requirement/requirement-spec/requirement-design/convergence/evidence；每 Story 6×2：story-spec/story-design/test-design/implementation/test-report/review-report；含 story-metadata 状态载体）
- 交付 DU：3（repo-1 DU-BE-304/305、repo-2 DU-FE-303），全部 completed

## 1. 知识变化总结

- 知识增量摘要:
  1. Product/SPU 聚合根落地：商品主数据（名称/分类/品牌/图片/属性）、状态机（DRAFT/ON_SALE/OFF_SALE/DISABLED）、主图唯一约束、属性键值对集合。
  2. SKU 与规格管理：SpecificationHash 规格组合唯一哈希（SHA-256，按 name 字典序拼接）、Money 分价模式（long amountInCents，DB BIGINT）、SKU 编码全局唯一、SKU 随 Product 聚合全量替换持久化。
  3. mall-product 新增 V2（product_spu/product_image/product_attribute）、V3（product_sku）迁移；mall-identity V4 新增 8 个商品/SKU 权限码 + 商品列表菜单。
  4. 工程经验：MyBatis-Plus JSON 列名陷阱、聚合根集合不可变性、Flyway 无 DEFAULT 字段处理、SpecificationHash 唯一哈希模式（已沉淀 standards 候选）。

## 2. 更新判断

### Standards

- 是否需更新: yes
- 更新内容: standards/engineering/coding-standard.md 或 testing-standard.md 新增约定：
  - MyBatis-Plus 3.5.12 对数据库列名以 `_json` 结尾自动套用 JacksonTypeHandler，会导致手动序列化的 JSON 字段双重序列化。解法：列名改用 `_data` VARCHAR + 手动 Jackson 序列化。
  - DDD 聚合根集合参数必须用 `new ArrayList<>(...)` 包装，不可直接赋值 `List.of()`/`.toList()` 返回的不可变集合，否则 add/remove 抛 UnsupportedOperationException。
  - Flyway 迁移中 createdAt/updatedAt 字段若无 DEFAULT，PO 转换时须 `field != null ? field : Instant.now()`。
  - 规格组合唯一哈希模式：按 name 字典序拼接 `name=value` 后 SHA-256，保证顺序无关的组合唯一性。
- 理由: 四条均为跨 Change 复用的工程约束，M2 后续发布/库存 Change 及 M3 订单 Change 直接受益。

### Product

- 是否需更新: no（本 Change 不直接改产品知识正文）
- 更新内容: 无。product/09-数据库设计.md、10-API与事件契约.md、11-权限与功能配置.md 的 M2 章节更新留待 M2 四个 Change 全部 converge 后统一回写。
- 理由: 商品/SKU 仅为 M2 第二组能力，发布、库存未落库前更新 09/10 会形成不完整契约视图。

### feature-tree.yaml

- 是否需更新: yes
- 更新内容: STORY-002-02-01-01（商品 SPU 管理）、STORY-002-02-02-01（SKU 与规格管理）status: planned → delivered。
- 理由: 两 Story 已 completed 且测试/评审证据齐备，特性树状态与交付事实对齐。

### Glossary

- 是否需更新: yes
- 更新内容: product/glossary/terms.md 新增术语：SPU（Standard Product Unit，标准商品单元，商品信息聚合的最小单位）、SKU（Stock Keeping Unit，库存量单位，规格组合下的可售单元）、SpecificationHash（规格组合哈希，按 name 字典序拼接后 SHA-256，用于同 Product 内规格组合唯一性判定）。
- 理由: 本 Change 引入 SPU/SKU/SpecificationHash 核心术语，后续发布/库存/订单 Change 持续引用。

## 3. 知识沉淀过程

- 已写回：convergence.md 登记 standards 候选（具体写入 standards/ 留待 M2 末或下一次集中沉淀）；feature-tree 两 Story 状态置 delivered；glossary 新增 SPU/SKU/SpecificationHash 术语。
- 留待后续：产品知识正文（09/10/11）M2 末统一更新；浏览器手工联调走查（TC-011）在具备网关+mall-product+mall-admin 集成环境时执行，结果回填 Story 1 test-report，不阻塞本次 converge（自动化契约证据双侧闭环）。
- 未沉淀为标准的内容：Product/Sku 的具体字段、错误码、页面结构——属实现细节，保留在各仓代码与 DU 文档中，符合"实现细节不进 standards"约束。

## 4. 全局验收标准对照

> 摘自 requirement-spec.md（AC-001~015）。跨 Story 项同时引用两个 Story 的证据。

| # | 验收点 | 覆盖 Story | 证据引用 | 结论 |
| --- | --- | --- | --- | --- |
| 1 | AC-001 提交合法 Product → 创建成功，状态 DRAFT | S1 SPU | Story 1 test-report TC-001；EV-011 | 通过 |
| 2 | AC-002 分类/品牌不存在或非启用 → 拒绝 | S1 SPU | Story 1 test-report TC-002 | 通过 |
| 3 | AC-003 一个 Product 可创建一个或多个 SKU | S2 SKU | Story 2 test-report TC-001 | 通过 |
| 4 | AC-004 SKU Code 全局唯一，重复拒绝且无落库 | S2 SKU | Story 2 test-report TC-002 | 通过 |
| 5 | AC-005 SKU 销售价为分（long）且 >= 0 | S2 SKU | Story 2 test-report TC-003 | 通过 |
| 6 | AC-006 同 Product 内规格组合唯一，重复拒绝 | S2 SKU | Story 2 test-report TC-004 | 通过 |
| 7 | AC-007 商品图片 object_key+image_url；仅一张主图 | S1 SPU | Story 1 test-report TC-003 | 通过 |
| 8 | AC-008 修改 Product/SKU/价格/图片/属性后查询最新值 | S1+S2 | Story 1 TC-004 + Story 2 TC-005 | 通过 |
| 9 | AC-009 product_spu/product_sku 无 stock 字段 | S1 SPU | Story 1 test-report TC-005 | 通过 |
| 10 | AC-010 创建商品状态 DRAFT，四态枚举 | S1 SPU | Story 1 test-report TC-006 | 通过 |
| 11 | AC-011 mall-admin 商品页列表/创建/编辑/查看 | S1 SPU | 前端 EV-012（28 单测、type-check/lint/build 全过）+ 后端契约 MockMvc；浏览器手工走查待集成环境 | 通过（自动化闭环；手工走查留跟踪项） |
| 12 | AC-012 商品属性键值对可增删改并保存 | S1 SPU | Story 1 test-report TC-007 | 通过 |
| 13 | AC-013 无 product:product/sku 写权限 → 403；有权限 → 成功 | S1+S2 | Story 1 TC-008 + Story 2 TC-006 | 通过 |
| 14 | AC-014 Product/SKU 变更注册领域事件 | S1+S2 | Story 1 TC-009 + Story 2 TC-007 | 通过 |
| 15 | AC-015 DISABLED 商品不可发布；SKU 可独立启停 | S1+S2 | Story 1 TC-010 + Story 2 TC-008 | 通过 |

跨 Story 集成说明：AC-008/013/014/015 为跨两个 Story 的全局验收点。SKU 作为 Product 聚合内实体，由 DU-BE-304 提供 Product 聚合根与仓储、DU-BE-305 提供 Sku 实体与 SKU 管理行为，两者同 commit（23a1dfb）交付，测试在同一 ProductAdminApiTest 中覆盖，证明聚合内跨 DU 协作可用。

## 5. 完成确认

- [x] 代码变更已完成（3 DU，5 个 commit 跨 repo-1/repo-2）
- [x] 测试已完成（后端 product 36、前端 28，全绿；质量门全过）
- [x] 证据已收集（Change evidence.yaml 12 条 EV + 各仓 DU evidence）
- [x] 全局验收标准已逐条对照（§4，含 AC-008/013/014/015 跨 Story 集成验收点）
- [x] 知识更新已评估（standards 候选已登记；feature-tree 已更新；glossary 已更新；Product 留待 M2 末）
