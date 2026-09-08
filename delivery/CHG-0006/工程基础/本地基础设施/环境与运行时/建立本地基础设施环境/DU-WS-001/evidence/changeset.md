# DU-WS-001 Changeset

| 文件 | 变更类型 | 用途 |
| --- | --- | --- |
| `deploy/docker-compose.infra.yml` | 新增 | 四服务、网络、卷、端口、healthcheck |
| `deploy/.env.example` | 新增 | 本地环境变量契约 |
| `deploy/.gitignore` | 新增 | 忽略真实 `.env` |
| `deploy/.gitattributes` | 新增 | MySQL shell 脚本强制 LF |
| `deploy/mysql/init/001-init-databases.sh` | 新增 | 八个空库与本地账号授权 |
