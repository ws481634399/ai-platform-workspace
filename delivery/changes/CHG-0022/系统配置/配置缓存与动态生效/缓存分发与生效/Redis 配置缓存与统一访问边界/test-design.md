# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0022
- Story ID: STORY-006-02-01-01
- Feature Path: 系统配置 > 配置缓存与动态生效 > 缓存分发与生效 > Redis 配置缓存与统一访问边界
- 状态流转: designed → tasked
- TC 总数: 8

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 集成（testcontainers Redis）：首次 getFeature → 回源并写入 `aimall:{env}:system:feature:{key}`，TTL 断言 ≈600s；第二次读取 DB/HTTP 零回源（计数断言） | AC-001 | DU-BE-508 | [S1] |
| TC-002 | 集成：后台更新开关/参数提交后断言 Redis 单键与 public-features 聚合键被删除；再读得到新值且 TTL 重建 | AC-002 | DU-BE-508 | Integration Gate 场景七 |
| TC-003 | API：内部 features/parameters 端点无 SERVICE 令牌 401/403、经网关 404；只返回请求键；含不存在键 → missingKeys；keys>100 → 400 | AC-003 | DU-BE-508 | [S1] |
| TC-004 | 单测/集成：在消费服务测试中注入 FeatureGate/Provider，getString/getInt/getLong/getDecimal/getBoolean 正确；错误类型值 → default + WARN | AC-004 | DU-BE-508 | [S1] |
| TC-005 | 韧性：停 Redis 且 HTTP 端点 503 → 读取返回代码默认不抛、业务请求 200；ensureEnabled 缺键默认放行 WARN | AC-005 | DU-BE-508 | [S1] |
| TC-006 | 集成：本地短 TTL（测试覆盖置 60s 逻辑用可配置 TTL 注入 100ms）更新后消费端尽快拿到新值，最长不超过本地 TTL；负缓存（missing key 60s）生效 | AC-006 | DU-BE-508 | [S1] |
| TC-007 | 静态：mall-search/mall-cart pom 与源码无 mall_system 数据源/DAO/Mapper；仅依赖 mall-common-config | AC-007 | DU-BE-508 | 架构评审 grep |
| TC-008 | 构建门禁：mvn test（mall-system + common-config + 消费服务）全绿；AutoConfiguration.imports 生效的上下文加载测试 | AC-004, AC-007 | DU-BE-508 | [S1] |

## 2. 测试策略

- common-config 以单测为主：FakeRedis（接口层 mock）+ MockWebServer/ WireMock 模拟内部端点，验证三级读顺序、回填、TTL、负缓存与故障回退。
- mall-system 侧用 testcontainers Redis 验证真实 key 命名/TTL 与 AFTER_COMMIT 删键。
- 不引 Caffeine：静态检查 + Code Review 确认。

## 3. 不可测项标注

- 真实 60s TTL 等待以可注入 TTL 参数加速验证，逻辑等价（TC-NOT-TESTABLE: 真实墙钟 60s）。

## 4. 依赖与前置条件

- DU-BE-507 配置模型与端点数据；mall-common-redis 既有基线。
