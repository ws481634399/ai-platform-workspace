# Implementation（跨仓实施汇总）— 购物车实时校验 STORY-003-03-01-02

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文位于各实现仓 DU 目录。

## 0. 元信息

- Change ID：CHG-0018（购物车）
- Story：STORY-003-03-01-02 购物车实时校验
- 实施日期：2026-09-16（后端 DU-BE-802）
- 范围边界：GET /api/mall/cart 读模型实时聚合——一次 product sku/batch + 一次 inventory
  availability（各一批、禁 N+1）装配 CartLine：商品/SKU 双状态、最新整数分价、调价标记、
  库存三态（与 CHG-0017 同口径）、条目级 UNKNOWN 降级（整车恒 200）、VALID+选中+有货金额合计；
  装配只读不改 Redis。
  不含：写操作（STORY-003-03-01-01 已交付，写响应仍回显原始车，前端写后强拉）；
  游客车与合并（STORY-003-03-02-01）；结算计价（M4，selectedTotalFen 仅展示）。
  product/inventory/gateway 三服务零改动，全部复用既有内部契约。

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-802 | repo-1（ai-platform-backend） | 完成并验证：mall-cart 41/41（基线 23 + 新增 18：装配器 10 + 读模型 API 6 + 边界审计 2），package 成功；真实五服务联调含 inventory 宕机降级与重启恢复 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 34a0eb2 | DU-BE-802 | repo-1 | 读车实时聚合：inventory 出站端口+Rest 适配、CartReadModel/CartViewAssembler/CartQueryService、GET 替换读模型、阈值常量、边界审计（13 文件） |

（另有 docs(sdd) 提交仅回填 DU implementation/metadata/evidence，非代码提交，按机检规则不计入 code-change Evidence。）

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0018/商城前台/购物车/会员购物车/购物车实时校验/DU-BE-802/implementation.md`
  - 状态优先级：product 故障 UNKNOWN > 快照缺失 NOT_FOUND > 商品非 ON_SALE PRODUCT_OFF_SHELF >
    sku 非 ENABLED SKU_INVALID > 最新价≠快照价 PRICE_CHANGED > VALID。
  - 库存三态：inventory 给精确数，cart 本地常量映射 0 / 一至九 / ≥十（阈值常量注释标注
    与 CHG-0017 同 SSOT）；无库存记录按 0。
  - 降级：product 故障 → 全条目商品态 UNKNOWN（库存态照常）；inventory 故障 → 仅库存 UNKNOWN；
    仅 Redis 自身故障才 503；空车零依赖调用短路。
  - 合计：仅 itemStatus=VALID 且 selected 且库存 IN_STOCK/LOW_STOCK，按 product 最新价
    ×数量累加整数分；调价/失效/缺货/未知库存/未选中均排除。
  - DEV-1：product 契约无 SKU 名称字段，CartLine.skuName 承载 skuCode（specs 规格名值对完整）。
  - DEV-2：PRICE_CHANGED 单字段状态不与 VALID 并存，调价行按 AC-013 不参与合计（新价仍展示）。

## 4. 与 Task / AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-008 | CartLine 回填 productId/productName/skuName/specs/imageUrl/priceFen(整数分)/quantity/selected/双状态/时间戳，雪花 ID 字符串 | passed（CartViewAssemblerTest#validLineEnriched；CartReadApiTest#readModelEnriched；真实商品 E2E） |
| AC-009 | NOT_FOUND/PRODUCT_OFF_SHELF/SKU_INVALID 三态由 product 批量快照占位与双状态字段映射 | passed（invalidStatusMatrix 四态；statusMatrixAndTotalExclusion 七条目真实链路） |
| AC-010 | 最新价≠priceFenAtAdded → PRICE_CHANGED + priceFen 取最新值；写/读链路均无价格入参入口 | passed（priceChanged；REST 契约无 price 入参，边界审计佐证） |
| AC-011 | 阈值 0/1/9/10 边界 → OUT_OF_STOCK/LOW_STOCK/LOW_STOCK/IN_STOCK，与 CHG-0017 同口径 | passed（stockThresholds；真实 E2E IN_STOCK） |
| AC-012 | product 故障全条目 UNKNOWN、inventory 故障仅库存 UNKNOWN，整车均 200 不白屏；恢复无需重启 cart | passed（productFailureDegradesItemStatus/inventoryFailureDegradesGracefully/bothDependenciesDown；真实停服 8106 验证 + 重启自恢复） |
| AC-013 | 合计仅 VALID+selected+有货（IN/LOW），整数分；七条目矩阵合计精确为一件有效条目 | passed（priceChanged/stockThresholds/unselectedAndInvalidExcluded/statusMatrixAndTotalExclusion） |
| AC-021 | mall-cart pom 无 JDBC/MyBatis/JPA/Flyway/驱动；主干无 java.sql/JPA/MyBatis/Spring JDBC import；仅两条 RestClient 出站 | passed（CartBoundaryAuditTest 2 例自动审计） |

## 5. 真实环境验证（2026-09-16）

Docker infra（MySQL/Redis）+ 真实 jar 五服务（identity/product/cart/inventory/gateway）：
会员登录经网关读车，真实在售 SKU 返回商品名/规格/图/最新价（三九九九〇〇分）与 VALID+IN_STOCK、
选中合计正确；随后停止 inventory 进程，读车仍返回 200：商品态 VALID 不变、库存态 UNKNOWN、
合计按未知库存口径归零、数量与选择正常展示；以原 jar 重启 inventory（cart 不重启）后状态与
合计自动恢复。另由自动化测试断言读车前后 Redis Hash 字节一致、TTL 不续期（只读）。
