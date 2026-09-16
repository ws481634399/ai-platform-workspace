# Test Report — STORY-003-03-01-01 购物车核心操作

> 阶段：sdd-test 产物。

## 0. 元信息

- Change ID：CHG-0018
- Story ID：STORY-003-03-01-01
- 执行时间：2026-09-16
- 覆盖：AC-001~AC-007、AC-014
- 测试基线：repo-1 mall-product 93/93、mall-gateway 19/19；mall-cart 为本期新业务化模块（原仅 Smoke 1 例）。
- 实施来源（implementation-source）：repo-1 DU-BE-801，代码提交 ebfbeb2（分支 M3-dev）。

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| TC-001 | Redis 集成：有效加购 → 条目写入，默认勾选/快照价，TTL≈90 天常量 | Testcontainers Redis 7 | passed | RedisCartRepositoryLuaTest#addNewItemSetsDefaultsAndTtl |
| TC-002 | 同 SKU 再购累加成一条；超 999 → 400 且保持原值 | Testcontainers + MockMvc | passed | addMergesSameSku/addOverQuantityLimitKeepsOriginal/mergeAndQuantityLimit |
| TC-003 | 下架/禁用/不存在 SKU → 400 SKU_NOT_SALABLE；数量非法 400；车不变；依赖故障 503 | MockMvc（mock ProductSkuClient） | passed | addUnsalableRejected/invalidRequestRejected/addDependencyFailure503；真实环境 DRAFT SKU 实测 400 |
| TC-004 | 连续 100 个不同 SKU 成功，第 101 个 → 400 CART_ITEMS_LIMIT，车保持 100 | Testcontainers | passed | addRejects101stDistinctSku/itemsLimit |
| TC-005 | PUT 合法/非法数量；DELETE 单条与批删；批删含不存在项幂等 | Testcontainers + MockMvc | passed | updateQuantityLifecycle/removeIsIdempotent/updateAndRemove |
| TC-006 | 单选/取消/全选/取消全选；存储在服务端 Hash，第二会话读取一致 | Testcontainers + MockMvc | passed | selectSemantics/selectionLifecycle（Redis 真实存储即跨设备一致） |
| TC-007 | 无 Token 401；请求体 memberId 被忽略（会员隔离）；ADMIN 403；M4 内部端点三态凭证 | MockMvc + 真实网关 | passed | noTokenUnauthorized/adminForbidden/cartIsolation；网关无 Token 401 实测 |
| TC-008 | mall-cart pom/代码无 inventory 锁库存调用路径（本 DU 仅可售校验） | 静态/依赖审计 | passed | mall-cart pom 无 mall-inventory 依赖；ProductSkuClient 仅调 product sku/batch |
| TC-009 | GET /api/internal/carts/members/{id}/selected-items 无凭证 401、X-Internal-Token 返选中条目；网关 /api/internal/** 404 | MockMvc + 真实 jar 联调 | passed | CartApiTest 内部凭证三态；真实环境 unselect 0 项/select-all 1 项 |
| TC-010 | product POST /api/internal/products/skus/batch 双状态/价/图/规格；≤100 校验；无凭证 401 | MockMvc（H2 + JDBC 夹具） | passed | InternalProductApiTest#skuBatchSalableAndMissing / skuBatchAuthAndValidation（mall-product 95/95） |
| TC-011 | 每次写操作（改量/删除/选择）后 TTL 均续期；删除不存在键不重建 | Testcontainers | passed | writeOperationsRenewTtl/removeIsIdempotent |

合计：自动化 23（mall-cart：Lua 9 + API 13 + Smoke 1）+ 契约回归 2（mall-product 新增，模块 95/95）
+ 网关 19/19 无回归；另完成一轮真实 jar + Docker infra 端到端联调（见 §4）。

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-cart | `mvn -pl mall-services/mall-cart test`（TESTCONTAINERS_RYUK_DISABLED=true） | **23/23**（9+13+1，0 failures/0 errors/0 skipped） |
| mall-product | 开发期 `mvn -pl mall-services/mall-cart,mall-services/mall-product,mall-gateway -am test` | **95/95**（基线 93 + sku/batch 新增 2） |
| mall-gateway | 同上 | **19/19** 无回归 |
| 三模块打包 | `mvn -pl mall-services/mall-cart,mall-services/mall-product,mall-gateway package -DskipTests` | BUILD SUCCESS |
| 真实环境 | identity 8101 / product 8103 / cart 8104 / gateway 8080 / inventory 8106 真实 jar + Docker MySQL/Redis | 全链路 passed（§4） |

## 3. 证据清单

- 证据索引（evidence-index）：Story `evidence/evidence.yaml`
  - EV-001 code-change：repo-1 ebfbeb2（DU-BE-801，25 个代表文件）
  - EV-002 evidence-ref：repo-1 DU evidence/changeset.md（34 文件变更清单）
  - EV-003 evidence-ref：repo-1 DU evidence/red-green.md（过程红 RED-1~5 + E2E 结论）
  - EV-004 test-run：mall-cart 23/23（完整日志见下）
- repo-1 DU 侧证据目录：`implementation/ai-platform-backend/delivery/CHG-0018/商城前台/购物车/会员购物车/购物车核心操作/DU-BE-801/evidence/`
  - `logs/be-cart-test.log`：mall-cart 全量测试完整日志（含 Testcontainers Redis 拉起与 23/23 汇总、BUILD SUCCESS）
  - `changeset.md` / `commits.md` / `red-green.md` / `evidence.yaml`

## 4. 真实环境端到端（2026-09-16，Docker infra + 真实 jar）

注册新会员并登录 → 经网关 8080 加购真实在售 SKU（快照价 399900 分，默认勾选，响应 ID 为字符串雪花 ID）→
再次加购 2 件合并为 3 → 对 DRAFT 态商品 SKU 加购返回 400 B0303（车不变）→ 无 Token 访问 401 →
经网关访问内部路径返回 404（denyAll 不暴露存在性）→ 直连 cart 8104 以 X-Internal-Token 调 selected-items：
unselect 后返回 0 项、select-all 后返回 1 项（quantity=3）→ Redis 直查：Hash 条目数 1、
TTL 与 90 天常量相差不足 1 分钟、value 为约定 JSON（含快照价/勾选/时间戳）。测后已清理该测试会员购物车 key。

## 5. AC 覆盖

| AC | 覆盖 TC |
|----|---------|
| AC-001 | TC-001、TC-011（真实环境 TTL 复核） |
| AC-002 | TC-002 |
| AC-003 | TC-003、TC-010 |
| AC-004 | TC-004 |
| AC-005 | TC-005 |
| AC-006 | TC-006 |
| AC-007 | TC-007、TC-009 |
| AC-014 | TC-008 |
