# Implementation（跨仓实施汇总）— 后台订单查询与发货 STORY-004-03-02-01

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0019（M4 订单交易闭环）
- Story：STORY-004-03-02-01 后台订单查询与发货
- 实施日期：2026-09-17

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-907 | repo-1 | admin 多条件检索/详情/发货 CAS、order:* 权限点与菜单（identity V8）、网关 admin 路由；OrderApiTest 17/17、mall-identity 79/79 |
| DU-FE-903 | repo-2 | mall-admin 订单列表/详情发货弹窗（补偿台随本 DU 同文件交付，见 STORY-004-04）；test 35/35、build 成功 |

> 说明：task 阶段遗漏了本 Story 的后端 DU 物化，dev 阶段按同构模板补建 DU-BE-907（metadata 含完整 parent chain），代码本身在同一 M4 提交内，无范围遗漏。

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| a06ed4c | DU-BE-907 | repo-1 | feat(order): admin 订单检索/发货 + identity V8 order:* 权限菜单 |
| 22ad40f | DU-FE-903 | repo-2 | feat(order): mall-admin 订单管理与补偿台 |

## 3. 各仓实施引用

- repo-1：
  - `AdminOrderController`：GET /api/admin/orders（orderNo/memberId/status/startAt/endAt + 分页）、GET /{orderNo}、POST /{orderNo}/ship；方法级 @PreAuthorize 权限码 order:list/order:view/order:ship
  - `ShipmentService.ship`：PAID→SHIPPED 集中状态机 CAS，写 delivery_company/tracking_no（必填、≤64，缺失/超长 400）、shippedAt、history(SHIP, operator=管理员账号)；重复发货幂等仅一条 SHIP 历史；非法态 B0407；订单不存在 404
  - 鉴权：ROLE_ADMIN 路径链 + 方法权限码；无权限管理员 403、MEMBER 访问 admin 403（OrderWebExceptionHandler 统一 AccessDenied → 403 业务包体）
  - mall-identity V8 Flyway：order:list/order:view/order:ship/order:compensation 四权限点、订单管理目录 + 订单列表/补偿任务两页面（component_key=OrderList/CompensationList）、SUPER_ADMIN 角色权限与菜单授权（幂等 SQL）
  - 网关：/api/admin/orders/** → 8105 ADMIN 鉴权链
- repo-2：
  - OrderListView：筛选卡（订单号/会员 ID/状态/下单日期范围）+ 表格 + 分页（默认 20）
  - OrderDetailView：el-descriptions 全字段 + 商品表 + 轨迹时间线；PAID 态「发货」按钮（v-if has('order:ship')）弹窗校验物流公司/运单号必填，成功 ElMessage 并刷新
  - component-registry 注册 OrderList/CompensationList；静态详情路由 /orders/detail/:orderNo（meta.permission=order:view）；菜单按后端权限动态装配

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | orderNo/memberId/status/时间组合检索、分页排序 | passed（orderListIsolationAndAdminFilter admin 段） |
| AC-002 | 详情字段完整、history 可作轨迹 | passed（fullHappyPath admin 详情断言） |
| AC-003 | PAID 发货 → SHIPPED/物流字段/shippedAt/history(SHIP,operator) | passed（fullHappyPath 发货段） |
| AC-004 | PENDING/CANCELLED/COMPLETED 发货 B0407；重复发货幂等仅一条 SHIP | passed（状态机 ILLEGAL/ALREADY_TARGET） |
| AC-005 | 物流字段缺失/超长 400；订单不存在 404 | passed（ShipRequest bean validation + 404 用例） |
| AC-006 | 无 order:ship 权限 403；MEMBER 访问 admin 403 | passed（authBoundaries：会员 JWT 打 /api/admin → 403） |
| AC-007 | 列表/详情/发货弹窗可用、菜单按权限出现、四门全绿 | passed（mall-admin 35/35、type-check/lint 0 error、build SUCCESS；V8 Flyway 8/8 迁移 H2 验证通过） |
