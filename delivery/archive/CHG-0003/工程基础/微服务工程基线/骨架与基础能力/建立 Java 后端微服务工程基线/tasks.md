# Tasks（Repository Delivery Decomposition Plan）

> 阶段：sdd-task 产物（Phase 2.4 升级为 Delivery Decomposition Skill）
> 位置：STORY 级 —— `<CHG>/<L1>/<L2>/<L3>/<STORY>/tasks.md`（由 metadata.feature-path 决定）
> 输入：prd.md + design.md + .sdd/repositories.yaml + feature-path
> 产出状态：tasked

本文档将设计拆解为 Delivery Unit（DU）——每个 DU 是本次 Change 在一个具体仓库中的实施交付单元（DU 1:1 Repository，跨仓交付必须拆多个 DU）。

## 0. 元信息

- Change ID: CHG-0003
- Design 来源: design.md（CHG-0003）
- 状态流转: designed → tasked
- Feature Path: MOD-1 > FEAT-2 > FEAT-2-01 > STORY-3
- DU 总数: 2

## 任务清单

本 Change 为单仓（repo-1）实现型交付，按 design.md 四能力面拆为 2 个 DU：DU-BE-001 先交付公共基础能力（Web Foundation + Test Foundation 聚合器），DU-BE-002 在其产物之上完成服务与网关接入（Persistence Foundation + Skeleton 补全 + 上下文冒烟 + 全量验证）。DU 内部 1 Commit 粒度任务由 repo 侧 task.md 细化。

### DU-BE-001: 公共基础能力实现（Web Foundation + Test Foundation 聚合器）

- 目标仓库: repo-1（implementation/ai-platform-backend）
- 目标 Goal: mall-common-core/web/log/test 四模块由壳转能力实现——统一响应结构、错误码分段、TraceId 上下文（core 纯 Java 零 Spring）；TraceIdFilter、GlobalExceptionHandler、BusinessException、springdoc 传递依赖（web WebMVC 增强层）；logback-spring.xml 基础日志配置（log）；测试依赖聚合器（test），并交付 core 单元测试 + common-web @WebMvcTest 切片测试 + common-test 占位测试
- Scope（范围）:
  - mall-common-core：`UnifyResult<T>`（success/code/message/data/traceId + 静态工厂 ok/fail）、`ErrorCode` 接口 + A/B/S 分段常量、`TraceContext`（ThreadLocal，UUID 去横线 32 位）、`TraceConstants`（header=X-Trace-Id，MDC key=traceId）+ 对应单元测试；POM 零依赖保持
  - mall-common-web：`BusinessException`（RuntimeException + ErrorCode + args）、`TraceIdFilter`（OncePerRequestFilter：生成/透传/MDC+TraceContext 写入/响应头回写）、`GlobalExceptionHandler`（参数异常→400+A 段、业务异常→异常携带码+HTTP 语义、未预期→500+S 段通用文案，响应体一律 UnifyResult，禁止泄露 StackTrace/SQL/凭据）+ @WebMvcTest 切片测试；POM 增加 springdoc-openapi-starter-webmvc-ui（版本走 BOM）
  - mall-common-log：`logback-spring.xml`（console appender，pattern 含 %X{traceId}），零新增依赖
  - mall-common-test：聚合 spring-boot-starter-test + h2（test scope，均由 Boot BOM 托管）+ 1 个占位单元测试
  - 禁止事项：core 不出现任何 Spring 依赖（AC-12）；common 四模块不出现业务领域模型（AC-06）；不产生对外业务 Controller
- Design References: design.md §2.2 BOM 策略 / §2.3 Web Foundation（含接口契约：统一响应 JSON 与 TraceId 约定）/ §2.4 common/contracts 边界不变量 / §2.8 Test Foundation（聚合器与 core/web 测试部分）/ §2.9 关键组件清单
- Dependencies（依赖的 DU id）: 无
- Acceptance Criteria: AC-06 复验通过（common 无业务污染）；AC-10 通过（统一响应可使用、参数/系统异常转换、TraceId 进响应与日志——以 @WebMvcTest 切片测试为验证形态）；AC-12 core 部分通过（mall-common-core 依赖树仍仅自身坐标）；mall-common 四模块 `mvn test` 全绿
- Execution Order: 1
- Parallelization: 无（DU-BE-002 依赖本 DU 产物 `mvn install` 后才能引用）
- Implementation Sketch:
  ```text
  请求处理协作关系（mall-common-web 内，供服务继承）:
  TraceIdFilter (OncePerRequestFilter)
      ├── 读取请求头 X-Trace-Id（合法性校验：32 位十六进制）
      ├── 无/不合法 → TraceContext.generate() 生成
      ├── 写入 MDC（key=traceId）+ TraceContext（ThreadLocal）
      ├── doFilterChain → 业务处理（本 Change 无业务 Controller）
      ├── 响应头回写 X-Trace-Id
      └── finally: TraceContext.clear()（防线程池污染）
  异常 → GlobalExceptionHandler (@RestControllerAdvice)
      ├── MethodArgumentNotValidException/BindException → UnifyResult.fail(A 段码, 参数文案), HTTP 400
      ├── BusinessException → UnifyResult.fail(异常携带 ErrorCode), HTTP 语义由异常携带
      └── 其他未预期 → UnifyResult.fail(S 段通用文案), HTTP 500（不泄露 StackTrace/SQL）
  响应出口统一: UnifyResult{success, code, message, data, traceId}
  测试资产: core 纯单测（TraceContext/UnifyResult/错误码分段）
           web @WebMvcTest 切片（Filter 行为 + 三类异常路径 + 响应 JSON 断言）
  ```
- Pseudocode:（complexity-trigger: orchestration → 必填；Filter/Handler/TraceContext 多组件协作 + 关键异常分支）
  ```text
  doFilterInternal(request, response, chain):
      traceId = request.getHeader("X-Trace-Id")
      if traceId == null or not matches ^[0-9a-f]{32}$:
          traceId = TraceContext.generate()          # UUID 去横线 32 位
      TraceContext.set(traceId); MDC.put("traceId", traceId)
      try:
          chain.doFilter(request, response)
      finally:
          response.setHeader("X-Trace-Id", traceId)   # 响应头回写
          MDC.remove("traceId"); TraceContext.clear() # 防线程池污染

  handleException(ex):                              # @RestControllerAdvice 分派
      if ex is MethodArgumentNotValidException or BindException:
          return UnifyResult.fail(ErrorCode.A_PARAM, 提取字段错误文案)   # HTTP 400
      if ex is BusinessException:
          return UnifyResult.fail(ex.errorCode, ex.message)              # HTTP 语义随异常
      log.error("unhandled", ex)                     # 服务端留痕
      return UnifyResult.fail(ErrorCode.S_INTERNAL, "系统繁忙，请稍后重试")  # HTTP 500，不泄露内部信息
  ```
- Verification:
  - Unit（core）: TraceContext 生成/设置/获取/清理与线程隔离；UnifyResult ok/fail 工厂字段完整性；错误码分段常量归属正确
  - Integration（web @WebMvcTest 切片）: 参数异常→400+A 段 JSON；BusinessException→业务码 JSON；未预期异常→500+通用文案且 JSON 不含 StackTrace/SQL/类名；MockMvc 断言响应头 X-Trace-Id 与 UnifyResult.traceId 一致、请求携带合法 TraceId 时透传不重生成
  - Error Case: Filter 异常路径验证 finally 清理生效（二次请求无残留）；core 依赖树复验 `mvn dependency:tree -pl mall-common/mall-common-core` 仅自身坐标
  - 构建门: mall-common 聚合 `mvn clean test` 全绿

### DU-BE-002: 服务与网关基线接入（Persistence Foundation + Skeleton 补全 + 上下文冒烟）

- 目标仓库: repo-1（implementation/ai-platform-backend）
- 目标 Goal: 8 个业务服务 + gateway 完成依赖接入与配置统一——MyBatis-Plus/Flyway/MySQL 驱动服务直连、common-web/log/test 引用、Nacos discovery 预留（默认关闭）、application.yml 统一结构（数据源/Flyway/MyBatis-Plus/logging 环境变量化）、各服务 db/migration 目录规范、9 个 @SpringBootTest 上下文冒烟测试，并完成全量构建与测试验证留证
- Scope（范围）:
  - mall-services 8 模块（identity/member/product/cart/order/inventory/search/system）POM 增量：`mybatis-plus-spring-boot3-starter`（mybatis-plus-bom 托管）+ `flyway-core`/`flyway-mysql`（Boot BOM 托管）+ `mysql-connector-j`（runtime，Boot BOM 托管）+ nacos discovery（SCA BOM 托管）+ mall-common-web/log 依赖 + mall-common-test（test scope）
  - 8 服务 application.yml 统一结构：application name / server.port（沿用现有分配）/ datasource（`${MYSQL_HOST:localhost}:${MYSQL_PORT:3306}/${MYSQL_DB_<svc>}` + `${MYSQL_USER:root}`/`${MYSQL_PASSWORD:}`）/ `spring.flyway.enabled: ${FLYWAY_ENABLED:false}` + `locations: classpath:db/migration` / `mybatis-plus.configuration.map-underscore-to-camel-case: true` / `spring.cloud.nacos.server-addr: ${NACOS_ADDR:}` + `discovery.enabled: ${NACOS_ENABLED:false}` / logging
  - 各服务 `src/main/resources/db/migration/` 目录规范（含 .gitkeep，本阶段不提交业务表 DDL）
  - mall-gateway：POM 增 nacos discovery 预留（不依赖 common-web，WebFlux 栈隔离）+ application.yml 增 Nacos 占位
  - 测试资产：8 业务服务 + gateway 各 1 个 @SpringBootTest 上下文冒烟（Nacos 默认关闭；业务服务 DataSource 以 H2 test profile 提供，Flyway 在 H2 上执行验证配置工程正确性；gateway 无数据源直接冒烟）
  - 全量验证：`mvn clean package -DskipTests`（AC-03）与 `mvn test`（AC-11）BUILD SUCCESS 留证
  - 禁止事项：服务间实现依赖（AC-12）；BOM 版本覆盖声明（AC-05）；真实密码入库；启动断言 Nacos/MySQL 在场
- Design References: design.md §2.1 方案概要 / §2.5 模块依赖方向（目标态）/ §2.6 服务 Skeleton 补全 / §2.7 Persistence Foundation / §2.8 Test Foundation（冒烟测试部分）/ §3.1 repo-1 修改概要 / §4 集成边界（环境变量注入点）
- Dependencies（依赖的 DU id）: DU-BE-001（common-web/log/test 能力就绪并已 install）
- Acceptance Criteria: AC-01 环境核验留证；AC-02 Reactor 清单复验（24 项目在列无异常）；AC-03 全量构建 BUILD SUCCESS 留证；AC-04 单模块 `mvn clean package -pl mall-services/mall-order -am -DskipTests` BUILD SUCCESS 留证；AC-05 抽样服务 POM 无版本覆盖声明；AC-07 contracts 复验无污染（本 Change 未触碰）；AC-08 gateway+8 服务独立主类/独立打包逐一核验；AC-09 抽验服务 MyBatis-Plus/Flyway 配置正确且无跨服务库访问；AC-11 `mvn test` 全绿且含最小测试集；AC-12 全仓复验（无循环依赖、服务间无实现依赖、core 零反向依赖）
- Execution Order: 2
- Parallelization: 无（顺序执行于 DU-BE-001 之后；8 服务内部改动彼此同构可一次完成）
- Implementation Sketch:
  ```text
  目标依赖方向（design §2.5）:
  mall-services/* ──→ mall-common-web ──→ mall-common-core（单向）
        │    └────────→ mall-common-log（logback-spring.xml import 或复制）
        └─(test scope)→ mall-common-test（starter-test + h2 聚合）
  mall-services/* ──直连──→ mybatis-plus-spring-boot3-starter / flyway-core+flyway-mysql / mysql-connector-j(runtime)
  mall-gateway ──→ nacos-discovery（预留）──× mall-common-web（WebFlux 栈隔离，禁止依赖）

  配置注入链（环境变量 → application.yml 占位，为 ENG-M0-004 留接入点）:
  MYSQL_HOST/PORT/DB_<svc>/USER/PASSWORD → spring.datasource.*
  FLYWAY_ENABLED(false) + locations → spring.flyway.*
  NACOS_ADDR("") + NACOS_ENABLED(false) → spring.cloud.nacos.*

  冒烟测试形态: @SpringBootTest + test profile（H2 数据源 + Flyway 执行）→ context loads
  ```
- Pseudocode: N/A（依赖接入 + 配置统一 + 标准 @SpringBootTest 冒烟，未命中 business-flow/algorithm/state-transition/orchestration 任一触发器；组件关系与环境变量注入链已在 Implementation Sketch 给出）
- Verification:
  - Integration（构建）: `mvn clean package -DskipTests` Reactor 24 项目全 BUILD SUCCESS（AC-02/03）；`mvn clean package -pl mall-services/mall-order -am -DskipTests`（AC-04）
  - Integration（测试）: `mvn test` 全绿，新增测试数 ≥ 11（core/web 单测与切片 + 8 服务冒烟 + gateway 冒烟 + common-test 占位）（AC-11）
  - Static（边界复验）: 抽样服务 POM 无 `<version>` 覆盖声明（AC-05）；`mvn dependency:tree` 复验服务间无实现依赖、无循环（AC-12）；contracts 扫描无污染（AC-07）
  - Error Case: 无 MySQL/无 Nacos 环境下 `mvn test` 仍通过（默认关闭生效，禁启动断言）；Flyway 在 H2 test profile 执行成功验证迁移目录工程正确性；真实 MySQL/Nacos 集成项记录 Pending M0 Integration Verification（AC-09 集成部分）

## 覆盖检查（Quality Self-check）

- affected-repositories: [repo-1] → DU-BE-001 ✓ / DU-BE-002 ✓（每仓至少 1 DU；DU 1:1 仓库）
- design.md 变更点覆盖: §2.3 Web Foundation → DU-BE-001 ✓；§2.8 Test Foundation → DU-BE-001（聚合器+core/web 测试）/ DU-BE-002（冒烟）✓；§2.6 Skeleton 补全 → DU-BE-002 ✓；§2.7 Persistence Foundation → DU-BE-002 ✓；§2.5 依赖方向 → DU-BE-002（复验）✓；§2.4 边界不变量 → DU-BE-001（AC-06）/ DU-BE-002（AC-07）✓
- PRD AC 映射: AC-01/02/03/04/05/07/08/09/11/12 → DU-BE-002；AC-06/10 → DU-BE-001；AC-11/12 双 DU 共担 ✓（全覆盖无遗漏）
- 跨 DU 依赖: DU-BE-002 → DU-BE-001（单向，无循环）✓
- Implementation Sketch: 2/2 非空 ✓；Pseudocode: DU-BE-001 命中 orchestration 已写、DU-BE-002 N/A+理由 ✓；Verification: 2/2 ✓
