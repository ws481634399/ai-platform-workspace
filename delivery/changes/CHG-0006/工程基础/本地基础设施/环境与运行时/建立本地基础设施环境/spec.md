# 产品规格

> 阶段：sdd-prd 产物
> 输入：CHG Context（`requirement.md` + `exploration.md`）
> 产出状态：specified（草稿待人工确认）

本文档将 REQ-M0-004 转换为可设计、可测试、可追溯的产品规格，作为后续 `design.md`、`tasks.md`、实施与验收的权威输入。

## 0. 元信息

- Change ID: CHG-0006
- Requirement: REQ-M0-004（完整原文见 `references/REG-M0-004.md`）
- Feature ID: STORY-1-03-01-01（MOD-1 工程基础 > FEAT-1-03 本地基础设施 > FEAT-1-03-01 环境与运行时 > 建立本地基础设施环境）
- 优先级: P0（M0 项目初始化必须）
- 状态流转: exploring → specified
- 规格模式: 单 Story inline（Change Spec 与 Story Spec 合并）

## 1. 背景

CHG-0003、CHG-0004 与 CHG-0005 已分别建立 Java Backend、Frontend 和 AI Service 的工程基线，但当前工作区没有可运行的本地基础设施基线。Java 仓虽然已预留 MySQL 数据源与 Nacos Discovery 环境变量，但真实 MySQL、Redis 和 Nacos 联调仍缺少可复现的运行时。

本 Change 新增一套 M0 本地共享基础设施“插座”：开发者只需 Docker Desktop / Docker Engine 和 Docker Compose，即可以统一方式启动、停止、检查和恢复 MySQL、Redis、Nacos、MinIO。它不承载业务表、业务缓存、文件业务或生产部署能力。

本规格是 `product/13-部署方案.md` 中分层 Compose 目标的 M0 子集，并与 `product/08-系统与微服务架构.md` 中“基础设施由 Compose 运行、应用由 IDE 运行”的本地拓扑一致。与既有 Change 无范围重复：CHG-0003 提供 Java 连接点，本 Change 提供真实容器与联调证据；CHG-0005 的 AI Service 仍不得直连 Java 业务数据库。

## 2. 用户价值

- **目标用户**：主要是 Windows 本地开发环境中的 Java、Frontend 和 AI 工程师；次要是需要复现问题、执行 M0 集成验收的测试与架构角色。
- **痛点**：四类中间件尚无统一版本、端口、网络、账号、卷和健康检查契约；手工安装会造成环境漂移，容器“已启动”也无法证明服务“已就绪”。
- **JTBD—开发者**：When I 首次拉取项目或重建本地环境, I want to 使用一组文档化命令启动全部 M0 基础设施并看到真实健康状态, So that 我不需要在 Windows 上分别安装和调试四套中间件。
- **JTBD—联调人员**：When I 验证 Java 工程的 MySQL、Redis 与 Nacos 接入, I want to 使用稳定的宿主机端口与环境变量契约完成真实连接, So that CHG-0003 中挂起的 M0 Integration Verification 能用真实证据收口。
- **直接价值**：基础设施可重复启停、可健康判定、可保留关键开发数据，并能快速定位日志。
- **业务价值**：完成 M0 四项基础需求的最后一环，为 M1/M2 业务开发提供可复现的本地运行时。

## 3. 范围

### 3.1 包含（Scope In）

本期全部为 P0：

1. **共享 Compose 基线**：在工作区根目录 `deploy/` 建立唯一权威 `docker-compose.infra.yml`，统一编排 MySQL、Redis、Nacos 和 MinIO；不在三个实现仓重复维护 Compose 副本。
2. **环境契约**：提交 `.env.example`、忽略真实 `.env`，集中声明版本、端口、本地账号、时区和其他可配置项；所有容器镜像使用明确且已验证的非漂移 tag。
3. **MySQL 本地数据环境**：提供 utf8mb4、Asia/Shanghai、健康检查、持久卷和幂等初始化；为 Java 已规划服务预建 `mall_identity`、`mall_member`、`mall_product`、`mall_cart`、`mall_order`、`mall_inventory`、`mall_search`、`mall_system` 空数据库，可创建仅限本地开发的应用账号。
4. **Redis 本地服务**：提供密码注入、就绪检查、数据卷与持久化配置，保证普通 `down` 后再 `up` 不会无条件丢失已验证的测试键。
5. **Nacos 本地服务**：以 Standalone 模式启动，提供 Console、健康检查、持久卷及 Java Discovery 所需的宿主机端口。
6. **MinIO 本地对象存储**：提供 Server API、Console、本地凭据、健康检查与持久卷；本期不预建业务 Bucket。
7. **统一网络、端口与卷**：四项服务加入正式名为 `ai-platform-network` 的网络；默认宿主机端口为 MySQL 3306、Redis 6379、Nacos 8848（及客户端必需端口）、MinIO API 9000 与 Console 9001，均可通过 `.env` 覆盖。
8. **运行与排障入口**：文档化 `up/down/ps/logs/restart`，并为 Windows 主要开发环境提供轻量 PowerShell 便捷脚本（start/stop/status/health）；脚本只封装 Docker Compose，不建立自定义部署系统。
9. **可重复运行与真实验证**：完成 up → health/status → down → up，验证四项服务就绪、服务名解析、MySQL/Redis/MinIO 关键数据恢复、日志可检索和未误提交 Secret。
10. **Java M0 基础联调**：至少选择一个已交付的 Java 业务服务，以真实运行结果证明 Java → MySQL、Java → Redis、Java → Nacos 三条基础连接。若现有 Java 代码尚无某一连接入口，该项可记为 PENDING，但必须写明受阻代码事实与后续 Requirement，不得用容器检查代替 Java 连接证据。

### 3.2 不包含（Scope Out）

1. RocketMQ、Elasticsearch、Vector Database、Prometheus、Grafana、Loki、SkyWalking、Nginx 及任何其他后续基础设施。
2. Java、Frontend 或 AI Service 的业务功能，以及前端 → Gateway 的 M0 总验收。
3. 商品、订单、库存等正式业务表 DDL；正式表结构只能由对应 Java 服务的 Flyway Migration 管理。
4. 购物车、权限缓存、商品缓存、分布式锁等 Redis 业务逻辑。
5. 商品图片上传、AI 知识库文件、Bucket 命名与权限策略等 MinIO 业务能力。
6. Nacos 集群、高可用、外部 MySQL 部署和生产级鉴权加固。
7. Docker 应用镜像、应用编排、CI/CD、云环境、Kubernetes 与生产部署。
8. AI Service 直连 MySQL 或借助本地基础设施绕过 Java API 访问业务数据。
9. 为规避端口冲突而自动选择随机端口；冲突通过显式 `.env` 覆盖解决，端口契约仍可查询、可复现。

## 4. 业务规则

- **[R-01 单一编排入口]**：启动任一 M0 基础设施 → 必须由 `deploy/docker-compose.infra.yml` 统一管理 → 禁止要求开发者单独执行 `docker run`。
- **[R-02 镜像可复现]**：Compose 引用容器镜像 → 必须使用 Design/Test 已验证的明确版本 tag → 禁止 `latest` 或未声明 tag。
- **[R-03 就绪优先]**：容器进程已启动但服务尚不可连接 → 健康状态仍为非健康 → 不得将 `running` 代替 Service Ready 记为 PASS。
- **[R-04 统一网络]**：基础设施容器间通信 → 加入 `ai-platform-network` 并使用 `mysql`、`redis`、`nacos`、`minio` 服务名 → 禁止依赖固定宿主机 IP。
- **[R-05 端口单一来源]**：宿主机端口需要调整 → 通过 `.env` 覆盖 `.env.example` 中的默认值 → 禁止在 Compose、脚本和 README 中维护互相矛盾的端口值。
- **[R-06 数据所有权]**：共享一个 MySQL 实例 → 各微服务仍只拥有自身 Database/Schema 的数据边界 → 禁止跨服务查表或 AI Service 直连业务库。
- **[R-07 初始化边界]**：MySQL 初始化 → 只可建立库、本地账号及必要权限 → 禁止写入正式业务表、业务数据或替代 Flyway Migration。
- **[R-08 普通重建保留数据]**：执行文档化的 `down` 后再 `up` → 命名卷继续保留 MySQL、Redis、Nacos 和 MinIO 的开发数据 → 仅显式的数据清理操作可删除卷。
- **[R-09 凭据分层]**：本地开发需要账号密码 → 真实本地值只写入已忽略的 `.env` → Git 只允许跟踪变量名与明确标注的 Local Development 示例值，不得包含生产 Secret。
- **[R-10 联调证据真实性]**：Java 尚不具备某连接能力 → 对应集成项标记 PENDING 并写明原因 → 禁止伪造 PASS 或用 `docker compose ps` 代替 Java 客户端连接。
- **[R-11 范围节制]**：后续中间件尚未有独立 Requirement → 不得加入本 Compose 默认服务集 → 不以“一次搭全”为理由扩大 M0 范围。
- **[R-12 脚本轻量化]**：使用便捷脚本 → 脚本输出底层 Docker Compose 命令与错误码 → 不吞掉错误、不封装复杂状态机。

## 5. 验收标准

| ID | 验收标准（可测试） | 覆盖范围 |
| --- | --- | --- |
| AC-001 | 在安装 Docker 的验收机上执行 `docker info` 与 `docker compose version` → 两条命令退出码均为 0，Evidence 记录完整版本。 | Docker 前置 |
| AC-002 | 从 `deploy/` 按 `.env.example` 准备本地配置后执行 `docker compose -f docker-compose.infra.yml up -d` → 退出码为 0，且只创建 MySQL、Redis、Nacos、MinIO 及其必需辅助容器。 | Compose 基线 |
| AC-003 | 启动后执行 `docker compose -f docker-compose.infra.yml ps` 并等待预定义健康超时 → 四项关键服务均为 running/healthy；任一服务不可连接时不得显示为健康。 | Health |
| AC-004 | 使用 MySQL 客户端和 `.env` 中的本地凭据连接 → `SELECT 1` 成功，8 个规划数据库存在且字符集为 utf8mb4，初始化脚本不包含正式业务表。 | MySQL |
| AC-005 | 使用已配置密码执行 Redis `PING` → 返回 `PONG`；使用错误密码→鉴权失败。 | Redis |
| AC-006 | 访问 Nacos Console 和服务健康端点 → Console 可加载、服务端就绪，且实例以 Standalone 模式运行。 | Nacos |
| AC-007 | 访问 MinIO API 健康端点和 Console，并使用本地凭据登录 → API 就绪、Console 可访问且登录成功，默认不出现业务 Bucket。 | MinIO |
| AC-008 | 从某一容器执行名称解析/连接检查 → `mysql:3306`、`redis:6379`、`nacos:8848`、`minio:9000` 均通过 `ai-platform-network` 可解析且可连接，配置中不依赖固定宿主机 IP。 | Network |
| AC-009 | 分别在 MySQL 写入测试行、Redis 写入测试键、MinIO 写入测试对象，执行普通 `down` 后重新 `up -d` → 三类数据均可读取，命名卷未被普通停止命令删除。 | Volume |
| AC-010 | 检查 Git 跟踪文件 → `deploy/.env.example` 存在且端口/凭据变量完整，`.env` 被忽略，真实生产 Password/Token/AccessKey 零命中，Compose 中无硬编码生产 Secret。 | Environment/Security |
| AC-011 | 使用 PowerShell 便捷脚本分别执行 start/status/health/stop，并按 README 查看全部或单服务日志 → 脚本退出码与 Compose 结果一致，失败时能在文档化命令中定位对应容器日志。 | Scripts/README |
| AC-012 | 完整执行 up → status/health → down → up → 两次启动均成功，四项服务恢复健康，且 AC-009 的关键数据仍存在。 | Repeatability |
| AC-013 | 在至少一个真实 Java 业务服务上配置本地环境变量 → 产生 Java → MySQL 成功连接、Java → Redis 成功连接、Java → Nacos 注册成功的原始日志/查询证据；不具备的连接入口必须明确记为 PENDING 并关联后续 Requirement。 | Java Integration |
| AC-014 | 检查 Compose 服务清单与实现仓改动 → 不包含 Scope Out 中间件、业务 DDL、业务 Bucket、应用业务功能或 AI 直连业务库能力。 | Scope Guard |

### 5.1 探索待澄清项闭环

| # | 问题 | 本规格决策 | 后续阶段 |
| --- | --- | --- | --- |
| 1 | `deploy/` 落仓 | 工作区根 `deploy/` 为三仓共享权威入口，不在 repo-1 建副本。 | Design 将工作区仓纳入 DU/repository 追踪。 |
| 2 | 镜像与版本 | 必须锁定非 `latest` 的已验证 tag；Nacos 使用与现有 Java 客户端兼容的 Standalone 版本。 | Design 调查并确定精确 tag/鉴权参数，Test 留证。 |
| 3 | 端口终值 | 默认 3306/6379/8848/9000/9001，Nacos 附加端口按客户端必需开放；冲突由 `.env` 显式覆盖。 | Design 给出完整端口表。 |
| 4 | MySQL 初始化 | 预建 8 个空服务库，utf8mb4/Asia-Shanghai，允许本地应用账号，禁止业务 DDL。 | Design 确定最小权限和脚本幂等方式。 |
| 5 | Redis 持久化 | 测试键必须跨普通 down/up 保留。 | Design 选择 AOF/RDB 参数。 |
| 6 | 脚本形态 | Windows + Docker Desktop 为主要验收环境，PowerShell 脚本 P0；原生 Compose 命令必须同时文档化。 | Design 定脚本参数与共享封装。 |
| 7 | Java 联调准入 | 至少一个真实业务服务验证三条连接；现有代码缺口可 PENDING，但不得伪造。 | Design 选联调服务，Test 实测。 |
| 8 | MinIO Bucket | M0 只起服务，不预建业务 Bucket。 | 已闭环。 |
| 9 | Network 名称 | 正式名 `ai-platform-network`，并保留未来应用 Compose 按稳定名称 attach 的可能性。 | Design 确定 Compose network 属性。 |
| 10 | Frontend 边界 | Frontend → Gateway 属于 M0 总验收，不是本 Change DoD。 | 已闭环。 |

## 6. 成功指标

M0 工程基线不度量商业转化类指标，以可观测的交付效果为成功指标：

| 指标 | 目标值 | 观测方式 |
| --- | --- | --- |
| 统一启动覆盖 | 4/4 关键服务由同一 Compose 项目管理 | Compose config/ps Evidence |
| 服务就绪率 | 4/4 关键服务在预定义超时内健康 | Health Evidence |
| 重复启动成功率 | 验收过程中 2/2 次完整启动成功 | AC-012 日志 |
| 关键数据恢复 | MySQL、Redis、MinIO 3/3 持久化验证通过 | AC-009 日志 |
| 真实 Secret 泄露 | Git 跟踪文件 0 个真实 Secret | 安全扫描 Evidence |
| Java 基础连接 | MySQL/Redis/Nacos 有能力入口的项目 100% PASS；其余 100% 有明确 PENDING 原因 | AC-013 日志与报告 |
| 环境复现文档 | 新开发者仅依赖 README + `.env.example` 可完成启停、健康检查与日志查看 | 按文档的独立复验记录 |
