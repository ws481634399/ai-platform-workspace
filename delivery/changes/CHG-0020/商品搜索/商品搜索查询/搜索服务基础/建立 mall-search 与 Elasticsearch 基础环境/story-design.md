---
affected-repositories: [repo-4, repo-1]
story-id: "STORY-005-01-01-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §2.0/§2.1/§3
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0020
- Story ID: STORY-005-01-01-01
- 状态流转: specified → designed
- 相关仓库: repo-4（ai-platform-infrastructure）、repo-1（ai-platform-backend）
- 需要 Migration: no
- 数据变更概要: 无数据库变更；新增 ES 容器与命名卷

## 1. 模块改动（Module Changes）

### repo-4（DU-WS-501）

- `deploy/docker-compose.infra.yml` 新增服务 elasticsearch：
  - image `docker.elastic.co/elasticsearch/elasticsearch:8.17.4`；container_name ai-platform-elasticsearch；
  - environment：discovery.type=single-node、xpack.security.enabled=false、ES_JAVA_OPTS="-Xms512m -Xmx512m"、cluster.name=ai-platform；
  - ulimits memlock soft=-1 hard=-1；ports "${ES_PORT:-9200}:9200"；
  - healthcheck：`curl -fs http://localhost:9200/_cluster/health?wait_for_status=yellow&timeout=10s`，interval 10s/timeout 5s/retries 12；
  - volumes ai-platform-es-data:/usr/share/elasticsearch/data；networks ai-platform；
- 顶层 volumes 增 ai-platform-es-data；`.env.example` 增 ES_PORT=9200。

### repo-1 mall-search（DU-BE-501）

- pom.xml 增依赖（不写版本）：co.elastic.clients:elasticsearch-java、org.elasticsearch.client:elasticsearch-rest-client、jakarta.json:jakarta.json-api（+ eclipse parsson 实现运行时，由 BOM/显式补齐 dev 验证）。
- application.yml：`mall.elasticsearch.uris=${MALL_ES_URIS:http://localhost:9200}`、connect-timeout=2s、socket-timeout=5s、`mall.search.index-alias=mall_products`。
- infrastructure.elasticsearch.ElasticsearchConfiguration：RestClientBuilder（超时）+ ElasticsearchTransport(JacksonJsonpMapper) + ElasticsearchClient Bean。
- infrastructure.health.ElasticsearchHealthIndicator implements HealthIndicator：client.ping()，异常 DOWN（含异常 message），不抛出。
- src/test：AbstractElasticsearchIT（Testcontainers ElasticsearchContainer 8.17.4 withSecurityDisabled，static 单例容器）；ElasticsearchSmokeIT（建临时索引→index 2 文档→search 命中）；保留 ContextLoadsTest（无 ES 也能加载：client Bean 不发起连接）。

## 2. 接口契约细化

| 方法 | 路径 | 身份 | 说明 |
| --- | --- | --- | --- |
| GET | /actuator/health | 内网 | components.search=UP/DOWN（ping） |
| TCP | 9200 | 内网 | ES 单节点；MALL_ES_URIS 可覆盖 |

## 3. 数据变更

无。ES 数据卷 ai-platform-es-data 首次创建；本 Story 不建业务索引（测试临时索引随容器销毁）。

## 4. 错误处理

- ping 异常 → Health DOWN，不阻断应用；健康检查端点 503 由 actuator 自身策略返回。
- Client Bean 构造不连接 ES，保证离线启动与上下文测试。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-WS-501 | repo-4 | compose Elasticsearch 8.17.4 单节点/健康检查/命名卷/.env | AC-001, AC-004 | — |
| DU-BE-501 | repo-1 | ES 官方 Client 接入/配置/健康指标/Testcontainers 基类与冒烟（含后续 Story 02 的异常归一模块位） | AC-002, AC-003, AC-005 | DU-WS-501 |

## 6. 测试策略

- 手工/脚本：compose up -d elasticsearch 后 curl _cluster/health；down/up 数据保留验证。
- 集成：ElasticsearchSmokeIT（Testcontainers）建临时索引写读；ContextLoadsTest 无容器通过。
- 依赖检查：mvn dependency:tree -pl mall-services/mall-search 确认版本由 Boot BOM 管理、无 RestHighLevelClient。
