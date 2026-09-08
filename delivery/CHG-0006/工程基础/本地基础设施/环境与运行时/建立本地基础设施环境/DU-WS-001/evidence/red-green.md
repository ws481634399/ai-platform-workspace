# DU-WS-001 Red-Green

| TC | 红灯失败摘要 | 绿灯通过确认 | 备注 |
| --- | --- | --- | --- |
| TC-002/004/005/008/010/014 | `deploy/` 与 Compose、环境模板、初始化脚本均不存在 | PASS：Compose config、八库/utf8mb4、Redis 正误密码、网络、Secret/Scope 扫描 | 必填变量为空时 config 非零退出 |
