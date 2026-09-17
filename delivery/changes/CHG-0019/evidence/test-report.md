# Test Report — CHG-0019 M4 订单交易闭环（Integration Gate 十场景）

> 阶段：sdd-test 产物（Change 级集成验收）。

## 0. 元信息

- Change ID：CHG-0019
- 执行时间：2026-09-17
- 覆盖：M4 Integration Gate 场景一~场景十（`docs/需求/M4/M4.md` §M4 Integration Gate）
- 实施来源：repo-1 a06ed4c、repo-2 22ad40f

## 1. Integration Gate 十场景

| #   | 场景         | 验证内容                                                                                    | 执行方式                 | 结果   | 证据                                                      |
| --- | ------------ | ------------------------------------------------------------------------------------------- | ------------------------ | ------ | --------------------------------------------------------- |
| 一  | 完整成功交易 | 预览→下单→重复支付→后台发货→确认收货，库存 lock/confirm 各一次，快照/金额/history 完整      | MockMvc + Redis          | passed | OrderApiTest#fullHappyPath                                |
| 二  | 库存不足     | 二次核价发现库存为 0 → 409 B0404，不锁库存不建单                                            | MockMvc                  | passed | OrderApiTest#insufficientStockOnCreate                    |
| 三  | 价格变化     | 预览后商品调价，下单以服务端二次核价为准                                                    | MockMvc                  | passed | OrderApiTest#priceChangedBetweenPreviewAndCreate          |
| 四  | 前端篡改价格 | 下单行数量与令牌指纹不一致 → 400 B0406，金额无入口                                          | MockMvc                  | passed | OrderApiTest#tamperedFingerprintRejected                  |
| 五  | 重复提交订单 | 同一 submitToken 第二次消费 → 400 B0406，不产生第二单                                       | MockMvc + Redis DEL 原子 | passed | OrderApiTest#duplicateSubmitRejected                      |
| 六  | 支付重复     | PENDING 单重复 pay → 第二次 200 幂等，confirm 仅一次、库存只扣一次                          | MockMvc                  | passed | OrderApiTest#fullHappyPath（重复支付段）                  |
| 七  | 取消重复     | PENDING 单取消后重复取消幂等；PAID/SHIPPED/COMPLETED 取消 B0407                             | MockMvc                  | passed | OrderApiTest#cancelAndIdempotent / payCancelStateConflict |
| 八  | 支付取消竞争 | Pay‖Cancel 真并发：CAS 仲裁恰一方成功，终态与库存一致无撕裂                                 | 多线程 + JDBC 终态       | passed | OrderApiTest#payCancelConcurrentRace                      |
| 九  | 订单越权     | Member A 访问 Member B 的订单详情/支付/取消/收货统一 404；未认证 401；MEMBER 访问 admin 403 | MockMvc                  | passed | OrderApiTest#crossMemberAccess404 / authBoundaries        |
| 十  | 锁成功单失败 | 锁库存中途失败 → 已锁行立即 RELEASED；释放再失败登记补偿并可人工重试成功                    | MockMvc                  | passed | OrderApiTest#lockMidwayFailureReleasesAndCompensates      |

## 2. 测试执行汇总

| 模块           | 命令                                                                                                                                                                                                                                                               | 结果                                             |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------ |
| mall-order     | `mvn -pl mall-services/mall-order,mall-services/mall-inventory,mall-services/mall-member,mall-services/mall-cart,mall-gateway -am test`                                                                                                                            | **18/18**（含十场景），BUILD SUCCESS             |
| mall-inventory | 同上                                                                                                                                                                                                                                                               | **28/28**（含 InventoryReleaseConfirmCasTest 4） |
| mall-identity  | `mvn -pl mall-services/mall-identity test`（V8 迁移）                                                                                                                                                                                                              | **79/79**                                        |
| mall-web       | `pnpm test` / `pnpm build`                                                                                                                                                                                                                                         | **90/90**（19 files），build SUCCESS             |
| mall-admin     | `pnpm type-check` / `pnpm test` / `pnpm build`                                                                                                                                                                                                                     | type-check 0 error、**35/35**、build SUCCESS     |
| 日志           | `delivery/changes/CHG-0019/evidence/logs/backend-m4-test.log`、`backend-mall-identity-test.log`、`frontend-mall-web-test.log`、`frontend-mall-web-build.log`、`frontend-mall-admin-test.log`、`frontend-mall-admin-build.log`、`frontend-mall-admin-typecheck.log` | 完整输出                                         |

## 3. 结论

M4 Integration Gate 十场景全部通过；后端 5 模块 + identity 共 125 例 0 失败，前端 mall-web 90/90、mall-admin 35/35，构建全绿。
