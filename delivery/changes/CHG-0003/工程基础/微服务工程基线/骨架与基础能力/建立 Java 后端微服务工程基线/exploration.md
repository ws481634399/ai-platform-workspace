# Exploration

> 阶段：sdd-explore 产物
> 输入：Requirement（requirement.md）
> 产出状态：exploring（推进 Change 状态）

本文档记录 sdd-explore 阶段的探索结果。

## 1. 需求理解

**需求类型**：新功能开发（工程基线补全型）——不是全新建设，而是"在已交付结构与边界之上补基础能力"。

**需求本质**（表面描述 vs 实际意图）：

- 表面：建立完整的 Java 后端工程基线（6 能力域 A~F + 12 AC + DoD + Evidence）。
- 实际：ENG-BASE-001（CHG-0001）/ ENG-BASE-002（CHG-0002）已交付 **A 域（Maven 与版本治理）与 B 域（common/contracts 结构与边界）**，并已核验。本需求的**真实增量是 C 域确认 + D/E/F 域实现**：
  - **C 域（骨架）已基本存在**：mall-gateway + 8 业务服务骨架已由 CHG-0001 交付（Maven Reactor 24 项目、各服务独立 Application 主类 + application.yml + spring-boot-maven-plugin fat-jar + 端口分配），本需求只需按 AC-08 复验确认并补齐可能的缺口（如 Nacos 依赖预留结构），**不是重建**；
  - **D 域（数据访问基础）完全缺失**：服务 POM 目前仅依赖 spring-boot-starter-web，无 MyBatis-Plus/Flyway 依赖与配置（BOM 版本治理已就绪但未接入）；
  - **E 域（Web 基础）完全缺失**：mall-common-web/core/log 等公共模块均为空壳（仅 package-info.java，CHG-0001 交付定位即 buildable skeleton），统一响应/异常处理/TraceId/日志基础/OpenAPI 接入为从零实现；
  - **F 域（测试基础）完全缺失**：全仓无任何 src/test 测试类，mall-common-test 为空壳，mvn test 目前无可执行内容。

**隐含需求**（用户未明说但文档已固化）：不依赖 ENG-M0-004 的真实 Nacos/MySQL 环境（集成验证挂 Pending）；验证代码不得演变为业务功能；不得为通过验收伪造证据；已有实现不得覆盖重建（执行要求 §2/§10）。

## 2. Feature 归属

- Feature ID: STORY-3
- Feature 路径: MOD-1 工程基础 > FEAT-2 微服务工程基线 > FEAT-2-01 骨架与基础能力 > STORY-3 建立 Java 后端微服务工程基线
- 是否新建 candidate: no（正式节点，已在探索阶段创建并晋升；归属方案经用户确认：能力域超出 FEAT-1"工程结构与公共模块"边界，故新建 FEAT-2；L3 层同时规避 harness bind 对 "story directly under L2" 的已知遍历缺陷）

## 3. 影响分析

- 受影响仓库: repo-1（implementation/ai-platform-backend）
- 受影响模块:
  - **mall-common**：mall-common-web（统一响应/异常处理）、mall-common-core（TraceId 基础/通用错误结构，保持最轻量）、mall-common-log（日志基础配置）、mall-common-test（JUnit5/AssertJ/Spring Boot Test 公共能力）——由空壳到基础能力实现；mall-common-redis/mq/security/openfeign 本阶段仍保持边界占位（仅按需声明依赖，不提前实现完整能力）
  - **mall-services/**：8 个服务 POM 接入 MyBatis-Plus/Flyway/springdoc 等依赖与统一配置结构，application.yml 补数据源（环境变量化）/Flyway/日志/OpenAPI 配置骨架；mall-gateway 同步补齐（网关不接数据库）
  - **mall-bom**：确认 MyBatis-Plus/Flyway/H2（或测试用）等首批版本已治理（MyBatis-Plus/MapStruct/Springdoc 已在 BOM，Flyway 版本来源需设计阶段确认——Spring Boot BOM 已管理 Flyway）
  - 无业务领域模型变更，无数据迁移（禁止提前建业务表）
- 影响范围: 已核验的 AC-06/07/12（边界与依赖方向）必须保持不回退；Reactor 结构不变更（仅模块内部 POM/配置增强）；对 M1+ 业务开发形成直接基线

## 4. 未知问题

留待 PRD/设计阶段澄清：

- 统一响应与 TraceId 的归属划分：统一响应结构（success/code/message/data/traceId）与异常处理放 mall-common-web；TraceId 生成/日志上下文放 mall-common-core 还是 web？需结合 AC-12"core 保持最轻量"划分（倾向：core 放 TraceId 上下文纯 Java 实现 + 通用错误码结构，web 放 Filter/Advice）
- MyBatis-Plus/Flyway 的接入方式：各服务直接依赖 starter 并各自配置，还是 mall-common 提供持久化基础封装模块？文档未规划 mall-common-persistence 模块，倾向服务直连 + 公共配置说明，需设计确认
- 测试基线的最小测试集：当前全仓无测试类，AC-11 要求 mvn test 通过——需定义基础测试范围（如各服务 contextLoads + common-web 单元测试）；MyBatis-Plus 接入后 contextLoads 是否需要真实 DataSource（倾向 H2 或排除自动配置），需设计阶段定
- AC-10"最小验证"的实现载体与摆放位置（验证 Controller/集成测试如何避免演变为业务功能）
- Flyway migration 目录规范细节（各服务 src/main/resources/db/migration?）与验证策略（MySQL 未就绪时如何证明"工程基线正确"）
- Nacos 依赖预留的正确结构（依赖声明 + bootstrap/application 配置占位 vs 注释预留）

## 5. 旧需求沿用判断

- 匹配进行中 Change: 无（当前无进行中 Change）
- 匹配 archived Change: CHG-0001（ENG-BASE-001，交付 Maven 层级/BOM/公共模块骨架/服务骨架）、CHG-0002（ENG-BASE-002，核验 9 AC + core 依赖方向，确认边界零违规）
- 决策: 新建 CHG-0003（能力增量交付型，区别于 CHG-0002 的核验型）；**复用 CHG-0001 交付的全部结构与骨架，不重建不覆盖**（执行要求 §2/§10）；A/B 域验收项直接引用 CHG-0001/0002 归档证据 + 本 Change 复验，增量集中在 C 确认与 D/E/F 实现

## 参考文档

- `references/ENG-M0-001.md` — 用户提供的原始需求文档（958 行，完整归档）
- `standards/engineering/backend/framework-standard.md` — CHG-0001 已晋升的版本基线/POM 体系/依赖边界规范（§7.3/§7.4）
- `standards/INDEX.md` — 编码/架构/测试/API/数据库规范索引（D/E/F 域设计的约束来源）
- `delivery/archive/CHG-0001/`、`delivery/archive/CHG-0002/` — 前置 Change 归档（结构基线与边界核验证据）
