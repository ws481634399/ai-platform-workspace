# Test Design（Verification Intent — 验证意图）

> Story：STORY-001-03-01-02 — 加载菜单与权限状态
> 在开发前锁定测试意图；状态流转：designed → tasked

## 0. 元信息

- Change ID: CHG-0009
- Story ID: STORY-001-03-01-02
- Spec 来源: story-spec.md §3
- Design 来源: story-design.md §5–§6
- TC 总数: 3

## 1. 测试用例（验证意图，dev 开始前锁定）

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
|---|---|---|---|---|
| TC-001 | Unit/集成测试 | AC-001 | DU-BE-302 | 验证 合法 bootstrap 响应被原子写入 store，Permission Codes 去重且 hasPermission 结果正确。 |
| TC-002 | 组件/E2E 测试 | AC-002 | DU-FE-302 | 验证 两个并发 bootstrap 调用只产生一个 HTTP 请求并共享同一结果。 |
| TC-003 | 组件/E2E 测试 | AC-003 | DU-FE-302 | 验证 响应包含非法菜单节点时不注册未知能力并进入受控错误/告警路径。 |

## 2. 测试策略

- Unit：领域规则、状态转换、解析与拒绝分支；外部依赖使用可控 fake/mock。
- Integration/API：验证序列化、事务、持久化、过滤器/路由及 HTTP 状态码。
- Frontend：store、router、请求协调器用单元/组件测试；关键权限旅程用 E2E。
- Security：伪造、越权、重放、过期、未知值默认拒绝，断言日志不泄露敏感数据。

## 3. 不可测项标注

无；AC-001、AC-002、AC-003 均有自动化验证意图。

## 4. 依赖与前置条件

使用固定时钟、内存仓储或隔离测试数据库；跨 DU 时先完成后端契约用例，再执行前端消费与 E2E 用例。
