---
id: "ENG-M0-001"
name: "建立 Java 后端微服务工程基线"
content: "建立 AI 智能电商微服务平台完整的 Java 后端工程基线：统一工程结构、版本治理、公共技术能力、服务骨架、开发基础（数据访问/Web/日志/测试）与构建入口，作为单个完整 Change 管理（M0，P0，repo-1 backend/**）"
source: user
created-at: "2026-09-01T00:05:00+08:00"
---

# Requirement

> 本文件记录需求来源原文，由 sdd-explore 在探索阶段写入。
> 与 exploration.md 分离：本文件是输入沉淀，exploration.md 是分析产物（Feature 归属/影响分析）。
> 原始需求文档（958 行）已完整归档至 `references/ENG-M0-001.md`，未做改写；本文件为结构化导航摘录。

## 需求描述

> 以下为需求文档关键内容的忠实摘录（保持原话，未做改写），完整原文以 `references/ENG-M0-001.md` 为准。

**Requirement ID**：ENG-M0-001；**名称**：Java 后端基础工程；**Stage**：M0 项目初始化；**Priority**：P0；**Repository**：ai-mall-platform（现有 repo-1）；**Implementation Scope**：backend/**

**管理方式**：本 Requirement 作为一个完整 Change 管理，不把 Maven、mall-common、mall-contracts、Gateway、服务骨架、MyBatis-Plus、Flyway、统一响应、异常、TraceId、日志、OpenAPI、测试拆成多个独立 Change。

### 一、需求目标

建立 AI 智能电商微服务平台完整的 Java 后端工程基线：统一工程结构 + 统一版本治理 + 统一公共技术能力 + 统一服务骨架 + 统一开发基础 + 统一构建入口，使 M1 身份权限、M2 商品库存、M3 商城基础、M4 订单交易等后续业务可直接在此基线上开发。

### 二、已确认技术决策（不再讨论）

1. Java 21；2. Maven 3.9+（不用 Maven Wrapper，统一 `mvn`）；3. Spring Boot 3.5.15 / Spring Cloud 2025.0.3 / Spring Cloud Alibaba 2025.0.0.0，业务服务不得自行覆盖；4. Monorepo，backend 位于 ai-mall-platform/backend/，不新建独立 backend Git 仓库；5. mall-common 8 模块全部建立（只建边界与必要基础能力）；6. mall-contracts 2 模块只用于跨服务通信契约；7. mall-gateway + 8 业务服务（identity/member/product/cart/order/inventory/search/system）均须独立 Spring Boot Application 主类并可独立打包，M0 不实现业务；8. mall-bom 首批治理：三大 BOM + MyBatis-Plus + MapStruct + Springdoc，Lombok 用 Spring Boot BOM 版本。

### 三、需求范围（6 能力域）

- **A. Maven 与版本治理**：根聚合工程、mall-bom、Java 21 编译基线、三大框架统一版本、全量构建与 -pl -am 单模块构建；禁止业务模块自带另一套版本、大量重复声明 BOM 已管版本、循环依赖。
- **B. mall-common 与 mall-contracts**：mall-common = 技术复用、mall-contracts = API/Event Published Language、mall-services = 业务模型和规则；common 禁业务领域模型与 Repository/Mapper/DomainService/ApplicationService；contracts 禁 Aggregate/Repository/Mapper/PO/DomainService/ApplicationService/业务实现；禁止 mall-common-all 统一依赖，按需依赖。
- **C. Gateway 与业务服务骨架**：9 服务独立 Application、可独立编译/打包/出 Jar、命名与配置结构统一、为 Nacos Discovery 预留结构；不依赖本地 Nacos 已运行（Nacos 属 ENG-M0-004）；禁止提前实现任何业务逻辑。
- **D. 数据访问基础**：MyBatis-Plus 接入、通用数据访问基础配置、Flyway 接入与 migration 目录规范、各服务独立维护迁移、连接参数走配置与环境变量；禁真实密码入库、禁跨服务数据库访问、禁提前建业务表；MySQL 未就绪时只要求工程基线正确，真实连接验证可延至 M0 总验收。
- **E. Web、异常、Trace、日志和 OpenAPI 基础**：统一响应（success/code/message/data/traceId）、异常处理基础（参数/业务/系统异常转换，不得暴露 StackTrace/SQL/敏感信息）、TraceId（生成/传递/日志上下文/响应返回/为 Feign/MQ 传播预留）、统一基础日志配置（不要求完整观测平台）、OpenAPI 可生成可访问；不得为业务接口提前创建大量空 Controller。
- **F. Java 测试基础**：JUnit 5 / AssertJ / Spring Boot Test / 基础测试公共能力 / Maven Test 生命周期；可建 mall-common-test；不提前实现业务 Fixture；至少保证基础工程可执行测试并通过。

### 四、架构约束

不共享业务领域模型；服务间禁止直接 Maven 依赖实现（跨服务协作用 Internal API/OpenFeign/Integration Event/ACL）；mall-common-core 保持最轻量（不无理由依赖 Spring Web/Redis/RocketMQ/OpenFeign/业务服务）；不提前实现业务（注册登录/RBAC/商品/下单等）；不提前实现完整分布式增强（Outbox/最终一致性/ES/RAG 等）。

### 五、建议 Task / Delivery Unit 划分（单 Change 内）

TASK-001 Maven 与 BOM 基线 / TASK-002 mall-common·contracts / TASK-003 Gateway 与微服务 Skeleton / TASK-004 MyBatis-Plus·Flyway / TASK-005 Web·Response·Exception / TASK-006 Trace·Log·OpenAPI·Test / TASK-007 全量验证与 Evidence；对应 DU-BE-001~007 可按最终 Design 调整，但不得拆成 7 个独立 Change。

### 六、验收标准（AC-01 ~ AC-12）

AC-01 Java 21 / Maven ≥3.9；AC-02 全模块入 Reactor（无目录缺 module、无父 POM 指向不存在目录、无重复/无法解析）；AC-03 `mvn clean package -DskipTests` 全量 BUILD SUCCESS；AC-04 单模块 `-pl mall-services/mall-order -am` BUILD SUCCESS；AC-05 统一版本治理（Java 21 + 三大框架版本统一控制，业务服务不得自行覆盖）；AC-06 mall-common 无业务领域模型与业务实现；AC-07 mall-contracts 无 Repository/Mapper/PO/Aggregate/DomainService/ApplicationService；AC-08 gateway + 8 服务独立主类/可独立编译/打包/出 Jar；AC-09 MyBatis-Plus 与 Flyway 基础配置正确、无跨服务数据库访问；AC-10 最小验证统一响应/参数异常转换/系统异常不泄敏感信息/TraceId 入响应与日志/OpenAPI 工作（验证代码不得演变成业务功能）；AC-11 `mvn test` 通过（不得删测试/@Disabled/跳过验证伪称 PASS）；AC-12 无循环依赖、无业务服务直接实现依赖、mall-common-core 无反向依赖上层技术模块。

### 七、Evidence 要求

Environment（Java/Maven 版本）、Version Baseline（三大框架）、Maven Reactor 模块清单、Full Build、Tests（mvn test）、Module Build、Architecture Check（领域污染/实现污染/跨服务依赖/循环依赖四项检查）；依赖 ENG-M0-004 的项（Nacos 实际注册、MySQL 实际连接、Flyway 真实执行）必须记录为 **Pending M0 Integration Verification**，不得伪造 PASS。

### 八、非本需求范围

Docker Compose 基础设施、MySQL/Redis/Nacos/MinIO 容器部署（ENG-M0-004）、mall-web/mall-admin/ai-service（ENG-M0-002/003）、管理员登录/RBAC/商品/SKU/库存/会员/购物车/订单/模拟支付/RocketMQ 业务/ES/AI Agent/RAG（后续业务阶段）。

## 补充信息

- 需求来源：`docs/需求/M0/ENG-M0-001.md`（原始文档已归档至本 Change `references/ENG-M0-001.md`）
- 关联历史：ENG-BASE-001（CHG-0001 已归档）、ENG-BASE-002（CHG-0002 已归档）——两者交付了本需求 6 域中 A/B 域的结构与边界部分
