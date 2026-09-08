# Exploration（需求探索报告）

> 阶段：sdd-explore 产物
> 业界锚点：Discovery 文档（Problem → Evidence → Conflict → Recommendation）
> 输入：requirement.md（原文沉淀；本文件不复述原文，只做分析）
> 产出状态：exploring（推进 Change 状态）

本文档回答探索阶段的五个问题：需求要点是什么、归属哪个 Story（是否已存在）、证据是否充分、有无冲突点、还有什么待澄清。

## 1. 需求要点

- 做什么：用一份 Docker Compose 把 M0 本地中间件（MySQL、Redis、Nacos、MinIO）变成可重复的启动/停止/健康检查/恢复能力；开发机只装 Docker，不再本机安装四套中间件。
- 给谁：全体本地开发者（Windows 为主），以及后续要联调的 Java 后端；前端只间接受益（经 Gateway），AI Service 本阶段不强制依赖这套环境。
- 解决什么问题：三仓工程基线（CHG-0003/0004/0005）已齐，但应用仍没有统一、可恢复的本地运行时；没有它，Java → MySQL/Redis/Nacos 无法做真实连接，M0 不能进入业务开发。
- 表面 vs 实际意图：
  1. 表面是“写一份 compose、起四个容器”。实际是**共享运行时契约**：统一网络、统一端口、统一 env、统一 volume、统一 health，让后续应用配置有稳定引用点。
  2. 这是**插座不是全栈机房**：明确砍掉 RocketMQ / ES / 向量库 / 监控栈 / Nginx / 生产部署；禁止“一次搭全”。
  3. Compose **不改变数据所有权**：一个 MySQL 实例仍按服务分库/分 Schema；Flyway 管业务表；AI 不得因本需求拿到业务库直连。
- 隐含需求：
  1. 镜像与 Compose 文件版本必须可锁定，否则 “可重复”无法在 Evidence 中复现。
  2. Windows 开发机需要能跑通脚本（PowerShell 或文档化的 `docker compose` 命令），不能只给 Linux shell。
  3. 宿主机端口必须与 Java `application.yml` / 前端 Gateway 约定可对齐，否则 AC-11 会变成“容器绿了、应用连不上”。
  4. 本地凭据可以存在，但只能是 Local Development Credentials；`.env` 不入库，与 Git 规范一致。
  5. Java 联调允许 PENDING（文档已写），但 PENDING 必须有原因，不能把容器启动记成注册成功。

知识检索命中（sdd-knowledge 能力 D）：

关键词：`Docker Compose`、`本地基础设施`、`MySQL`、`Nacos`、`MinIO`、`环境变量`。

- 命中且相关（score ≥ 2）——注入分析：
  - `product/13-部署方案.md`（tags: deployment, docker-compose）[score: tags docker-compose=2 / title 部署=3]——长期方案已把 `docker-compose.infra.yml` 与“可重复 up -d”写成目标；本 Change 是该方案的 **M0 子集**，不是另起一套部署哲学。
  - `product/08-系统与微服务架构.md`（summary 含 Nacos/Redis/MinIO/Docker Compose）[score: summary 命中多组件]——本地拓扑推荐“基础设施 Compose + 应用 IDE 启动”；并给出 Nacos 8848、MinIO 9000/9001 等端口线索，供 Design 对齐而非本阶段拍板。
  - `product/09-数据库设计.md`（tags: mysql）[score: tags=2]——库表归属按微服务划分；与本需求“只建库不建业务 DDL”一致。
  - `standards/git-conventions.md`（tags: git；.gitignore 基线含 `.env`）[score: title/tags 高]——AC-09 / DoD「Git 中不存在真实 Secret」直接引用该基线。
  - `standards/security-guidelines.md`（Secret 从环境变量读取、不硬编码、日志不输出密码）[score: summary 数据保护 + 正文 Secret 约定]——对齐 §十八：Compose 不写生产密码，`.env.example` 只放占位符。
- 命中但不相关（score = 1）——仅记录：
  - `standards/engineering/backend/framework-standard.md`（summary 含“基础设施组件”，内容是 Java BOM/框架版本，不定义 Compose）。
  - `standards/architecture-principles.md`（分层/SOLID，不覆盖容器编排）。
  - `standards/engineering/database-standard.md`（库表/迁移规范，业务 DDL 仍归各服务 Flyway）。
- 未命中：Workspace 内无 Docker Compose 专属工程规范、无镜像版本锁定约定、无 `deploy/` 目录落仓规则——标注“无历史知识参考，需独立探索；converge 时考虑是否晋升 `standards/engineering/` 下本地基础设施规范”。

参考文档：

- `docs/需求/M0/REG-M0-004.md`（用户提供原文）
- `delivery/changes/CHG-0006/references/REG-M0-004.md`（Change 内归档副本）
- `product/feature-tree.yaml`（STORY-1-03-01-01 已规划）
- `delivery/archive/CHG-0003/`、`CHG-0005/`（Java 联调 PENDING 约定；AI 不依赖本环境启动）

## 2. Story 归属判定

- Feature ID: FEAT-1-03-01
- Story 节点: STORY-1-03-01-01「建立本地基础设施环境」（已存在，status: planned）
- 是否新建 candidate: no
- Feature 路径: MOD-1 工程基础 → FEAT-1-03 本地基础设施 → FEAT-1-03-01 环境与运行时 → STORY-1-03-01-01 建立本地基础设施环境

判定说明：树中已有专为 REQ-M0-004 预留的 L2/L3/Story，核心动词「建立」+ 对象「本地基础设施 / Docker Compose」与节点描述一致，故直接挂靠，不新建 Candidate，也不并入 FEAT-2（Java 应用基线）或 FEAT-1-02（Python 应用基线）。

## 3. 证据评估

- 证据类型与来源:
  - 业务目标对齐：M0 四件套的最后一块；`REG-M0-004` 写明无本环境则无法做 Java 基础联调，无法进入 M1/M2。
  - 产品知识对齐：`product/08` 本地拓扑与 `product/13` Compose 可重复启动，与需求方向一致。
  - 规格完备度：原文含范围、排除项、AC-01~12、DoD、Evidence 模板、与 Java/Frontend/AI 边界。
  - 既有交付缺口：工作区无 `docker-compose*.yml`；CHG-0003 已把真实 Nacos/MySQL 集成验证挂 PENDING，等待本 Change。
- 结论: 充分（充分——工程基线类需求以规格与架构对齐为据；运行时 Evidence 属于后续 test 阶段，不作为探索阻断）

## 4. 冲突点检测

- 与 product/specs/ 规则冲突: 无（`product/specs/` 目录不存在，无已确认产品规则可冲突）
- 与既有 Change 重叠或沿用: 无（findChangeByRequirement 命中的进行中 Change 即本 CHG-0006，沿用该载体；归档无同 REQ 可复用包。与 CHG-0003 的交叉是**联调接口**不是范围重复：本 Change 提供容器，Java 仓保留 DataSource/Nacos 客户端配置。与 CHG-0005 交叉是**禁止项对齐**：AI 不因本需求获得业务库直连。）
- 与已规划 Story 重复: 无（STORY-1-03-01-01 正是本需求预留节点；STORY-3 / STORY-1-02-01-01 分别为 Java/Python 应用基线，不包含 Compose 四件套。）
- 处理决策: 无冲突。与 `product/08` §27.1、`product/13` 全量拓扑（含 RocketMQ/ES/向量库/监控/Nginx）的差异按**阶段裁剪**处理：那些组件仍属后续 Requirement，M0 不得提前引入；本地默认密码与「生产不用默认中间件密码」分层适用，不在本 Change 做生产加固。

## 5. 待澄清问题

1. **落仓位置**：`deploy/` 放在工作区仓（三仓共享）还是 `repo-1`（Java 侧）？需求写“优先复用已有部署目录”，当前工作区与各仓均未发现 compose 文件，需 Design 定权威路径并写入 CHG `repositories`。
2. **镜像与版本**：MySQL / Redis / Nacos / MinIO 的具体镜像 tag、Nacos 2.x vs 3.x、是否 `MODE=standalone` 以外还需鉴权模式（无鉴权 vs 默认用户），需求未钉死。
3. **端口终值**：`product/08` 已有 8848/9000/9001 等线索，但宿主机是否沿用默认、如何避免与本机已占用端口冲突、Java 配置引用单点（仅 `.env` vs 另出端口表），待 Design。
4. **MySQL 初始化粒度**：要预创建哪些 Database/Schema 名称、字符集/时区默认值、是否创建非 root 业务账号；禁止写入业务 DDL 的边界如何在 init 脚本里落实。
5. **Redis 持久化策略**：需求写“Volume 根据开发需求配置”——AOF/RDB 是否启用、down 后再 up 是否必须保留缓存数据（AC-08 对 Redis 的严格程度）。
6. **脚本形态**：start/stop/status/health 用 `.ps1`、`.sh` 还是只在 README 写 `docker compose` 原生命令；Windows + Docker Desktop 为默认假设是否成立。
7. **AC-11 准入**：Java 联调以“至少一个业务服务注册成功”还是“Gateway + 规划清单中的服务均可注册”为 PASS；CHG-0003 归档后本地是否已能启动可注册的服务，探索阶段无法验证，PRD/test 需定义 PENDING 条件。
8. **MinIO Bucket**：M0 是否预创建空 bucket（商品图 / AI 知识库占位）还是只起服务、业务侧后续自建。
9. **Network 名称**：示例 `ai-platform-network` 是否定为正式名；是否允许外部 compose（未来应用容器）attach 同一网络。
10. **与前端总验收的边界**：§二十把 Frontend→Gateway 放到“M0 总验收”，本 Change DoD 是否包含该项，还是只保证基础设施端口可被 Gateway 使用。
