# DU-WS-002 Red-Green

| TC | 红灯失败摘要 | 绿灯通过确认 | 备注 |
| --- | --- | --- | --- |
| TC-003/006/007/011 | 运行脚本和 readiness 配置不存在 | PASS：四服务 healthy、Nacos/MinIO readiness、脚本退出码 | 首次退出码测试发现 `Write-Error` 提前终止，修复后绿灯 |
