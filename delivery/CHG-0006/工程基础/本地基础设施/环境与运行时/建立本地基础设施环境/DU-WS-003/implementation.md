# DU Implementation — DU-WS-003

> DU 级实施记录（Actual Implementation，sdd-dev 绑定本 DU 产出）。实施正文归属本仓库，Workspace 仅保留引用。
> 本文件固定为 Actual Implementation（实际修改模块/文件、Commit、Task/DU Mapping、实现偏离、完成情况），
> 与 task.md（Expected Implementation）分立，不得合并。

## 变更内容

- Docker Engine 29.4.0、Compose v5.1.1；四个固定镜像均成功拉取并记录 digest。
- 首次 up 因宿主机 3306 占用失败；仅在忽略的本地 `.env` 覆盖 MySQL 为 13306 后成功，两轮四服务均 healthy。
- MySQL 行、Redis key、MinIO object 跨普通 down/up 恢复，验证后已清理 fixture。
- `mall-identity` 以现有 Jar 连接 MySQL 8.4，并作为 healthy instance 注册 Nacos；进程取证后已停止。
- Java → Redis 因 `mall-identity` 无 `mall-common-redis`/Spring Data Redis 依赖和配置入口，按规格记 PENDING。

## Commits

本 DU 为运行验证与 Evidence，不修改 repo-1 源码；Evidence 提交由 Workspace 开发记录汇总。

## Deviations

### DEV-1

- 原 DU 建议: 只读联调路径写为 `implementation/mall-backend-microservices`。
- 实际实现: 使用 registry 中真实路径 `implementation/ai-platform-backend/mall-services/mall-identity`。
- 原因: Task 草稿引用了旧目录名，实际 repo-1 path 已登记为 `implementation/ai-platform-backend`。
- 影响评估: 仓库与服务身份不变，未修改 repo-1 源码，AC-013 证据有效。

### DEV-2

- 原 DU 建议: 默认 MySQL 宿主端口 3306。
- 实际实现: 本机 `.env` 临时覆盖为 13306。
- 原因: 3306 已被其他进程占用，首次 up 真实返回端口绑定失败。
- 影响评估: `.env.example` 和正式端口契约仍为 3306；Java 联调显式使用 13306，符合可覆盖规则。

## 自检

- [x] 未修改 repo-1 源码；Java 进程取证后停止。
- [x] 三类 fixture 跨普通 down/up 恢复并已清理。
- [x] Java MySQL/Nacos 为 PASS；Java Redis 为有代码事实的 PENDING。
- [x] 未将未执行或失败项标记 PASS。
