---
affected-repositories: [repo-1] # Phase 2.4：受影响仓库 id 列表（对应 .sdd/repositories.yaml，供 task 阶段 du-coverage 机检）
---

# Design

> 阶段：sdd-design 产物
> 输入：prd.md
> 产出状态：designed

本文档制定技术方案。

职责边界（硬约束）：Design 回答"系统如何实现、哪些仓受影响、跨仓如何协作"；不产生正式交付单元（正式拆分是 sdd-task 的职责，本文 §8 仅保留 Requirement 建议的任务域映射）。

## 0. 元信息

- Change ID: CHG-0003
- PRD 来源: CHG-0003/prd.md（STORY 目录）
- 状态流转: specified → designed
- 需求执行要求 §4 的 9 项设计记录映射：Maven 层级（§1.1）、BOM 策略（§2.2）、common/contracts 边界（§2.4）、模块依赖方向（§2.5）、服务 Skeleton（§2.6）、Web Foundation（§2.3）、Persistence Foundation（§2.7）、Test Foundation（§2.8）、任务域划分（§8）

## 1. 当前状态

结构基线已交付且经 CHG-0002 核验（Reactor 24 项目全绿、边界零违规），但公共模块均为空壳、服务无持久化/Web 基础/测试能力——本设计的出发点即在此基线上做能力补全而非重建。现状证据与已固化约束如下。

### 1.1 Maven 层级与现状（引用 implementation 证据）

- 当前架构模式: Maven 四层单体聚合（多模块 ≠ 单体）：根 POM（backend，enforcer 守门 Maven 3.9+/Java [21,22)，插件版本集中管理）→ mall-bom（唯一版本权威，无 parent，import 三大 BOM）→ 聚合层（mall-common / mall-contracts / mall-services）→ 模块层
- 相关仓库: repo-1（implementation/ai-platform-backend）
- Reactor 24 项目全绿（CHG-0002 归档证据 mvn-validate.txt）：mall-bom、mall-common(8)、mall-contracts(2)、mall-gateway、mall-services(8)
- 相关模块: mall-common-web/core/log/test（空壳，仅 package-info + 位置依赖声明）、mall-services/*/pom.xml（各仅 spring-boot-starter-web + spring-boot-maven-plugin repackage）、mall-gateway（独立 WebFlux 骨架）、全仓无 src/test

### 1.2 已固化的约束（CHG-0001 晋升 standards + CHG-0002 核验基线）

- 版本权威唯一：全部三方版本只允许出现在 mall-bom（Spring Boot 3.5.15 / Cloud 2025.0.3 / SCA 2025.0.0.0 / MyBatis-Plus 3.5.12 / MapStruct 1.6.3 / Springdoc 2.8.9；Lombok 由 Boot BOM 托管）
- mall-common-core 零反向依赖（dependency:tree 基线：仅自身坐标）
- common/contracts 无业务污染；子模块禁止声明插件版本

## 2. 提议方案

四个能力面增量补全：Web Foundation（core 纯 Java 基础 + web MVC 增强 + log 配置）、Persistence Foundation（服务直连 starter）、Test Foundation（common-test 聚合 + 最小测试集）、Skeleton 补全（Nacos 预留）；结构、边界与 BOM 权威零变更。分节设计如下。

### 2.1 方案概要

在不动 Reactor 结构与已核验边界的前提下，分四个能力面补全：**Web Foundation**（core 纯 Java 基础 + web MVC 增强层 + log 配置）、**Persistence Foundation**（8 业务服务直连 MyBatis-Plus/Flyway starter）、**Test Foundation**（common-test 依赖聚合 + 最小测试集）、**Skeleton 补全**（Nacos 依赖预留 + 配置占位）。全部新版本依赖走 mall-bom 权威（Flyway/H2 由 Spring Boot BOM 托管，不重复声明版本）。

- 方案概要: 四能力面增量补全（Web/Persistence/Test Foundation + Skeleton 补全），Reactor 结构、mall-bom 与已核验边界零变更

### 2.2 BOM 策略

- 不在 BOM 新增版本条目：Flyway、H2、MySQL 驱动（mysql-connector-j）、JUnit5/AssertJ 全部由 spring-boot-dependencies（Boot 3.5.15）托管，符合"Lombok 不重复覆盖"的同款原则
- mall-bom 仅当出现 Boot BOM 未托管的三方依赖时才追加（本 Change 预计为空）

### 2.3 Web Foundation（E 域）

**mall-common-core（纯 Java，零 Spring 依赖，守 AC-12）新增：**
- `UnifyResult<T>`：统一响应结构（字段固定 success/code/message/data/traceId），纯 POJO + 静态工厂（ok/fail）
- `ErrorCode` 接口 + 基础错误码分段常量：0=成功；A0001~ 参数类；B0001~ 业务类；S0001~ 系统类（值域初稿，评审可调）
- `TraceContext`：ThreadLocal TraceId 上下文（generate/ get/ set/ clear，UUID 去横线 32 位）；`TraceConstants`：header 名 `X-Trace-Id`、MDC key `traceId`

**mall-common-web（WebMVC 增强层）新增：**
- `TraceIdFilter`（OncePerRequestFilter）：请求无合法 TraceId → 生成；有 → 透传；写入 MDC 与 TraceContext；响应头回写 `X-Trace-Id`
- `GlobalExceptionHandler`（@RestControllerAdvice）：参数校验异常（MethodArgumentNotValidException/BindException → 400 + A 段码）、`BusinessException`（→ 业务码 + 对应 HTTP 400/404/409 语义由异常携带）、未预期异常（→ 500 + S 段通用文案）；响应体一律 UnifyResult；禁止序列化 StackTrace/SQL/凭据
- `BusinessException`（RuntimeException + ErrorCode + args）
- springdoc 依赖由 common-web 传递（springdoc-openapi-starter-webmvc-ui，版本走 BOM），业务服务零额外声明即获 OpenAPI

**mall-common-log：**
- 提供 `logback-spring.xml` 基础配置（console appender，pattern 含 `%X{traceId}`），随模块 jar 提供供服务 import 或复制；不引入任何新依赖（logback 随 starter-web）

**栈隔离（关键设计决策）**：mall-gateway 为 Spring Cloud Gateway（WebFlux 栈），**不依赖 mall-common-web**（WebMVC 专用）；gateway 的响应/异常规范属后续里程碑，本阶段 gateway 仅做依赖与配置补全。统一响应/异常/OpenAPI 能力覆盖 8 个 WebMVC 业务服务。

- 接口契约: 统一响应 JSON——`{success, code, message, data, traceId}`；TraceId header=`X-Trace-Id`，MDC key=`traceId`；错误码分段 0/A/B/S（初稿）。作为未来跨服务 Internal API 的公共响应约定

### 2.4 common/contracts 边界（不变量）

本 Change 不触碰 mall-contracts；mall-common 8 模块清单不变、不新建 common-persistence 之类模块；common 内不出现业务领域模型（AC-06/07 复验基线保持）。

### 2.5 模块依赖方向（目标态）

- 服务 → mall-common-web → mall-common-core（单向）
- 服务 → mall-common-log、mall-common-test（test scope）
- 服务 → MyBatis-Plus starter / flyway-core / flyway-mysql / mysql-connector-j（runtime）——服务直连，不经 common 中转（需求 8 模块封闭清单 + 避免 common 承载持久化语义）
- gateway → nacos discovery 预留依赖；服务 → nacos discovery 预留依赖（默认关闭，见 §2.6）
- 禁止：服务 ↔ 服务实现依赖；common-* 之间除 web→core/test→core 外互依

### 2.6 服务 Skeleton 补全（C 域）

- 服务骨架现状已满足 AC-08 主体（独立主类/repackage fat-jar），本阶段只补：
  - **依赖预留**：`spring-cloud-starter-alibaba-nacos-discovery` 加入 gateway 与 8 服务
  - **配置占位**：application.yml 增 `spring.cloud.nacos.server-addr: ${NACOS_ADDR:}` 且 `spring.cloud.nacos.discovery.enabled: ${NACOS_ENABLED:false}`——默认关闭，禁启动断言（ENG-M0-004 后由环境开启）
  - application.yml 统一结构（8 服务一致）：application name / server.port（沿用现有分配）/ datasource（`jdbc:mysql://${MYSQL_HOST:localhost}:${MYSQL_PORT:3306}/${MYSQL_DB_<svc>}`，用户名密码 `${MYSQL_USER:root}` / `${MYSQL_PASSWORD:}` 环境变量化）/ flyway / mybatis-plus / logging

### 2.7 Persistence Foundation（D 域）

- 8 业务服务 POM 新增：`mybatis-plus-spring-boot3-starter`（BOM import 的 mybatis-plus-bom 托管）、`flyway-core` + `flyway-mysql`（Boot BOM 托管）、`mysql-connector-j`（runtime，Boot BOM 托管）
- application.yml：`spring.flyway.enabled: ${FLYWAY_ENABLED:false}`（默认关闭 → 服务本机无 MySQL 也可启动，工程正确性以测试 profile 验证）、`spring.flyway.locations: classpath:db/migration`
- migration 目录规范：各服务 `src/main/resources/db/migration/`，命名 `V<版本>__<描述>.sql`；本阶段不提交业务表迁移（需求禁止提前建业务表），目录规范由设计文档固化，首个真实迁移随首个业务需求交付
- MyBatis-Plus 基础配置：`mybatis-plus.configuration.map-underscore-to-camel-case: true`；不建 Mapper/实体（业务留后续）
- 真实 MySQL 连接与迁移执行 → **Pending M0 Integration Verification**（ENG-M0-004）

### 2.8 Test Foundation（F 域 + AC-10/11 载体）

- mall-common-test：聚合 `spring-boot-starter-test`（含 JUnit5/AssertJ/Mockito）+ `h2`（test scope，Boot BOM 托管）——作为公共测试依赖聚合器供全部模块 test 引用
- 最小测试集（本 Change 交付的测试资产，全部不依赖真实 MySQL/Nacos）：
  - common-core：TraceContext（生成/透传/清理）、UnifyResult 工厂、错误码分段 —— 纯单元测试
  - common-web：@WebMvcTest 切片——参数异常转换、业务异常转换、系统异常不泄露内部信息、TraceIdFilter 生成/透传/响应头回写（MockMvc 验证 UnifyResult JSON 与 X-Trace-Id）
  - 各业务服务 + gateway：1 个 Spring 上下文冒烟测试（`@SpringBootTest`，Nacos discovery 默认关闭 + DataSource 以 H2 test profile 提供，Flyway 在 H2 上执行以验证配置工程正确性；gateway 无数据源，直接上下文冒烟）
  - mall-common-test 自身：1 个占位单元测试（保证模块参与 mvn test）
- AC-10 验证形态 = 上述 common-web 测试切片；不产生对外业务 Controller

### 2.9 关键组件清单

- 关键组件: UnifyResult / ErrorCode+分段常量 / TraceContext / TraceIdFilter / GlobalExceptionHandler / BusinessException / logback-spring.xml / common-test 聚合器 / 各服务 pom+application.yml 增量 / gateway pom+yml 增量

## 3. 仓库影响（Repository Impact）

- 受影响仓库数: 1
- 主要修改点: common 4 模块由壳转能力实现；8 业务服务 POM+配置接入持久化/Web 基础/Nacos 预留；gateway 补 Nacos 预留；新增各服务与 common 的测试资产；Reactor 结构与 mall-bom 原则上零变更

### 3.1 repo-1（implementation/ai-platform-backend）

- 技术职责: 承载上述全部工程基线能力实现与验证
- 修改概要: mall-common-core/web/log/test 新增实现与测试；mall-services 8 模块 POM 依赖接入 + application.yml 统一结构 + db/migration 目录；mall-gateway POM/yml 增量；无新增/删除模块；不改 mall-bom（除非评审发现 Boot BOM 未托管依赖）
- 涉及模块: mall-common/*（4 个）、mall-services/*（8 个）、mall-gateway、（mall-bom 视评审）

## 4. 跨仓协作（Cross-Repository Contract）

- 接口契约: 无（单仓 Change；统一响应/TraceId header 约定作为未来跨服务 Internal API 的公共约定沉淀于本设计 §2.3）
- 仓库依赖: 无
- 集成边界: Nacos 地址与开关（NACOS_ADDR/NACOS_ENABLED）、MySQL 连接参数（MYSQL_HOST/PORT/DB/USER/PASSWORD）全部经环境变量注入，为 ENG-M0-004 提供接入点
- 跨仓时序: 无

## 5. 数据变更

- 是否需 Migration: no
- 变更摘要: 不创建任何业务表（需求禁止）；仅固化各服务 db/migration 目录规范与 Flyway 配置；真实 DDL 随首个业务需求交付

## 6. 风险

- 风险等级: 中
- 主要风险:
  1. WebFlux/WebMVC 栈冲突：gateway 误依赖 common-web 将引入 Servlet 栈冲突
  2. SCA nacos-discovery 依赖引入后的启动连接尝试
  3. H2 与 MySQL 方言差异导致迁移文件"测试通过、真实库失败"
  4. 依赖下载触发沙箱拦截（D:\maven-repository 教训）
  5. 最小测试集掩盖真实集成问题
- 缓解措施:
  1. gateway 显式不依赖 common-web（§2.3 栈隔离）+ 复验依赖树
  2. discovery 默认 disabled（NACOS_ENABLED:false），禁启动断言
  3. 本阶段迁移目录仅规范不提交 DDL，H2 仅验证配置工程正确性；真实执行挂 Pending
  4. Maven 命令统一使用工作区内 -Dmaven.repo.local（CHG-0002 DEV-1 既有适配）
  5. Evidence 记录 Pending 项而非伪称 PASS（需求强制要求）

## 7. 待澄清问题

- 无阻塞性待澄清。错误码分段值域（A/B/S 段）与 header 名（X-Trace-Id）为设计内初稿决策，评审时可调整；其余实现细节（MDC key 命名、UnifyResult 字段冻结）在任务拆解阶段按本设计固化

## 8. 任务域建议（Requirement §六 建议映射，正式拆分由 sdd-task 产出）

- TASK-001 Maven 与 BOM 基线 → 本设计中为复验项（结构零变更）
- TASK-002 mall-common / mall-contracts → 复验项 + core/web/log/test 四模块能力实现（§2.3/§2.8）
- TASK-003 Gateway 与微服务 Skeleton → 骨架复验 + Nacos 预留（§2.6）
- TASK-004 MyBatis-Plus / Flyway → 服务直连接入（§2.7）
- TASK-005 Web / Response / Exception → common-web 实现（§2.3）
- TASK-006 Trace / Log / OpenAPI / Test → core TraceContext + log 配置 + OpenAPI 传递 + 最小测试集（§2.3/§2.8）
- TASK-007 全量验证与 Evidence → AC-01~AC-12 验证与归档（含 Pending 项标注）
