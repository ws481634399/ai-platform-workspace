# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物
> 位置：STORY 级，与 `tasks.md` 同目录
> 产出状态：tasked

本文档在开发前锁定 CHG-0006 的验证意图。测试执行以 `spec.md`、`design.md` 和本文件为依据，不从 `implementation.md` 反推断言。

## 0. 元信息

- Change ID: CHG-0006
- Story ID: STORY-1-03-01-01
- Spec 来源: `delivery/changes/CHG-0006/工程基础/本地基础设施/环境与运行时/建立本地基础设施环境/spec.md`
- Design 来源: `delivery/changes/CHG-0006/工程基础/本地基础设施/环境与运行时/建立本地基础设施环境/design.md`
- 状态流转: designed → tasked
- Feature Path: 工程基础 > 本地基础设施 > 环境与运行时 > 建立本地基础设施环境
- TC 总数: 14

## 1. 测试用例（验证意图，dev 开始前锁定）

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | Environment preflight：记录 `docker info` 与 `docker compose version` 输出和退出码 | AC-001 | DU-WS-003 | Docker Engine 不可用时如实 BLOCKED，不执行后续运行用例 |
| TC-002 | Compose config + up 集成：服务集合、固定镜像、环境插值与启动退出码 | AC-002 | DU-WS-001 | 仅允许四项服务及必需辅助容器 |
| TC-003 | 四服务 health 集成：ps 与各真实 readiness 一致 | AC-003 | DU-WS-002 | running 但不可连接必须失败 |
| TC-004 | MySQL 集成：`SELECT 1`、八库/utf8mb4、初始化脚本边界 | AC-004 | DU-WS-001 | 使用新卷验证首次初始化 |
| TC-005 | Redis 集成：正确密码 PONG、错误密码鉴权失败 | AC-005 | DU-WS-001 | 同时确认 AOF 配置生效 |
| TC-006 | Nacos API/UI 集成：Server/Console readiness、Standalone 与端口 | AC-006 | DU-WS-002 | Console host 8849，Server 8848，gRPC 9848 |
| TC-007 | MinIO API/UI 集成：ready、Console 登录、无业务 Bucket | AC-007 | DU-WS-002 | 只使用本地测试凭据 |
| TC-008 | Network 集成：容器内解析并连接 mysql/redis/nacos/minio 服务名 | AC-008 | DU-WS-001 | 静态扫描固定宿主机 IP 零命中 |
| TC-009 | Persistence E2E：三类 fixture 跨普通 down/up 恢复 | AC-009 | DU-WS-003 | MySQL 行、Redis 键、MinIO 对象各一项 |
| TC-010 | Security/Config 静态测试：环境变量完整、`.env` 忽略、真实 Secret 零命中 | AC-010 | DU-WS-001 | 不输出密码值到 Evidence 日志 |
| TC-011 | PowerShell 接口测试：start/status/health/stop/logs/restart 与错误码 | AC-011 | DU-WS-002 | 覆盖成功、非法参数、Docker 不可用、health 超时 |
| TC-012 | Repeatability E2E：完整 up/health/down/up/health 两轮成功 | AC-012 | DU-WS-003 | 两轮均保留 ps、时间与退出码 |
| TC-013 | Java Integration：mall-identity MySQL/Nacos 实连 + Redis PENDING 事实 | AC-013 | DU-WS-003 | Redis 无入口以 POM/配置证据标 PENDING，不以容器 PING 替代 |
| TC-014 | Scope Guard 静态测试：无后续中间件、业务 DDL/Bucket/功能或 AI 直连 | AC-014 | DU-WS-001 | 对 Compose、init、工作树改动联合扫描 |

## 2. 测试策略

- 分层：Static 覆盖 Compose/Secret/Scope；Integration 覆盖单项服务协议与 UI/API；E2E 覆盖四服务编排、持久化和 Java 联调。下层验证配置事实，上层只验证真实协作结果，避免重复用 `ps` 代替 readiness。
- 执行顺序：先 TC-001；再以全新本地 `.env` 运行 TC-002、TC-004、TC-005、TC-008、TC-010、TC-014；随后运行 TC-003、TC-006、TC-007、TC-011；最后运行 TC-009、TC-012、TC-013。
- 数据准备：使用带 CHG/时间戳的唯一 MySQL 表/行、Redis key 和 MinIO object；测试结束清理 fixture，不删除开发者既有卷。八库初始化必须使用隔离的新卷验证，避免旧卷掩盖脚本错误。
- 证据纪律：每项记录命令、开始时间、退出码、原始 stdout/stderr 与日志路径；凭据值先脱敏。未执行为 NOT RUN，失败为 FAIL，代码无入口为 PENDING，禁止推断 PASS。
- 环境要求：Windows + PowerShell、Docker Desktop/Engine、Docker Compose、可访问官方镜像仓；Java 联调还需 repo-1 所需 JDK/Maven 和可运行的 `mall-identity`。

## 3. 不可测项标注

无。AC-013 中 Redis 允许的 PENDING 是可验证的“能力入口不存在”结果，TC-013 通过代码事实与关联说明验收，不标记为不可测。

## 4. 依赖与前置条件

- TC-001 通过后才能执行所有容器运行测试；镜像 tag 拉取失败时停止并返回 Design 更新，禁止换用 `latest`。
- TC-002 是 TC-003～TC-009、TC-011～TC-013 的运行前置；TC-003 四服务健康是持久化和 Java 联调的前置。
- TC-009 的第二次 up/health 与 TC-012 合并执行，但分别保留数据恢复断言和编排恢复断言。
- TC-013 依赖 TC-003、TC-004、TC-006；repo-1 只读，联调失败不得通过修改业务工程绕过。
- 物化后的 DU-WS-003 `evidence/` 是原始日志与 `evidence.yaml` 的权威位置；Workspace DU 只保存引用。

