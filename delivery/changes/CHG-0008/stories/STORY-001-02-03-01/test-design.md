# Test Design（Verification Intent — 验证意图）

> Story：STORY-001-02-03-01 — 执行后端 API 权限校验
> 在开发前锁定测试意图；状态流转：designed → tasked

## 0. 元信息

- Change ID: CHG-0008
- Story ID: STORY-001-02-03-01
- Spec 来源: story-spec.md §3
- Design 来源: story-design.md §5–§6
- TC 总数: 3

## 1. 测试用例（验证意图，dev 开始前锁定）

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
|---|---|---|---|---|
| TC-001 | Unit/集成测试 | AC-001 | DU-BE-207 | 验证 具备指定 authority 的 ADMIN 调用受保护 API 时请求通过。 |
| TC-002 | API/安全边界测试 | AC-002 | DU-BE-207 | 验证 已认证但缺少 authority 的 ADMIN 直接调用同一 API 时返回 403，业务方法未执行。 |
| TC-003 | API/安全边界测试 | AC-003 | DU-BE-207 | 验证 未认证请求返回 401，未知 Permission Code 或禁用权限不会获得默认放行。 |

## 2. 测试策略

- Unit：领域规则、状态转换、解析与拒绝分支；外部依赖使用可控 fake/mock。
- Integration/API：验证序列化、事务、持久化、过滤器/路由及 HTTP 状态码。
- Frontend：store、router、请求协调器用单元/组件测试；关键权限旅程用 E2E。
- Security：伪造、越权、重放、过期、未知值默认拒绝，断言日志不泄露敏感数据。

## 3. 不可测项标注

无；AC-001、AC-002、AC-003 均有自动化验证意图。

## 4. 依赖与前置条件

使用固定时钟、内存仓储或隔离测试数据库；跨 DU 时先完成后端契约用例，再执行前端消费与 E2E 用例。
