# Review Report — STORY-005-01-01-01 建立 mall-search 与 Elasticsearch 基础环境

## 0. 元信息

- Change ID：CHG-0020（M5 商品搜索）
- Story ID：STORY-005-01-01-01 建立 mall-search 与 Elasticsearch 基础环境
- 审查对象：DU-WS-501（repo-4：compose Elasticsearch 8.17.4）、DU-BE-501（repo-1：官方 elasticsearch-java Client/配置/健康探针/Testcontainers 基线）
- Test Report 来源：`evidence/test-report.md`
- Evidence 索引：`evidence/evidence.yaml`（EV-001~EV-005）
- 检查时间：2026-09-19
- 状态：testing 检查点（不推进 Story/Change 状态）

## 1. 检查结论

**通过（PASS，带 2 项开放 minor）。** ES 运行环境与服务接入的设计声明全部落地：compose 8.17.4 单节点（健康检查/命名卷/ES_PORT）、官方 co.elastic.clients 客户端（无 RestHighLevelClient）、MALL_ES_URIS 环境覆盖、SearchHealthIndicator ping 探针（DOWN 不外抛、进程存活）、Testcontainers 8.17.4 static 单例基线与懒连接上下文冒烟。自动化 2/2 通过（ElasticsearchSmokeTest、MallSearchApplicationSmokeTest，经全 reactor 482/482 回归实证）。无 blocker/major。

### 1.1 需求一致性

| Story AC | test-run 证据 | 结论 |
| --- | --- | --- |
| AC-001 compose 起 ES 健康、命名卷持久化、重启数据不丢 | compose 配置静态核对（docker-compose.infra.yml elasticsearch 服务、es-data→ai-platform-es-data 卷、healthcheck wait_for_status=yellow）；设计既定手工/脚本项 | passed（手工/静态；容器级启停复核留 Integration Gate，见 EV-004） |
| AC-002 官方 elasticsearch-java、无 RHLC、版本不由本服务写死 | mall-search pom 坐标无 `<version>`，随 Spring Boot 3.5.15 BOM 解析 8.18.8；全工程 grep 无 RestHighLevelClient | passed（静态） |
| AC-003 连通时 health UP、停 ES 时 DOWN 且进程不退出 | SearchHealthIndicator 源码核对（ping 异常 catch→Health.down 不外抛）；MallSearchApplicationSmokeTest 证明无 ES 上下文可加载（Bean 懒连接） | passed（自动+静态；停容器实跑留 Gate，见 EV-004） |
| AC-004 MALL_ES_URIS 可覆盖 ES 地址 | application.yml `mall.elasticsearch.uris=${MALL_ES_URIS:http://localhost:9200}`；Testcontainers 经 @DynamicPropertySource 注入容器地址实证覆盖链路 | passed（静态+实证） |
| AC-005 mvn test 含 ES 冒烟与上下文测试 | ElasticsearchSmokeTest#indexTwoDocumentsAndSearchHits（建临时索引写 2 文档命中 1 条并清理）、MallSearchApplicationSmokeTest#contextLoads；mall-search 模块 32/32、全 reactor 482/482 | passed |

### 1.2 设计一致性

- 模块职责：story-design §1 的 ES Client Bean（RestClient+JacksonJsonpMapper+ElasticsearchClient）、超时（connect 2s/socket 5s）、健康探针、Testcontainers 基类均与 DU-BE-501 实施一致；Client Bean 构造期不发连，离线可启动的设计约束经 contextLoads 验证。
- compose 声明：镜像 tag、single-node、关 xpack.security/enrollment、512m 堆、memlock、9200 端口环境变量、healthcheck、命名卷、内网接入与 DU-WS-501 实施一致。
- Deviations 完整性：DU-WS-501 DEV-1（healthcheck 宽限参数、infra 网络键/es-data 卷键命名、省略 cluster.name）与 DU-BE-501 DEV-1（客户端 8.18.8/服务端 8.17.4 同主版本兼容、8.18 禁对 `_id` 排序→PIT+_shard_doc）、DEV-2（健康指示器命名 SearchHealthIndicator、关闭默认 ES 健康项）均按"原建议/实际/原因/影响"四要素记录，外部契约（components.search、卷名、端口、URI 覆盖）不变，记录完整可接受。
- 错误策略：ping 异常仅 WARN 并置 DOWN，不影响进程存活，符合 story-design §4。

### 1.3 跨仓一致性

requirement-design §4 的环境链路在本 Story 闭环于前两段：repo-4 提供 8.17.4 运行时（compose 网络内主机名 elasticsearch、本机 ES_PORT），repo-1 mall-search 以 MALL_ES_URIS 消费、不强依赖 compose 网络寻址；版本口径（服务端 8.17.4 / Testcontainers 8.17.4 / 客户端 BOM 8.18.8）在两侧 DU 文档一致。后续 repo-1→repo-2 的 API 契约不在本 Story 范围。无跨仓矛盾。

### 1.4 代码质量

对照 standards 明确条目抽查：

- `standards/project/local-infrastructure-standard.md`（单一编排入口/健康与就绪/配置凭据/数据保留）：镜像固定明确 tag（非 latest）、健康检查打真实 `_cluster/health` 协议、命名卷持久化、端口经 ES_PORT 显式覆盖——均符合。
- 唯一缺口：同规范"首次采用或升级镜像时必须记录实际 RepoDigest"未落实，ES 镜像为本次首次引入，DU 与 evidence 仅有 tag 无 digest（见 EV-005，minor）。
- Java 侧分层（infrastructure.elasticsearch/health）、配置属性绑定、超时显式化、无启动期强连，质量符合工程范式；测试经真实 Testcontainers 而非 mock 猜测，符合 testing-standard §2.2 风险覆盖原则。

### 1.5 知识同步候选

1. ES 版本组合事实：Spring Boot 3.5.15 BOM 将 elasticsearch-java 解析到 8.18.8，服务端/Testcontainers 固定 8.17.4，同 8.x 主版本互通可作为后续里程碑的版本基线。
2. ES 8.18 约束与替代写法：8.x（8.18 客户端）禁止对 `_id` 做 fielddata 排序，全量遍历/深分页采用 PIT（openPointInTime+keepAlive）+ `_shard_doc` asc + search_after，finally closePointInTime 兜底——建议沉淀为搜索/索引工程知识（正文在共存的 CHG-0021 EsSearchIndexAdapter，本 Change DU-BE-501 DEV-1 已记录事实）。

## 2. 发现清单

| EV id | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-004 | Story AC-001/AC-003；test-report §4 | minor | compose healthy/卷持久化/down-up 数据保留、停 ES 后 health=DOWN 为设计既定手工/静态项，尚未做容器级实停实起复核 | 处置去向：M5 Integration Gate 场景五执行 compose up/down 与实停 ES 容器，复核 healthy、数据保留、mall-search DOWN 且进程存活，并补运行证据 |
| EV-005 | DU-WS-501 implementation.md；deploy/docker-compose.infra.yml | minor | local-infrastructure-standard 要求首次引入镜像记录实际 RepoDigest，本次 ES 8.17.4 仅有 tag 无 digest，镜像内容追溯链不完整 | 处置去向：联调首次拉起时以 docker inspect 读取容器 Image ID，再以 docker image inspect 读取该镜像 RepoDigests，将摘要补录至 DU-WS-501 实施记录/evidence |

无 blocker / major。

## 3. 完成确认

- [x] 四项检查全部执行（需求/设计/跨仓/代码质量）
- [x] 全部 blocker/major finding 已闭环（本 Story 无 blocker/major）
- [x] minor finding 已记录（EV-004/EV-005，允许开放，处置去向明确）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（repo-4 环境 → repo-1 消费链路）
