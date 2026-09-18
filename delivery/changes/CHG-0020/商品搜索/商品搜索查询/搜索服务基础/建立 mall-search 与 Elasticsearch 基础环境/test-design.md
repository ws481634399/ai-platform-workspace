# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0020
- Story ID: STORY-005-01-01-01
- Feature Path: 商品搜索 > 商品搜索查询 > 搜索服务基础 > 建立 mall-search 与 Elasticsearch 基础环境
- 状态流转: designed → tasked
- TC 总数: 6

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 手工/脚本：docker compose up elasticsearch → healthcheck healthy；curl _cluster/health yellow 可接受；down→up 后写入文档仍在；docker volume ls 含 ai-platform-es-data | AC-001 | DU-WS-501 | [S1] |
| TC-002 | 静态：mvn dependency:tree -pl mall-services/mall-search -Dincludes=co.elastic.clients:*,org.elasticsearch.client:* 断言存在 elasticsearch-java 且版本解析自 BOM；grep 全仓无 RestHighLevelClient；pom 未写死版本号 | AC-002 | DU-BE-501 | [S1] |
| TC-003 | 手工：ES 运行时启动 mall-search 日志含连通成功、/actuator/health components.search=UP；停 ES 后 health=DOWN 且进程存活（actuator 状态码按配置） | AC-003 | DU-BE-501 | [S1] |
| TC-004 | 配置：MALL_ES_URIS=http://127.0.0.1:19200 启动时 client 实际目标 URI 断言（Bean 属性/失败日志中的目标） | AC-004 | DU-BE-501 | [S1] |
| TC-005 | 集成（Testcontainers ES）：ElasticsearchSmokeIT 建临时索引→index 2 文档→search 命中 2 条，结束自动清理 | AC-005 | DU-BE-501 | [S1] |
| TC-006 | 启动：ContextLoadsTest 在无 ES 环境通过（client Bean 懒连接） | AC-003, AC-005 | DU-BE-501 | [S1] |

## 2. 测试策略

- 分层：静态依赖检查（Maven/grep）+ Testcontainers 集成（static 单例容器 AbstractElasticsearchIT）+ 手工 compose 验证（TC-001/003 进 test-report evidence/logs）。
- 数据准备：IT 使用随机前缀临时索引，不依赖共享数据；RYUK 禁用沿用工程既有 Testcontainers 配置。
- 环境要求：Docker 可用；mvn -pl mall-services/mall-search -am test 全绿。

## 3. 不可测项标注

- 无。

## 4. 依赖与前置条件

- Docker Engine 运行；MALL_ES_URIS 配置项；JDK21/Maven 工程基线。
