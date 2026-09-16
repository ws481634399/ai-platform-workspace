# Review Report — STORY-003-03-02-01 游客购物车与登录合并

## 0. 元信息

- Change ID：CHG-0018
- Story ID：STORY-003-03-02-01
- 审查对象：DU-BE-803（repo-1：mall-cart 合并 + mall-product 公开 items）、DU-FE-801（repo-2：mall-web 双模购物车）
- 审查时间：2026-09-16
- 审查者：trae-agent
- 测试报告来源：`evidence/test-report.md`（mall-cart 53/53、mall-product 95/95、mall-web 85/85）

## 1. 检查结论

**通过（PASS）。** 游客购物车与登录合并实现符合 story-design/requirement-design 契约：

**后端 DU-BE-803：**
- 合并 token 一次性：`cart:merge:{token}` String，值=memberId，TTL 300s，Lua 内 DEL 消费（重放 400）；
- cart_merge.lua 单脚本原子：token GET 校验→DEL→逐条合并（同 SKU 相加、>999 截断、>100 dropped）→EXPIRE 90 天；
- 应用层预校验：CartMergeService 先调 ProductSkuClient 批量校验可售性，失效项 dropped(SKU_NOT_SALABLE) 不入 Lua；
- 错误码语义清晰：TOKEN_MISSING→400（token 不存在/过期），TOKEN_MISMATCH→401（跨会员串号）；
- 公开端点 POST /api/mall/skus/items 复用 SkuBatchApplicationService.batch()，filter salable=true，缺失项不返回；
- Lua 返回 JSON 手写 encodeArray() 兼容 Redis 7.4 cjson 空表问题（DEV-1）。

**前端 DU-FE-801：**
- useGuestCart LocalStorage 持久化：key=`mall-web:guest-cart`，999 件/100 条上限拦截，90 天惰性清理；
- cart store 双模：游客走本地、会员走 API；watch member.isAuthenticated 自动触发合并；
- 合并编排：issueMergeToken→merge；400/401 重取 token 重试一次；网络失败保留游客车+mergePending；
- CartView 双模列表：游客行调 /api/mall/skus/items + availability，缺失标失效；合计仅有效+选中+有货；去结算置灰 tooltip；
- AOF 配置验证：docker-compose.infra.yml redis `--appendonly yes --appendfsync everysec`（repo-4 零改动）。

开发期暴露的问题全部闭环，最终审查未发现遗留 blocker / major。

## 2. 发现清单

| 编号 | 严重度 | 发现 | 处理 |
|------|--------|------|------|
| F-001 | minor | CartApiTest.mergeAccumulates 期望 merged=2 实得 1：mock 只返回第一个 skuId 快照 | 已修复：mock 改为对入参列表中每个 skuId 返回 salable 快照 |
| F-002 | minor | `cjson.encode_empty_table_as_object` 在 Redis 7.4-alpine 不存在 | 已修复（DEV-1）：手写 encodeArray() 拼接数组 |
| F-003 | minor | `mvn package` repackage 失败：旧版进程占用 target jar | 已修复：停旧进程后重新打包 |
| F-004 | minor | Pinia store 中 cart.guest.items 已自动解包，组件内不应加 .value | 已修复：移除 CartView 中多余的 .value |
| F-005 | minor | ProductDetailView 404 测试 mock 抛出普通对象而非 AxiosError | 已修复：用 hasResponseStatus 类型守卫兼容两种错误形态 |
| F-006 | info | 前端无 toast 库，合并提示用 store 内 mergeMessage ref + CartView 顶部 banner 展示 | 符合 M3 占位要求，不影响功能 |

无遗留 blocker / major。

## 3. 完成确认

| 检查项 | 结论 |
|--------|------|
| 游客加购进本地车，999/100 上限提示 | 通过（TC-001，useGuestCart + ProductDetailView 接线） |
| merge-token TTL 300s、一次性消费 | 通过（TC-002、TC-007，RedisCartRepositoryLuaTest） |
| 合并同 SKU 相加/异 SKU 并入，90 天 TTL | 通过（TC-003、TC-011，RedisCartRepositoryLuaTest） |
| 超 999 截断、超 100 dropped | 通过（TC-004，RedisCartRepositoryLuaTest） |
| token 不存在 400 / 串号 401 | 通过（TC-005，CartApiTest） |
| 失效 SKU 应用层预校验 dropped | 通过（TC-006，CartApiTest#mergeDropsUnsalableSkus） |
| 公开 /api/mall/skus/items 仅返可售快照 | 通过（TC-008，mall-product 95/95） |
| 游客车行展示+缺失失效+三检 | 通过（TC-009、TC-012） |
| 合并编排：成功清空/truncated 提示/重取 token/失败保留 | 通过（TC-010，cart store performMerge） |
| AOF everysec 配置证据 | 通过（TC-012，docker-compose.infra.yml 摘录） |
| 后端自动化 | 通过：mall-cart 53/53、mall-product 95/95、package SUCCESS |
| 前端三检 | 通过：type-check/lint/build/test 全绿（85/85） |

证据索引：Story `evidence/evidence.yaml` EV-001~EV-005。

## 4. Deviations

- DEV-1：Lua 返回 JSON 手写 encodeArray()，因 Redis 7.4 cjson 不支持 encode_empty_table_as_object，空表会编成 {} 而非 []。返回结构与契约一致，无功能影响。
