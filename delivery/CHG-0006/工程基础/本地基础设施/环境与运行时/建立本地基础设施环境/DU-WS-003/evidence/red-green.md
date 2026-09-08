# DU-WS-003 Red-Green

| TC | 红灯失败摘要 | 绿灯通过确认 | 备注 |
| --- | --- | --- | --- |
| TC-001 | 初始 Docker Engine 未启动 | PASS：Engine 29.4.0 与 Compose v5.1.1 | Docker Desktop 后台启动后通过 |
| TC-009/012 | 首次 up 因宿主机 3306 占用失败 | PASS：本机覆盖 13306，两轮 healthy，三类数据恢复 | 默认模板仍为 3306 |
| TC-013 | Java Redis 无依赖/配置入口 | PARTIAL：MySQL/Nacos PASS，Redis PENDING | 规格允许能力缺口记录 PENDING |
