# Test Report — 商城商品列表与详情查询 STORY-002-03-02-01

> 阶段：sdd-test 产物（独立验证：按 test-design.md 的 14 条 TC 逐条核对，证据取自各 DU evidence，不在此重复实现正文）

## 0. 元信息

- Change ID：CHG-0015
- Story ID：STORY-002-03-02-01
- 执行时间：2026-09-15
- 覆盖：AC-001～AC-012（14/14 TC）
- 测试基线：repo-1 `mvn clean package`（24 模块，197→DEV-4 后 inventory 20/20）；repo-2 pnpm 四门静态/单测/构建；真实基础设施端到端联调。

## 1. TC 执行结果

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| TC-001 | 网关匿名 GET /api/mall/products 200 有数据 | 网关安全链集成测试 + 真网关冒烟 | passed | CHG0015GatewaySecurityChainTest（gateway-green-final.log 13/13）；smoke-api-verify.log |
| TC-002 | 匿名详情 200；不存在/不可售 404 | MockMvc 集成 + 真网关冒烟 | passed | MallProductApiTest（product-green-run2.log 70/70，含无启用 SKU 404 断言）；smoke 详情 JSON |
| TC-003 | 外部请求 /api/internal/** → 404 | 集成测试（匿名/持 ADMIN JWT 双形态）+ 真网关冒烟 | passed | gateway-green-final.log；smoke 双 404 同构体 B0001 |
| TC-004 | inventory 初始化真实 SKU 成功（SkuClient 带凭证） | 内部接口安全测试 + 端到端冒烟 | passed | InternalInventorySecurityTest；smoke init 100→adjust 150 无误报 |
| TC-005 | 33 行分页 total=33、翻页恒定、筛选一致 | InventoryAdminApiTest 分页回归 | passed | inventory-green-final.log（19/19，分页插件 total 断言） |
| TC-006 | 商品列表 id 为 JSON 字符串不丢精度 | JSON 类型断言 + 真接口取数 | passed | MallProductApiTest 字符串 ID 断言；冒烟 19 位雪花商品 ID 全链路完整 |
| TC-007 | 五域业务 ID 全字符串（嵌套/分页），金额/数量/分页仍 number | 序列化单测 + 双端类型门 + 冒烟抽查 | passed | StringIdJacksonTest；product/inventory DTO 测试；vue-tsc 0 错；smoke 详情 JSON（id 带引号、salePriceInCents 无数引号） |
| TC-008 | 入参 "123" 与 123 双形态同结果 | Jackson 序列化器单测 + 控制器 Long 入参 | passed | StringIdJacksonTest（仅出参转换、入参不受影响）；冒烟字符串 skuId 入参 200 |
| TC-009 | 价区=启用 SKU MIN/MAX 整数分、无 null | 集成测试多 SKU 断言 + 单条分组 SQL 核对 | passed | MallProductApiTest 价区断言（`expected 2000L` 真实价区）；SkuMapper 单条 GROUP BY 聚合 |
| TC-010 | 全 SKU 禁用后商品从列表消失 | 集成测试 EXISTS 过滤 | passed | MallProductApiTest（EXISTS 启用 SKU 过滤、无启用 SKU 详情 404） |
| TC-011 | mall-admin 五页面 CRUD/分页/跳转/回显零回归 | vitest + 真实浏览器五页面操作 | passed | fe-test-run1.log 14 文件 31/31；浏览器冒烟九场景全过 |
| TC-012 | skuId 网关取回原样回传无末位偏差 | 端到端加购预演 + 精度反证 | passed | smoke JSON skuId 19 位完整；舍入形态 ID（末位归整）查详情反证 404 |
| TC-013 | InternalIdentityFilter：无头 401/错头 401/正确头 ROLE_SERVICE | 安全过滤器单测 8 例 | passed | InternalIdentityFilterTest（含合法 JWT 无凭证仍 401、常量时间比较） |
| TC-014 | 价区聚合一次分组 SQL，无 N+1 | Mapper SQL 核对 + 多商品列表集成测试 | passed | SkuMapper 单条 `GROUP BY product_id` 取 MIN/MAX；多商品列表用例一次聚合通过（product-green-run2.log） |

合计：14 passed / 0 failed / 0 skipped。

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | ---: | ---: | ---: | ---: |
| 后端 Maven 全量（13 个测试模块） | 198 | 198 | 0 | 0 |
| └ 其中 mall-inventory（DEV-4 追加回归后） | 20 | 20 | 0 | 0 |
| └ mall-product / mall-gateway / mall-common-* | 其余全部 | 全绿 | 0 | 0 |
| 前端 Vitest | 31 | 31 | 0 | 0 |
| 前端 type-check / lint(0 error) / build | 3 | 3 | 0 | 0 |
| 端到端冒烟场景（五页面 + 接口反证） | 9 | 9 | 0 | 0 |

> 后端全量构建时点 197/197（backend-full-package-run1.log）；DEV-4 新增流水 ID 回填用例后 inventory 单模块 20/20（inventory-logid-green.log），合计口径 198。

## 3. 联调新发现缺陷（独立验证产出）

- **DEV-4（blocker→已修复）**：库存流水列表 id 恒为 `"0"`——`InventoryRepositoryImpl.logToDomain` 重建领域对象时漏传持久化雪花 ID。
  - 红证据：inventory-logid-red.log（`expected:<2099557758270611458> but was:<0>`）
  - 绿证据：bd309ec 修复后 inventory-logid-green.log 20/20；冒烟流水修复后 INIT/ADJUST 均回填真实雪花 ID。

## 4. 证据位置

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0015/商品与库存/商品发布与商城查询/商城查询/商城商品列表与详情查询/DU-BE-501/evidence/`（red-green.md、evidence/logs/*.log）
- repo-2：`implementation/ai-platform-frontend/delivery/CHG-0015/商品与库存/商品发布与商城查询/商城查询/商城商品列表与详情查询/DU-FE-501/evidence/`（red-green.md、evidence/logs/ 静态门禁日志、smoke-api-verify.log、smoke/ 服务日志）

## 5. 非阻塞观察项

- 冒烟期一次 `/api/admin/categories/tree` `net::ERR_ABORTED`（页面快速切换取消请求），重试正常，与本次改造无关。
- vue-router "Parent route admin-layout" 为既有测试期告警。

## 6. 结论

AC-001～AC-012 全部通过，14 条 TC 无遗留失败。独立联调额外发现并闭环 1 个潜伏缺陷（DEV-4），red→green 证据完整可审计。本 Story 具备进入 review 的条件。
