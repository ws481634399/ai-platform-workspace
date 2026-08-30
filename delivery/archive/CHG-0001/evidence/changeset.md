# Changeset — CHG-0001

> 记录时间：2026-08-28
> 说明：TASK-001~007 每任务一提交；TASK-008~010 为验证任务，期间的一次修复（mq 坐标）单独成提交（1c054b1）

## repo-1：implementation/ai-platform-backend（后端独立仓库）

| 仓库 | 模块 | 文件 | 变更类型 | 行数变化 | Task |
| ---- | ---- | ---- | -------- | -------- | ---- |
| repo-1 | 仓库根 | pom.xml | 新增 | +125 | TASK-001 |
| repo-1 | 仓库根 | .gitignore | 新增 | +23 | TASK-001 |
| repo-1 | mall-bom | mall-bom/pom.xml | 新增 | +83 | TASK-002 |
| repo-1 | mall-common | pom.xml（聚合） | 新增 | +29 | TASK-003 |
| repo-1 | mall-common | 8 个子模块 pom.xml | 新增 | +194（17/24/24/28/24/24/25/24） | TASK-003 |
| repo-1 | mall-common | 8 个 package-info.java | 新增 | +37（5/4/4/4/4/4/4/4） | TASK-003 |
| repo-1 | mall-contracts | pom.xml（聚合） | 新增 | +23 | TASK-004 |
| repo-1 | mall-contracts | api/event 两个 pom.xml | 新增 | +34（17×2） | TASK-004 |
| repo-1 | mall-contracts | 2 个 package-info.java | 新增 | +10（5×2） | TASK-004 |
| repo-1 | mall-gateway | pom.xml | 新增 | +34 | TASK-005 |
| repo-1 | mall-gateway | MallGatewayApplication.java | 新增 | +15 | TASK-005 |
| repo-1 | mall-gateway | application.yml | 新增 | +6 | TASK-005 |
| repo-1 | mall-services | pom.xml（聚合） | 新增 | +29 | TASK-006 |
| repo-1 | mall-services | 8 个服务 pom.xml | 新增 | +272（34×8） | TASK-006 |
| repo-1 | mall-services | 8 个 Mall\<Svc\>Application.java | 新增 | +120（15×8） | TASK-007 |
| repo-1 | mall-services | 8 个 application.yml | 新增 | +48（6×8） | TASK-007 |
| repo-1 | mall-common-mq | pom.xml | 修改 | +2/-2 | TASK-008（修复） |
| repo-1 | 仓库根 | .gitignore | 修改 | +3 | TASK-008（修复，.m2-repo/） |
| repo-1 | 仓库根 | README.md | 新增 | +66 | TASK-011（待提交） |

合计（已提交部分）：9 次提交，52 个文件，约 +1336/-2 行。

## workspace 仓（文档与证据侧）

| 仓库 | 模块 | 文件 | 变更类型 | Task |
| ---- | ---- | ---- | -------- | -------- |
| workspace | .sdd | repositories.yaml（repo-1 path 修正为 implementation/ai-platform-backend） | 修改 | 技术决策 3 修订落地 |
| workspace | .sdd | workspace.yaml（name=ai-platform-workspace，早已就绪） | 无需改 | — |
| workspace | delivery/changes/CHG-0001 | tasks.md（仓库结构调整修订记录） | 修改 | 前置修订 |
| workspace | delivery/changes/CHG-0001 | exploration.md / design.md（仓库描述修订） | 已提交 | 前置修订 |
| workspace | delivery/changes/CHG-0001/evidence | build-evidence.md | 新增 | TASK-011 |
| workspace | delivery/changes/CHG-0001/evidence/logs | full-build.log / maven-java-version.txt / apps-dependency-tree.txt / mq-dependency-tree.txt / startup/*.out.log（9 份） | 新增 | TASK-008~010 留档 |
| workspace | .gitignore | evidence/logs 入库例外 | 修改 | TASK-011 |
