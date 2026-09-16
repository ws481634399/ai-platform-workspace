# Test Report — STORY-003-03-01-02 购物车实时校验

> 阶段：sdd-test 产物。

## 0. 元信息

- Change ID：CHG-0018
- Story ID：STORY-003-03-01-02
- 执行时间：2026-09-16
- 覆盖：AC-008~AC-013、AC-021
- 测试基线：mall-cart 全模块 41/41（基线 23 + 本期新增 18：装配器 10 + 读模型 API 6 + 边界审计 2）。
- 实施来源（implementation-source）：repo-1 DU-BE-802，代码提交 34a0eb2（分支 M3-dev）。

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| TC-001 | GET 车返回 productId/productName/skuName/specs/imageUrl/priceFen(整数分)/quantity/selected/双状态/时间戳，雪花 ID 字符串 | MockMvc（mock product+inventory client） | passed | CartReadApiTest#readModelEnriched；CartViewAssemblerTest#validLineEnriched |
| TC-002 | 下架→PRODUCT_OFF_SHELF；SKU 禁用→SKU_INVALID；快照缺失→NOT_FOUND；四态优先级矩阵 | Assembler 表驱动 | passed | CartViewAssemblerTest#invalidStatusMatrix；CartReadApiTest#statusMatrixAndTotalExclusion |
| TC-003 | 最新价≠priceFenAtAdded → PRICE_CHANGED + priceFen 取最新值；写/读链路无价格入参入口 | MockMvc + REST 契约审计 | passed | CartViewAssemblerTest#priceChanged；CartDtos 无 price 入参字段 |
| TC-004 | 库存阈值 0/1/9/10 → OUT_OF_STOCK/LOW_STOCK/LOW_STOCK/IN_STOCK，与 CHG-0017 同口径 | Assembler 表驱动 | passed | CartViewAssemblerTest#stockThresholds |
| TC-005 | product 故障→全条目 itemStatus=UNKNOWN（库存态照常）；inventory 故障→仅 stockStatus=UNKNOWN；整车 HTTP 200 不白屏 | MockMvc 异常注入 | passed | CartReadApiTest#productFailureDegradesItemStatus / inventoryFailureDegradesGracefully / bothDependenciesDown |
| TC-006 | selectedTotalFen 仅计 VALID+selected+有货（IN/LOW），整数分；七条目矩阵合计精确为一件有效条目 | Assembler + MockMvc | passed | CartViewAssemblerTest#statusMatrixAndTotalExclusion / unselectedAndInvalidExcluded |
| TC-007 | 一次读车 product batch 一次、inventory 一次（≤100 条目无 N+1） | mock 客户端计数 | passed | CartReadApiTest#singleBatchEachDependency |
| TC-008 | 读车后 Redis Hash 字节一致、TTL 不续期（只读校验不改写） | Testcontainers Redis 7 | passed | CartReadApiTest#readDoesNotMutateRedis |
| TC-009 | mall-cart pom 无 JDBC/MyBatis/JPA/Flyway/驱动；主干无 java.sql/JPA/MyBatis/Spring JDBC import；仅两条 RestClient 出站 | 静态/依赖审计 | passed | CartBoundaryAuditTest（2 例自动审计） |

合计：mall-cart 41/41（Lua 9 + 写 API 13 + 装配器 10 + 读 API 6 + 边界审计 2 + Smoke 1），0 failures/0 errors/0 skipped。

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-cart | `mvn -pl mall-services/mall-cart test`（TESTCONTAINERS_RYUK_DISABLED=true） | **41/41**（0 failures/0 errors/0 skipped） |
| mall-cart 打包 | `mvn -pl mall-services/mall-cart package -DskipTests` | BUILD SUCCESS（61.9 MB fat jar） |
| 真实环境 | identity 8101/product 8103/cart 8104/inventory 8106/gateway 8080 真实 jar + Docker MySQL/Redis | 全链路 passed（§4） |

## 3. 证据清单

- 证据索引（evidence-index）：Story `evidence/evidence.yaml`
  - EV-001 code-change：repo-1 34a0eb2（DU-BE-802，13 个文件）
  - EV-002 evidence-ref：repo-1 DU evidence/changeset.md（13 文件变更清单）
  - EV-003 evidence-ref：repo-1 DU evidence/red-green.md（过程红 RED-1~4 + E2E 结论）
  - EV-004 test-run：mall-cart 41/41
- repo-1 DU 侧证据目录：`implementation/ai-platform-backend/delivery/CHG-0018/商城前台/购物车/会员购物车/购物车实时校验/DU-BE-802/evidence/`
  - `logs/be-cart-read-test.log`：mall-cart 全量测试完整日志
  - `changeset.md` / `commits.md` / `red-green.md` / `evidence.yaml`

## 4. 真实环境端到端（2026-09-16，Docker infra + 真实 jar）

五服务真实进程（identity 8101/product 8103/cart 8104/inventory 8106/gateway 8080）：

1. 会员登录经网关 GET /api/mall/cart → 真实在售 SKU 行：productId 字符串雪花 ID、商品名/规格名值对/图片、priceFen=399900、priceFenAtAdded=399900、itemStatus=VALID、stockStatus=IN_STOCK（inventory 真实精确数经阈值映射）、selectedTotalFen=399900、selectedCount=1。
2. 停 mall-inventory 进程后再次 GET → HTTP 200 不白屏：itemStatus 仍 VALID（product 未受影响）、stockStatus=UNKNOWN、selectedTotalFen=0（未知库存按缺货口径排除）、quantity/selected 照常展示。
3. 以同 jar 重启 mall-inventory 后再次 GET（cart 未重启）→ 自动恢复 IN_STOCK 与合计 399900，证明降级为纯运行时行为、无残留状态。
4. 自动化断言读车前后 Redis Hash 字节一致、TTL 不续期（只读不改写）。

## 5. AC 覆盖

| AC | 覆盖 TC |
|----|---------|
| AC-008 | TC-001、TC-007 |
| AC-009 | TC-002、TC-008 |
| AC-010 | TC-003 |
| AC-011 | TC-004 |
| AC-012 | TC-005、真实环境 §4.2/§4.3 |
| AC-013 | TC-006 |
| AC-021 | TC-009 |
