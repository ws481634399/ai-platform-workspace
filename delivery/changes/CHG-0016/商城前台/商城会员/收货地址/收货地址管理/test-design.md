# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0016
- Story ID: STORY-003-01-03-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- Feature Path: 商城前台 > 商城会员 > 收货地址 > 收货地址管理
- 状态流转: designed → tasked
- TC 总数: 11

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API：新增合法地址 → 201；会员首条地址 isDefault=true | AC-019 | DU-BE-604 | |
| TC-002 | API：列表仅本人地址，is_default DESC, updated_at DESC | AC-020 | DU-BE-604 | |
| TC-003 | API：PUT 自己地址成功；A 会员改 B 的 addressId → 404 且 B 数据不变 | AC-021 | DU-BE-604 | 归属 |
| TC-004 | API：DELETE 他人地址 → 404；自己地址 → 204 | AC-021 | DU-BE-604 | |
| TC-005 | API：setDefault 后 SQL 断言该会员全表仅一条 is_default=1，旧默认复位 | AC-022 | DU-BE-604 | 生成列唯一 |
| TC-006 | 并发：两请求同时把不同地址设默认 → 其一 409，最终仍仅一个默认 | AC-022 | DU-BE-604 | uk 兜底 |
| TC-007 | API：删除默认地址 → 200；getDefault 返回 {item:null} | AC-023 | DU-BE-604 | |
| TC-008 | API 参数化：手机号非法、必填缺失、detail 超长、postalCode 非 6 位 → 400 | AC-024 | DU-BE-604 | |
| TC-009 | API：已有 20 条后第 21 条 → 409 ADDRESS_LIMIT | AC-024 | DU-BE-604 | 上限 |
| TC-010 | 迁移测试：V2 建表 + default_member_flag 生成列与 uk 存在 | AC-024 | DU-BE-604 | DDL |
| TC-011 | 前端组件：地址列表/新增/编辑/删除/设默认全流程与错误提示；三检通过 | AC-025 | DU-FE-603 | |

## 2. 测试策略

- Unit：地址工厂字段校验。
- Integration：双会员 fixture 越权矩阵；并发用 CountDownLatch/Executor；默认唯一直接查库断言。
- Frontend：vitest 组件 + vue-tsc/eslint/build。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-602（MEMBER 鉴权）、DU-FE-601（mall-web 登录态）。
