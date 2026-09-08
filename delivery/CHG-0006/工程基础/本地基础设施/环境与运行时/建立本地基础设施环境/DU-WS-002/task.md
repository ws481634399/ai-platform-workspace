# DU Task — DU-WS-002

> Repository Delivery 的 DU 级任务细化（Expected Implementation）。
> 权威来源：workspace-source.tasks 中本 DU 小节；本文件是 repo 侧可执行副本，
> Agent 依据权威来源填写，允许按仓内实际情况微调并保持一致。
>
> Implementation Guidance 提示：Implementation Sketch 必填；
> Pseudocode 必填（complexity-trigger: orchestration）；Verification 必填。
> 本文件固定为 Expected Implementation（Plan / Sketch / Pseudocode / Verification），
> 与 implementation.md（Actual Implementation）分立，不得合并。

## 1. Goal

补齐 Nacos/MinIO 与四服务 readiness，并提供 Windows 运行入口和可复现文档。

## 2. Repository

`repo-workspace`（工作仓根目录）。

## 3. Scope

`deploy/docker-compose.infra.yml`、`deploy/scripts/infra.ps1`、`deploy/README.md`。

## 4. Design References

Workspace `design.md` §2.3～§2.5、§2.7、§3.1、§4、§5.2。

## 5. Dependencies

DU-WS-001。

## 6. Acceptance Criteria

AC-003、AC-006、AC-007、AC-011；绑定 TC-003/006/007/011。

## 7. Implementation Sketch

开发者调用 `infra.ps1`，脚本校验参数与环境、显示并执行底层 Compose 命令，再由容器 healthcheck 和服务 readiness 汇总结果；失败保留 stderr、ps 和最近日志。

## 8. Pseudocode

定位 deploy → 校验 Action/Service/.env/Docker → 显示 Compose 命令 → 分派 start/stop/restart/status/health/logs；health 轮询至超时，全部健康返回 0，否则打印状态与日志返回 1；无效输入返回 2。

## 9. Verification

验证 Nacos v3 Server/Console readiness、MinIO ready 与登录；六个 Action 成功路径及非法参数、Docker 不可用、超时失败路径；README 原生命令与脚本等价，普通 stop 不删卷。
