# Implementation（跨仓实施汇总）— 游客购物车与登录合并 STORY-003-03-02-01

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文位于各实现仓 DU 目录。

## 0. 元信息

- Change ID：CHG-0018（购物车）
- Story：STORY-003-03-02-01 游客购物车与登录合并
- 实施日期：2026-09-16
- 范围边界：游客车 LocalStorage 持久化 + 登录后合并到会员车（merge-token 一次性 token +
  Lua 原子合并）；公开 SKU 条目批量查询供游客车行展示；购物车双模前端；AOF 配置验证留证。
  不含：结算计价（M4）；会员车写操作（STORY-003-03-01-01 已交付）；实时校验（STORY-003-03-01-02 已交付）。

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-803 | repo-1（ai-platform-backend） | 完成并验证：mall-cart 53/53（基线 41 + 新增 12：Lua 合并 7 + API 合并 5），mall-product 95/95，package 成功 |
| DU-FE-801 | repo-2（ai-platform-frontend） | 完成并验证：type-check/lint/build 三检通过，test 85/85 |

## 2. Commit 记录

未提交（待用户确认）。

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0018/商城前台/购物车/游客购物车与合并/游客购物车与登录合并/DU-BE-803/implementation.md`
  - 合并 token：`cart:merge:{token}` String，值=memberId，TTL 300s，一次性（Lua 内 DEL 消费）。
  - cart_merge.lua 单脚本原子：token GET 校验→DEL→逐条合并（同 SKU 相加，>999 截断，>100 dropped）→EXPIRE 90 天。
  - 应用层预校验：CartMergeService 先调 ProductSkuClient 批量校验可售性，失效项 dropped(SKU_NOT_SALABLE) 不入 Lua。
  - 错误码：TOKEN_MISSING→400（token 不存在/过期），TOKEN_MISMATCH→401（跨会员串号）。
  - 公开端点：POST /api/mall/skus/items 复用 SkuBatchApplicationService.batch()，filter salable=true，缺失项不返回。
  - DEV-1：Lua 返回 JSON 手写 encodeArray()，因 Redis 7.4 cjson 空表编为 {} 而非 []。

- repo-2：`implementation/ai-platform-frontend/delivery/CHG-0018/商城前台/购物车/游客购物车与合并/游客购物车与登录合并/DU-FE-801/implementation.md`
  - useGuestCart：LocalStorage key `mall-web:guest-cart`，999 件/100 条上限，90 天惰性清理。
  - cart store 双模：游客走本地、会员走 API；watch member.isAuthenticated 自动触发合并。
  - 合并编排：issueMergeToken→merge；400/401 重取 token 重试一次；网络失败保留游客车+mergePending。
  - CartView：游客行展示调 /api/mall/skus/items + /api/mall/skus/availability，缺失标失效；合计仅有效+选中+有货；去结算置灰 tooltip。
  - AOF 证据：docker-compose.infra.yml redis `--appendonly yes --appendfsync everysec`（repo-4 零改动）。

## 4. 与 Task / AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-015 | 游客详情加购进本地车，操作可用且有上限提示 | passed（useGuestCart add/updateQuantity 999/100 拦截；ProductDetailView addToCart 接线） |
| AC-016 | 登录合并同 SKU 相加/异 SKU 并入 | passed（cart_merge.lua 累加；RedisCartRepositoryLuaTest#mergeAccumulates；CartApiTest#mergeAccumulates） |
| AC-017 | truncated/dropped 有明确提示且本地清空 | passed（cart store handleMergeResult 汇总提示；guest.clear()） |
| AC-018 | 重放/过期场景前端能重取 token 完成或明确失败 | passed（400/401 重取 token 重试一次；CartApiTest#replayTokenReturns400/#forgedTokenReturns400AndMismatch401） |
| AC-019 | 合并成功清 LocalStorage、刷新不重复合并；失败保留可重试 | passed（mergedThisSession 防重复；mergePending 标记重试） |
| AC-020 | 购物车双模全字段/三态/合计可用；游客车行展示正确；去结算置灰 | passed（CartView 双模渲染；StockBadge 三态；去结算 disabled+tooltip） |
| AC-022 | infra redis AOF everysec 证据留档；前端三检通过 | passed（docker-compose.infra.yml 摘录；type-check/lint/build/test 全绿） |

## 5. 真实环境验证

单元测试与集成测试（Testcontainers Redis）已覆盖合并全场景；前端三检通过。端到端联调待 test 阶段执行。
