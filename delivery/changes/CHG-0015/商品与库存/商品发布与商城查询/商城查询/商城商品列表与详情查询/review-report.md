# Review Report — 商城商品列表与详情查询 STORY-002-03-02-01

> 阶段：sdd-review 产物（同态检查点，状态保持 testing）

## 0. 元信息

- Change ID：CHG-0015（M3 前置就绪修复）
- Test Report 来源：`商品与库存/商品发布与商城查询/商城查询/商城商品列表与详情查询/evidence/test-report.md`
- Evidence 索引：`evidence/evidence.yaml`（EV-001～EV-008 code-change、EV-009 test-run、EV-012 review-finding、EV-010/011 evidence-ref）
- 检查时间：2026-09-15T20:00:00+08:00

## 1. 检查结论

评审发现 1 项 major（EV-012，库存流水 ID 漏回填），在 testing 阶段由 bd309ec 修复并 red→green 回归闭环；无开放 blocker/major/minor。

### 1.1 需求一致性

| AC | test-run 证据 | 结论 |
| --- | --- | --- |
| AC-001、AC-002 | EV-009（covers 全量）；网关 13/13 + MallProductApiTest 70/70 + 冒烟 | passed |
| AC-003 | EV-009；internal 双形态 404 + InternalIdentityFilterTest 8 例 | passed |
| AC-004 | EV-009；内部凭证测试 + 冒烟 init/adjust | passed |
| AC-005 | EV-009；分页 33 行 total 回归 | passed |
| AC-006、AC-007、AC-008 | EV-009；StringIdJacksonTest + 双端类型门 + 冒烟 JSON 抽查（EV-012 闭环后值正确） | passed |
| AC-009、AC-010 | EV-009；价区分组/EXISTS 集成测试 + 源码抽查 SkuMapper 单条 GROUP BY | passed |
| AC-011 | EV-009；vitest 31/31 + 浏览器五页面九场景 | passed |
| AC-012 | EV-009；19 位雪花全链路 + 舍入形态 404 反证；EV-012 闭环 | passed |

12 条 AC 均有 covers 包含其的 test-run 条目（EV-009），追踪链 AC→TC（14 条）→EVD 无断链。

### 1.2 设计一致性

- **序列化契约**：@StringId = @JacksonAnnotationsInside + ToStringSerializer 仅作用于出参业务 ID；金额（分）/数量/分页/层级/排序保持 number；入参保持 Long 由 Jackson 原生兼容字符串——与 story-design 契约逐项一致，冒烟 JSON 抽查（id 带引号、salePriceInCents 无引号）佐证。
- **服务间凭证**：InternalIdentityFilter 共享 X-Internal-Token、"无凭证=拒绝"、JWT 不通内部，product/inventory 内部安全链与 SkuClient 调用方向符合设计；配置占位 `${MALL_INTERNAL_SHARED_SECRET:dev-internal-secret}` 未硬编码生产密钥。
- **网关边界**：源码抽查 `GatewaySecurityConfiguration` 白名单为最小集（login/refresh/`/api/mall/products/**`/health），`/api/internal/**` denyAll 并经异常转换返回 404 同构体；未提前扩张 home/categories/brands/skus（属 CHG-0017）。
- **价区与过滤**：SkuMapper `selectEnabledPriceRanges` 单条 `WHERE status='ENABLED' ... GROUP BY product_id` 聚合（源码抽查确认无 N+1）；商城列表 EXISTS 过滤无启用 SKU 商品，详情侧返回 404。
- **Deviations 复核**：repo-1 DEV-1（条件装配）/DEV-2（方言自动探测）/DEV-3（库存潜伏 400·500）、repo-2 DEV-1（local-n 临时键）/DEV-2（双证据形态）均在各仓 implementation.md 记录且理由合理，未发现未记录偏离。

### 1.3 跨仓一致性（Phase 2.4）

- 两 DU 均物化、completed 且 result commit 已回填（repo-1 dc4035a、repo-2 40cd3d1），与各仓 HEAD 一致；baseline 锚定实现前 commit（d5ed15fc / 77c8b23）。
- 契约方向正确：repo-1 先行输出字符串 ID 与内部凭证契约，repo-2 按同构字段消费；联调在真实四服务 + vite 代理下完成，暴露的跨切面缺陷（EV-012）已回补 repo-1 并回归。
- 范围外项（公开分类树/品牌/批量库存、mall-web、会员、购物车）在 story-spec §2.2 明确排除，无漏接契约。

### 1.4 代码质量

- 后端 24 模块全量构建成功、198 测试全绿；前端 lint 0 error。存量 281 项 vue/max-attributes-per-line 等格式 warning 为历史遗留、非本次引入，不阻断。
- 抽查 GatewaySecurityConfiguration、SkuMapper、InventoryRepositoryImpl 实现职责单一、与设计符号对应；DEV-4 修复仅 5 行且附带独立回归用例，修复面最小。
- 无依据 standards 明确条文的新增违规。

### 1.5 知识同步候选

- 候选 standards（供 converge 决策，本次不沉淀）：
  1. 「业务 ID 出参字符串化、入参保持 Long」的 @StringId 组合注解模式，可作为雪花 ID 跨语言传输的通用约束。
  2. 「网关 internal 路径 denyAll + 404 同构体外拒、服务间共享凭证不经网关」的内外网隔离模式。
- 无新术语/新产品知识候选（本 Change 为前置缺口修复，不新增业务能力）。

## 2. 发现清单

| EV | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-012 | InventoryRepositoryImpl.java#logToDomain | major | 流水重建漏传持久化雪花 ID，列表 id 恒为 "0" | bd309ec（EV-006）回填；red→green 20/20 与冒烟双流水验证（EV-009），已闭环 |

## 3. 完成确认

- [x] 四项检查全部执行（需求/设计/跨仓/质量 + 知识候选）
- [x] 全部 blocker/major finding 已闭环（EV-012 resolution 非空）
- [x] minor finding 已记录（本次无开放 minor；存量 lint warning 见 §1.4）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（两 DU completed、result/HEAD 对齐、契约双向验证）
- [x] 追踪链 AC→TC→EVD 完整，红绿灯证据可追溯
