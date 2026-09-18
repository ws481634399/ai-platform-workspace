---
story-id: "STORY-005-01-01-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S1]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.1 [S1]/§5
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0020
- Story ID: STORY-005-01-01-01 建立 mall-search 与 Elasticsearch 基础环境
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`（S1）

## 1. Story 目标

为商城搜索建立运行与开发基线：repo-4 的 docker-compose 新增 Elasticsearch 8.x 单节点服务（健康检查/数据卷/内网/环境变量/.env 样例）；mall-search 从空骨架接入官方 elasticsearch-java Client（版本经 mall-bom/Spring Boot BOM 管理）、连接配置可环境化、暴露 ES 连通性健康检查；建立 Testcontainers ES 集成测试基线，后续查询/同步 Story 在其上迭代。

## 2. Scope（范围）

### 2.1 包含

- [S1] docker-compose.infra.yml 新增 elasticsearch 服务（8.x、单节点 discovery.type、mem 锁与 JVM 堆限制、healthcheck、数据卷 ai-platform-es-data、接入既有 ai-platform 网络、.env.example 补充）。
- [S1] mall-search pom 引入 co.elastic.clients:elasticsearch-java + jakarta.json 依赖（不写死版本）；mall-bom 必要时补版本管理。
- [S1] ElasticsearchConfiguration：RestClient（http://${MALL_ES_URIS:http://localhost:9200}，超时配置）+ JacksonJsonpMapper + ElasticsearchClient Bean。
- [S1] SearchHealthIndicator（Spring Boot Actuator HealthIndicator）：ping ES，UP/DOWN 反映连通状态。
- [S1] Testcontainers 基线：ElasticsearchContainer 8.x 测试基类/配置（与既有 MySQL/Redis Testcontainers 测试同构），完成建临时索引→写文档→检索的冒烟集成测试；保留原无外部依赖的 ContextLoads 冒烟测试。

### 2.2 不包含

- 业务索引 Mapping 代码化与别名（CHG-0021 STORY-005-02-01-01；本 Story 测试中创建的是临时测试索引）。
- 任何商品搜索业务接口、同步接口（后续 Story）。
- ES 安全认证（TLS/账号密码）——本地单节点内网简化配置，生产安全方案后续里程碑。

## 3. 业务规则

- ES 单节点仅服务内网；数据持久化到命名卷；compose down 不丢数据（除非 -v）。
- 连接地址必须可由环境变量覆盖（MALL_ES_URIS），默认 localhost:9200；连接/套接字超时显式配置（建议 connect 2s / socket 5s）。
- mall_search MySQL 数据源与 Flyway 保留（CHG-0021 使用失败记录表；本 Story 不建业务表）。

## 4. 接口与字段规格

- 无业务 API；健康检查：GET /actuator/health 含 search/ES 健康项（actuator 已在基线服务中暴露，沿用既有 management 配置）。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | docker compose -f docker-compose.infra.yml up -d elasticsearch 后容器健康（healthcheck healthy），数据卷存在；重启容器索引数据不丢（手工 curl _cluster/health 为 green/yellow 单节点可接受） |
| AC-002 | mall-search 依赖为官方 elasticsearch-java，工程内不出现 RestHighLevelClient；依赖版本不由本服务 pom 写死 |
| AC-003 | mall-search 本地启动连接 ES 成功；ES 停止时 /actuator/health 体现 DOWN 且应用进程不退出 |
| AC-004 | MALL_ES_URIS 环境变量可覆盖 ES 地址 |
| AC-005 | mvn -pl mall-services/mall-search -am test 通过：含 1 条 Testcontainers ES 冒烟（建临时索引→写 2 文档→搜索命中文档）与上下文加载测试 |
