# Implementation（跨仓实施汇总）— 建立 mall-search 与 Elasticsearch 基础环境 STORY-005-01-01-01

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0020（Elasticsearch 商品搜索）
- Story：STORY-005-01-01-01 建立 mall-search 与 Elasticsearch 基础环境
- 实施日期：2026-09-18

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-WS-501 | repo-4（ai-platform-infrastructure） | compose ES 8.17.4 单节点/健康检查/命名卷/ES_PORT；冒烟由后端 Testcontainers 承载 |
| DU-BE-501 | repo-1（ai-platform-backend） | mall-search 骨架、官方 Java Client、配置与健康探针；ElasticsearchSmokeTest 1 例、MallSearchApplicationSmokeTest 1 例 |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 7f05e11 | DU-WS-501 | repo-4 | feat(infra): docker-compose.infra.yml 增加 elasticsearch 8.17.4 服务与 es-data 卷、ES_PORT |
| 82ccf6e | DU-BE-501 | repo-1 | feat(search): mall-search 服务骨架（官方 Java Client 8.18.8/8.17.4 对齐、配置、健康探针、Testcontainers 冒烟） |

## 3. 各仓实施引用

- repo-4（ai-platform-infrastructure）：
  - 实施记录：`implementation/ai-platform-infrastructure/delivery/CHG-0020/商品搜索/商品搜索查询/搜索服务基础/建立 mall-search 与 Elasticsearch 基础环境/DU-WS-501/implementation.md`
  - 要点：`deploy/docker-compose.infra.yml` 第 85–110 行 elasticsearch 服务（8.17.4、single-node、关 xpack.security/enrollment、512m 堆、healthcheck wait_for_status=yellow）；卷 es-data（外部名 ai-platform-es-data）；网络键 infra（外部名 ai-platform-network）；`.env.example` ES_PORT=9200。
- repo-1（ai-platform-backend）：
  - 实施记录：`implementation/ai-platform-backend/delivery/CHG-0020/商品搜索/商品搜索查询/搜索服务基础/建立 mall-search 与 Elasticsearch 基础环境/DU-BE-501/implementation.md`
  - 要点：mall-search 独立 Spring Boot 模块（端口 8107）；官方 co.elastic.clients（无 RHLC 依赖）；ElasticsearchConfiguration（uris/connectTimeout 2s/socketTimeout 5s）；SearchHealthIndicator（ping 失败 DOWN 不外抛）；application.yml 显式 management.health.elasticsearch.enabled=false + show-components always；MALL_ES_URIS 环境覆盖；Testcontainers 8.17.4 static 单例（AbstractElasticsearchTest）。

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | compose 服务 healthy 判定（wait_for_status=yellow）、es-data 命名卷持久化、重启数据保留；8.17.4 固定镜像 | passed（docker-compose.infra.yml 第 85–110/150–151 行；参数与设计差异见 DU-WS-501 DEV-1） |
| AC-002 | 仅官方 co.elastic.clients，无 RHLC 坐标；客户端随 Boot 3.5.15 BOM 解析 8.18.8，服务端/Testcontainers 固定 8.17.4（同主版本 8.x 兼容） | passed（DU-BE-501 DEV-1 版本事实记录） |
| AC-003 | 连通时 health UP；ES 停止时 SearchHealthIndicator 捕获异常置 DOWN，服务进程不退出 | passed（SearchHealthIndicator；management show-components always） |
| AC-004 | mall.elasticsearch.uris=${MALL_ES_URIS:http://localhost:9200} 环境覆盖 | passed（mall-search application.yml） |
| AC-005 | Testcontainers 真实 ES 冒烟：索引 2 文档并检索命中；Spring 上下文加载 | passed（ElasticsearchSmokeTest.indexTwoDocumentsAndSearchHits 1 例、MallSearchApplicationSmokeTest.contextLoads 1 例；surefire-reports 不存在，按源码 @Test 枚举） |
