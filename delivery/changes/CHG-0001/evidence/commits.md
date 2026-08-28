# Commits — CHG-0001

## repo-1：implementation/ai-platform-backend

| Commit | Task | 消息 | 文件数 |
| ------ | ---- | ---- | ------ |
| 14c6db0 | TASK-001 | feat(build): 创建后端聚合根 POM，统一版本守门与插件管理 | 2 |
| 9babc0f | TASK-002 | feat(bom): 创建 mall-bom 唯一版本权威模块 | 1 |
| d0421c2 | TASK-003 | feat(common): 创建 mall-common 聚合与 8 个技术子模块骨架 | 18 |
| 94629ad | TASK-004 | feat(contracts): 创建 mall-contracts 聚合与 2 个契约子模块骨架 | 5 |
| 84cd1f5 | TASK-005 | feat(gateway): 创建 mall-gateway 独立应用骨架 | 3 |
| f49c30f | TASK-006 | feat(services): 创建 mall-services 聚合与 8 个业务服务 POM 骨架 | 9 |
| dfed84f | TASK-007 | feat(services): 补齐 8 个服务启动类与最小配置 | 16 |
| 1c054b1 | TASK-008 | fix(common-mq): 修正 RocketMQ starter 坐标为 SCA BOM 受管的 spring-cloud-starter-stream-rocketmq | 2 |
| （待提交） | TASK-011 | docs(readme): 新增仓库 README（构建说明/环境要求/版本治理约定） | 1 |

## workspace 仓

| Commit | Task | 消息 | 说明 |
| ------ | ---- | ---- | ---- |
| 8c4ff72 | 前置 | chore(repo): 工作区忽略 implementation/ 并修订 CHG-0001 任务清单 | 双仓结构落地 |
| （待提交） | TASK-011 | docs(chg-0001): 归档构建证据与实现轨迹 | evidence/ + .sdd 路径修订 + .gitignore 例外 |

> 注：commit 中文说明经 UTF-8 消息文件提交（`git commit -F`），终端 GBK 显示乱码不影响仓库内容。
