# DU Implementation — DU-WS-002

> DU 级实施记录（Actual Implementation，sdd-dev 绑定本 DU 产出）。实施正文归属本仓库，Workspace 仅保留引用。
> 本文件固定为 Actual Implementation（实际修改模块/文件、Commit、Task/DU Mapping、实现偏离、完成情况），
> 与 task.md（Expected Implementation）分立，不得合并。

## 变更内容

- 新增 `deploy/scripts/infra.ps1`，实现 start/stop/restart/status/health/logs，显示底层命令并区分退出码 0/1/2。
- 新增 `deploy/README.md`，记录账号、端口、健康、初始化、数据保留、危险清理与 Java 联调方法。
- Nacos Server/Console 和 MinIO readiness 已实测，四服务健康汇总通过。

## Commits

| Commit | Task | 说明 |
| --- | --- | --- |
| `f99a2738f5827293bc65038bab9f7da8636138e7` | T-WS-002-01～04 | 运行入口、健康编排和操作文档 |

## Deviations

### DEV-1

- 原 DU 建议: 每个内部 Task 独立 Commit。
- 实际实现: 脚本与文档作为一个 DU Commit 提交。
- 原因: README 是脚本公开接口的同步说明，分开提交会短暂形成不可用或未文档化接口。
- 影响评估: Commit 未跨 DU，所有 TC 仍可分别追踪。

## 自检

- [x] PowerShell 语法解析通过；非法 Action/Service 与缺 `.env` 均返回 2。
- [x] start/status/health/stop/restart 路径已在两轮启动中验证，四服务 healthy。
- [x] Nacos 两个 v3 readiness、Standalone 与 MinIO readiness/登录通过。
- [x] 默认 stop/down 不删除卷，危险清理仅在 README 单独警告。
