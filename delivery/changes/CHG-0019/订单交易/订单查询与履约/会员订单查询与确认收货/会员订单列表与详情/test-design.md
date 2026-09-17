# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-03-01-01
- Feature Path: 订单交易 > 订单查询与履约 > 会员订单查询与确认收货 > 会员订单列表与详情
- 状态流转: designed → tasked
- TC 总数: 10

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API：造 15 单 → 默认 size 10 倒序分页、total/pages/边界页正确；size=101 → 400 | AC-001 | DU-BE-904 | [S4] |
| TC-002 | API：六 Tab 过滤正确（含"全部"不传）；非法 status 400；时间区间过滤正确；start>end 400 | AC-002 | DU-BE-904 | [S4] |
| TC-003 | API：详情全字段断言（items 快照/地址 7 字段/金额三项/物流/cancelReason/keyTimes/history 升序），无下游服务调用 | AC-003 | DU-BE-904 | [S4] |
| TC-004 | API：A 访问 B 订单详情与列表均不可见；猜 orderNo 详情 → 404；无 token 401；ADMIN JWT 403 | AC-004 | DU-BE-904 | [S4] 场景九 |
| TC-005 | 前端 vitest：tab↔枚举映射常量表、分页参数、空态、行点击跳转 | AC-005 | DU-FE-902 | [S4] |
| TC-006 | 前端 vitest：detail store 加载、金额 fen 格式化、history 时间线渲染、404 态 | AC-006 | DU-FE-902 | [S4] |
| TC-007 | 前端组件：待支付单支付/取消按钮操作后重查（mock api）；非待支付无按钮 | AC-006 | DU-FE-902 | [S4] |
| TC-008 | 前端：路由守卫未登录跳登录带 redirect | AC-005 | DU-FE-902 | [S4] |
| TC-009 | 前端质量：type-check/lint/unit test/build 全绿 | AC-007 | DU-FE-902 | [S4] |
| TC-010 | API：列表 SummaryView firstItem/itemCount 与订单快照一致 | AC-001 | DU-BE-904 | [S4] |

## 2. 测试策略

- H2 批量造单（直接 Mapper 写入覆盖各状态/时间）；归属矩阵用两个会员 JWT。
- 前端 vitest + msw/mock fetch；金额格式化复用全局过滤器测试。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-902/903；前端依赖 DU-FE-901 api 层。
