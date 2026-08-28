# PRD

> 阶段：sdd-prd 产物
> 输入：CHG Context（exploration.md + requirement.md）
> 产出状态：specified

本文档将 ENG-BASE-001 需求转化为产品规格。需求原文见 CHG-0001/references/ENG-BASE-001.md。

## 0. 元信息

- Change ID: CHG-0001
- Requirement: ENG-BASE-001（M0，P0，工程基础需求）
- Feature ID: STORY-1（Product → MOD-1 工程基础 → FEAT-1 Maven 工程与版本治理）
- 状态流转: exploring → specified

## 1. 背景

ENG-BASE-001 是 M0 里程碑的阻塞型前置工程需求：AI Mall 后端计划包含 1 个 Gateway 与 8 个业务微服务，在写任何业务代码之前，必须先建立统一的 Maven 多模块工程与版本治理基线，否则每个服务将自行决定 Java/Spring 版本，产生不可控的版本漂移。

该需求为绿地工程（`implementation/` 尚无任何代码），属于**新增**能力而非增强或替代。经探索阶段确认（exploration.md §3），本 Change 只新建 `backend/` 目录及其 POM 体系，不修改任何现有内容、无数据迁移；需求 §17 列出的统一响应、TraceId、Nacos 注册、MySQL/Redis 连接等能力全部依赖本基线，是后续所有 M0 Requirement 的前置。

技术基线已经用户确认锁定（exploration.md 技术决策）：Java 21 + Maven 3.9+（不提交 Wrapper）+ Spring Boot 3.5.15 + Spring Cloud 2025.0.3 + Spring Cloud Alibaba 2025.0.0.0，仓库策略为 ai-mall-platform Monorepo 的 `backend/` 目录。

## 2. 用户价值

本需求的用户不是 C 端消费者，而是平台的建设者与维护者（Java 后端开发工程师、架构维护者、以及执行统一构建的 CI/构建环境）。

**Job-to-be-Done：**

- 角色：Java 后端开发工程师
- 场景：When I 开始开发或维护某个微服务（如 mall-order）, I want to 在 POM 中只声明"这个服务需要哪些能力"而不需要决定"整个项目用什么 Java、Spring Boot、Spring Cloud、Spring Cloud Alibaba 版本"
- 价值：So that 全部服务共享一致的技术基线，版本升级一处完成、全模块生效，模块边界不被"为了复用方便"破坏

- 角色：构建/CI 环境
- 场景：When I 在 `backend/` 根目录执行统一构建, I want to 一次解析并构建全部 Java 模块，且在 Java/Maven 版本不满足基线时明确失败
- 价值：So that 构建结果可复现、可审计，不会因环境差异静默产出不一致的构建物

- 目标用户: 后端开发工程师、架构维护者、构建/CI 环境
- 痛点摘要: 多服务各自维护框架版本导致版本漂移；模块边界被随意复用破坏；"多模块"退化为单体；构建环境不一致导致产物不可复现
- 预期价值: 后续任何一个微服务开始开发时，开发者只需关心"这个服务需要哪些能力"；版本升级通过 mall-bom 一个中心位置完成；mall-common/mall-contracts 的边界由 Maven 依赖关系固化

## 3. 范围

### 3.1 包含

- 包含范围摘要: 建立 `backend/` Maven 多模块工程（24 个 Maven 项目：1 根 POM + 23 子模块），mall-bom 统一版本治理，9 个可独立启动的 Spring Boot 应用骨架，统一构建入口与版本守门机制

**Scope In（P0）：**

1. `backend/pom.xml` 根聚合 POM：统一坐标（项目级 groupId/version）、聚合全部模块、Java 21 编译配置、引入 mall-bom、公共 Plugin 管理、统一构建入口；
2. `mall-bom`：导入 Spring Boot 3.5.15 / Spring Cloud 2025.0.3 / Spring Cloud Alibaba 2025.0.0.0 三个 BOM；第一批额外统一管理 MyBatis-Plus、MapStruct、Springdoc；Lombok 使用 Spring Boot BOM 版本、不重复声明；
3. `mall-common` 聚合 + 8 个技术子模块骨架（core/web/security/redis/mq/openfeign/log/test）：仅模块骨架与依赖边界，不实现具体技术能力；
4. `mall-contracts` 聚合 + `mall-api-contracts`、`mall-event-contracts` 两个子模块骨架；
5. `mall-gateway`：独立 Spring Boot Application 骨架，可独立打包与启动；
6. `mall-services` 聚合 + 8 个业务服务骨架（identity/member/product/cart/order/inventory/search/system）：各含独立 Application 主类，可独立打包与启动，M0 不实现业务功能；
7. 版本守门：maven-enforcer-plugin 强制 Java 21 与 Maven 3.9+，不满足时构建显式失败；
8. 工程配置统一：UTF-8 编码、artifactId 与模块名一致、子模块 POM 精简（BOM 已管理的依赖不声明 version）；
9. 构建验证与 Evidence：根目录 `mvn clean package -DskipTests` 全量成功，形成构建证据（命令、版本、模块清单、结果）。

### 3.2 不包含

- 不包含范围摘要: 需求 §17 列出的全部运行期能力与其他工程（由其他 M0 Requirement 负责），以及任何业务功能实现

**Scope Out：**

1. 统一响应结构、统一异常处理、TraceId、日志体系、OpenAPI、Flyway —— 属其他 M0 Requirement（mall-common-* 子模块 M0 只建骨架）；
2. Nacos 实际服务注册、MySQL/Redis 实际连接、RocketMQ 实际接入 —— 属其他 M0 Requirement；
3. Docker Compose、AI Service、Vue 工程 —— 不在本需求范围；
4. 任何业务功能实现（8 个服务 M0 为空骨架）；
5. 新增微服务或扩大服务边界 —— MAY 约束明确排除；
6. Maven Wrapper 提交 —— 技术决策 7：不提交（本地/CI 保证 Maven 3.9+）。

## 4. 业务规则

1. [版本唯一性] mall-bom 已管理的依赖 → 业务模块 POM 不得声明 `<version>`；Spring Boot / Spring Cloud / Spring Cloud Alibaba 版本只能由 mall-bom 决定；
2. [版本漂移禁止] 项目公共基础依赖出现多版本共存 → 视为验收失败；确需版本例外的公共依赖 → 必须作为显式工程例外记录，禁止业务 POM 私自覆盖；
3. [Java 基线] 所有模块统一 `release=21` → 编译环境非 Java 21 时（enforcer requireJavaVersion）→ 构建显式失败，不允许静默降级；
4. [Maven 基线] 构建环境 Maven < 3.9（enforcer requireMavenVersion）→ 构建显式失败；
5. [技术基线锁定] Spring Boot 3.5.15 + Spring Cloud 2025.0.3 + Spring Cloud Alibaba 2025.0.0.0 组合一经确定 → 业务开发过程中不随意升级，升级走"改统一版本配置 → 全模块编译 → 测试 → 确认"流程；
6. [公共模块边界] mall-common 只存放公共技术能力（工具/Web/Security/Redis/MQ/OpenFeign/日志/测试基础）→ 出现 Product/Order/Inventory/Member 等业务领域模型即验收失败；
7. [契约模块边界] mall-contracts 只存放内部 API DTO、集成事件 DTO、事件公共元数据 → 出现领域聚合、Repository、MyBatis PO、业务 Service 即验收失败；
8. [依赖方向] 业务服务 → mall-common / mall-contracts 单向依赖 → 服务之间 Maven 双向依赖、common↔服务循环依赖均禁止；跨服务协作只能通过 API Contract / OpenFeign / 集成事件完成；
9. [服务独立性] 每个微服务必须能独立编译、运行、测试、打包、生成 Spring Boot Jar 与 Docker Image → Maven 多模块只用于工程治理，全量构建不得只产出单体 Jar；
10. [坐标一致] 全部模块使用统一项目级 groupId 与 version，artifactId 与模块名一致（mall-*）→ 子模块不得自建独立版本体系；版本升级必须能通过统一位置完成；
11. [编码与命名] 全模块 `project.build.sourceEncoding=UTF-8`；模块命名与 product/08-系统与微服务架构.md 定义的服务名保持一致；
12. [敏感信息] POM 文件中出现密码、Token、数据库连接串等敏感配置 → 不允许（应使用环境变量/外部配置）。

## 5. 验收标准

以下标准与需求原文 §19 的 AC-01~AC-10 一一对应（PRD AC-N ↔ 原文 AC-0N），并补充证据要求：

- [ ] AC-1: 在 `backend/` 执行 Maven 构建 → Reactor 正确识别全部 24 个 Maven 项目（1 根 POM + mall-bom + mall-common 聚合及 8 个子模块 + mall-contracts 聚合及 2 个子模块 + mall-gateway + mall-services 聚合及 8 个服务），无模块缺失、无路径错误、无 artifactId 冲突；
- [ ] AC-2: 在 `backend/` 执行 `mvn clean package -DskipTests` → BUILD SUCCESS，全部模块构建成功；
- [ ] AC-3: 检查全部模块有效 POM → 统一编译到 Java 21（release=21 或等效统一配置），无任何模块使用 Java 17/8 等其他版本；用非 Java 21 环境执行构建 → 因 enforcer 检查显式失败（非静默成功）；
- [ ] AC-4: 检查 9 个应用模块（gateway + 8 服务）的 Effective POM / Dependency Tree → Spring Boot 版本唯一（3.5.15，由 mall-bom 提供），无任何业务模块自行声明 Spring Boot 版本；
- [ ] AC-5: 检查全部 Spring Cloud 依赖 → 版本统一（2025.0.3）来自统一 Dependency Management，无微服务分别维护版本；
- [ ] AC-6: 检查全部 spring-cloud-starter-alibaba-* 依赖 → 版本统一（2025.0.0.0）由统一版本管理提供；
- [ ] AC-7: 检查 mall-common 源码树 → 不存在 Product、Order、Inventory、Member 等具体业务领域代码（M0 为空骨架时，包结构中无业务包）；
- [ ] AC-8: 检查 mall-contracts 源码树 → 只包含 API/Event 契约占位结构，不包含 Repository、领域聚合或业务实现；
- [ ] AC-9: 全模块依赖解析正常 → 不存在 Maven 循环依赖，不存在业务服务之间的双向 Maven 依赖；
- [ ] AC-10: mall-gateway 与 8 个业务服务分别产出独立可执行 Spring Boot Jar（repackage），各自可独立启动（M0 无业务功能）→ 全量构建不产出包含所有业务的单体 Jar；
- [ ] AC-11: 形成构建 Evidence → 至少记录 Requirement（ENG-BASE-001）、Java 版本（21）、Maven 版本（3.9+）、构建命令、Result（PASS/FAIL）、实际参与构建的模块清单与异常说明，不允许只写"构建应该可以通过"。
