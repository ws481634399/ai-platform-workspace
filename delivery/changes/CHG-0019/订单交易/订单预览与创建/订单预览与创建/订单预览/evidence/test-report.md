# Test Report — STORY-004-01-01-01 订单预览

> 阶段：sdd-test 产物。

## 0. 元信息

- Change ID：CHG-0019
- Story ID：STORY-004-01-01-01
- 执行时间：2026-09-17
- 覆盖：AC-001~AC-010
- 实施来源：repo-1 DU-BE-901，代码提交 a06ed4c。

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| TC-001 | BUY_NOW 现货预览：服务端计价、可下单签发 submitToken | MockMvc（Redis 集成 + 依赖端口 mock） | passed | OrderApiTest#previewBuyNowOk |
| TC-002 | CART 预览以服务端购物车勾选项为准，请求体 items 被忽略 | MockMvc | passed | OrderApiTest#previewCartUsesCartSelection |
| TC-003 | 下架/SKU 失效/无库存 → issueCodes、availableToSubmit=false、token=null | MockMvc | passed | OrderApiTest#previewBlockedWhenUnsableOrOutOfStock |
| TC-004 | 地址不存在/非本人 → 地址 invalid 不可下单，不泄露归属差异 | MockMvc | passed | OrderApiTest#previewAddressNotOwned |
| TC-005 | 库存三档（OUT 阻断 / 1–9 LOW 可下单 / ≥10 OK）与 1..999、≤100 行校验 | 领域/应用单测 + MockMvc | passed | CheckoutPreviewService 行装配逻辑 + preview 用例 |
| TC-006 | 金额完全来自 product 实时快照，请求无金额入口 | MockMvc | passed | previewBuyNowOk 断言 goods/pay 金额 |
| TC-007 | submitToken Redis TTL 600s、载荷 source/addressId/行指纹 | Testcontainers Redis | passed | RedisSubmitTokenStore 经 AbstractRedisIntegrationTest |
| TC-008 | 任一依赖故障 → 503 ORDER_DEPENDENCY_UNAVAILABLE | MockMvc（端口异常注入） | passed | Rest*Port 异常转译 + fullHappyPath 夹具 |
| TC-009 | 未认证 401；member 内部地址端点 401/404；/api/internal 经网关 404 | MockMvc + 网关配置回归 | passed | OrderApiTest#authBoundaries；mall-gateway 路由用例 |
| TC-010 | 工程骨架：Flyway V1/V2、MyBatis-Plus、安全链，smoke 通过 | SpringBootTest | passed | MallOrderApplicationSmokeTest |

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-order 等 5 模块 | `mvn -pl mall-services/mall-order,mall-services/mall-inventory,mall-services/mall-member,mall-services/mall-cart,mall-gateway -am test` | mall-order **18/18**（OrderApiTest 17 + Smoke 1），其余模块 0 失败，BUILD SUCCESS |
| 日志 | `delivery/changes/CHG-0019/evidence/logs/backend-m4-test.log` | 完整 Maven 输出 |

## 3. AC 覆盖

| AC | 覆盖 TC |
|----|---------|
| AC-001 | TC-002、TC-009 |
| AC-002 | TC-001、TC-005 |
| AC-003 | TC-003 |
| AC-004 | TC-005 |
| AC-005 | TC-006 |
| AC-006 | TC-004 |
| AC-007 | TC-007 |
| AC-008 | TC-008 |
| AC-009 | TC-009 |
| AC-010 | TC-010 |

> 真实 jar + Docker infra 的端到端复核在 Change 级 Integration Gate（十场景）统一执行，记录于 Change `evidence/test-report.md`。
