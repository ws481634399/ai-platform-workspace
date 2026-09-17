# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-01-01-01
- Feature Path: 订单交易 > 订单预览与创建 > 订单预览与创建 > 订单预览
- 状态流转: designed → tasked
- TC 总数: 12

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API：CART preview（mock cart selected-items + product batch + availability）逐行返回快照价/库存；body 伪造 items 被忽略；断言无 inventory lock 调用、无订单写入 | AC-001 | DU-BE-901 | [S1] |
| TC-002 | API：BUY_NOW preview 只含传入行；quantity 0/-1/1.5/1000 → 400；101 行 → 400；source 缺失/非法 → 400 | AC-002 | DU-BE-901 | [S1] |
| TC-003 | API：product 返 salable=false 三态（下架/禁用/不存在占位）→ issueCodes 且 availableToSubmit=false | AC-003 | DU-BE-901 | [S1] |
| TC-004 | API：available 1 数量 2 → OUT_OF_STOCK；available 5 → LOW；available 20 → OK，金额与标志正确 | AC-004 | DU-BE-901 | [S1] |
| TC-005 | API：product 单价返回 12000（120.00）→ 小计/总额按 12000 计算；响应无前端价格入参依赖 | AC-005 | DU-BE-901 | [S1] 改价场景 |
| TC-006 | API：addressId 非归属（member 端点 404）/为空 → 不可下单；有效地址返回完整字段 | AC-006 | DU-BE-901 | [S1] |
| TC-007 | Redis 集成：可下单 preview 后 GET token 存在、TTL≈600s、载荷含 source/addressId/fingerprint；不可下单 token=null | AC-007 | DU-BE-901 | [S1] |
| TC-008 | API：product/inventory/cart/member mock 分别抛连接异常/5xx → 503 ORDER_DEPENDENCY_UNAVAILABLE | AC-008 | DU-BE-901 | [S1] |
| TC-009 | 安全：无 token 401；ADMIN JWT 调会员接口 403；member 内部地址端点无 X-Internal-Token 401/有 token 非归属 404 | AC-009 | DU-BE-901 | [S1] |
| TC-010 | 单测：Money 不变量（pay=goods-discount+freight、负数非法） | AC-010 | DU-BE-901 | [S1] |
| TC-011 | 单测：PreviewAssembler 矩阵（全 OK/缺货/下架/空车/地址无效）金额合计与 availableToSubmit | AC-001,003,004 | DU-BE-901 | [S1] |
| TC-012 | 启动：@SpringBootTest smoke（H2 + 安全链 + Flyway 目录）上下文加载成功 | AC-010 | DU-BE-901 | [S1] |

## 2. 测试策略

- 单测覆盖 assembler/Money；API 用 MockMvc + 端口 mock（MockRestServiceServer 或 Mockito bean）；Redis token 用 Testcontainers；安全链复用进程内 RSA JWT support。
- 断言锁库存零调用：InventoryPort mock 验证 lock 无交互（本 Story 端口虽声明 lock 方法，preview 不得调用）。

## 3. 不可测项标注

- 结算页前端在 DU-FE-901（STORY-004-01-01-02）交付，本 Story 不做浏览器验证。

## 4. 依赖与前置条件

- CHG-0015/0016/0017/0018 契约；H2 MODE=MySQL；Testcontainers Redis（RYUK disabled）。
