# Test Design（Verification Intent — 验证意图）

## 0. 元信息

- Change：CHG-0014
- Story：STORY-002-02-01-01

## 1. 测试用例

| TC | 验证方式 | 覆盖 AC | DU |
|---|---|---|---|
| TC-001 | POST 合法 Product+SKU 后校验 Product/SKU/图片/属性 | AC-001 | DU-BE-401 |
| TC-002 | 无 SKU 或 SKU 非法创建失败且无 Product 残留 | AC-002 | DU-BE-401 |
| TC-003 | 商品表单组装/回显 images 与 attributes | AC-003 | DU-FE-402 |
| TC-004 | 新建前可添加多 SKU，payload 包含规格/价格/图片 | AC-004 | DU-FE-402 |
| TC-005 | 匿名经网关请求 mall product 不被拦截且不 404 | AC-005 | DU-BE-401 |
| TC-006 | 已认证请求经网关转发 internal product | AC-006 | DU-BE-401 |
| TC-007 | anonymous/ADMIN 调用 inventory internal 失败，SERVICE 通过 | AC-007 | DU-BE-401 |
| TC-008 | login 401 不触发 refresh，其他 API 401 仍单次刷新 | AC-008 | DU-FE-402 |
| TC-009 | mall-admin test/type-check/lint/build | AC-009 | DU-FE-402 |

## 2. 测试策略

- 先为 TC-001～008 写失败测试，再以最小实现使其通过。
- 事务回滚优先用 Spring/H2 集成测试；权限使用 Security 测试上下文。
- 前端组件测试不依赖真实后端，最终浏览器联调只读检查列表/表单与 API 状态。

## 3. 不可测项标注

- 无。M3 mall-web 页面不在本次 Scope，不列为不可测项。

## 4. 依赖与前置条件

- MySQL/Redis/JWT 本地环境仅用于最终联调；自动化测试使用 H2/Mock。
- 先完成 DU-BE-401 契约，再执行 DU-FE-402。

