---
id: "REQ-M0-004"
name: "建立本地基础设施环境（Docker Compose）"
content: "建立 AI 智能电商微服务平台统一的本地基础设施运行环境，通过 Docker Compose 管理 MySQL、Redis、Nacos、MinIO，提供可重复启动、停止、验证和恢复的本地开发环境（M0，P0）。"
source: requirement-doc
created-at: "2026-09-07T22:05:00+08:00"
---

# Requirement

> 业界锚点：原始需求记录（Feature Request / User Voice）
> 本文件记录需求来源原文，由 sdd-explore 在探索阶段写入。
> 与 exploration.md 分离：本文件是输入沉淀（保持用户原话），exploration.md 是分析产物（Story 归属/证据/冲突）。
> 原始需求文档已完整归档至 `references/REG-M0-004.md`，未做改写；本文件为结构化导航摘录。

## 需求描述

> 以下为需求文档关键内容的忠实摘录（保持原话，未做改写），完整原文以 `references/REG-M0-004.md` 为准。

**Requirement ID**：REQ-M0-004；**名称**：本地基础设施环境；**阶段**：M0 项目初始化；**类型**：工程基础需求；**优先级**：P0；**前置依赖**：无强依赖，可与 `REQ-M0-001`、`REQ-M0-002`、`REQ-M0-003` 并行开发；**实现范围**：Docker Compose、本地基础设施、环境配置、运行脚本与基础联调能力。

**管理方式**：本 Requirement 只创建一个 Change，不要将 MySQL / Redis / Nacos / MinIO 各自重新创建成独立 Change（§二十四）。

### 一、需求目标

建立 AI 智能电商微服务平台统一的本地基础设施运行环境，为 Java 后端、前端和 AI Service 提供可重复启动、停止、验证和恢复的本地开发环境。M0 阶段需要优先建立：MySQL；Redis；Nacos；MinIO。所有基础设施统一通过 Docker Compose 管理。完成本需求后，开发人员不需要在 Windows 本机分别安装 MySQL、Redis、Nacos、MinIO 等中间件，只需要 Docker 即可启动项目 M0 阶段所需基础设施。核心目标是：统一运行方式 + 统一网络 + 统一环境变量 + 统一数据持久化 + 统一健康检查 + 统一启动/停止方式 + 为 M0 联调提供基础环境。

### 二、基础原则

本地基础设施统一使用 Docker + Docker Compose。开发机器本地只负责安装 Docker Desktop / Docker Engine。MySQL、Redis、Nacos、MinIO 等基础设施不得要求开发人员另外以 Windows Service 等方式安装。原则：开发工具 → 本地安装；基础设施 → Docker 运行。

### 三、M0 基础设施范围

本阶段建立 MySQL、Redis、Nacos、MinIO。暂不建立：RocketMQ、Elasticsearch、Vector Database、Prometheus、Grafana、Loki、SkyWalking、Nginx。以上中间件根据后续 Requirement 实际需要再引入。不得为了“一次把环境搭全”而提前启动所有后续技术组件。

### 四、基础目录结构

建议建立独立基础设施目录，例如 `deploy/`（`docker-compose.infra.yml`、`.env.example`、`.gitignore`、`mysql/init/`、`redis/`、`nacos/`、`minio/`、`scripts/` start/stop/status/health）。具体文件划分可由 Design 阶段调整。如果项目已经存在部署目录，应优先复用现有结构，不得无理由重新创建另一套部署体系。

### 五、Docker Compose

建立统一 `docker-compose.infra.yml` 用于管理 M0 基础设施。必须能够通过统一命令启动：`docker compose -f docker-compose.infra.yml up -d`；停止：`docker compose -f docker-compose.infra.yml down`；查看：`docker compose -f docker-compose.infra.yml ps`。不应要求开发人员逐个执行 `docker run mysql/redis/nacos`。

### 六、Docker Network

所有基础设施应加入统一 Docker Network。例如语义上 `ai-platform-network`，使容器之间能够使用服务名称互相访问（如 `mysql:3306`、`redis:6379`、`nacos:8848`、`minio:9000`）。容器内部不得依赖固定宿主机 IP。

### 七、MySQL

建立 MySQL 本地开发实例，用于后续 identity / member / product / order / inventory / system 等 Java 微服务的数据持久化。至少配置：MySQL 容器、Root Password、Character Set、Timezone、Volume、Health Check、必要初始化能力。统一字符集建议 utf8mb4。数据库配置必须通过环境变量注入。禁止在 Compose 文件中提交真实生产密码。M0 可以创建项目运行所需的基础数据库，但 M0-004 只负责创建数据库环境，不负责创建商品、订单、库存等正式业务表。正式业务表结构由各服务通过 Flyway Migration 管理。不要在 Docker MySQL 初始化脚本中维护整个业务数据库 DDL。正确职责：Docker → 创建 MySQL 与必要 Database；Flyway → 管理业务表版本。

### 八、Redis

建立 Redis 本地开发实例。后续用于登录会话辅助、Token / Permission Cache、商品缓存、购物车、分布式基础能力、系统配置缓存。M0 只负责 Redis 基础服务可用。要求：Redis 容器正常启动；必要密码通过环境变量管理；数据 Volume 根据开发需求配置；Health Check 正常；Java 服务后续可以连接。M0 不实现购物车、权限缓存、商品缓存、分布式锁等具体业务逻辑。

### 九、Nacos

建立 Nacos 本地开发实例，用于后续 Service Discovery + Configuration Management。M0 重点完成：Nacos 容器可启动；Nacos Console 可访问；Java 服务能够连接 Nacos；Java 服务能够完成注册发现基础验证。如果采用 Nacos Standalone 模式，应明确 `MODE=standalone`。本地开发不需要建立 Nacos 集群。`REQ-M0-001` 已经建立 mall-gateway / mall-identity / mall-member / mall-product / mall-cart / mall-order / mall-inventory / mall-search / mall-system。M0-004 完成后，需要进行一次集成验证：Java Service → Nacos，至少确认服务能够正常注册。理想情况下最终能够在 Nacos Console 中看到规划的 Java 服务实例。

### 十、MinIO

建立 MinIO 本地对象存储服务。后续用于商品图片、商品资源、AI 知识库文件、其他对象文件。要求至少提供：MinIO Server、Console、Access Key、Secret Key、Volume、Health Check、环境变量配置。M0 只保证 MinIO 可运行和可访问。不需要提前开发商品图片上传业务、AI 文档上传、文件权限业务。

### 十一、数据持久化

MySQL / Redis / Nacos / MinIO 需要根据实际情况配置 Docker Volume。重点保证 `docker compose down` 后重新 `docker compose up -d` 时，不会因为普通容器重建导致全部开发数据无条件丢失。需要明确区分 Container ≠ Data：容器可以重建，开发数据通过 Volume 保留。

### 十二、环境变量

建立 `.env.example` 用于描述 Docker 基础设施需要的配置（例如 MYSQL_ROOT_PASSWORD / MYSQL_PORT、REDIS_PASSWORD / REDIS_PORT、NACOS_PORT、MINIO_ROOT_USER / MINIO_ROOT_PASSWORD / MINIO_API_PORT / MINIO_CONSOLE_PORT）。实际变量名称由 Design 最终确定。真实本地配置可以通过 `.env` 维护。`.env` 不得提交 Git。必须提交 `.env.example` 作为运行说明。

### 十三、端口规划

M0 需要建立清晰端口规划，避免本地开发时发生冲突。例如需要明确 MySQL、Redis、Nacos Server、Nacos Console、MinIO API、MinIO Console 的宿主机端口。具体端口以 Design 中最终决策为准。要求：端口集中管理；不在多个文件中随意硬编码；README 或环境说明能够查到；后续 Java / AI 配置能够正确引用。

### 十四、健康检查

每个关键基础设施应尽可能配置健康检查。至少验证 MySQL、Redis、Nacos、MinIO 运行状态。执行 `docker compose -f docker-compose.infra.yml ps` 应能够清晰看到服务运行状态。不允许仅根据 container started 判断服务可用。需要尽可能验证 Process Started + Service Ready。

### 十五、基础运行脚本

为了简化开发，可以建立基础脚本，例如 start / stop / restart / status / health。脚本只作为 Docker Compose 命令的便捷封装。不要构建复杂的自定义部署系统。目标是让开发人员能够简单完成：启动基础设施、停止基础设施、检查状态、查看日志。

### 十六、日志查看

需要明确基础设施日志查看方式。例如 `docker compose -f docker-compose.infra.yml logs` 或查看指定服务 `docker compose -f docker-compose.infra.yml logs mysql`。要求开发人员发生 MySQL 无法启动 / Redis 无法连接 / Nacos 注册失败 / MinIO 不可访问时能够快速找到容器日志。

### 十七、基础设施与应用配置边界

Docker 基础设施负责：服务运行、端口、Network、Volume、基础账号、Health Check。Java / AI 应用负责：如何连接这些基础设施。例如 MySQL Container 不应该知道 mall-order 如何配置 DataSource；Nacos Container 不负责 mall-product 的 Spring Cloud 配置。避免部署配置和应用配置互相污染。

### 十八、安全要求

虽然属于本地开发环境，也必须遵守基本安全规范。禁止提交真实生产 Password / Token / AccessKey、LLM API Key、云服务 Secret。M0 Docker 中使用的账号密码只允许是 Local Development Credentials，并通过 `.env` 管理。`.env.example` 中只能提供变量名 + 示例值/占位符。

### 十九、与 Java Backend 的联调

在 `REQ-M0-001` 和 `REQ-M0-004` 均完成后，应进行 M0 Java 基础联调。至少验证 Java → MySQL、Java → Redis、Java → Nacos。重点确认：数据库连接正常；Redis 连接正常；Nacos 注册正常；Gateway / 服务启动不会因为基础设施配置错误失败。

### 二十、与 Frontend 的关系

`REQ-M0-004` 不负责启动 mall-web / mall-admin，但需要保证后续前端能够通过 Frontend → Gateway 完成联调。如果 Gateway 使用宿主机端口运行，应在 M0 总验收阶段验证前端和 Gateway 的基础连接能力。

### 二十一、与 AI Service 的关系

M0 AI Service 不强制依赖 MySQL / Redis / MinIO 才能启动。尤其 AI Service：不允许通过本需求获得 Java 业务数据库直接连接能力。AI Service 后续获取业务数据仍然通过 Java API。MinIO 后续可以提供 AI Knowledge File Storage，但不在 M0 实现知识库业务。

### 二十二、禁止跨服务数据库访问

本地存在一个 MySQL 实例不意味着所有服务可以随意查询所有表。必须继续遵守 Service → Own Database / Schema 边界。禁止 mall-order → SELECT mall_product.xxx；禁止 AI Service → SELECT mall_order.xxx。Docker 只是提供运行基础设施，不改变微服务数据所有权。

### 二十三、本需求不包含

REQ-M0-004 不负责：Java Maven 工程、Java Common、Gateway 业务、Vue 工程、AI FastAPI 工程；也不负责提前建立 RocketMQ、Elasticsearch、Vector Database、Prometheus、Grafana、Nginx、CI/CD、Production Deployment。这些由后续对应 Requirement 实现。

### 二十四、建议 Task 划分

内部建议拆分 TASK-001 Docker Compose 与环境变量基线 / TASK-002 MySQL / TASK-003 Redis / TASK-004 Nacos / TASK-005 MinIO / TASK-006 Network / Volume / Health Check / TASK-007 Scripts / README / TASK-008 M0 Infrastructure Integration Verification。可进一步形成 DU-INFRA-001 Compose Foundation、DU-INFRA-002 Data Infrastructure、DU-INFRA-003 Service Infrastructure、DU-INFRA-004 Runtime Verification。具体 Delivery Unit 根据 Design 确定。

### 二十五、验收标准（AC-01 ~ AC-12）

AC-01 Docker 环境：`docker info` 成功，`docker compose version` 成功。
AC-02 Compose 启动：`docker compose -f docker-compose.infra.yml up -d` 成功。
AC-03 MySQL：Container 正常运行；Health Check 正常；能够建立客户端连接；数据库初始化符合预期；Volume 正常。
AC-04 Redis：Container 正常；Health Check 正常；PING 正常；Java 后续能够连接。
AC-05 Nacos：Container 正常；Console 可访问；服务端正常；Java Service 可以完成注册验证。如果 Java Requirement 尚未完成：Nacos Container Verification = PASS，Java Registration Integration = PENDING；不得伪造联调结果。
AC-06 MinIO：Server 正常；Console 可访问；登录正常；Volume 正常；API 可访问。
AC-07 Network：所有基础设施加入规划的统一 Docker Network；容器间服务名称解析正常。
AC-08 Volume：执行容器重启或重建验证后，关键持久数据符合预期；不得因为普通 Container Recreation 无条件丢失全部开发数据。
AC-09 Environment：存在 `.env.example`；不存在提交 Git 的真实 Secret。
AC-10 Health：执行 `docker compose -f docker-compose.infra.yml ps`，关键服务均处于正常运行状态。
AC-11 Java 集成：在 `REQ-M0-001` 完成的前提下至少验证 Java → Nacos / MySQL / Redis 基础连接正常。
AC-12 可重复运行：完整执行 up → status → down → up 能够正常恢复本地开发环境。

### 二十六、Definition of Done 与 Evidence

DoD：Docker Compose 基线完成、docker-compose.infra.yml 完成、.env.example 完成、.gitignore 完成、MySQL/Redis/Nacos/MinIO Container 完成、Docker Network 完成、Volume 策略完成、Health Check 完成、端口规划完成、四项 Health PASS、MySQL/MinIO 数据持久化验证 PASS、基础启动/停止说明完成、环境变量说明完成、Git 中不存在真实 Secret、Java → MySQL/Redis/Nacos 基础联调 PASS 或明确 PENDING、未提前引入 RocketMQ/Elasticsearch/Vector Database/完整监控平台、所有实际测试形成 Evidence。

Evidence 至少记录：Docker 版本信息、Compose up PASS/FAIL、Container Status、MySQL Connection/Init/Volume、Redis PING、Nacos Server/Console/Java Registration、MinIO Server/Console/Storage、Security 检查（.env / Password / Secret 未误提交）。Java Registration 若不具备联调条件须记 PENDING 并给出 Reason。

### 二十七、M0 最终集成关系与交付状态

REQ-M0-004 完成后，M0 四个基础需求形成：Java Backend（REQ-M0-001）连接本需求基础设施，Frontend（REQ-M0-002）经 Gateway 联调，AI Service（REQ-M0-003）后续经 Java API 联调。最终 M0 阶段应具备：Java Backend 可构建/可启动；Frontend 可构建/可启动；AI Service 可启动/可测试；Infrastructure 可启动/可恢复；以及 Java → MySQL / Redis / Nacos PASS。核心目标：完成本需求以后，本地开发所需要的 MySQL、Redis、Nacos、MinIO 不再由开发人员手工安装和维护，而是能够通过统一 Docker Compose 一键创建、启动、停止和验证。

## 补充信息

- 来源文档：`docs/需求/M0/REG-M0-004.md`
- Change 内归档：`delivery/changes/CHG-0006/references/REG-M0-004.md`
- 关联需求：REQ-M0-001（Java 后端，归档 CHG-0003）、REQ-M0-002（前端，归档 CHG-0004）、REQ-M0-003（AI Service，归档 CHG-0005）
