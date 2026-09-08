# Review Report

> 阶段：sdd-review 产物（Phase 2.2 同态检查点；Phase 2.4 扩展跨仓审查）
> 位置：CHG-0006 / STORY-1-03-01-01 / review-report.md
> 输入：spec.md + design.md + implementation.md + evidence/test-report.md + evidence/evidence.yaml + standards/ + DU 状态
> 产出状态：testing（检查点，不推进 Change 状态）

本文档记录 converge 前的独立质量检查结论。评审发现的两项 major 偏差均已修复并回归通过，无开放 blocker、major 或 minor finding。

## 0. 元信息

- Change ID: CHG-0006
- Test Report 来源: CHG-0006/工程基础/本地基础设施/环境与运行时/建立本地基础设施环境/evidence/test-report.md
- Evidence 索引: CHG-0006/工程基础/本地基础设施/环境与运行时/建立本地基础设施环境/evidence/evidence.yaml
- 状态流转: testing（检查点，状态不变）
- 检查时间: 2026-09-08T20:52:53+08:00

## 1. 检查结论

需求、设计、跨仓契约、代码质量与知识同步候选均已核对。14 条 AC 全部具备结构化 test-run 证据；AC-013 的 Java Redis 子项按规格允许保持 PENDING，其“能力入口不存在”事实已被验证，未伪造为 PASS。评审发现 2 项 major，均通过 EV-013/EV-014 闭环。

### 1.1 需求一致性

| AC | TC | test-run 证据 | 结论 |
| --- | --- | --- | --- |
| AC-001 | TC-001 | EV-010 | ✅ Docker/Compose 前置通过 |
| AC-002 | TC-002 | EV-007 | ✅ 四服务 Compose 基线通过 |
| AC-003 | TC-003 | EV-007、EV-014 | ✅ 四服务健康，Nacos 双 readiness 已补强 |
| AC-004 | TC-004 | EV-007 | ✅ MySQL 与八库通过 |
| AC-005 | TC-005 | EV-007 | ✅ Redis 正误密码路径通过 |
| AC-006 | TC-006 | EV-007、EV-014 | ✅ Nacos Server/Console/Standalone 通过 |
| AC-007 | TC-007 | EV-007 | ✅ MinIO API/Console/空 Bucket 通过 |
| AC-008 | TC-008 | EV-007 | ✅ 统一网络解析与连接通过 |
| AC-009 | TC-009 | EV-008 | ✅ 三类数据跨普通 down/up 恢复 |
| AC-010 | TC-010 | EV-007 | ✅ `.env` 忽略且无生产 Secret |
| AC-011 | TC-011 | EV-007、EV-014 | ✅ 脚本动作、错误码、命令透明度通过 |
| AC-012 | TC-012 | EV-008 | ✅ 两轮启动与健康恢复通过 |
| AC-013 | TC-013 | EV-009 | ✅ MySQL/Nacos PASS；Redis 无入口按规格 PENDING |
| AC-014 | TC-014 | EV-007 | ✅ 无 Scope Out 内容 |

追踪链 `AC → Design §9 → DU → TC → EV` 完整；TC-001～TC-014 均在 test-design.md 定义，并由中央 test-run 或 DU evidence-ref 追溯到执行证据。

### 1.2 设计一致性

| 设计声明 | DU / 实现证据 | 结论 |
| --- | --- | --- |
| §2.2～§2.6：单一 Compose、固定镜像、环境变量、网络、卷、MySQL/Redis | DU-WS-001；EV-001、EV-003、EV-007 | ✅ 与实际 Compose/init 一致 |
| §2.4：Nacos Server/Console readiness 与 MinIO readiness | DU-WS-002；EV-002、EV-004、EV-013、EV-014 | ✅ Nacos 双 readiness 偏差已闭环 |
| §2.7：PowerShell 动作、参数、命令透明度与退出码 | DU-WS-002；EV-002、EV-013、EV-014 | ✅ 参数/退出码偏差已闭环 |
| §2.8：健康、普通 down/up 与持久化数据流 | DU-WS-003；EV-006、EV-008 | ✅ 三类 fixture 恢复后已清理 |
| §2.9：mall-identity MySQL/Nacos 实连与 Redis PENDING | DU-WS-003；EV-006、EV-009 | ✅ 与既有代码能力一致 |
| §5：无业务 Migration、默认不删卷、Secret 分层 | DU-WS-001/002/003；EV-003～EV-008 | ✅ 风险控制落实 |

三个 DU 的 Sketch/Pseudocode 与 Design 方向一致。既有实现偏离均在各 DU implementation.md `## Deviations` 中说明；本轮新发现的未记录偏差已登记为 EV-011/EV-012 并闭环。

### 1.3 跨仓一致性（Phase 2.4）

- 写入仓只有 `repo-workspace`，三个 DU 均已 `completed`；baseline 为 `4a343a68...`，result 为 `9ccb7ac...`，Review 开始时与仓库 HEAD 一致。
- API/Event Contract 均无新增内容；Data Contract 保持“工作区只建库与授权、Java 服务通过 Flyway 拥有业务表、AI 不直连业务库”。
- `mall-identity` 仅作为 repo-1 只读联调对象运行，未产生源码或 POM 改动；MySQL/Nacos 证据有效，Redis 缺入口按契约 PENDING。
- 依赖顺序 `DU-WS-001 → DU-WS-002 → DU-WS-003` 与实际构建、运行、联调顺序一致，无循环或反向依赖。

结论：单写入仓场景的跨仓运行契约已满足，无开放一致性问题。

### 1.4 代码质量

对照 `standards/coding-standards.md`、`standards/security-guidelines.md`、`standards/git-conventions.md`、`standards/testing-conventions.md` 抽查全部 `deploy/` 变更：

- 密码类配置通过环境变量注入，真实 `.env` 未跟踪；`.env.example` 明确标注为隔离本地开发示例，README 禁止复用到共享/生产环境。
- MySQL 初始化使用受限标识符校验，只有建库与库级授权，无业务 DDL/DML。
- PowerShell 参数错误现在稳定输出 stderr 并返回 2；Docker/Compose 操作失败继续返回 1，健康动作展示底层命令。
- 默认 stop/down 不携带 `--volumes`；不可恢复清理只在 README 独立警告。
- Commit 消息符合约定，修复提交仅包含相关的 Compose 与脚本文件。

结论：2 项有明确设计依据的 major finding 已闭环；无开放规范违规。

### 1.5 知识同步候选

- standards 候选：沉淀“本地基础设施 Compose 基线”，包括固定镜像、双层 readiness、命名卷、`.env` 分层及默认不删卷规则。
- standards 候选：沉淀 PowerShell 运维脚本退出码约定（0 成功、1 运行失败、2 参数/配置错误）与命令透明度要求。
- product 候选：将 MySQL/Redis/Nacos/MinIO 四服务共享本地运行时标记为已交付能力；Java Redis 客户端接入保留为后续 Requirement。

## 2. 发现清单

| EV | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-011 | design.md#2.4 Compose 服务设计 | major | Nacos healthcheck 未覆盖 Console readiness | ✅ EV-013 修复，EV-014 验证 |
| EV-012 | tasks.md#DU-WS-002 | major | 脚本参数组合、退出码和命令透明度偏离契约 | ✅ EV-013 修复，EV-014 验证 |

开放 finding：0。blocker：0；未闭环 major：0；minor：0。

## 3. 完成确认

- [x] 四项检查全部执行
- [x] 全部 blocker/major finding 已闭环（evidence.yaml resolution 非空）
- [x] minor finding 已记录（本次无 minor）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（单写入仓 + repo-1 只读联调）
