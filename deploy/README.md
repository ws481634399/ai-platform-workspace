# 本地基础设施

该目录是 AI Platform 本地开发环境中 MySQL、Redis、Nacos 和 MinIO 的唯一 Compose 入口。应用默认从宿主机 IDE 运行；这里只管理基础设施，不包含业务服务、业务表或生产部署配置。

## 前置条件

- Docker Desktop 或 Docker Engine 已启动
- `docker info` 与 `docker compose version` 均返回退出码 0
- Windows PowerShell 5.1+ 或 PowerShell 7+

首次使用：

```powershell
Copy-Item .env.example .env
# 仅编辑本机 .env；不要提交该文件，也不要复用生产凭据。
```

`.env.example` 中的值仅用于本地开发。端口冲突时编辑 `.env`，不要修改 Compose、脚本或 README 中的契约。

默认本地账号为 MySQL `mall_local`、MinIO `minio_local`；MySQL/Redis 密码按项目约定为 `123456`。MinIO 强制口令至少 8 位，因此使用最小兼容值 `12345678`。这些弱口令只允许用于隔离的本机开发环境。

## 快速运行

在 `deploy/` 下使用原生命令：

```powershell
docker compose --env-file .env -f docker-compose.infra.yml up -d
docker compose --env-file .env -f docker-compose.infra.yml ps
docker compose --env-file .env -f docker-compose.infra.yml logs --tail 100
docker compose --env-file .env -f docker-compose.infra.yml down
```

或从任意目录使用脚本：

```powershell
./deploy/scripts/infra.ps1 -Action start
./deploy/scripts/infra.ps1 -Action status
./deploy/scripts/infra.ps1 -Action health
./deploy/scripts/infra.ps1 -Action logs -Service nacos
./deploy/scripts/infra.ps1 -Action logs -Service minio -Follow
./deploy/scripts/infra.ps1 -Action restart -Service redis
./deploy/scripts/infra.ps1 -Action stop
```

脚本会显示实际执行的 Docker 命令并透传失败。退出码 `0` 表示成功，`1` 表示 Docker/Compose/健康失败，`2` 表示参数或 `.env` 配置错误。

## 服务契约

| 服务 | 宿主机地址 | 容器网络地址 | 用途 |
| --- | --- | --- | --- |
| MySQL | `localhost:${MYSQL_PORT}`（默认 3306） | `mysql:3306` | 八个 Java 服务空库 |
| Redis | `localhost:${REDIS_PORT}`（默认 6379） | `redis:6379` | 本地缓存基础服务 |
| Nacos Server | `localhost:${NACOS_PORT}`（默认 8848） | `nacos:8848` | Discovery/Config HTTP |
| Nacos gRPC | `localhost:${NACOS_GRPC_PORT}`（默认 9848） | `nacos:9848` | Nacos Client gRPC |
| Nacos Console | `http://localhost:${NACOS_CONSOLE_PORT}`（默认 8849） | `nacos:8080` | Nacos 3 Console |
| MinIO API | `http://localhost:${MINIO_API_PORT}`（默认 9000） | `minio:9000` | S3 API |
| MinIO Console | `http://localhost:${MINIO_CONSOLE_PORT}`（默认 9001） | `minio:9001` | 对象存储控制台 |

所有容器加入 `ai-platform-network`。未来容器化应用可以将该网络声明为 `external: true`；宿主机运行的应用仍使用 `localhost`。

## 健康与排障

`infra.ps1 -Action health` 等待四个容器报告 `healthy`，超时后打印 Compose 状态和失败服务最近 50 行日志。也可以单独检查：

```powershell
./deploy/scripts/infra.ps1 -Action health -Service mysql
docker compose --env-file .env -f docker-compose.infra.yml logs --tail 100 nacos
```

不能把 `running` 当作 ready。Nacos Server 使用 `/nacos/v3/admin/core/state/readiness`，MinIO 使用 `/minio/health/ready`，MySQL 与 Redis 使用带凭据的客户端探针。

## MySQL 初始化边界

首次创建空 MySQL 卷时，`mysql/init/001-init-databases.sh` 创建以下空库并向本地应用账号授权：

`mall_identity`、`mall_member`、`mall_product`、`mall_cart`、`mall_order`、`mall_inventory`、`mall_search`、`mall_system`。

脚本不创建业务表或测试数据；业务表必须由对应服务的 Flyway Migration 管理。初始化脚本只在空卷首次启动时执行，修改脚本后仅 restart 不会重放。

## 数据保留与清理

普通 `stop`/`docker compose down` 不删除命名卷，MySQL、Redis、Nacos 和 MinIO 数据会保留。

> 危险：只有确认本地数据无需保留时，才手动执行 `docker compose --env-file .env -f docker-compose.infra.yml down --volumes`。该操作不可恢复，脚本刻意不提供清卷 Action。

持久化验收使用唯一测试标识，分别写入 MySQL 行、Redis key 和 MinIO object，执行普通 down/up 后逐项读取；完成后删除测试数据而不是删除卷。

## Java 联调

`mall-identity` 从宿主机运行时使用：

```text
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_DB_IDENTITY=mall_identity
MYSQL_USER=mall_local
MYSQL_PASSWORD=<与本机 .env 一致>
FLYWAY_ENABLED=true
NACOS_ADDR=localhost:8848
NACOS_ENABLED=true
```

验收必须保留 Hikari/Flyway 成功连接和 Nacos healthy instance 的原始证据。当前 `mall-identity` 未接入公共 Redis 模块或 Redis properties，因此 Java → Redis 必须记录为 PENDING，并附 POM/配置文件事实；容器 `PING` 不能代替 Java 客户端连接证据。

## 范围与安全

- 本 Compose 不包含 RocketMQ、Elasticsearch、Vector Database、监控、日志、Nginx 或应用容器。
- 不预建 MinIO 业务 Bucket，不在 MySQL init 中维护业务 DDL。
- Nacos Auth 默认关闭只适用于单机本地开发，禁止照搬到共享或生产环境。
- 日志和 Evidence 不得输出密码、Token 或 Access Key；记录命令时对值脱敏。
