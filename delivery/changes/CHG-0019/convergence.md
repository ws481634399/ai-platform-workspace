# Convergence — CHG-0019 M4 订单交易闭环

> 阶段：sdd-converge 产物

## 0. 元信息

- Change ID：CHG-0019
- 完成时间：2026-09-17
- standards-need-update：yes（订单交易集中状态机与 CAS 仲裁模式、submitToken 双层幂等模式）
- product-need-update：yes（Spec 晋升候选 1 篇，待人工评审）
- featuretree-need-update：yes（7 个 Story planned → delivered）
- glossary-need-update：no

## 1. 知识变化总结

本 Change 交付订单交易域全部 7 个 Story、10 个 DU（repo-1 六个：DU-BE-901~906 + 补建 907；repo-2 三个：DU-FE-901/902/903），确立两类可跨 Change 复用的规则：

1. **订单集中状态机 + CAS 仲裁模式（BE）**：`OrderStatus.evaluate(from, operation)` 输出 MUTATED/ALREADY_TARGET/ILLEGAL；
   所有写操作（pay/cancel/ship/confirm）统一走带 fromStatus 谓词的 UPDATE，rows=0 重读聚合并判幂等或冲突，
   杜绝状态撕裂；库存预留 LOCKED→DEDUCTED/RELEASED 用单条条件 UPDATE 同时完成状态与数量变更，重复请求幂等不重复增减。
   ——适用于后续所有有状态聚合（退款单、售后单等）。

2. **submitToken 双层幂等模式（BE）**：预览签发 Redis token（TTL 600s，载荷含 source/addressId/行指纹 SHA），
   下单时原子 DEL 单消费 + 行指纹比对（SKU 集合/quantity），同 token 仅 1 单；请求金额一律不采信，product 二次核价。
   ——适用于后续所有"先预览后下单"类交易（秒杀、拼团、优惠券核销）。

3. **补偿任务有界退避模式（BE）**：CompensationTask 唯一键 (business_type,business_id,operation) 防重复行，
   maxRetries=5 → FAILED_DEAD，指数退避 nextRetryAt，admin 手动 retry 重置执行；handler 对已处目标态资源直接判成功。
   ——适用于后续所有跨服务最终一致性补偿（支付回调、库存对账、优惠券回滚）。

## 2. 更新判断

### Standards 晋升

- 文件：`standards/engineering/backend/order-state-machine-and-cas.md`（新建，由 sdd-knowledge 创建）
- 内容：①集中状态机 evaluate 三态返回；②写操作 CAS UPDATE + rows=0 重读仲裁；③库存侧单条条件 UPDATE 合并状态与数量；④幂等路径不写 history、不触发副作用；⑤越权统一 404 不泄露存在性。
- 理由：订单状态机是交易域核心，后续退款/售后/支付回调均复用。

### Spec 晋升候选（人工评审后落 product/specs/）

- 文件：`product/specs/订单交易.md`（评审通过后创建）
- 内容（草稿，来源 7 个 story-spec AC 汇总）：
  - 订单状态五态：PENDING_PAYMENT/PAID/SHIPPED/COMPLETED/CANCELLED；非法迁移 409，幂等迁移 200。
  - 预览：CART 取服务端选中项、BUY_NOW 入参；金额服务端实时价；库存三态（0 缺货/1-9 紧张/≥10 现货）；可用签发 submitToken。
  - 建单：submitToken 单消费 + 行指纹；金额不采信；逐行锁库失败回滚释放；CART 成功清购物车。
  - 支付/取消：CAS 仲裁；pay→confirm 扣减、cancel→release 释放；库存副作用失败落补偿。
  - 确认收货：仅 SHIPPED 可确认，重复确认幂等。
  - 后台发货：仅 PAID 可发货，物流字段必填≤64，operator 记录。
  - 补偿：有界退避 5 次、FAILED_DEAD 人工介入、admin 手动重试。
  - 鉴权：会员越权 404、MEMBER 访问 admin 403、无权限 403。
- 理由：订单交易为商城核心闭环，后续退款/售后/营销需稳定产品依据。

### Feature Tree 更新

- 节点：STORY-004-01-01-01 / STORY-004-01-01-02 / STORY-004-02-01-01 / STORY-004-03-01-01 / STORY-004-03-01-02 / STORY-004-03-02-01 / STORY-004-04-01-01
- 操作：planned → delivered（7 节点）
- 方式：`openspec feature update <STORY-ID> --status delivered`

### Glossary 更新

无。订单五态/补偿任务为电商通用概念，已由 Feature Tree 与接口契约承载。

### No Update

- 各端点具体 JSON 字段：实现细节。
- 雪花 ID 与金额分：CHG-0002 已确立，本 Change 仅验证。

## 3. 知识沉淀过程

- 通读 7 Story 全部 Artifact（requirement/spec/design、7 套 story-spec/design/test-design、10 个 DU metadata、7 份 Story test-report/review-report）。
- 提取技术候选 3 组、业务规则候选 1 组。
- 检索既有 standards：CHG-0018 已立 Redis 存储与 Lua 原子写 → 本次补订单状态机 CAS 与 submitToken 幂等。
- Spec 候选只在本文件起草（§2），未直接写 product/specs/，等待人工评审。
- 无 Unresolved 问题；7 个 Story review-report 无开放 blocker/major。

## 4. 全局验收标准对照

| # | 场景 | 证据 | 结论 |
|---|------|------|------|
| 一 | 完整成功交易 | OrderApiTest#fullHappyPath | 通过 |
| 二 | 库存不足 | OrderApiTest#insufficientStockOnCreate | 通过 |
| 三 | 价格变化 | OrderApiTest#priceChangedBetweenPreviewAndCreate | 通过 |
| 四 | 前端篡改价格 | OrderApiTest#tamperedFingerprintRejected | 通过 |
| 五 | 重复提交订单 | OrderApiTest#duplicateSubmitRejected | 通过 |
| 六 | 支付重复 | fullHappyPath 重复支付段 | 通过 |
| 七 | 取消重复 | cancelAndIdempotent | 通过 |
| 八 | 支付取消竞争 | payCancelConcurrentRace | 通过 |
| 九 | 订单越权 | crossMemberAccess404 / authBoundaries | 通过 |
| 十 | 锁成功单失败 | lockMidwayFailureReleasesAndCompensates | 通过 |

## 5. 完成确认

- [x] 全部 7 Story Artifact 已读取
- [x] 知识分类完成（1 个 standards 文件新建、1 篇 Spec 晋升候选、7 节点 Feature Tree）
- [x] 10 个 DU 均 completed（含补建 DU-BE-907）
- [x] M4 Integration Gate 十场景全部通过
- [x] 无未解决 Conflict、Unresolved 问题或开放的 blocker/major
