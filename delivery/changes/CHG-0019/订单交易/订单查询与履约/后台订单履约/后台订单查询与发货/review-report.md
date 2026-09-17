# Review Report — STORY-004-03-02-01 后台订单查询与发货

## 0. 元信息

- Change ID：CHG-0019
- Story ID：STORY-004-03-02-01
- 审查对象：DU-BE-907（repo-1 admin 订单/发货 + identity V8）+ DU-FE-903（repo-2 admin 订单管理）
- 审查时间：2026-09-17
- 审查者：trae-agent
- 测试报告来源：`evidence/test-report.md`（mall-order 18/18、mall-identity 79/79、mall-admin 35/35）

## 1. 检查结论

**通过（PASS）。** admin 订单多条件检索（orderNo/memberId/status/时间）+ 分页；发货 PAID→SHIPPED 经集中状态机 CAS，物流字段必填且 ≤64、写 delivery_company/tracking_no/shippedAt/history(SHIP,operator)；非法态 B0407、重复发货幂等、不存在 404。鉴权：ROLE_ADMIN 路径链 + order:list/view/ship/compensation 方法级权限码，无权限 403、MEMBER 访问 admin 403。identity V8 Flyway 幂等插入权限点与订单菜单（OrderList/CompensationList 组件 key），SUPER_ADMIN 同步授权。前端列表/详情/发货弹窗可用，菜单按权限动态装配。

## 2. 发现清单

| 编号 | 严重度 | 发现 | 处理 |
|------|--------|------|------|
| F-001 | minor | task 阶段遗漏后端 DU 物化，仅有前端 DU-FE-903 | 已补建 DU-BE-907（同构 metadata，完整 parent chain），代码无遗漏 |
| F-002 | minor | auth_permission UK(code) 单码，补偿台 GET 与 POST 需共用一码 | 已处理：http_method 置 NULL（任意方法匹配），V8 幂等 SQL |

无遗留 blocker / major。

## 3. 完成确认

| 检查项 | 结论 |
|--------|------|
| 多条件组合检索、分页排序 | 通过（TC-001） |
| 详情字段完整、history 可作轨迹 | 通过（TC-002） |
| PAID 发货 → SHIPPED/物流/shippedAt/history(SHIP,operator) | 通过（TC-003） |
| 非法态发货 B0407；重复发货幂等仅一条 SHIP | 通过（TC-004） |
| 物流字段缺失/超长 400；不存在 404 | 通过（TC-005） |
| 无 order:ship 权限 403；MEMBER 访问 admin 403 | 通过（TC-006 authBoundaries） |
| 列表/详情/发货弹窗可用、菜单按权限、四门全绿 | 通过（TC-007，mall-admin 35/35 build SUCCESS；V8 8/8 迁移 H2 验证） |

## 4. Deviations

- DEV-1：task 阶段未物化本 Story 后端 DU，dev 阶段补建 DU-BE-907（id 顺延，metadata 完整），不影响范围与测试。
