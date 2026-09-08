# DU Task — DU-WS-003

> Repository Delivery 的 DU 级任务细化（Expected Implementation）。
> 权威来源：workspace-source.tasks 中本 DU 小节；本文件是 repo 侧可执行副本，
> Agent 依据权威来源填写，允许按仓内实际情况微调并保持一致。
>
> Implementation Guidance 提示：Implementation Sketch 必填；
> Pseudocode 必填（complexity-trigger: orchestration）；Verification 必填。
> 本文件固定为 Expected Implementation（Plan / Sketch / Pseudocode / Verification），
> 与 implementation.md（Actual Implementation）分立，不得合并。

## 1. Goal

执行真实环境、持久化、重复运行与 Java 联调验证，并形成可信 Evidence。

## 2. Repository

`repo-workspace`；`implementation/mall-backend-microservices` 仅只读运行联调。

## 3. Scope

`deploy/README.md` 验收说明、当前 DU 的 `evidence/`、repo-1 只读联调。

## 4. Design References

Workspace `design.md` §1.1～§1.2、§2.8～§2.9、§3.2、§4、§5.2。

## 5. Dependencies

DU-WS-001、DU-WS-002。

## 6. Acceptance Criteria

AC-001、AC-009、AC-012、AC-013；绑定 TC-001/009/012/013。

## 7. Implementation Sketch

Docker preflight → pull/config/up/health → 写入三类 fixture → down/up/read → 启动 mall-identity 验证 MySQL/Nacos；Redis 无入口以代码事实记 PENDING；所有原始命令、退出码和日志进入 DU Evidence。

## 8. Pseudocode

先记录 Docker/Compose；Engine 不可用即 BLOCKED。健康后写 MySQL/Redis/MinIO fixture，普通 down/up 后逐项读取；再以 localhost 契约启动 mall-identity，要求数据库连接和 Nacos healthy，检查 Redis 入口，缺失则 PENDING，绝不以容器 PING 代替 Java 证据。

## 9. Verification

记录环境版本；三类数据跨 down/up 可读；两轮四服务健康；Java MySQL/Nacos 原始日志与 Redis PENDING 文件事实。任一未执行/失败项保持 NOT RUN/FAIL/BLOCKED/PENDING。
