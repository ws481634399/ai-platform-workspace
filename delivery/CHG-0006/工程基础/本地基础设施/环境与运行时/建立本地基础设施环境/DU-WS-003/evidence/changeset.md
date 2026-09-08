# DU-WS-003 Verification Scope

| 对象 | 操作 | 结果 |
| --- | --- | --- |
| Docker/Compose | version、pull、up/health/down/up | PASS |
| MySQL/Redis/MinIO | 写入、重建、读取、清理 fixture | PASS |
| `mall-identity` | 运行既有 Jar，连接 MySQL/Nacos | PASS |
| Java Redis | POM/配置入口静态检查 | PENDING（入口不存在） |
