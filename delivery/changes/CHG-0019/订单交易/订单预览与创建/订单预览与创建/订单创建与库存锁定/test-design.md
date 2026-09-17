# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-01-01-02
- Feature Path: 订单交易 > 订单预览与创建 > 订单预览与创建 > 订单创建与库存锁定
- 状态流转: designed → tasked
- TC 总数: 15

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | Redis 集成：有效 token 创建成功后 GET token 已消费（GETDEL）；orders/order_item/history 落库字段完整（快照/金额分/orderNo 格式 ORD+17+4） | AC-005 | DU-BE-902 | [S2] |
| TC-002 | API：库存全 OK 时逐行 inventory lock 调用，reservationId=orderNo:skuId；Locked 行可查 | AC-005 | DU-BE-902 | [S2] |
| TC-003 | API：CART 创建成功后调 cart batch-delete 清购物车（mock 断言一次）；BUY_NOW 不调用；创建失败车不变 | AC-009 | DU-BE-902 | [S2] |
| TC-004 | API：body 单价/金额与服务端重算不符 → 以服务端值落库（篡改价格场景，Integration Gate 场景四） | AC-003 | DU-BE-902 | [S2] |
| TC-005 | API：无 token/伪造/已消费/过期/他人 token → B0406，无锁无单 | AC-001 | DU-BE-902 | [S2] 双层幂等第一层 |
| TC-006 | API：同 submitToken 并发重复提交（两线程）→ 唯一键仲裁返回同一 orderNo，仅一组 lock（场景五） | AC-001 | DU-BE-902 | [S2] 第二层 uk |
| TC-007 | API：请求 addressId/items/source 与令牌载荷不一致 → B0406，token 已消费 | AC-002 | DU-BE-902 | [S2] |
| TC-008 | API：地址非归属/删除 → 失败无锁；product 下架（preview 后变化）→ 失败无单 | AC-004 | DU-BE-902 | [S2] |
| TC-009 | API：available=1 quantity=2 → B0404 无订单库存不为负；第 2 行锁失败 → 第 1 行 release 一次、无悬挂 | AC-006, AC-007 | DU-BE-902 | [S2] 场景二 |
| TC-010 | API：全部 lock 成功后 repository 抛异常（mock）→ 全部 release 调用、无订单、ERROR 日志（场景十，补偿表下 Story 升级） | AC-008 | DU-BE-902 | [S2] |
| TC-011 | 单测：OrderNoGenerator 万次唯一；冲突重试 3 次逻辑 | AC-005 | DU-BE-902 | [S2] |
| TC-012 | 单测：Order.create 聚合（PENDING_PAYMENT/CREATE history/Money/ReceiverSnapshot） | AC-005 | DU-BE-902 | [S2] |
| TC-013 | 前端 vitest：checkout store 成功/失败/重复提交禁用；CART 成功清车跳转；BUY_NOW 跳转 | AC-011 | DU-FE-901 | [S2] |
| TC-014 | 前端组件：不可下单原因展示/地址未选禁用/失败提示；路由守卫未登录跳登录 | AC-011 | DU-FE-901 | [S2] |
| TC-015 | 网关：/api/mall/orders 路由到 8105、MEMBER 可访问、/api/internal 经网关不可达 | AC-010 | DU-BE-902 | [S2] |

## 2. 测试策略

- H2 + Flyway V1 真实三表；Redis Testcontainers 验 GETDEL；inventory/product/member/cart 端口 mock 并做调用次数/参数断言。
- 并发：CountDownLatch 两提交；唯一键冲突路径用正常提交后再提交（直接命中 DuplicateKey 分支）补一用例。
- 前端 vitest + Vue Test Utils；type-check/lint/build 全绿。

## 3. 不可测项标注

- 真实 MySQL 差异在 Integration Gate 阶段用本地 docker MySQL 冒烟（V1 脚本双兼容已审）。

## 4. 依赖与前置条件

- DU-BE-901；STORY-004-04-01-01 前锁后失败释放失败仅日志（TC-010 不要求补偿任务）。
