# CHG-0006 Red-Green 汇总

| DU | 红灯 | 绿灯/结果 | 原始记录 |
| --- | --- | --- | --- |
| DU-WS-001 | `deploy/` 基础文件不存在 | Compose/数据库/Redis/网络/安全静态与集成验证 PASS | `delivery/CHG-0006/工程基础/本地基础设施/环境与运行时/建立本地基础设施环境/DU-WS-001/evidence/red-green.md` |
| DU-WS-002 | 脚本/readiness 不存在；初版退出码不可达 | 四服务 healthy、Nacos/MinIO、脚本错误码 PASS | `delivery/CHG-0006/工程基础/本地基础设施/环境与运行时/建立本地基础设施环境/DU-WS-002/evidence/red-green.md` |
| DU-WS-003 | Engine 未启动；3306 被占用；Java Redis 无入口 | Engine/端口覆盖/持久化/MySQL/Nacos PASS；Redis PENDING | `delivery/CHG-0006/工程基础/本地基础设施/环境与运行时/建立本地基础设施环境/DU-WS-003/evidence/red-green.md` |
