# DU Task — DU-WS-001

> Repository Delivery 的 DU 级任务细化（Expected Implementation）。
> 权威来源：workspace-source.tasks 中本 DU 小节；本文件是 repo 侧可执行副本，
> Agent 依据权威来源填写，允许按仓内实际情况微调并保持一致。
>
> Implementation Guidance 提示：Implementation Sketch 必填；
> Pseudocode 条件必填（本 DU 未声明触发器，未命中时写 N/A + 理由）；Verification 必填。
> 本文件固定为 Expected Implementation（Plan / Sketch / Pseudocode / Verification），
> 与 implementation.md（Actual Implementation）分立，不得合并。

## 1. Goal

建立四服务共享 Compose 底座，并交付 MySQL/Redis 可启动、可鉴权、可持久化的配置。

## 2. Repository

`repo-workspace`（工作仓根目录）。

## 3. Scope

`deploy/docker-compose.infra.yml`、`.env.example`、`.gitignore`、`.gitattributes`、`mysql/init/001-init-databases.sh`。

## 4. Design References

Workspace `design.md` §2.2～§2.6、§3.1、§4 Data Contract、§5.1。

## 5. Dependencies

无。

## 6. Acceptance Criteria

AC-002、AC-004、AC-005、AC-008、AC-010、AC-014；绑定 TC-002/004/005/008/010/014。

## 7. Implementation Sketch

`.env` 经 required interpolation 注入单一 Compose；四服务共享 `ai-platform-network`，各自使用命名卷；MySQL init 仅创建八个空库和授权。缺失必填配置必须在 config/up 阶段失败。

## 8. Pseudocode

N/A（声明式 Compose、环境模板与幂等初始化配置，无复杂流程触发器）。

## 9. Verification

Compose config/服务集合/固定 tag 静态检查；MySQL 八库与 Redis 正误密码集成检查；网络 DNS、Secret 和 Scope Guard 扫描；缺变量及业务 DDL 为失败路径。
