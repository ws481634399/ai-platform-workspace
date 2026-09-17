# Test Design（Change 级聚合）— CHG-0019 M4 订单交易闭环

> 阶段：sdd-task 聚合产物（7 Story Change）；各 Story 明细见对应目录 test-design.md。

- Change ID: CHG-0019
- Feature Path: 订单交易
- 覆盖 Story: 预览 10、建单锁库 11、支付取消 9、会员查询 7、确认收货 4、后台发货 7、补偿 7，共 55 TC；另含 Change 级 M4 Integration Gate 十场景。

## 1. 测试用例

### S1 订单预览（DU-BE-901）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S1-TC-001 | BUY_NOW 现货预览，服务端计价、签发 submitToken | AC-102 |
| S1-TC-002 | CART 以服务端选中项为准，忽略请求体 items | AC-101, AC-102 |
| S1-TC-003 | 下架/失效/无库存 → issueCodes、availableToSubmit=false、token=null | AC-103 |
| S1-TC-004 | 地址不存在/非本人 → 不可下单，不泄露归属 | AC-105 |
| S1-TC-005 | 库存三档 OUT 阻断 / LOW 可下单 / OK | AC-103 |
| S1-TC-006 | 数量 0/负/≥1000 400；条目 101 400 | AC-102 |
| S1-TC-007 | 金额来自 product 实时快照，请求无金额入口 | AC-104 |
| S1-TC-008 | submitToken TTL 600s、载荷 source/addressId/行指纹 | AC-106 |
| S1-TC-009 | 依赖故障 503 ORDER_DEPENDENCY_UNAVAILABLE | AC-103 |
| S1-TC-010 | 未认证 401；内部地址 401/404；网关 internal 404 | AC-128 |

### S2 订单创建与库存锁定（DU-BE-902 / DU-FE-901）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S2-TC-001 | 成功建单：PENDING_PAYMENT、快照、金额不变量、history(CREATE)、reservation LOCKED、orderNo | AC-108, AC-127 |
| S2-TC-002 | 预览后调价，下单按服务端二次核价 | AC-107 |
| S2-TC-003 | 令牌行指纹漂移 → 400 B0406 | AC-106 |
| S2-TC-004 | 同 submitToken 双提交 → 第二次 400 B0406，仅 1 单 | AC-106 |
| S2-TC-005 | 二次核价库存 0 → 409 B0404，不锁库不建单 | AC-109 |
| S2-TC-006 | 第 N 行锁失败 → 前 N-1 行 RELEASED，整体失败 | AC-109 |
| S2-TC-007 | 全锁后落库失败 → 同步 release | AC-123 |
| S2-TC-008 | CART 成功清购物车选中项；BUY_NOW 不清；失败车不变 | AC-110, AC-111 |
| S2-TC-009 | 网关 MEMBER 8080 可达、未认证 401、internal 404 | AC-128 |
| S2-TC-010 | 地址非本人/不存在失败且无锁定 | AC-105 |
| S2-TC-011 | CheckoutView 阻断/防双击/跳详情/双入口、前端四门 | AC-129 |

### S3 模拟支付与订单取消（DU-BE-903）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S3-TC-001 | PENDING pay → PAID/paidAt/history(PAY)，预留 DEDUCTED，total/locked 同减 | AC-112, AC-127 |
| S3-TC-002 | 重复 pay 200 幂等，confirm 仅一次、库存只扣一次 | AC-113 |
| S3-TC-003 | CANCELLED pay B0407；他人/不存在 404 | AC-114 |
| S3-TC-004 | PENDING cancel → CANCELLED/reason/history(CANCEL)，预留 RELEASED | AC-115 |
| S3-TC-005 | 重复 cancel 幂等；PAID/SHIPPED/COMPLETED cancel B0407 | AC-116 |
| S3-TC-006 | Pay‖Cancel 真并发：恰一方成功，终态与库存一致 | AC-117 |
| S3-TC-007 | inventory 重复 release/confirm 不重复变化、返回当前 status | AC-118 |
| S3-TC-008 | inventory 既有全量回归绿 + 新增 CAS 并发测试 | AC-118 |
| S3-TC-009 | 库存副作用异常订单不回滚，ERROR 含 orderNo/traceId | AC-126 |

### S4 会员订单列表与详情（DU-BE-904 / DU-FE-902）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S4-TC-001 | 创建倒序分页、total/pages、size≤100 | AC-119 |
| S4-TC-002 | 状态五态筛选、非法 status 400、start>end 400 | AC-119 |
| S4-TC-003 | 仅本人订单；详情全字段 + history 升序 | AC-119, AC-127 |
| S4-TC-004 | 越权 404、未认证 401 | AC-119 |
| S4-TC-005 | 列表 Tab/分页/空态/行摘要/金额格式 | AC-129 |
| S4-TC-006 | 详情全信息 + 待付款操作后重查 | AC-127, AC-129 |
| S4-TC-007 | 前端四门全绿 | AC-129, AC-130 |

### S5 确认收货（DU-BE-905）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S5-TC-001 | 本人 SHIPPED 确认 → COMPLETED/completedAt/history | AC-122, AC-127 |
| S5-TC-002 | 非 SHIPPED 确认 B0407；他人/不存在 404 | AC-122 |
| S5-TC-003 | COMPLETED 重复确认 200 幂等，无新 history、无库存调用 | AC-122 |
| S5-TC-004 | 前端仅 SHIPPED 显按钮、二次确认、成功刷新 | AC-129 |

### S6 后台订单查询与发货（DU-BE-907 / DU-FE-903）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S6-TC-001 | 多条件组合检索、分页排序 | AC-120 |
| S6-TC-002 | 详情字段完整、history 可作轨迹 | AC-120 |
| S6-TC-003 | PAID 发货 → SHIPPED/物流/shippedAt/history(SHIP,operator) | AC-121, AC-127 |
| S6-TC-004 | 非法态发货 B0407；重复发货幂等 | AC-121 |
| S6-TC-005 | 物流字段缺失/超长 400；不存在 404 | AC-121 |
| S6-TC-006 | 无 order:ship 权限 403；MEMBER 访问 admin 403 | AC-120 |
| S6-TC-007 | 列表/详情/发货弹窗可用、菜单按权限、四门全绿 | AC-129, AC-130 |

### S7 交易异常补偿与幂等加固（DU-BE-906）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S7-TC-001 | 锁成功落库失败：release 成功无任务；release 失败 → PENDING 重试至 SUCCESS | AC-123 |
| S7-TC-002 | 取消 release 首次失败 → 退避重试成功；支付 confirm 失败同构 | AC-124 |
| S7-TC-003 | 重复 pay/cancel 不重复库存副作用；handler 对目标态预留直接成功 | AC-118, AC-124 |
| S7-TC-004 | 超 5 次 → FAILED_DEAD；admin 列表可查；手动 retry 重置成功 | AC-125 |
| S7-TC-005 | 同单同操作并发不重复行（唯一键） | AC-123 |
| S7-TC-006 | 失败日志 orderNo+traceId，无 secret/token；迁移有 history | AC-126 |
| S7-TC-007 | 调度有界、单条异常不影响下一条、无无限重试 | AC-125 |

## 2. M4 Integration Gate（Change 级十场景）

见 `evidence/test-report.md` §1，对应 OrderApiTest 17 例 + InventoryReleaseConfirmCasTest 4 例，覆盖 AC-127（全链路 E2E）与红线 AC-128/AC-130。

## 3. 测试覆盖确认

- [x] 全部 30 个 Change 级 AC（AC-101~AC-130）均有 ≥1 个 TC verified-by
- [x] M4 Integration Gate 十场景在 OrderApiTest 中覆盖
- [x] 红线 AC-128（库存非负、无跨库直改、internal 404）通过审计
- [x] 前端 AC-129/测试 AC-130 通过
