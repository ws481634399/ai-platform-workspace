# Review Report（Change 级聚合）— CHG-0019 M4 订单交易闭环

> 各 Story 审查明细见对应 Story review-report.md。

## 0. 元信息

- Change ID：CHG-0019
- 审查时间：2026-09-17
- 审查者：trae-agent

## 1. 检查结论

**通过（PASS）。** 七个 Story 全部 review 通过，无遗留 blocker/major。

- Story 1：订单预览（只读、不锁库、submitToken 签发）
- Story 2：订单创建与库存锁定（双层幂等、二次核价、逐行锁库失败回滚）
- Story 3：模拟支付与订单取消（集中状态机 CAS + inventory 预留 CAS + 真并发）
- Story 4：会员订单列表与详情（强制归属、越权 404）
- Story 5：确认收货（SHIPPED→COMPLETED 幂等）
- Story 6：后台订单查询与发货（PAID→SHIPPED、order:* 权限、identity V8 菜单）
- Story 7：交易异常补偿（有界退避 5 次、唯一键幂等、人工重试）

## 2. 发现清单

| 编号 | 严重度 | 发现 | 处理 |
|------|--------|------|------|
| F-001 | minor | task 阶段遗漏后台发货 Story 后端 DU 物化（DU-BE-907） | dev 阶段按同构模板补建，代码无遗漏（见 Story 6 review DEV-1） |
| F-002 | minor | H2/MySQL 时间戳 NULL 与 NOT NULL 列兼容（reservation/compensation） | 统一在落 PO 时回填 Instant.now() |

无遗留 blocker / major。

## 3. 各 Story 审查引用

- Story 1：`订单交易/订单预览与创建/订单预览与创建/订单预览/review-report.md`
- Story 2：`订单交易/订单预览与创建/订单预览与创建/订单创建与库存锁定/review-report.md`
- Story 3：`订单交易/支付与取消/模拟支付与订单取消/模拟支付与订单取消/review-report.md`
- Story 4：`订单交易/订单查询与履约/会员订单查询与确认收货/会员订单列表与详情/review-report.md`
- Story 5：`订单交易/订单查询与履约/会员订单查询与确认收货/确认收货/review-report.md`
- Story 6：`订单交易/订单查询与履约/后台订单履约/后台订单查询与发货/review-report.md`
- Story 7：`订单交易/交易异常与补偿/交易补偿基础/交易异常补偿与幂等加固/review-report.md`

## 4. 全局 AC 确认

| 检查项 | 结论 |
|--------|------|
| M4 Integration Gate 十场景全部通过 | 通过（evidence/test-report.md §1） |
| 金额一律服务端核算，前端篡改无入口 | 通过（Gate-3/Gate-4） |
| 订单状态集中 CAS 仲裁，无撕裂 | 通过（Gate-6/Gate-7/Gate-8） |
| 越权统一 404 不泄露存在性 | 通过（Gate-9） |
| 锁库失败回滚释放 + 补偿兜底 | 通过（Gate-10） |
| 后端 125 例 0 失败；前端 125 例全绿 | 通过（evidence/test-report.md §2） |
| 7 Story 无开放 blocker/major | 通过 |
