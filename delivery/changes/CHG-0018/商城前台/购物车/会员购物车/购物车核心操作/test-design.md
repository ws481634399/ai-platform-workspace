# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0018
- Story ID: STORY-003-03-01-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- Feature Path: 商城前台 > 购物车 > 会员购物车 > 购物车核心操作
- 状态流转: designed → tasked
- TC 总数: 11

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | Redis 集成：有效加购 → 条目写入；TTL 断言 ≈7776000s（90 天） | AC-001 | DU-BE-801 | Lua/add |
| TC-002 | Redis 集成：同 SKU 再购累加成一条（2+1=3）；加到 1000 → 400 且保持 999 | AC-002 | DU-BE-801 | 合并/上限 |
| TC-003 | API：下架商品/禁用 SKU/不存在 skuId（mock product batch）→ 400 SKU_NOT_SALABLE；数量 0/负/非整数/1000 → 400；车不变 | AC-003 | DU-BE-801 | |
| TC-004 | Redis 集成：连续加 100 个不同 SKU 成功；第 101 个 → 400 CART_ITEMS_LIMIT | AC-004 | DU-BE-801 | HLEN |
| TC-005 | API：PUT 合法数量成功/非法 400；DELETE 单条与批删成功；批删含不存在项幂等 200 | AC-005 | DU-BE-801 | |
| TC-006 | API：单选/取消/全选/取消全选；用同账号第二会话读车 selected 一致（服务端存储） | AC-006 | DU-BE-801 | 跨设备 |
| TC-007 | 安全：无 Token → 401；请求体塞 memberId 被忽略（A 操作不到 B）；ADMIN Token → 403 | AC-007 | DU-BE-801 | 归属 |
| TC-008 | 静态/依赖审计：mall-cart pom 与代码无 inventory lock 调用路径（仅 availability 在下一 Story 引入） | AC-014 | DU-BE-801 | 不锁库存 |
| TC-009 | 内部 API：GET /api/internal/carts/members/{id}/selected-items 无凭证 401、带凭证返选中条目 | AC-007 | DU-BE-801 | M4 预留 |
| TC-010 | product internal：POST /api/internal/products/skus/batch 返回双状态/价/图/规格；≤100；无凭证 401 | AC-003 | DU-BE-801 | 新契约 |
| TC-011 | Redis 集成：每次写操作（改量/删除/选择）后 TTL 均被续期 | AC-001 | DU-BE-801 | 滑动 TTL |

## 2. 测试策略

- Lua/Redis：Testcontainers redis:7.4 执行真实脚本（TTL/返回码矩阵）；空 key 与残留 key 两态。
- API：@SpringBootTest + MockMvc + mock ProductSkuClient；SecurityContext 切片。
- 依赖审计：grep + 模块依赖分析。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- CHG-0015/0016 前置 DU；Redis 容器。
