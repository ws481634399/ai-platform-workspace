# Test Design（Verification Intent — 验证意图）

> Story：STORY-001-03-02-02 — 注册安全动态路由
> 在开发前锁定测试意图；状态流转：designed → tasked

## 0. 元信息

- Change ID: CHG-0009
- Story ID: STORY-001-03-02-02
- Spec 来源: story-spec.md §3
- Design 来源: story-design.md §5–§6
- TC 总数: 3

## 1. 测试用例（验证意图，dev 开始前锁定）

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
|---|---|---|---|---|
| TC-001 | 组件/E2E 测试 | AC-001 | DU-FE-305 | 验证 已知 componentKey 生成并注册正确路由，页面可通过受控 path 访问。 |
| TC-002 | 组件/E2E 测试 | AC-002 | DU-FE-305 | 验证 未知 componentKey 不产生路由、不触发动态 import，并记录受控告警。 |
| TC-003 | 组件/E2E 测试 | AC-003 | DU-FE-305 | 验证 重复同步同一菜单不产生重复路由；clear 后所有动态路由被移除而静态路由保留。 |

## 2. 测试策略

- Unit：领域规则、状态转换、解析与拒绝分支；外部依赖使用可控 fake/mock。
- Integration/API：验证序列化、事务、持久化、过滤器/路由及 HTTP 状态码。
- Frontend：store、router、请求协调器用单元/组件测试；关键权限旅程用 E2E。
- Security：伪造、越权、重放、过期、未知值默认拒绝，断言日志不泄露敏感数据。

## 3. 不可测项标注

无；AC-001、AC-002、AC-003 均有自动化验证意图。

## 4. 依赖与前置条件

使用固定时钟、内存仓储或隔离测试数据库；跨 DU 时先完成后端契约用例，再执行前端消费与 E2E 用例。
