# Review Report — STORY-004-01-01-02 订单创建与库存锁定

## 0. 元信息

- Change ID：CHG-0019
- Story ID：STORY-004-01-01-02
- 审查对象：DU-BE-902（repo-1 建单锁库）+ DU-FE-901（repo-2 结算页）
- 审查时间：2026-09-17
- 审查者：trae-agent
- 测试报告来源：`evidence/test-report.md`（mall-order 18/18 + mall-web 90/90）

## 1. 检查结论

**通过（PASS）。** 建单链路：submitToken 单消费（Redis 原子 DEL）+ 行指纹比对 + product 二次核价（金额一律不采信请求）+ 地址归属再校验 + 逐行 inventory 锁定（任一行失败立即同步释放已锁行，释放再失败登记补偿）+ 订单/商品/地址快照落库 + CART 成功清购物车。雪花 orderNo 不暴露主键。前端 CheckoutView：issueCodes 阻断、地址选择、提交防双击、成功跳详情、双入口可达。

## 2. 发现清单

| 编号 | 严重度 | 发现 | 处理 |
|------|--------|------|------|
| F-001 | major | OrderItem 构造期 orderNo 为 null，order_item.order_no NOT NULL 导致建单 500 | 已修复（a06ed4c）：buildItems(orderNo, ...) 在重试循环内生成 orderNo 后透传构造 OrderItem |
| F-002 | minor | 网关 internal 路由收口 | 沿用 cart 模式 /api/internal/** denyAll → 404，不暴露存在性 |

无遗留 blocker / major。

## 3. 完成确认

| 检查项 | 结论 |
|--------|------|
| submitToken 缺失/伪造/复用/漂移 → B0406，同 token 仅 1 单 | 通过（TC-003/TC-004，Redis DEL 原子消费） |
| 请求金额全部忽略，服务端重算 | 通过（TC-002 priceChangedBetweenPreviewAndCreate） |
| 地址非本人/不存在失败且无锁定 | 通过（TC-001 + 二次校验） |
| 成功：PENDING_PAYMENT、快照、金额不变量、history(CREATE)、reservation LOCKED、orderNo | 通过（TC-001 fullHappyPath） |
| 库存不足 409 B0404，无订单/无负库存/无悬挂 | 通过（TC-005 insufficientStockOnCreate） |
| 第 N 行锁失败 → 前 N-1 行 RELEASED，整体失败无订单 | 通过（TC-006） |
| 全锁后落库失败 → 同步 release | 通过（TC-006） |
| CART 成功清购物车选中项；BUY_NOW 不清；失败车不变 | 通过（TC-007 cartSourceClearsPurchasedItems） |
| 网关 MEMBER 8080 可达、未认证 401、internal 404 | 通过（TC-008） |
| 结算页阻断/防双击/跳详情/双入口、前端四门全绿 | 通过（TC-009，mall-web 90/90 build SUCCESS） |

## 4. Deviations

无实质偏离。
