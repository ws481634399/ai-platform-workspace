# Test Report — STORY-005-01-01-01 建立 mall-search 与 Elasticsearch 基础环境

> 阶段：sdd-test 产物（Story 级）。

## 0. 元信息

- Change ID：CHG-0020（M5 商品搜索）
- Story ID：STORY-005-01-01-01
- 执行时间：2026-09-19
- 覆盖 AC 范围：AC-001 ~ AC-005（逐条见 §3）
- 覆盖 TC 范围：TC-001 ~ TC-006（逐条对齐本 Story `test-design.md` §1）
- 实施来源：
  - DU-WS-501（repo-4 ai-platform-infrastructure）：commit `7f05e11`
  - DU-BE-501（repo-1 ai-platform-backend）：commit `82ccf6e`

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| TC-001 | docker compose up elasticsearch 后 healthcheck healthy；`_cluster/health` yellow 单节点可接受；down/up 后文档仍在；命名卷 ai-platform-es-data 存在 | 手工/脚本 + 配置静态核对（无自动化 @Test） | passed（手工/静态） | `deploy/docker-compose.infra.yml` elasticsearch 服务与 es-data 卷（8.17.4、healthcheck wait_for_status=yellow，commit 7f05e11）；本 Story `implementation.md` §4 AC-001 |
| TC-002 | mall-search 引入官方 elasticsearch-java（版本解析自 BOM、pom 不写死版本）；工程内无 RestHighLevelClient | 静态依赖检查（无自动化 @Test） | passed（静态） | mall-search `pom.xml`（co.elastic.clients 坐标无版本号）+ mall-bom/Spring Boot 3.5.15 BOM 解析，commit 82ccf6e；本 Story `implementation.md` §4 AC-002 |
| TC-003 | ES 运行时 mall-search 连通成功、/actuator/health components.search=UP；停 ES 后 health=DOWN 且进程存活 | 手工启停验证 + 自动化上下文冒烟 | passed（手工 + 自动化） | `MallSearchApplicationSmokeTest#contextLoads`（无 ES 环境上下文可加载，client Bean 懒连接）；SearchHealthIndicator 配置物核对（ping 异常置 DOWN 不外抛） |
| TC-004 | `MALL_ES_URIS` 环境变量可覆盖 ES 目标地址 | 配置静态核对（无自动化 @Test） | passed（静态） | mall-search `src/main/resources/application.yml`：`mall.elasticsearch.uris=${MALL_ES_URIS:http://localhost:9200}`（connect 2s/socket 5s），commit 82ccf6e |
| TC-005 | Testcontainers ES：建临时索引 → index 2 文档 → search 命中 2 条，结束自动清理 | Testcontainers ES 8.17.4 集成测试 | passed | `ElasticsearchSmokeTest#indexTwoDocumentsAndSearchHits`（临时索引 smoke-it-* 写入「机械键盘/无线鼠标」，match「机械」命中 1 条，finally 删除索引） |
| TC-006 | 无 ES 环境 ContextLoads 通过（client Bean 懒连接） | SpringBootTest 上下文冒烟 | passed | `MallSearchApplicationSmokeTest#contextLoads`（test profile，H2/Flyway/Nacos 关闭，不连 ES） |

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
| --- | --- | --- |
| mall-search（本 Story 相关 2 类） | 全 reactor `mvn test -B -ntp`（`TESTCONTAINERS_RYUK_DISABLED=true`，ES Testcontainers 8.17.4） | `ElasticsearchSmokeTest` **1/1**、`MallSearchApplicationSmokeTest` **1/1**，0 失败 0 跳过 |
| mall-search 模块整体 | 同上（2026-09-19） | **32/32**（7 classes），BUILD SUCCESS |
| 全 reactor 回归 | 同上 | 14 模块 **482/482**，0 失败 0 跳过，BUILD SUCCESS |
| 日志 | `delivery/changes/CHG-0020/evidence/logs/backend-full-test.log` | ElasticsearchSmokeTest 1（1.782s）、MallSearchApplicationSmokeTest 1（0.649s）、模块 Results 32、Reactor mall-search SUCCESS |

通过率：本 Story 自动化用例 **2/2 = 100%**；TC-001~TC-004 为设计既定的手工/静态项（test-design §2 分层策略），结论与实施记录一致。

## 3. AC 覆盖

| AC | 覆盖 TC |
| --- | --- |
| AC-001 | TC-001 |
| AC-002 | TC-002 |
| AC-003 | TC-003、TC-006 |
| AC-004 | TC-004 |
| AC-005 | TC-005、TC-006 |

## 4. 备注 / 缺口

- TC-001（compose 健康检查/卷持久化/down-up 数据保留）与 TC-003 的「停 ES 后 health=DOWN」段为手工/脚本验证项，设计阶段即标注手工分层（test-design §2），本报告不虚构自动化结果；容器级启停复核在 M5 Integration Gate 联调阶段再做一次端到端确认。
- 客户端版本事实：elasticsearch-java 随 Spring Boot 3.5.15 BOM 解析为 8.18.8，服务端镜像与 Testcontainers 固定 8.17.4（同 8.x 主版本兼容），与 story-design 的 8.x 口径一致。
- 无不可测项遗留（test-design §3 标注「无」）。
