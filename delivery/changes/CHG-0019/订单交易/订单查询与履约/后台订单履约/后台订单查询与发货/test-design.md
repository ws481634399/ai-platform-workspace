# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-03-02-01
- Feature Path: 订单交易 > 订单查询与履约 > 后台订单履约 > 后台订单查询与发货
- 状态流转: designed → tasked
- TC 总数: 10

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API（order:list）：orderNo/memberId/status/时间组合检索与分页排序正确；无归属过滤可跨会员 | AC-001 | DU-BE-905 | [S6] |
| TC-002 | API（order:view）：admin 详情含 memberId 与全字段、history 升序 | AC-002 | DU-BE-905 | [S6] |
| TC-003 | API（order:ship）：PAID → SHIPPED、物流两列、shippedAt、SHIP history(operator=username) | AC-003 | DU-BE-905 | [S6] |
| TC-004 | API：PENDING/CANCELLED/COMPLETED ship → B0407；重复 ship 幂等 200 且一条 SHIP；body 差异忽略 | AC-004 | DU-BE-905 | [S6] |
| TC-005 | API：deliveryCompany/trackingNo 缺失/空白/65 字 → 400；不存在订单 → 404 | AC-005 | DU-BE-905 | [S6] |
| TC-006 | 安全：无 order:ship 权限码 ADMIN JWT → 403；MEMBER JWT → 403；无 token 401 | AC-006 | DU-BE-905 | [S6] |
| TC-007 | 前端 vitest：搜索参数拼装、表格分页、详情时间线 | AC-007 | DU-FE-903 | [S6] |
| TC-008 | 前端 vitest：发货弹窗校验（必填/长度）、PAID 才显示按钮、v-permission 隐藏 | AC-007 | DU-FE-903 | [S6] |
| TC-009 | 前端：动态菜单按 order:* 权限码出现（mock 权限两种账号） | AC-007 | DU-FE-903 | [S6] |
| TC-010 | 前端质量：type-check/lint/unit/build 全绿 | AC-007 | DU-FE-903 | [S6] |

## 2. 测试策略

- 后端构造带不同权限码集合的 ADMIN JWT（M1 授权机制）测 403 矩阵；发货并发沿用 latch。
- 前端按既有 mall-admin 测试模式 mock 权限与 api。

## 3. 不可测项标注

- 菜单种子数据真实落库在 Integration Gate 用 admin 环境验证一次（dev evidence 记录迁移位置）。

## 4. 依赖与前置条件

- DU-BE-903/904；M1 RBAC 与 mall-admin 动态菜单机制。
