# Review Report — STORY-003-03-01-02 购物车实时校验

## 0. 元信息

- Change ID：CHG-0018
- Story ID：STORY-003-03-01-02
- 审查对象：DU-BE-802（repo-1：mall-cart；product/inventory/gateway 零改动，复用既有内部契约）
- 审查时间：2026-09-16
- 审查者：trae-agent
- 测试报告来源（test-report-source）：`evidence/test-report.md`（mall-cart 41/41 + 真实环境 E2E）

## 1. 检查结论

**通过（PASS）。** 购物车读模型实时聚合实现符合 story-design/requirement-design 契约：

- 一次读车对 product sku/batch 与 inventory availability 各最多一次批量调用（mock 计数断言），禁 N+1，不访问对方数据库；
- 状态优先级正确：product 故障 UNKNOWN > 快照缺失 NOT_FOUND > 商品非 ON_SALE PRODUCT_OFF_SHELF > sku 非 ENABLED SKU_INVALID > 最新价≠快照价 PRICE_CHANGED > VALID；
- 库存三态阈值与 CHG-0017 同口径（0/1..9/≥10），cart 侧持同一常量值并注释标注 SSOT 对齐；
- 降级策略：product 故障→全条目商品态 UNKNOWN（库存态照常）；inventory 故障→仅库存 UNKNOWN；整车恒 200 不白屏；仅 Redis 自身故障才 503；空车零依赖短路；
- 合计仅 VALID+selected+有货（IN/LOW）按 product 最新价×数量累加整数分，调价/失效/缺货/未知库存/未选中均排除；
- 只读不改 Redis（Hash 字节一致 + TTL 不续期断言）；
- AC-021 跨服务边界：mall-cart 无 product/inventory 库表直查，仅两条 RestClient 出站（pom+import 自动审计）；
- 真实 jar + Docker infra 端到端验证含 inventory 宕机降级与重启自恢复。

开发期暴露的 4 个问题（RED-1~4，见 red-green.md）全部在开发期闭环并留守护测试，最终审查未发现遗留 blocker / major。

## 2. 发现清单

| 编号 | 严重度 | 发现 | 处理 |
|------|--------|------|------|
| F-001 | minor | CartReadApiTest 六个测试方法漏 `throws Exception` 导致编译失败（MockMvc checked Exception） | 已修复（34a0eb2）：统一补 throws Exception |
| F-002 | minor | stockThresholds 用例算术错误：LOW_STOCK 按口径应计入合计，排除的只有缺货 | 已修复（34a0eb2）：修正期望并注释「LOW 计入、OUT 排除」 |
| F-003 | minor | readDoesNotMutateRedis TTL 断言在同一整秒内采样不成立（非产品缺陷） | 已修复（34a0eb2）：写车后等待 2 秒越过整秒边界再采样 |
| F-004 | minor | `mvn package` repackage 失败：旧版 cart 进程占用 target jar | 已修复：停旧进程后重新打包（部署流程问题，非代码） |
| F-005 | info | product 契约无 SKU 名称字段，CartLine.skuName 承载 skuCode（specs 规格名值对完整） | 记录为 DEV-1，不影响功能；前端以 specs 渲染规格 |
| F-006 | info | PRICE_CHANGED 单字段状态不与 VALID 并存，调价行按 AC-013 不参与合计（新价仍展示） | 记录为 DEV-2，符合 spec「合计仅 VALID」语义 |

无遗留 blocker / major。

## 3. 完成确认

| 检查项 | 结论 |
|--------|------|
| 读模型字段完整性（图/名/SKU 属性/最新价整数分/数量/选择/双状态/时间戳/雪花 ID 字符串） | 通过（TC-001，CartReadApiTest#readModelEnriched） |
| 失效状态矩阵与优先级（NOT_FOUND / PRODUCT_OFF_SHELF / SKU_INVALID / PRICE_CHANGED / VALID） | 通过（TC-002，CartViewAssemblerTest#invalidStatusMatrix） |
| 调价检测：最新价≠快照价→PRICE_CHANGED+展示最新价；无价格入参入口 | 通过（TC-003，CartDtos 无 price 入参） |
| 库存阈值与 CHG-0017 同口径（0/1/9/10） | 通过（TC-004，CartViewAssemblerTest#stockThresholds） |
| 依赖降级：product 故障全条目 UNKNOWN、inventory 故障仅库存 UNKNOWN、整车 200 | 通过（TC-005 + 真实环境 §4.2） |
| 选中合计：仅 VALID+选中+有货，整数分 | 通过（TC-006，七条目矩阵精确断言） |
| 无 N+1：product/inventory 各一次批量调用 | 通过（TC-007，mock 计数） |
| 只读不改 Redis：Hash 字节一致 + TTL 不续期 | 通过（TC-008，Testcontainers Redis） |
| AC-021 跨服务边界：无 JDBC/MyBatis/JPA，仅 RestClient | 通过（TC-009，CartBoundaryAuditTest 2 例） |
| 自动化与构建 | 通过：mall-cart 41/41、package SUCCESS |
| 真实环境 | 通过：§test-report §4 inventory 宕机降级 + 重启恢复 |

证据索引（evidence-index）：Story `evidence/evidence.yaml` EV-001~EV-004，
repo-1 DU evidence/（changeset/commits/red-green/logs）。

## 4. Deviations

- DEV-1：product 内部 sku/batch 契约无 SKU 名称字段，CartLine.skuName 承载 skuCode；规格信息由 specs（规格名值对）完整提供，前端据此渲染。
- DEV-2：PRICE_CHANGED 为独立 itemStatus（不与 VALID 并存），调价行按 AC-013 不参与选中合计，但 priceFen 仍展示最新值供用户感知。
