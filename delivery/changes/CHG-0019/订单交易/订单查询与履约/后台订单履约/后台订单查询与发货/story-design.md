---
affected-repositories: [repo-2]
story-id: "STORY-004-03-02-01"
change-design-ref: "requirement-design.md#28-前端方案"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design §4.4/§2.8
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-03-02-01
- 状态流转: specified → designed
- 需要 Migration: no（菜单种子经既有 admin 机制，实施时确认迁移位置）
- 数据变更概要: orders.delivery_company/tracking_no/shipped_at V1 已建

## 1. 模块改动（Module Changes）

### repo-1 mall-order（DU-BE-905 发货/admin 部分）

- OrderRepository：pageForAdmin(AdminOrderPageQuery)（order_no 精确、member_id 精确、status、时间区间）；getDetailByOrderNo（无归属条件，admin 用）。
- application.order：OrderQueryService.listForAdmin/getForAdmin；ShipmentService.ship(orderNo, cmd, operator)：加载（404）→ Order.ship（PAID→SHIPPED + 物流快照值 + history；SHIPPED 幂等；其他 B0407）→ transitionStatus CAS（shipped_at；物流列随 CAS update 同更新）；rows=0 重读解释。
- interfaces.rest.admin.AdminOrderController：@PreAuthorize("hasAuthority('order:list')") 等方法级权限（JwtSubjectConverter 映射的 authority 命名按既有 admin 服务写法实施时核对）。
- DTO：ShipRequest（@NotBlank/@Size 1-64）；AdminOrderSummaryView（在会员 summary 上增 memberId）。

### repo-2 mall-admin（DU-FE-903）

- src/api/order.ts：adminList/get/ship 类型；stores/orderAdmin.ts。
- views/order/OrderListView.vue：搜索表单（orderNo、memberId、状态 select、时间范围 Element Plus 组件）、表格（orderNo/会员/状态/金额/创建时间/操作查看）、分页；OrderDetailView.vue：详情 + 状态时间线 + 发货弹窗（仅 PAID 显示发货按钮，受 v-permission order:ship 控制）。
- 路由/菜单：订单管理菜单（目录"订单管理"→"订单列表"，权限码 order:list/order:view/order:ship）；组件白名单注册按既有动态路由机制；种子数据经 admin 菜单库既有迁移/bootstrap（dev 实施确认，evidence 记录）。

## 2. 接口契约细化

| 方法 | 路径 | 权限 | 响应/错误 |
| --- | --- | --- | --- |
| GET | /api/admin/orders | order:list | 200 Page |
| GET | /api/admin/orders/{orderNo} | order:view | 200 Detail；404 |
| POST | /api/admin/orders/{orderNo}/ship | order:ship | 200 Detail；400/404/B0407 403 |

## 3. 数据变更

无 DDL。CAS 发货 SQL：`UPDATE orders SET status='SHIPPED', delivery_company=#{}, tracking_no=#{}, shipped_at=NOW(), version=version+1 WHERE id=#{} AND status='PAID' AND version=#{}`。

## 4. 错误处理

- 权限不足 403 由既有安全链返回；前端按钮隐藏 + 接口兜底。
- 并发重复发货：CAS rows=0 → 重读；SHIPPED 幂等 200；其余 B0407。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-907 | repo-1 | admin 订单多条件检索/详情 + PAID→SHIPPED 发货 + order:* 权限菜单 | AC-001~006 | 无 |
| DU-FE-903 | repo-2 | mall-admin 订单列表/详情/发货 + 菜单权限接入 | AC-007 | DU-BE-907 |

> 说明：task 阶段后端 DU 误标为复用 DU-BE-905，dev 阶段按本 Story 独立后端能力补建 DU-BE-907（物化于本 Story 目录），代码无遗漏。

## 6. 测试策略

- API 集成：多条件检索；发货成功/非法状态/重复幂等/字段校验；权限码 403（构造无权限 ADMIN JWT）；MEMBER 403。
- 前端 vitest：搜索表单查询参数拼装、发货弹窗校验、权限指令隐藏按钮、详情渲染。
