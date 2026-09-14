# Test Design（Change 级聚合）— CHG-0018 购物车

> 阶段：sdd-task 聚合产物（3 Story Change）；各 Story 明细见对应目录 test-design.md。

- Change ID: CHG-0018
- Feature Path: 商城前台/购物车
- 覆盖 Story: 核心操作 11、实时校验 9、游客合并 12，共 32 TC。

## 1. 测试用例

### S1 购物车核心操作（DU-BE-801）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S1-TC-001 | 加购写入；TTL≈7776000 | AC-001 |
| S1-TC-002 | 同 SKU 累加；加到 1000 拒保 999 | AC-002 |
| S1-TC-003 | 不可售/非法数量 400 车不变 | AC-003 |
| S1-TC-004 | 100 条目成功/101 → CART_ITEMS_LIMIT | AC-004 |
| S1-TC-005 | 改量/删除/批删幂等 | AC-005 |
| S1-TC-006 | 单选/全选跨会话一致 | AC-006 |
| S1-TC-007 | 401/body memberId 忽略/ADMIN 403 | AC-007 |
| S1-TC-008 | 无 inventory lock 调用路径审计 | AC-014 |
| S1-TC-009 | selected-items internal 凭证/返回 | AC-007 |
| S1-TC-010 | product sku/batch 双状态 ≤100/401 | AC-003 |
| S1-TC-011 | 每次写操作续 TTL | AC-001 |

### S2 购物车实时校验（DU-BE-802）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S2-TC-001 | GET 车读模型全字段整数分 | AC-008 |
| S2-TC-002 | 下架/禁用/缺失三状态 | AC-009 |
| S2-TC-003 | PRICE_CHANGED 最新价；请求 price 忽略 | AC-010 |
| S2-TC-004 | 库存 0/1/9/10 三态 | AC-011 |
| S2-TC-005 | product 全 UNKNOWN；inventory 仅库存 UNKNOWN | AC-012 |
| S2-TC-006 | selectedTotalFen/Count 口径 | AC-013 |
| S2-TC-007 | product/inventory 各一次无 N+1 | AC-008 |
| S2-TC-008 | 读校验不改写 Redis | AC-009 |
| S2-TC-009 | 无跨库 JDBC 仅 RestClient 审计 | AC-021 |

### S3 游客购物车与登录合并（DU-BE-803 / DU-FE-801）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S3-TC-001 | 游客本地车操作与上限提示（前端） | AC-015 |
| S3-TC-002 | 同 SKU 2+1=3；异 SKU 并入 | AC-016 |
| S3-TC-003 | 998+2 截断 999；超 100 dropped | AC-017 |
| S3-TC-004 | 失效游客条目 dropped(SKU_NOT_SALABLE) | AC-017 |
| S3-TC-005 | 重放 401 不累加；过期 400；伪造 401 | AC-018 |
| S3-TC-006 | 合并成功清本地不重复触发（前端） | AC-019 |
| S3-TC-007 | 合并失败保留可重试（前端） | AC-019 |
| S3-TC-008 | 购物车页双模全字段/合计/结算置灰（前端） | AC-020 |
| S3-TC-009 | 游客车 skus/items+availability 展示（前端） | AC-020 |
| S3-TC-010 | 公开 skus/items 仅 ON_SALE+ENABLED ≤100 | AC-015 |
| S3-TC-011 | mergeToken TTL=300；合并后车 TTL 90 天 | AC-018 |
| S3-TC-012 | AOF everysec 证据 + 前端三检（零 repo-4 diff） | AC-022 |

## 2. 测试策略

- Redis Testcontainer：Lua 原子行为（累加/上限/TTL/合并截断/dropped/幂等消费）；MockRestServiceServer 模拟 product/inventory（单次调用、5xx 降级）；Redis 前后 dump/TTL 比对证明只读。
- 前端 vitest（useGuestCart/合并编排/双模行）+ 三检；完整 E2E（游客车合并）留 test 阶段五场景。
- 明细见各 Story 级 test-design.md。
