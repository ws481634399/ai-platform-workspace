# Design

> 阶段：sdd-design 产物
> 输入：prd.md
> 产出状态：designed

本文档制定 CHG-0001（ENG-BASE-001，Java Maven 多模块工程与版本治理基线）的技术方案。架构依据：product/08-系统与微服务架构.md。

## 0. 元信息

- Change ID: CHG-0001
- PRD 来源: CHG-0001/prd.md
- 状态流转: specified → designed

## 1. 当前状态

本 Change 为绿地工程：`implementation/` 下仅有说明文档，无任何现有代码，因此不存在需要兼容的既有架构；但目标架构已在知识库中定义（product/08-系统与微服务架构.md：DDD 分层 + Spring Cloud Alibaba 微服务 + Python AI 服务），本设计的职责是把该架构决策落实为 Maven 工程基线。

- 当前架构模式: 绿地工程（无代码）；目标模式 = Spring Cloud Alibaba 微服务 + 模块内 DDD 分层
- 相关仓库: repo-1（ai-mall-platform Monorepo，backend 位于 `backend/` 目录）
- 相关模块: backend/（24 个 Maven 项目全部新建）

**技术基线（用户已锁定）：** Java 21 / Maven 3.9+（不提交 Wrapper）/ Spring Boot 3.5.15 / Spring Cloud 2025.0.3 / Spring Cloud Alibaba 2025.0.0.0 / MyBatis-Plus（版本治理首批）。

## 2. 提议方案

- 方案概要: 四层 POM 聚合体系——`backend/pom.xml` 根聚合（守门与编译治理）→ `mall-bom`（唯一版本权威，packaging=pom）→ `mall-common` / `mall-contracts`（技术层与契约层，packaging=pom）→ `mall-services`（8 个可独立打包启动的 Spring Boot 应用骨架）+ `mall-gateway`。M0 全部模块为"可构建骨架"：POM + 包结构 + 应用模块最小启动类，不实现业务与技术能力
- 关键组件: 根 POM / mall-bom / mall-common(8) / mall-contracts(2) / mall-gateway / mall-services(8)
- 接口契约: 本 Change 无业务 API；工程契约见 §2.6（构建命令、模块命名、依赖方向）

### 2.1 POM 层级与模块清单（24 个 Maven 项目）

```text
backend/                                    # 根 POM（com.ai-mall:backend:1.0.0-SNAPSHOT, pom）
├── pom.xml                                 # 聚合 + 编译/插件/enforcer 治理
├── mall-bom/pom.xml                        # 版本权威（pom）
├── mall-common/pom.xml                     # 聚合（pom，父=backend）
│   ├── mall-common-core/                   # jar（父=mall-common，下同）
│   ├── mall-common-web/
│   ├── mall-common-security/
│   ├── mall-common-redis/
│   ├── mall-common-mq/
│   ├── mall-common-openfeign/
│   ├── mall-common-log/
│   └── mall-common-test/
├── mall-contracts/pom.xml                  # 聚合（pom，父=backend）
│   ├── mall-api-contracts/                 # jar
│   └── mall-event-contracts/               # jar
├── mall-gateway/pom.xml                    # jar（父=backend，Spring Cloud Gateway 应用）
└── mall-services/pom.xml                   # 聚合（pom，父=backend）
    ├── mall-identity/                      # jar（父=mall-services，下同）
    ├── mall-member/
    ├── mall-product/
    ├── mall-cart/
    ├── mall-order/
    ├── mall-inventory/
    ├── mall-search/
    └── mall-system/
```

### 2.2 根 POM（backend/pom.xml）设计

| 关注点 | 设计 |
|---|---|
| 坐标 | groupId=`com.ai-mall`、artifactId=`backend`、version=`1.0.0-SNAPSHOT`，全部子模块继承 |
| properties | `java.version=21`、`maven.compiler.release=21`、`project.build.sourceEncoding=UTF-8`、`project.reporting.outputEncoding=UTF-8`、框架版本属性集中声明 |
| dependencyManagement | 仅一条：import `com.ai-mall:mall-bom:${project.version}` |
| pluginManagement | maven-compiler-plugin、maven-enforcer-plugin、spring-boot-maven-plugin、maven-surefire-plugin、maven-resources-plugin 统一版本与配置 |
| plugins（全模块生效） | maven-enforcer-plugin：`requireMavenVersion [3.9,)` + `requireJavaVersion [21,22)` → 不满足即构建显式失败 |
| modules | mall-bom、mall-common、mall-contracts、mall-gateway、mall-services |

### 2.3 mall-bom 设计（唯一版本权威）

- `dependencyManagement` import 三方 BOM：`spring-boot-dependencies:3.5.15`、`spring-cloud-dependencies:2025.0.3`、`spring-cloud-alibaba-dependencies:2025.0.0.0`；
- 直接管理首批公共依赖：`com.baomidou:mybatis-plus-bom`（MyBatis-Plus 官方 BOM）、`org.mapstruct:mapstruct`（含 processor）、`org.springdoc:springdoc-openapi-starter-*`；
- **Lombok 不在此声明**——版本由 spring-boot-dependencies 托管（技术决策 6）；
- mall-bom 自身不依赖任何模块、不加入任何模块的 dependencies，只被 import。

### 2.4 模块依赖方向（M0 依赖边界）

```text
mall-services/* ──→ mall-common/*（技术能力，M0 仅声明的骨架依赖）
mall-services/* ──→ mall-contracts/*（契约，M0 可暂不声明，按需）
mall-gateway ──→ （M0 仅 Spring Cloud Gateway 官方 starter）
mall-common / mall-contracts ──→ 无内部业务依赖（仅官方 starter/库）
服务 ↔ 服务：禁止 Maven 依赖；跨服务协作 = API Contract / OpenFeign / 集成事件
```

M0 子模块 POM 只声明其**定位所需**的依赖（版本全部由 BOM 提供，禁止写 `<version>`）：

| 模块 | M0 声明的依赖（示例边界） |
|---|---|
| mall-common-core | 无第三方依赖（纯工具定位） |
| mall-common-web | spring-boot-starter-web |
| mall-common-security | spring-boot-starter-security |
| mall-common-redis | spring-boot-starter-data-redis |
| mall-common-mq | spring-cloud-starter-stream-rocketmq（或 rocketmq-spring-boot-starter，实现阶段按需调整） |
| mall-common-openfeign | spring-cloud-starter-openfeign + loadbalancer |
| mall-common-log | spring-boot-starter-logging（仅聚合定位） |
| mall-common-test | spring-boot-starter-test（scope=test） |
| mall-api-contracts / mall-event-contracts | 无依赖（纯 DTO 定位） |
| mall-gateway | spring-cloud-starter-gateway（webflux 传递） |
| mall-services/8 服务 | spring-boot-starter-web（最小启动） |

### 2.5 应用模块独立性设计（AC-10 关键）

- 9 个应用模块（mall-gateway + 8 服务）各自含最小启动类 `com.ai.mall.<svc>.Mall<Svc>Application`（仅 `@SpringBootApplication`，无业务 Bean）；
- 各应用模块 POM 绑定 `spring-boot-maven-plugin`（repackage goal，版本/配置继承 pluginManagement）→ `mvn package` 产出独立可执行 Fat Jar；
- 各应用模块含最小 `application.yml`：`spring.application.name`（服务名）+ `server.port`（gateway=8080，identity/member/product/cart/order/inventory/search/system=8101~8108 顺序分配）——仅保证 M0 可独立启动验证，不涉及 Nacos/DB 配置（属后续 Requirement）；
- mall-gateway、mall-services 子模块不配置 repackage 之外的任何业务逻辑。

### 2.6 工程契约（无业务 API 的"接口契约"）

1. **构建命令契约**：根目录全量 `mvn clean package -DskipTests`（AC-2）；单模块 `mvn -pl mall-services/mall-order -am package -DskipTests`（`-am` 自动带依赖，不要求手动 install，满足需求 §14.3）；
2. **模块命名契约**：目录名 = artifactId = `mall-*`，与 product/08 服务名一一对应；
3. **依赖方向契约**：§2.4 图即规范，Maven 循环依赖/服务间依赖视为构建失败（AC-9）；
4. **版本声明契约**：业务/技术模块 POM 出现 BOM 已管依赖的 `<version>` 即违规（PRD 规则 1、AC-4~6）；
5. **敏感信息契约**：M0 全部 POM 无密码/Token/连接串（PRD 规则 12）。

## 3. 仓库影响

repos-involved: repo-1

- 受影响仓库数: 1
- 主要修改点: 仅 repo-1（Monorepo）新增 `backend/` 目录，无任何现有文件修改

| 仓库 | 模块 | 文件数（估算） | 变更类型 |
|------|------|--------|---------|
| repo-1 | backend/*.xml（24 个 POM） | 24 | 新增 |
| repo-1 | backend/ 应用启动类（9 个 Application） | 9 | 新增 |
| repo-1 | backend/ application.yml（9 个） | 9 | 新增 |
| repo-1 | backend/ 包结构占位（.gitkeep 或 package-info） | ~13 | 新增 |
| repo-1 | backend/README.md（构建说明 + JDK 21/Maven 3.9 要求） | 1 | 新增 |
| repo-1 | 根 .gitignore（target/ 等） | 1 | 新增 |

合计约 57 个新增文件，0 个修改/删除。

## 4. 数据变更

- 是否需 Migration: no
- 变更摘要: 无数据库接入（MySQL/Flyway 属后续 M0 Requirement），本 Change 无任何数据结构变更。

## 5. 风险

- 风险等级: 低-中（绿地工程，无兼容性/数据风险；主要风险集中在版本组合验证）
- 主要风险与缓解措施:

| 风险项 | 级别 | 缓解措施 |
|--------|------|---------|
| 版本组合兼容性（Boot 3.5.15 + Cloud 2025.0.3 + SCA 2025.0.0.0） | 中 | 实现阶段以 `mvn dependency:tree` 与全量编译实测验证；发现冲突时按用户决策 2 为基线协调，必要时记录显式例外并回报 |
| mall-common-mq 的 starter 选型（rocketmq 官方 starter vs spring-cloud-stream-rocketmq） | 低 | M0 仅骨架依赖，实现阶段按 08-架构 的集成方式定夺并保持 BOM 管版本 |
| Lombok 依赖 Boot BOM 版本、注解处理器在 Java 21 下的生效性 | 低 | 编译验证（mapstruct/lombok annotation processor 顺序问题留待实际使用时处理，M0 无映射代码） |
| enforcer 使 CI/新环境构建失败 | 中 | 失败信息即"明确构建失败"的需求语义（PRD 规则 3/4）；backend/README 标注 JDK 21 + Maven 3.9+ 环境要求 |
| 9 个空应用启动的端口冲突 | 低 | §2.5 端口规划（8080 + 8101~8108），互不冲突 |
| "多模块退化为单体"（repackage 缺失或误配） | 中 | pluginManagement 统一 + 每应用模块显式绑定 repackage；AC-10 验收时逐一验证独立 Jar 可启动 |

- 缓解措施: 见上表；全部风险均可在本 Change 的构建 Evidence（AC-11）中留下实测记录。

## 6. 待澄清问题

无阻塞性待澄清项——探索阶段 6 个未知问题已全部由用户技术决策关闭（exploration.md）。留两项实现期核对（不阻塞设计批准）：

1. Spring Cloud 2025.0.3 与 Spring Cloud Alibaba 2025.0.0.0 的官方兼容矩阵正式核对（实现阶段以 dependency:tree + 编译实测兜底）；
2. mall-common-mq 的 RocketMQ starter 具体坐标选型（BOM 管版本的前提下不影响本设计结构）。
