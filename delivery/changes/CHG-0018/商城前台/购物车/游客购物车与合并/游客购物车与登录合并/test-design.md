# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0018
- Story ID: STORY-003-03-02-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- Feature Path: 商城前台 > 购物车 > 游客购物车与合并 > 游客购物车与登录合并
- 状态流转: designed → tasked
- TC 总数: 12

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 前端：游客详情加购 → LocalStorage 条目；改量/删除/勾选可用；100/999 上限提示 | AC-015 | DU-FE-801 | useGuestCart |
| TC-002 | E2E/API：游客 2 件 + 会员 1 件同 SKU 登录合并 → quantity=3；不同 SKU 并入 | AC-016 | DU-BE-803 | 相加 |
| TC-003 | API：会员车该 SKU 已有 998 + 游客 2 → 截断 999 且 truncated 含 finalQuantity；100 条目外游客项 dropped | AC-017 | DU-BE-803 | 截断/dropped |
| TC-004 | API：失效游客条目（下架/禁用）→ dropped(reason=SKU_NOT_SALABLE)，其余正常合并 | AC-017 | DU-BE-803 | |
| TC-005 | API：同 mergeToken 连提两次 → 第二次 401 且车数量不二次累加；过期 token → 400 可重取；伪造 → 401 | AC-018 | DU-BE-803 | 单 Lua 幂等 |
| TC-006 | 前端：合并成功后 LocalStorage 清空；刷新页面不再触发合并（无 pending 标记） | AC-019 | DU-FE-801 | 清理 |
| TC-007 | 前端：合并失败（网络错）保留游客车，登录后可重试不丢失 | AC-019 | DU-FE-801 | 失败保留 |
| TC-008 | 前端：购物车页双模全字段/操作（图/名/规格/价/步进/三态/单选全选/删除/合计）；去结算置灰 tooltip | AC-020 | DU-FE-801 | 页面 |
| TC-009 | 前端：游客车行展示调 /api/mall/skus/items + availability；缺失条目标失效；三检通过 | AC-020 | DU-FE-801 | 游客读展示 |
| TC-010 | 公开 API：POST /api/mall/skus/items 仅返 ON_SALE+ENABLED 快照、≤100、匿名 200 | AC-015 | DU-BE-803 | 公开契约 |
| TC-011 | API：mergeToken TTL=300s（TTL 断言）；合并后会员车 EXPIRE 续 90 天 | AC-018 | DU-BE-803 | TTL |
| TC-012 | 配置核查：docker-compose.infra.yml redis 含 --appendonly --appendfsync everysec（证据摘录，无 repo-4 diff）；mall-web build/lint/type-check | AC-022 | DU-FE-801 | AOF 已就绪 |

## 2. 测试策略

- Lua/Redis：Testcontainers 执行 cart_merge.lua 全矩阵（相加/截断/dropped/token 三态/TTL）。
- API：mock product batch 控制失效条目；token 重放查车前后数量快照。
- Frontend：useGuestCart 单测（localStorage mock）；合并编排 store 测试（成功/失败/刷新）；CartView 双模组件测试；三检。
- 配置：test 阶段留 compose 摘录证据。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-801/802；CHG-0016 登录态；CHG-0017 详情页；Redis 容器。
