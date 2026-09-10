---
affected-repositories: [repo-4]
---

# Design

> 阶段：sdd-design 产物
> 输入：`delivery/changes/CHG-0006/工程基础/本地基础设施/环境与运行时/建立本地基础设施环境/spec.md`
> 产出状态：designed（草稿待人工确认）

本文档定义 M0 本地基础设施的 Compose 架构、配置契约、健康检查、持久化、运行脚本与 Java 联调方案。Design 只定义系统方案和契约，不修改 `implementation/`，不编写实施级伪代码。

## 0. 元信息

- Change ID: CHG-0006
- Spec 来源: `delivery/changes/CHG-0006/工程基础/本地基础设施/环境与运行时/建立本地基础设施环境/spec.md`
- 状态流转: specified → designed
- 影响的已登记仓: repo-4（路径 `implementation/ai-platform-infrastructure`）
- 基础设施仓远程: `https://github.com/ws481634399/ai-platform-infrastructure.git`
- 受影响的已登记仓数: 1
- 是否需要业务数据库 Migration: no
- 是否需要基础设施初始化: yes（只创建空 Database/本地账号，不创建业务表）

## 1. 当前状态

### 1.0 完成后所有权纠偏（2026-09-09）

用户确认 `deploy/` 属于独立实现仓，而不是 Workspace 治理仓。本文后续早期记录中的“工作区根 deploy / repo-workspace”由本修订覆盖：实现与 Repository Delivery 已迁入 `implementation/ai-platform-infrastructure`，仓库登记为 `repo-4`。DU 编号 `DU-WS-*` 为保持已形成的证据引用与审计连续性不改号，其 `repository` 字段统一改为 `repo-4`。

### 1.1 工作区与仓库

| 对象 | 当前事实 | 设计影响 |
| --- | --- | --- |
| 工作区 Git 根 | 只管理 SDD/standards/product/delivery，不承载 `deploy/` | 登记并引用独立基础设施仓 |
| repo-1 Backend | Spring Boot 3.5.15 / Spring Cloud 2025.0.3 / SCA 2025.0.0.0；8 个服务已预留 MySQL/Nacos 变量 | 只作为运行时联调对象，本设计不改 Java 代码 |
| repo-2 Frontend | mall-web/mall-admin 基线已交付 | 不受影响，Frontend → Gateway 属 M0 总验收 |
| repo-3 AI Service | FastAPI 工程基线已交付且无基础设施强依赖 | 不修改，禁止直连 Java 业务库 |

repo-1 的实际连接点：

- `mall-services/*/src/main/resources/application.yml`：`MYSQL_HOST`、`MYSQL_PORT`、`MYSQL_DB_<SERVICE>`、`MYSQL_USER`、`MYSQL_PASSWORD`、`FLYWAY_ENABLED`。
- `mall-gateway` 与 8 个业务服务：`NACOS_ADDR`、`NACOS_ENABLED`。
- `mall-common/mall-common-redis`：已有 `spring-boot-starter-data-redis`，但当前业务服务 POM 未引入该模块，也无 Redis 运行配置；因此 Java → Redis 在不修改 repo-1 的前提下必须记为 PENDING。

### 1.2 本机运行环境

- Docker CLI: 29.4.0
- Docker Compose: v5.1.1
- Docker Engine: 当前未启动（Windows named pipe 不存在）
- 结论: Design 可完成静态方案；镜像拉取、Compose 解析与容器验证必须在 Dev/Test 启动 Docker Engine 后形成 Evidence。

### 1.3 现有规范约束

- `standards/engineering/backend/framework-standard.md`：基础设施使用官方推荐方式，配置集中、环境隔离，新依赖需评估。
- `standards/engineering/database-standard.md`：数据库权限最小化，业务结构变更必须通过 Migration。
- `standards/security-guidelines.md` 与 `standards/git-conventions.md`：Secret 从环境变量读取，`.env` 不进 Git，日志不输出密码/Token。

## 2. 提议方案

采用“独立基础设施仓单一 Compose 权威 + 四服务独立就绪检查 + 显式命名卷 + 环境变量契约 + PowerShell 轻量入口”方案。应用仍从 IDE/宿主机运行，基础设施不反向感知 Java、Frontend 或 AI 业务配置。

## 2.1 备选方案对比（Alternatives Considered）

| 方案 | 优点 | 代价/风险 | 结论 |
| --- | --- | --- | --- |
| A. 独立基础设施仓维护单一 `deploy/` | 四仓共享，运行资产与 Workspace 治理资产分离，无复制漂移 | 增加一个独立 Git 仓的版本协作 | **采用：已登记 repo-4** |
| B. 放入 repo-1 | 与 Java 联调距离近，可直接绑定 repo-1 | 基础设施被误解为 Java 私有，Frontend/AI 共享契约不对称，违反已确认 spec | 不采用 |
| C. 三仓各存一份 Compose | 每仓可独立拉起 | 版本、端口、账号和卷契约必然漂移 | 禁止 |
| D. 开发机手工安装中间件 | 无镜像拉取 | 无法复现，直接违反 REQ-M0-004 | 禁止 |

### 2.2 目标目录与职责

```text
deploy/
├── docker-compose.infra.yml     # 四项服务、网络、卷、healthcheck 权威
├── .env.example                 # 全部可配置项与本地示例值
├── .gitignore                   # 至少忽略 .env
├── .gitattributes               # *.sh 保持 LF，防止 Windows CRLF 破坏容器初始化
├── README.md                     # 启停、端口、凭据、日志、清理与联调说明
├── mysql/
│   └── init/
│       └── 001-init-databases.sh # 幂等建库/本地账号/授权，无业务 DDL
└── scripts/
    └── infra.ps1                # start/stop/restart/status/health/logs 轻量封装
```

不创建 `redis/`、`nacos/`、`minio/` 空目录；其配置能在 Compose 中清晰表达时直接维护，避免形式性文件。

### 2.3 镜像与兼容性基线

| 服务 | 锁定镜像 | 选择依据 |
| --- | --- | --- |
| MySQL | `mysql:8.4.11` | MySQL 8.4 LTS 系列，与 Connector/J 及现有 JDBC URL 兼容；使用官方镜像的初始化入口 |
| Redis | `redis:7.4.11-alpine` | 官方固定 patch tag，Spring Data Redis/Lettuce 基础命令兼容，镜像体积小 |
| Nacos | `nacos/nacos-server:v3.0.3` | repo-1 的 SCA 2025.0.0.0 官方组件矩阵对应 Nacos Client 3.0.3；Server 同版降低协议偏差 |
| MinIO | `quay.io/minio/minio:RELEASE.2025-06-13T11-33-47Z` | MinIO 官方容器文档标记的稳定发布，锁定 RELEASE 而非漂移 tag |

实施时必须先执行 `docker pull`和 `docker image inspect`；如任一 tag 无法从官方 registry 获得，停止实施并更新 Design，不得自动改用 `latest`。进一步的 digest 锁定在首次成功拉取后记录到 Evidence，本地 Compose 仍保留可读 tag。

### 2.4 Compose 服务设计

| 服务名 | 运行模式 | 持久路径 | 就绪检查 | 重启策略 |
| --- | --- | --- | --- | --- |
| `mysql` | MySQL 8.4 LTS，utf8mb4，`Asia/Shanghai` | `mysql-data:/var/lib/mysql` | `mysqladmin ping` 使用 root 本地凭据 | `unless-stopped` |
| `redis` | 密码鉴权，AOF `appendonly yes` + `appendfsync everysec` | `redis-data:/data` | 带密码的 `redis-cli ping` 必须返回 `PONG` | `unless-stopped` |
| `nacos` | `MODE=standalone`，内置 Derby，本地默认不开启 Client Auth | `nacos-data:/home/nacos/data` + `nacos-logs:/home/nacos/logs` | Server `/nacos/v3/admin/core/state/readiness`；Console `/v3/console/health/readiness` | `unless-stopped` |
| `minio` | 单节点 `server /data --console-address :9001` | `minio-data:/data` | `GET /minio/health/ready` 返回 HTTP 200 | `unless-stopped` |

网络采用 Compose 托管的 bridge network，顶层显式 `name: ai-platform-network`。首次 `up` 自动创建，未来应用 Compose 可以用 `external: true` 按同名 attach；本 Change 不建应用 Compose。

卷使用稳定显式名：`ai-platform-mysql-data`、`ai-platform-redis-data`、`ai-platform-nacos-data`、`ai-platform-nacos-logs`、`ai-platform-minio-data`。普通 stop/down 不携带 `--volumes`；数据销毁必须是 README 中分离的显式危险操作，不由默认脚本提供。

### 2.5 端口与环境变量契约

| 服务 | 容器端口 | 默认宿主机端口 | `.env.example` 变量 |
| --- | --- | --- | --- |
| MySQL | 3306 | 3306 | `MYSQL_PORT`、`MYSQL_ROOT_PASSWORD`、`MYSQL_USER`、`MYSQL_PASSWORD` |
| Redis | 6379 | 6379 | `REDIS_PORT`、`REDIS_PASSWORD` |
| Nacos Server HTTP | 8848 | 8848 | `NACOS_PORT` |
| Nacos Client gRPC | 9848 | 9848 | `NACOS_GRPC_PORT` |
| Nacos Console（3.x 独立） | 8080 | **8849** | `NACOS_CONSOLE_PORT`（避开 mall-gateway 8080） |
| MinIO API | 9000 | 9000 | `MINIO_API_PORT`、`MINIO_ROOT_USER`、`MINIO_ROOT_PASSWORD` |
| MinIO Console | 9001 | 9001 | `MINIO_CONSOLE_PORT` |

通用变量还包括 `COMPOSE_PROJECT_NAME=ai-platform-infra`、`TZ=Asia/Shanghai`、`NACOS_AUTH_ENABLE=false`、`NACOS_AUTH_TOKEN`、`NACOS_AUTH_IDENTITY_KEY`、`NACOS_AUTH_IDENTITY_VALUE`。Nacos Auth 关闭仅适用本地开发，README 必须明示禁止复用到共享/生产环境。

Compose 变量引用对密码类字段使用 required interpolation（`${VAR:?message}`），避免空密码静默启动。`.env.example` 的值是明确标注的 Local Development 示例，不得是任何真实外部环境凭据。

### 2.6 MySQL 初始化与数据边界

`001-init-databases.sh` 由 MySQL 官方镜像的 `/docker-entrypoint-initdb.d/` 仅在空卷初始化时执行，必须幂等创建以下空库：

```text
mall_identity  mall_member  mall_product  mall_cart
mall_order     mall_inventory  mall_search  mall_system
```

每个库使用 `utf8mb4`，collation 采用 MySQL 8.4 默认的 `utf8mb4_0900_ai_ci`。初始化脚本通过环境变量建立本地应用账号，仅授权这 8 个库，不授予全局管理权限。不创建 `nacos` 库，因为本地 Nacos 采用独立 Derby；不包含任何 `CREATE TABLE`、测试数据或业务 DML。

脚本用 LF 提交并在首行启用严格失败处理。已存在非空 MySQL 卷时，修改 init 文件不会自动重放；README 必须说明“初始化脚本只对新卷生效”。

### 2.7 PowerShell 运行接口

单一入口：

```text
./scripts/infra.ps1 -Action <start|stop|restart|status|health|logs> [-Service <mysql|redis|nacos|minio>] [-Follow]
```

| Action | 输入 | 输出 | 错误/退出码 |
| --- | --- | --- | --- |
| `start` | 无服务参数 | 执行 `up -d`，打印 ps | 0 成功；1 Docker/Compose 失败；2 `.env` 缺失/参数无效 |
| `stop` | 无服务参数 | 执行 `down`，不删卷 | 0/1/2 |
| `restart` | 可选 Service | 重启全部或单服务 | 0/1/2 |
| `status` | 可选 Service | 输出 Compose `ps` | 0 命令成功；1 命令失败 |
| `health` | 可选 Service | 等待并列出各服务 health，超时时打印最近日志 | 0 全部健康；1 任一不健康；2 参数无效 |
| `logs` | 可选 Service/Follow | 全部或单服务日志 | Compose 退出码原样透传 |

脚本先将工作目录定位到 `deploy/`，不依赖调用者当前目录；必须显示底层 Compose 命令，不捕获后吞掉 stderr。README 同时给出完全等价的原生 `docker compose -f docker-compose.infra.yml ...` 命令。

### 2.8 健康、重建与 Evidence 数据流

```text
.env.example → 开发者复制为 .env
       ↓
docker-compose.infra.yml → pull/create network + volumes → start 4 services
       ↓
container healthchecks → infra.ps1 health 汇总 → ps/logs 排障
       ↓
client probes + persistence fixtures → down/up → re-read fixtures
       ↓
Java mall-identity 启动联调 → MySQL PASS + Nacos PASS + Redis PENDING(现有代码缺口)
```

测试证据分为：Environment、Compose Config/Pull、Startup/Status、四服务 Ready、Network DNS、Persistence、Security Scan、Java Integration 八组。每组保留原始命令、时间、退出码和日志路径。

### 2.9 Java 联调契约

选择 `mall-identity` 作为最小真实联调服务：

| 契约 | 值/方法 | PASS 证据 |
| --- | --- | --- |
| MySQL | `MYSQL_HOST=localhost`、`MYSQL_PORT`、`MYSQL_DB_IDENTITY=mall_identity`、`MYSQL_USER`、`MYSQL_PASSWORD`、`FLYWAY_ENABLED=true` | Spring/Flyway/Hikari 成功建立真实 MySQL 连接，无连接异常 |
| Nacos | `NACOS_ADDR=localhost:8848`、`NACOS_ENABLED=true` | Nacos 服务列表中 `mall-identity` 存在 healthy instance，Java 日志无注册失败 |
| Redis | 现有 `mall-identity` 无 `mall-common-redis` 依赖和 Redis properties | **PENDING**：不改 repo-1 业务工程来伪造连接；关联后续 Java Redis 接入 Requirement |

应用从宿主机/IDE 运行，因此使用 `localhost` 和宿主机映射端口；未来容器化应用 attach `ai-platform-network` 时才改用 Compose 服务名。

## 3. 仓库影响（Repository Impact）

### 3.1 repo-4（独立基础设施仓）

- 技术职责: 作为 Backend、Frontend、AI Service 共享本地基础设施契约的唯一写入方。
- 修改概要: 新增 §2.2 所列 `deploy/` 资产。
- 追踪契约: `.sdd/repositories.yaml`、Change metadata 与 DU metadata 均使用 `repo-4`；历史 DU ID 保留 `WS` 后缀以保持引用连续。

### 3.2 repo-1（只读联调目标）

- 技术职责: 使用已有 MySQL/Nacos 配置点执行 AC-013 联调。
- 修改概要: 无代码、POM、配置或数据迁移修改。
- 限制: Redis 缺口记 PENDING，不扩大本 Change 去修改 Java 工程。

repo-2 与 repo-3 无修改、无运行时强依赖，不列入影响仓。

## 4. 跨仓协作（Cross-Repository Contract）

- **API Contract**: 无新增 HTTP API。Java 与基础设施使用标准 MySQL/Redis/Nacos 协议，联调变量见 §2.9。
- **Event Contract**: 无；本 Change 不引入 MQ。
- **Data Contract**: repo-4 拥有 Compose/环境变量契约；repo-1 各服务拥有各自 Database 的业务表和 Flyway 写权；Docker init 只建库与授权；repo-3 不得读写这些库。
- **Repository Dependencies**: repo-4 `deploy/` 是运行时上游；repo-1 联调时依赖其端口与凭据契约。repo-2/repo-3 本期无依赖。
- **Integration Boundary**: 宿主机运行 Java 使用 `localhost:<mapped-port>`；容器间使用 `mysql/redis/nacos/minio:<container-port>`；禁止固定宿主机 IP。
- **Cross-Repository Sequence**: 先冻结 `.env.example` 和 Compose 契约 → 启动并完成容器验证 → 再按 §2.9 启动 `mall-identity` 联调。基础设施失败时不启动 Java；Java 联调失败不回滚已验证的容器配置，而是根据日志判定契约或应用问题。

## 5. 风险

### 5.1 数据变更结论

- 业务 Migration: **no**。
- 基础设施初始化: **yes**，仅对空 MySQL 卷幂等建立 8 个空库和本地账号授权。
- 回滚: Compose 文件回滚不自动删卷；若初始化失败，开发阶段可在确认无需保留数据后手动重建指定本地卷。默认 stop/down 绝不执行数据回滚。

### 5.2 风险矩阵

| 风险项 | 级别 | 触发条件 | 缓解措施 |
| --- | --- | --- | --- |
| Nacos 3 端口/路径与 2.x 经验混用 | 高 | 把 Console 错当 8848，或未映射 9848 导致 Client gRPC 失败 | 锁定 3.0.3，显式映射 8848/9848，Console container 8080 → host 8849，使用 v3 readiness |
| Docker Engine 当前未启动 | 高 | Dev/Test 无法 pull/up | 实施首个检查点执行 `docker info`；未就绪则如实阻断，不伪造 Evidence |
| 镜像 tag 或 registry 可用性 | 中 | 网络、registry 或历史 MinIO RELEASE 不可获取 | 开发前单独 pull/inspect，失败则回到 Design 更新明确 tag，禁止改 `latest` |
| Windows CRLF 破坏 MySQL init shell | 中 | entrypoint 报 `bad interpreter` 或脚本未执行 | `deploy/.gitattributes` 强制 `*.sh text eol=lf`，Test 在新卷验证 8 库 |
| `.env` 或密码泄露 | 高 | 本地凭据误入 Git/日志 | deploy 和根忽略双重检查；Git 跟踪文件扫描；脚本不输出密码值 |
| `down --volumes` 导致开发数据丢失 | 高 | 用户误用危险命令 | 默认脚本不提供删卷 Action；README 将销毁操作独立标为不可恢复 |
| MySQL init 修改对旧卷不生效 | 中 | 修改库列表后仅 restart | README 明示首次初始化语义；Test 用全新项目名/卷验证 |
| Redis AOF 额外写入与磁盘体积 | 低 | 本地长期写入大量键 | `everysec` 在持久性/开销间折中；README 给出手动清理说明 |
| MinIO 版本/许可证演进 | 中 | 将本地开源镜像直接演进为生产部署 | 本 Change 仅限本地 M0；生产选型、许可证和升级必须新建 Change |
| Java → Redis 无现有入口 | 中 | AC-013 无法三项全 PASS | 明确 PENDING 并记录 repo-1 当前 POM/配置证据；不扩大本 Change |
| 基础设施仓远程地址漂移 | 中 | 本地 origin 或 `.sdd/repositories.yaml` 与正式地址不一致 | 两处统一为 `https://github.com/ws481634399/ai-platform-infrastructure.git`，doctor/Git remote 双重核对 |

## 6. DU 划分（Delivery Units）

> Harness 0.4 将交付单元的权威划分前移到 Design。完成后纠偏保持 DU 编号不变，仅将所有权迁移到已登记的 `repo-4`。

| DU | 仓库 | 职责（实现的设计范围） | covers AC | depends on |
| --- | --- | --- | --- | --- |
| DU-WS-001 | repo-4 | Compose/环境变量/网络/命名卷基线，MySQL/Redis 及幂等建库 | AC-002, AC-004, AC-005, AC-008, AC-010, AC-014 | — |
| DU-WS-002 | repo-4 | Nacos 3.0.3、MinIO、四服务 readiness，PowerShell 运行入口与 README | AC-003, AC-006, AC-007, AC-011 | DU-WS-001 |
| DU-WS-003 | repo-4 | 环境前置、数据持久化、up/down/up 可重复性、Java MySQL/Nacos 联调与 Redis PENDING 证据 | AC-001, AC-009, AC-012, AC-013 | DU-WS-001, DU-WS-002 |

划分依据：三个单元均只写入独立基础设施仓；第一单元可以用 Compose config + MySQL/Redis 探针独立红绿，第二单元可用 Nacos/MinIO readiness + 脚本退出码独立红绿，第三单元以完整运行链与联调 Evidence 独立收口；依赖是单向无环的基线 → 服务 → 验证。

## 8. 待澄清问题

业务、技术和流程方案的阻塞性待澄清项数量为 **0**。用户已确认基础设施远程地址，`repo-4` 已登记并与 Design/Change metadata 对齐。

非阻塞的实测项：Docker Engine 启动后确认四个镜像 tag 可拉取、镜像内 healthcheck 所需命令可用、Nacos 3.0.3 的 Server/Console readiness 路径按预期返回。这些是 Dev/Test Evidence，不改变本设计的契约。

## 9. 验收覆盖映射

| Spec AC | Design 落点 |
| --- | --- |
| AC-001 | §1.2 环境前置，§2.7 脚本错误码 |
| AC-002 | §2.2 目录，§2.4 Compose 服务 |
| AC-003 | §2.4 四项 readiness，§2.7 `health` |
| AC-004 | §2.4 MySQL，§2.6 幂等建库 |
| AC-005 | §2.4 Redis 鉴权/health |
| AC-006 | §2.3 Nacos 3.0.3，§2.4 v3 readiness，§2.5 端口 |
| AC-007 | §2.3 MinIO RELEASE，§2.4 ready endpoint |
| AC-008 | §2.4 `ai-platform-network` 和服务名 |
| AC-009 | §2.4 命名卷/Redis AOF，§2.8 重建数据流 |
| AC-010 | §2.2 `.gitignore`，§2.5 required env，§5 安全风险 |
| AC-011 | §2.7 PowerShell 入口、输出和退出码 |
| AC-012 | §2.8 up/down/up 数据流 |
| AC-013 | §1.1 现有连接点，§2.9 `mall-identity` 联调/PENDING 边界 |
| AC-014 | §2.2 最小目录，§2.6 无业务 DDL，§3 仓库影响 |
