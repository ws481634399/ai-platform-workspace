# Convergence

> 阶段：sdd-converge 产物
> 业界锚点：Postmortem + Lessons Learned（What → Why → Action → Knowledge）
> 输入：CHG-0006 全部前序 Artifact、DU 证据与 Review 结论
> 产出状态：completed（Human Gate 通过后推进）

本文档记录 CHG-0006 的知识分类、候选写回位置与全局验收对照。依照收敛规则，本阶段只形成候选，不直接修改 standards、product/specs、Glossary 或 Feature Tree。

## 0. 元信息

- Change ID: CHG-0006
- 完成时间: 2026-09-08T21:48:00+08:00
- 产出 Artifact 数: 10（含本 convergence.md）
- Standards 是否需更新: yes
- Product 是否需更新: no
- Feature Tree 是否需更新: yes
- Glossary 是否需更新: no

## 1. 知识变化总结

本 Change 将“本地四项中间件”从一组临时启动命令收敛为可复用的项目级运行契约：单一 Compose 权威入口、固定镜像版本、统一网络与命名卷、真实 readiness、`.env` 分层、普通停止不删卷，以及可诊断的 PowerShell 运维入口。

Review 进一步验证了两个可复用教训：聚合健康状态必须覆盖服务暴露的全部关键入口；运维脚本必须拒绝无效参数组合，并稳定区分成功、运行失败和调用错误。上述知识适合晋升为项目级基础设施规范。

产品业务规则和新领域术语均无增量。本 Change 交付的是工程基础能力，不应把镜像 tag、端口或本地账号提升为业务 Spec。Feature Tree 中既有 Story `STORY-1-03-01-01` 应在 Change 完成后从 `planned` 更新为 `delivered`。

## 2. 更新判断

### Standards

- 是否需更新: yes
- 候选文件: `standards/project/local-infrastructure-standard.md`
- 操作: 新增（Human Gate 批准后另行提交）
- 候选内容:
  - 独立基础设施仓只维护一份共享 Compose，镜像必须使用明确非漂移 tag，并在首次验收记录 digest。
  - 每个关键服务必须以真实协议/readiness 判定健康；同一服务有独立 Server/Console 入口时，聚合健康检查覆盖两者。
  - 本地数据使用稳定命名卷；普通 stop/down 不删除卷，清理动作必须显式、独立并标注不可恢复。
  - 真实 `.env` 不入 Git；示例凭据只能用于隔离本地开发，并明确禁止复用到共享或生产环境。
  - PowerShell 运维脚本显示底层命令，拒绝不适用的参数组合，并使用退出码 0=成功、1=运行失败、2=参数或配置错误。
- 理由: 这些规则经真实实现、独立测试和 Review 缺陷闭环验证，可供后续基础设施 Change 复用；其内容是项目运行约束而非通用语言编码规范。
- 复用场景: 后续增加 RocketMQ、Elasticsearch、向量库、监控组件或应用 Compose 时。

### Product

- 是否需更新: no
- Spec 晋升候选: 无。
- 理由: 本 Change 没有新增产品业务行为、交易规则或面向终端用户的长期验收约束；微服务数据所有权与 AI 不直连业务库在既有架构知识中已有定义，本次仅落实。

### feature-tree.yaml

- 是否需更新: yes
- 节点: `STORY-1-03-01-01`（建立本地基础设施环境）
- 操作: `planned → delivered`
- 方式: Convergence Human Gate 通过且 Change 推进为 `completed` 后，执行 `openspec feature update STORY-1-03-01-01 --status delivered`，不手写 YAML。
- 理由: 三个 DU 已 completed，代码、测试、Evidence 与 Review 均已闭环。

### Glossary

- 是否需更新: no
- 更新内容: 无。
- 理由: Docker Compose、readiness、命名卷等均为通用工程术语，本 Change 未引入需要团队统一定义的新业务概念。

### No Update

- 本机 MySQL 端口 `13306`：仅为 3306 被占用时的忽略配置，不具备跨环境约束价值。
- 本地弱口令与 MinIO 八位兼容值：用户指定且仅限隔离开发环境，不得晋升为安全标准。
- 测试 fixture、容器 ID、运行时间和当前镜像 digest：属于本次 Evidence；标准只晋升“记录 digest”的方法。
- `mall-identity` Redis PENDING：属于当前代码能力缺口，应由后续 Requirement 处理，不在本 Change 写成长期产品规则。

## 3. 知识沉淀过程

1. 已读取 requirement、exploration、spec、design、tasks、implementation、test-design、test-report、review-report，以及三个 DU 的 implementation/evidence。
2. 已对候选逐项执行“技术/业务、可复用性、既有知识重复性、是否需人工确认”分类。
3. 当前只在本报告中记录 Standards 和 Feature Tree 候选；按 `sdd-converge` R2，未直接修改 `standards/`、`product/specs/`、Glossary 或索引。
4. Human Gate 批准后，将单独写入项目级标准、用 OpenSpec 命令更新 Story 状态，并调用 `sdd-knowledge` 能力 C 重建 `standards/INDEX.md`、`product/INDEX.md` 与 `.sdd/knowledge-index.json`。
5. 未发现候选与既有知识的冲突；无 unresolved 项。

追踪链统计：14 个 AC、14 个 TC、3 个 DU；全部 AC 均有 Design 落点、DU 归属、TC 定义和结构化 Evidence。AC-013 的 Redis 子项为规格允许且有代码事实支持的 PENDING，不构成断链或失败。

## 4. 全局验收标准对照

| # | 验收点（spec.md §5） | 覆盖 Story | 证据引用 | 结论 |
| --- | --- | --- | --- | --- |
| AC-001 | Docker Engine 与 Compose 命令成功并记录版本 | STORY-1-03-01-01 | EV-010 / TC-001 | 通过 |
| AC-002 | 单一 Compose 成功启动精确四项服务 | STORY-1-03-01-01 | EV-007 / TC-002 | 通过 |
| AC-003 | 四项关键服务真实 healthy | STORY-1-03-01-01 | EV-007、EV-014 / TC-003 | 通过 |
| AC-004 | MySQL 可连接、八库 utf8mb4、无业务 DDL | STORY-1-03-01-01 | EV-007 / TC-004 | 通过 |
| AC-005 | Redis 正确密码 PONG、错误密码拒绝 | STORY-1-03-01-01 | EV-007 / TC-005 | 通过 |
| AC-006 | Nacos Server/Console 就绪且 Standalone | STORY-1-03-01-01 | EV-007、EV-014 / TC-006 | 通过 |
| AC-007 | MinIO API/Console/登录通过且无业务 Bucket | STORY-1-03-01-01 | EV-007 / TC-007 | 通过 |
| AC-008 | 四服务在统一网络按服务名解析连接 | STORY-1-03-01-01 | EV-007 / TC-008 | 通过 |
| AC-009 | MySQL、Redis、MinIO 数据跨普通 down/up 恢复 | STORY-1-03-01-01 | EV-008 / TC-009 | 通过 |
| AC-010 | 环境变量契约完整、`.env` 忽略、无生产 Secret | STORY-1-03-01-01 | EV-007 / TC-010 | 通过 |
| AC-011 | PowerShell 动作、日志、错误码和命令透明度符合约定 | STORY-1-03-01-01 | EV-007、EV-014 / TC-011 | 通过 |
| AC-012 | up/health/down/up/health 两轮可重复运行 | STORY-1-03-01-01 | EV-008 / TC-012 | 通过 |
| AC-013 | Java MySQL/Nacos 实连；无 Redis 入口时如实 PENDING | STORY-1-03-01-01 | EV-009 / TC-013 | 通过（Redis 子项按规格 PENDING） |
| AC-014 | 无越界中间件、业务 DDL/Bucket、业务功能或 AI 直连 | STORY-1-03-01-01 | EV-007 / TC-014 | 通过 |

14/14 条全局验收标准均通过；无跨 Story 集成点（本 Change 为单 Story inline 模式）。

## 5. 完成确认

- [x] 代码变更已完成
- [x] 测试已完成
- [x] 证据已收集
- [x] 全局验收标准已逐条对照（14/14 通过）
- [x] 知识更新已评估

## 6. 所有权修订补充（2026-09-09）

用户在完成后确认基础设施实现应属于独立仓。原 CHG-0006 不重新创建，`deploy/`、Repository Delivery、DU repository 及项目标准适用仓已统一迁移/修订为 `repo-4`；知识结论中的“单一 Compose 权威”保持不变，其物理所有者由 Workspace 修订为独立基础设施仓。迁移回归见 EV-015、EV-016。
