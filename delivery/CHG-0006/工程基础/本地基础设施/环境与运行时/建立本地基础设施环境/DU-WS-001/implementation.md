# DU Implementation — DU-WS-001

> DU 级实施记录（Actual Implementation，sdd-dev 绑定本 DU 产出）。实施正文归属本仓库，Workspace 仅保留引用。
> 本文件固定为 Actual Implementation（实际修改模块/文件、Commit、Task/DU Mapping、实现偏离、完成情况），
> 与 task.md（Expected Implementation）分立，不得合并。

## 变更内容

- 新增 `deploy/docker-compose.infra.yml`，统一编排 MySQL 8.4.11、Redis 7.4.11、Nacos 3.0.3、MinIO 固定 RELEASE。
- 新增 `.env.example`、deploy 级 ignore/attributes、五个命名卷和 `ai-platform-network`。
- 新增幂等 MySQL 初始化脚本，仅创建八个 utf8mb4 空库并授权 `mall_local`。
- MySQL/Redis 本地密码按用户要求为 `123456`；MinIO 因强制最少八位采用 `12345678`，用户为 `minio_local`。

## Commits

| Commit | Task | 说明 |
| --- | --- | --- |
| `66638a10296d1bf96ceb9a18dd1cae1ec835c04e` | T-WS-001-01～04 | Compose、环境契约、MySQL/Redis 与初始化基线 |

## Deviations

### DEV-1

- 原 DU 建议: 每个内部 Task 独立 Commit。
- 实际实现: 四个内部 Task 合并为一个 DU-WS-001 Commit。
- 原因: Compose 中服务、网络、卷、环境变量和 healthcheck 是同一份不可独立解析的 YAML，拆成中间不可用提交会破坏红绿灯基线。
- 影响评估: Commit 仍只对应一个 DU；文件与 TC 级映射保留在 changeset 和 red-green 记录中。

## 自检

- [x] Compose config 可解析，服务集合精确为四项且镜像均为固定 tag。
- [x] MySQL 八库为 utf8mb4；初始化脚本无业务 DDL/DML。
- [x] Redis 正确密码返回 PONG，错误密码被拒绝。
- [x] 网络服务名与端口全部可解析连接；`.env` 被忽略。
