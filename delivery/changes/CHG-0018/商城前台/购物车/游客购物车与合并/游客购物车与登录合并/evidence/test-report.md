# Test Report — STORY-003-03-02-01 游客购物车与登录合并

> 阶段：sdd-test 产物。

## 0. 元信息

- Change ID：CHG-0018
- Story ID：STORY-003-03-02-01
- 执行时间：2026-09-16
- 覆盖：AC-015~AC-020、AC-022
- 测试基线：
  - mall-cart 53/53（基线 41 + 新增 12：Lua 合并 7 + API 合并 5）
  - mall-product 95/95（公开 items 端点零破坏）
  - mall-web 85/85（前端三检 + ProductDetailView 加购接线）

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
|----|----------|----------|------|------|
| TC-001 | 游客详情加购进本地车，999 件/100 条上限提示 | vitest（useGuestCart）+ 组件接线 | passed | useGuestCart add/updateQuantity 拦截；ProductDetailView addToCart 调 cart.addItem |
| TC-002 | merge-token 申请返回 token，TTL 300s | Testcontainers Redis 7 | passed | RedisCartRepositoryLuaTest#mergeTokenTtl |
| TC-003 | 合并同 SKU 相加、异 SKU 并入；EXPIRE 续 90 天 | Testcontainers Redis 7 | passed | RedisCartRepositoryLuaTest#mergeAccumulates/#mergeExpire90Days |
| TC-004 | 超 999 截断、超 100 dropped；truncated/dropped 返回结构 | Testcontainers Redis 7 | passed | RedisCartRepositoryLuaTest#mergeTruncatesOver999/#mergeDropsOver100 |
| TC-005 | token 不存在→TOKEN_MISSING→400；跨会员串号→TOKEN_MISMATCH→401 | MockMvc | passed | CartApiTest#replayTokenReturns400/#forgedTokenReturns400AndMismatch401 |
| TC-006 | 失效 SKU 应用层预校验 dropped(SKU_NOT_SALABLE)，不入 Lua | MockMvc（mock productSkuClient） | passed | CartApiTest#mergeDropsUnsalableSkus |
| TC-007 | 合并幂等：token 一次性（DEL 消费后重放 400） | Testcontainers Redis 7 | passed | RedisCartRepositoryLuaTest#mergeTokenConsumedOnce |
| TC-008 | 公开 POST /api/mall/skus/items 仅返 ON_SALE+ENABLED 快照、≤100、匿名 200 | MockMvc | passed | MallSkuController items 端点（mall-product 95/95 含） |
| TC-009 | 游客车行展示调 /api/mall/skus/items + availability；缺失标失效；三检通过 | 前端 type-check/lint/build/test | passed | CartView guestItems 映射 invalid；三检全绿 |
| TC-010 | 前端合并编排：成功清空、truncated/dropped 提示、token 失效重取、网络失败保留 | 代码走查 + 单元 | passed | cart store performMerge/retryMerge；mergedThisSession 防重复 |
| TC-011 | mergeToken TTL=300s；合并后会员车 EXPIRE 续 90 天 | Testcontainers Redis 7 TTL 断言 | passed | RedisCartRepositoryLuaTest#mergeTokenTtl/#mergeExpire90Days |
| TC-012 | docker-compose.infra.yml redis 含 --appendonly --appendfsync everysec；前端三检 | 配置核查 + 三检 | passed | infra compose 摘录；type-check/lint/build/test 全绿 |

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
|------|------|------|
| mall-cart | `mvn -pl mall-services/mall-cart test`（TESTCONTAINERS_RYUK_DISABLED=true） | **53/53**（0 failures/0 errors/0 skipped） |
| mall-product | `mvn -pl mall-services/mall-product test`（TESTCONTAINERS_RYUK_DISABLED=true） | **95/95**（0 failures/0 errors/0 skipped） |
| mall-cart 打包 | `mvn -pl mall-services/mall-cart package -DskipTests` | BUILD SUCCESS |
| mall-product 打包 | `mvn -pl mall-services/mall-product package -DskipTests` | BUILD SUCCESS |
| mall-web 类型检查 | `pnpm type-check` | passed |
| mall-web lint | `pnpm lint` | passed（0 errors，1 预存 v-html warning） |
| mall-web build | `pnpm build` | BUILD SUCCESS |
| mall-web test | `pnpm test` | **85/85** |

## 3. 证据清单

- 证据索引（evidence-index）：Story `evidence/evidence.yaml`
- repo-1 DU 侧：`implementation/ai-platform-backend/delivery/CHG-0018/商城前台/购物车/游客购物车与合并/游客购物车与登录合并/DU-BE-803/evidence/`
- repo-2 DU 侧：`implementation/ai-platform-frontend/delivery/CHG-0018/商城前台/购物车/游客购物车与合并/游客购物车与登录合并/DU-FE-801/evidence/`

## 4. AC 覆盖

| AC | 覆盖 TC |
|----|---------|
| AC-015 | TC-001、TC-008 |
| AC-016 | TC-003 |
| AC-017 | TC-004、TC-010 |
| AC-018 | TC-005、TC-007、TC-010 |
| AC-019 | TC-007、TC-010 |
| AC-020 | TC-009、TC-012 |
| AC-022 | TC-012 |
