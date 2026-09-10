# Tasks（Repository Delivery Decomposition Plan）

> 阶段：sdd-task 产物
> 位置：STORY 级
> 输入：spec.md + design.md + .sdd/repositories.yaml + feature-path
> 产出状态：tasked

本文档消费 `design.md` §6 已冻结的 DU 划分，只细化各 DU 的实现指导、任务和验证绑定，不新增或改号 DU。

## 0. 元信息

- Change ID: CHG-0006
- Design 来源: `delivery/changes/CHG-0006/工程基础/本地基础设施/环境与运行时/建立本地基础设施环境/design.md`
- 状态流转: designed → tasked
- Feature Path: 工程基础 > 本地基础设施 > 环境与运行时 > 建立本地基础设施环境
- DU 总数: 3

### 0.1 完成后所有权纠偏

2026-09-09 用户确认实现资产应归属独立基础设施仓。三个 DU 保留原 ID，但目标仓统一由 `repo-workspace` 调整为 `repo-4`；Repository Delivery 位于该仓自身的 `delivery/CHG-0006/`。

## 任务清单

### DU-WS-001：Compose、环境变量、网络、卷与 MySQL/Redis 基线

- 目标仓库: repo-4
- 目标 Goal: 建立四服务共享 Compose 的声明式底座，并交付 MySQL/Redis 可启动、可鉴权、可持久化的基础配置。
- Scope（范围）: `deploy/docker-compose.infra.yml`、`deploy/.env.example`、`deploy/.gitignore`、`deploy/.gitattributes`、`deploy/mysql/init/001-init-databases.sh`
- Design References: `design.md` §2.2～§2.6、§3.1、§4 Data Contract、§5.1
- Dependencies: 无
- Acceptance Criteria: AC-002、AC-004、AC-005、AC-008、AC-010、AC-014
- Execution Order: 1
- Parallelization: 串行基线；完成后 DU-WS-002 才能开始
- verifies: TC-002、TC-004、TC-005、TC-008、TC-010、TC-014
- Implementation Tasks:
  - T-WS-001-01（verifies: TC-002、TC-008、TC-014）：创建单一 Compose，锁定四个镜像 tag、显式服务名、端口、`ai-platform-network`、命名卷及 `unless-stopped`；不得加入 Scope Out 服务。
  - T-WS-001-02（verifies: TC-004、TC-005）：配置 MySQL utf8mb4/时区/healthcheck 与 Redis 密码/AOF/healthcheck，所有凭据从环境变量读取。
  - T-WS-001-03（verifies: TC-004）：创建 LF 格式的幂等 MySQL 初始化脚本，只建 8 个空库和最小权限本地账号，禁止业务 DDL/DML。
  - T-WS-001-04（verifies: TC-010）：提交完整 `.env.example`、忽略 `.env`、强制 shell 脚本 LF，并用 `docker compose config` 与 Git Secret 静态扫描验证。
- Implementation Sketch:

  ```text
  deploy/.env（本地、不跟踪）
        ↓ Compose interpolation（密码字段 required）
  docker-compose.infra.yml
        ├── mysql ── mysql-data ── 001-init-databases.sh
        ├── redis ── redis-data（AOF everysec）
        ├── nacos ── nacos-data/nacos-logs
        └── minio ── minio-data
                    ↓
             ai-platform-network

  配置缺失 → Compose config/up 非零退出；不使用默认空 Secret 继续启动。
  ```

- Pseudocode: N/A（本 DU 为 Compose、环境模板与幂等建库脚本的声明式配置，不包含复杂业务流程、算法、状态转换或多组件运行编排。）
- Verification:
  - Static: `docker compose --env-file .env -f docker-compose.infra.yml config` 成功，服务集合精确为 MySQL/Redis/Nacos/MinIO，镜像无 `latest`。
  - Integration: MySQL `SELECT 1`、8 库字符集检查；Redis 正确密码 `PONG`、错误密码鉴权失败；容器间四个服务名可解析。
  - Security: `.env` 被 Git 忽略，跟踪文件不含真实生产 Secret，Compose 不硬编码密码。
  - Error Case: 缺失必填变量时 config/up 必须失败；初始化脚本出现业务 `CREATE TABLE` 或 DML 时验收失败。

### DU-WS-002：Nacos/MinIO 就绪、PowerShell 入口与运行文档

- 目标仓库: repo-4
- 目标 Goal: 在既有 Compose 基线上补齐 Nacos 3.0.3、MinIO 和四服务真实就绪判定，提供可诊断的 Windows 运行入口及等价原生命令。
- Scope（范围）: `deploy/docker-compose.infra.yml`、`deploy/scripts/infra.ps1`、`deploy/README.md`
- Design References: `design.md` §2.3～§2.5、§2.7、§3.1、§4 Cross-Repository Sequence、§5.2
- Dependencies: DU-WS-001
- Acceptance Criteria: AC-003、AC-006、AC-007、AC-011
- Execution Order: 2
- Parallelization: DU-WS-001 完成后执行；Nacos/MinIO 配置与脚本骨架可在本 DU 内并行，最终统一联调
- verifies: TC-003、TC-006、TC-007、TC-011
- Implementation Tasks:
  - T-WS-002-01（verifies: TC-003、TC-006）：配置 Nacos Standalone、8848/9848/8849 端口、数据/日志卷和 Server/Console v3 readiness。
  - T-WS-002-02（verifies: TC-003、TC-007）：配置 MinIO API/Console、根凭据、数据卷和 `/minio/health/ready`，不得预建业务 Bucket。
  - T-WS-002-03（verifies: TC-003、TC-011）：实现 `infra.ps1` 的 start/stop/restart/status/health/logs；脚本固定从 `deploy/` 执行、显示命令、透传错误且默认不删除卷。
  - T-WS-002-04（verifies: TC-006、TC-007、TC-011）：编写 README，覆盖环境准备、端口、凭据、原生 Compose 等价命令、健康超时、日志排障、旧卷初始化语义和显式数据销毁警告。
- Implementation Sketch:

  ```text
  Developer → infra.ps1(action, service?, follow?)
                    ↓ validate .env / Docker / arguments
             docker compose -f docker-compose.infra.yml
                    ↓
       ps + container healthchecks + service readiness
          ├── Nacos Server/Console v3 endpoints
          ├── MinIO ready endpoint
          ├── MySQL mysqladmin ping
          └── Redis authenticated PING
                    ↓
       success: exit 0 | operational failure: exit 1
       invalid input/missing .env: exit 2 + actionable message
  ```

- Pseudocode:

  ```text
  run(action, service, follow):
      locate deploy directory relative to script
      validate action and optional service; if invalid return 2
      if action requires runtime and .env or Docker is unavailable: explain and return 2/1
      print the exact docker compose command
      execute action:
          start: compose up -d; on success show ps
          stop: compose down without --volumes
          restart: restart all or selected service
          status: compose ps for all or selected service
          logs: compose logs with optional service/follow
          health:
              poll requested services until timeout
              if all are healthy return 0
              otherwise print compose ps and recent failing-service logs; return 1
      preserve stderr and propagate operational failure
  ```

- Verification:
  - Integration: Nacos Server/Console readiness、Standalone 模式、MinIO ready endpoint 与 Console 登录均通过。
  - Script: 六个 Action 的成功路径、非法 Action/Service、缺失 `.env`、Docker 不可用、服务超时路径均验证退出码和可诊断输出。
  - Documentation: 按 README 从空环境执行原生命令和脚本命令，结果一致；普通 stop/down 不出现 `--volumes`。
  - Error Case: readiness 失败时不得报告 healthy，且必须输出对应服务最近日志。

### DU-WS-003：持久化、重复运行与 Java 真实联调证据

- 目标仓库: repo-4
- 目标 Goal: 按冻结的验证链执行真实环境验收，证明数据跨普通 down/up 恢复，并用 `mall-identity` 收集 Java → MySQL/Nacos 证据及 Redis PENDING 事实。
- Scope（范围）: `deploy/README.md` 的验收说明、物化后 DU-WS-003 `evidence/`、`implementation/mall-backend-microservices` 只读联调
- Design References: `design.md` §1.1～§1.2、§2.8～§2.9、§3.2、§4 Cross-Repository Sequence、§5.2
- Dependencies: DU-WS-001、DU-WS-002
- Acceptance Criteria: AC-001、AC-009、AC-012、AC-013
- Execution Order: 3
- Parallelization: 前两 DU 完成后执行；数据恢复验证与 Java 联调共享同一健康环境，按顺序避免证据污染
- verifies: TC-001、TC-009、TC-012、TC-013
- Implementation Tasks:
  - T-WS-003-01（verifies: TC-001）：记录 Docker CLI、Compose、Engine 的原始版本与退出码；Engine 未启动时如实阻断后续运行测试。
  - T-WS-003-02（verifies: TC-009）：为 MySQL/Redis/MinIO 写入唯一 fixture，普通 down/up 后复查三类数据及命名卷，随后清理测试数据但不删卷。
  - T-WS-003-03（verifies: TC-012）：执行完整 up → status/health → down → up → health 两轮链路，保存时间、命令、退出码、ps 与日志。
  - T-WS-003-04（verifies: TC-013）：以宿主机变量启动 `mall-identity`，记录 MySQL 连接和 Nacos healthy instance；通过 POM/配置事实证明 Redis 尚无入口并标记 PENDING，不修改 repo-1。
  - T-WS-003-05（verifies: TC-001、TC-009、TC-012、TC-013）：在物化 DU 的 `evidence/` 中登记 Environment、Compose/Pull、Startup、Ready、Network、Persistence、Security、Java Integration 八组 Evidence，严禁未执行命令标 PASS。
- Implementation Sketch:

  ```text
  Docker preflight PASS
       ↓
  pull/config/up → four-service health PASS
       ↓
  write unique MySQL/Redis/MinIO fixtures
       ↓
  down(no volumes) → up → health → read fixtures
       ↓
  mall-identity(localhost ports)
       ├── MySQL connection/Flyway/Hikari evidence
       ├── Nacos healthy registration evidence
       └── Redis code-entry inspection → PENDING evidence
       ↓
  raw logs + evidence.yaml; any unexecuted/failed check stays FAIL/PENDING
  ```

- Pseudocode:

  ```text
  verify_environment():
      run docker info and docker compose version; record command/output/exit code
      if Docker Engine unavailable: mark blocked and stop without fabricated runtime results

  verify_repeatability():
      compose pull/config/up; wait for all services healthy or fail with logs
      write unique mysql row, redis key, minio object; record identifiers
      compose down without volumes
      compose up; wait for all services healthy
      read all three fixtures; if any differs mark TC-009 and TC-012 failed

  verify_java_integration():
      start mall-identity with localhost MySQL/Nacos variables
      require successful DB connection and healthy Nacos registration evidence
      inspect current dependency/config entry points for Redis
      if no Redis client entry exists: record PENDING with file facts and follow-up requirement
      never substitute container PING for Java client evidence
  ```

- Verification:
  - Environment: Docker/Compose 版本和 Engine 状态均保留原始输出、时间与退出码。
  - Persistence/E2E: MySQL 行、Redis 键、MinIO 对象跨普通 down/up 可读；两轮四服务均健康。
  - Java Integration: `mall-identity` 的 Hikari/Flyway 无连接异常，Nacos 服务列表存在 healthy instance；Redis 项为带代码证据的 PENDING。
  - Error Case: Docker 不可用、镜像拉取失败、任一数据未恢复或 Java 注册失败时保持 FAIL/PENDING，输出最近日志且不扩大范围修改 repo-1。

## 覆盖率矩阵

| Design/Spec 范围 | 归属 DU | 验证用例 |
| --- | --- | --- |
| Compose、环境变量、镜像、网络、卷、MySQL/Redis、八库、Secret、范围守卫 | DU-WS-001 | TC-002、TC-004、TC-005、TC-008、TC-010、TC-014 |
| Nacos、MinIO、四服务 readiness、PowerShell 与 README | DU-WS-002 | TC-003、TC-006、TC-007、TC-011 |
| Docker 前置、持久化、两轮重建、Java MySQL/Nacos/Redis PENDING Evidence | DU-WS-003 | TC-001、TC-009、TC-012、TC-013 |

affected-repositories 修订为 `[repo-4]`，三个 DU 均一对一归属该仓。AC-001～AC-014 全部有 DU 和 TC，依赖仅为 `DU-WS-001 → DU-WS-002 → DU-WS-003`，无循环。

## 依赖与跨仓契约

- `repo-4` 是唯一写入仓；`implementation/ai-platform-backend` 仅作为 `mall-identity` 联调对象读取和运行，不产生 repo-1 DU 或源代码改动。
- 基础设施契约先冻结并健康，再启动 Java；基础设施失败时不得继续 Java 联调。
- 宿主机应用使用 `localhost:<mapped-port>`，容器间使用服务名和容器端口；本 Change 不新增 HTTP/Event Contract 或业务 Migration。

## 风险缓解映射到 DU

| 风险 | 负责 DU | 缓解与验证 |
| --- | --- | --- |
| Nacos 3 端口/readiness 混用 | DU-WS-002 | 固定 8848/9848/8849 与 v3 endpoints，TC-006 |
| Docker Engine/registry 不可用 | DU-WS-003 | preflight/pull 失败即阻断并留原始证据，TC-001 |
| CRLF 破坏 MySQL init | DU-WS-001 | `.gitattributes` 强制 LF，新卷验证八库，TC-004 |
| Secret 泄露 | DU-WS-001 | `.env` ignore、required interpolation、跟踪文件扫描，TC-010 |
| 普通 down 误删数据 | DU-WS-002、DU-WS-003 | 默认脚本不传 `--volumes`，持久化恢复，TC-009/TC-012 |
| Java Redis 无入口 | DU-WS-003 | 代码事实 + PENDING，不伪造 PASS，TC-013 |
| 独立仓远程暂时不可达 | DU-WS-003 | 本地仓与 origin 已建立；保留网络失败事实，待网络恢复后推送 |

## 全局检查清单

- [x] 3 个 DU 均来自 `design.md` §6，ID、仓库、AC 与依赖未改号或越界。
- [x] 每个 DU 均有 Goal、Scope、Implementation Tasks、Sketch、Pseudocode 判定和 Verification。
- [x] DU-WS-002/003 命中 `orchestration` 并包含主流程与异常分支伪代码；DU-WS-001 明确 N/A 理由。
- [x] 14 条 AC 均映射到至少一个 DU 与一个 TC；所有任务都有 `verifies`。
- [x] 依赖单向无环，且只写 repo-4；repo-1 保持只读联调。
- [x] 未修改 spec.md/design.md，未写实现代码，未提前物化 Repository Delivery。

