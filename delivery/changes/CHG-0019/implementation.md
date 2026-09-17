# Implementation（跨仓实施汇总）— CHG-0019 M4 订单交易闭环

> 阶段：sdd-dev 产物。本文件为 Change 级跨 Story 汇总，各 Story 实施正文见对应 Story 目录。

## 0. 元信息

- Change ID：CHG-0019（M4 订单交易闭环）
- 实施日期：2026-09-17
- 范围：订单预览/创建锁库存（REQ-M4-001）、支付取消 CAS（REQ-M4-002）、会员查询/确认收货/后台发货（REQ-M4-003）、交易补偿任务有界重试（REQ-M4-004）

## 1. Story 实施总览

| Story | DU | 仓库 | 状态 |
| --- | --- | --- | --- |
| STORY-004-01-01-01 订单预览 | DU-BE-901 | repo-1 | completed |
| STORY-004-01-01-02 订单创建与库存锁定 | DU-BE-902 / DU-FE-901 | repo-1 / repo-2 | completed |
| STORY-004-02-01-01 模拟支付与订单取消 | DU-BE-903 | repo-1 | completed |
| STORY-004-03-01-01 会员订单列表与详情 | DU-BE-904 / DU-FE-902 | repo-1 / repo-2 | completed |
| STORY-004-03-01-02 确认收货 | DU-BE-905 | repo-1 | completed |
| STORY-004-03-02-01 后台订单查询与发货 | DU-BE-907 / DU-FE-903 | repo-1 / repo-2 | completed |
| STORY-004-04-01-01 交易异常补偿与幂等加固 | DU-BE-906 | repo-1 | completed |

## 2. Commit 记录

| Commit | 仓库 | 说明 |
| --- | --- | --- |
| a06ed4c | repo-1 | feat(order): M4 订单交易闭环（mall-order 新模块/状态机 CAS/补偿任务 + inventory 预留 CAS + member 内部地址 + cart 选中项端点 + 网关路由 + identity V8 权限菜单） |
| 22ad40f | repo-2 | feat(order): M4 前台结算/订单中心 + 后台订单履约/补偿台 |

## 3. 各 Story 实施引用

- 订单预览：`订单交易/订单预览与创建/订单预览与创建/订单预览/implementation.md`
- 订单创建与库存锁定：`订单交易/订单预览与创建/订单预览与创建/订单创建与库存锁定/implementation.md`
- 模拟支付与订单取消：`订单交易/支付与取消/模拟支付与订单取消/模拟支付与订单取消/implementation.md`
- 会员订单列表与详情：`订单交易/订单查询与履约/会员订单查询与确认收货/会员订单列表与详情/implementation.md`
- 确认收货：`订单交易/订单查询与履约/会员订单查询与确认收货/确认收货/implementation.md`
- 后台订单查询与发货：`订单交易/订单查询与履约/后台订单履约/后台订单查询与发货/implementation.md`
- 交易异常补偿与幂等加固：`订单交易/交易异常与补偿/交易补偿基础/交易异常补偿与幂等加固/implementation.md`

## 4. 关键技术决策

1. **集中状态机 + CAS 仲裁**：`OrderStatus.evaluate(from, operation)` 输出 MUTATED/ALREADY_TARGET/ILLEGAL；pay/cancel/ship/confirm 统一走带 fromStatus 谓词的 UPDATE，rows=0 重读判幂等或冲突，杜绝撕裂。
2. **submitToken 双层幂等**：Redis 原子 DEL 单消费 + 行指纹（source/addressId/skuId 集合/quantity）比对，同 token 仅 1 单；请求金额一律不采信，product 二次核价。
3. **库存预留状态 CAS**：mall-inventory 用单条条件 UPDATE 同时完成 reservation LOCKED→DEDUCTED/RELEASED 与 stock total/locked 数量变更；重复请求对已处终态预留直接幂等返回，不重复增减。
4. **补偿任务有界退避**：CompensationTask 唯一键 (business_type,business_id,operation) 防重复行，maxRetries=5 → FAILED_DEAD，指数退避 nextRetryAt，admin 手动 retry 重置执行。
5. **越权统一 404**：订单详情/支付/取消/收货均强制 memberId 归属校验，不匹配与不存在统一 B0401 404，不泄露单号存在性。
6. **权限模型**：identity V8 Flyway 幂等插入 order:list/view/ship/compensation 四码 + 订单管理目录与页面菜单（component_key=OrderList/CompensationList），SUPER_ADMIN 同步授权。
