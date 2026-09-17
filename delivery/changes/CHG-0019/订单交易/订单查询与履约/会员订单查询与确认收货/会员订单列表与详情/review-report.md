# Review Report — STORY-004-03-01-01 会员订单列表与详情

## 0. 元信息

- Change ID：CHG-0019
- Story ID：STORY-004-03-01-01
- 审查对象：DU-BE-904（repo-1 查询聚合）+ DU-FE-902（repo-2 订单中心）
- 审查时间：2026-09-17
- 审查者：trae-agent
- 测试报告来源：`evidence/test-report.md`（mall-order 18/18 + mall-web 90/90）

## 1. 检查结论

**通过（PASS）。** 会员订单分页强制 memberId 谓词、创建倒序、size 上限 100、status 五态与时间区间校验（非法 400）；详情聚合订单/商品行/收货/金额四件套/关键时间/升序 statusHistory；越权与不存在统一 404 不泄露存在性。前端列表 Tab/分页/空态、详情全字段 + 状态轨迹时间线 + 待付款操作入口。

## 2. 发现清单

| 编号 | 严重度 | 发现 | 处理 |
|------|--------|------|------|
| F-001 | minor | MyBatis-Plus 分页需独立 jsqlparser 依赖（3.5.9+ 拆分） | 已处理（a06ed4c）：mall-order pom 引入 mybatis-plus-jsqlparser |
| F-002 | info | 金额前端 fen→yuan 格式化集中在 utils/order.ts，无散落 parseFloat | 已确认（order.spec.ts fenToYuan 单测） |

无遗留 blocker / major。

## 3. 完成确认

| 检查项 | 结论 |
|--------|------|
| 创建倒序分页、total/pages、size≤100 | 通过（TC-001） |
| 状态五态筛选、非法 status 400、时间区间 start>end 400 | 通过（TC-002） |
| 仅本人订单；详情全字段 + history 升序 | 通过（TC-003） |
| 越权 404、未认证 401 | 通过（TC-004 crossMemberAccess404） |
| 列表 Tab/分页/空态/行摘要/金额格式 | 通过（TC-005） |
| 详情全信息 + 待付款操作后重查 | 通过（TC-006） |
| 前端四门全绿 | 通过（TC-007，90/90 build SUCCESS） |

## 4. Deviations

无实质偏离。
