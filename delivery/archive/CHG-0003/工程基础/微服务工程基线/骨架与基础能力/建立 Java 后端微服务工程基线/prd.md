# PRD

> 阶段：sdd-prd 产物
> 输入：CHG Context（exploration.md + requirement.md）
> 产出状态：specified

本文档将需求转化为产品规格。

## 0. 元信息

- Change ID: CHG-0003
- Requirement: ENG-M0-001（原始文档 958 行归档于 references/ENG-M0-001.md）
- Feature ID: STORY-3（MOD-1 工程基础 > FEAT-2 微服务工程基线 > FEAT-2-01 骨架与基础能力）
- 状态流转: exploring → specified

## 1. 背景

CHG-0001/CHG-0002 已交付并核验了 Java 后端的**工程结构与边界**（Maven 四层体系、mall-bom 版本治理、mall-common 8 模块 + mall-contracts 2 模块、Gateway + 8 业务服务骨架，Reactor 24 项目全绿），但公共模块均为空壳（仅 package-info）、服务无数据访问能力、无统一响应/异常/TraceId/日志/OpenAPI 基础、全仓零测试类。

M1 身份权限、M2 商品库存、M3 商城基础、M4 订单交易等后续业务需求即将进入实施，若不在 M0 补齐这些**基础能力**，各业务服务将各自搭建数据访问/响应规范/异常处理/测试，造成实现漂移与重复劳动。本 Change 是 M0 后端主体交付：在已有结构基线上补全 D/E/F 域能力并全量验证，单 Change 管理（Requirement 明确禁止拆分为多个 Change）。

## 2. 用户价值

- 目标用户: M1~M4 业务需求的实施者（后端开发 Agent / 工程师）与平台构建/运维角色
- 痛点摘要: 公共模块是空壳、服务无数据访问与 Web 基础能力，每开发一个业务服务都要重复搭建 MyBatis-Plus/Flyway 配置、响应与异常规范、TraceId、日志与测试底座；各服务自建将产生实现漂移，且无法通过统一构建入口验收
- 预期价值: When I 开始开发 M1+ 业务需求, I want to 在具备统一数据访问/Web 规范/日志/OpenAPI/测试基线的服务骨架上直接编写业务代码, So that 不再重复处理工程问题、服务间行为一致，且全仓可通过 mvn 一键构建与测试验收

## 3. 范围

### 3.1 包含

- 包含范围摘要: 在 CHG-0001 结构基线上补全工程基础能力（不重建已有骨架）：
  1. **复验并补齐服务骨架**（C 域）：按 AC-08 复验 Gateway + 8 服务独立主类/可打包符合性，补齐缺口
  2. **接入数据访问基础**（D 域）：MyBatis-Plus 与 Flyway 接入 8 个业务服务，统一配置结构，migration 目录规范，连接参数环境变量化
  3. **实现统一响应与异常处理**（E 域）：mall-common-web 提供统一响应结构（success/code/message/data/traceId）与全局异常处理基础（参数/业务/系统异常 → HTTP 转换，不泄露内部敏感信息）
  4. **实现 TraceId 基础**（E 域）：缺省生成、合法传递、写入日志上下文、响应返回，为 Feign/MQ 传播预留
  5. **建立日志基础**（E 域）：mall-common-log 提供统一基础日志配置（不含完整观测平台）
  6. **接入 OpenAPI**（E 域）：HTTP 服务可生成/访问 OpenAPI 文档
  7. **建立测试基础**（F 域）：mall-common-test 提供 JUnit5/AssertJ/Spring Boot Test 公共能力，建立最小测试集，mvn test 通过
  8. **预留 Nacos 结构**：依赖声明与配置占位（不含真实注册验证）
  9. **全量验证与 Evidence**：AC-01~AC-12 逐项验证归档，依赖 ENG-M0-004 的项标注 Pending M0 Integration Verification
  10. **边界保持复验**：AC-06/07/12 边界不回退（common/contracts 无污染、无循环依赖）

### 3.2 不包含

- 不包含范围摘要:
  - Nacos 实际注册、MySQL 实际连接、Flyway 真实执行的**集成验证**（ENG-M0-004 / M0 总验收，本 Change 记 Pending）
  - Docker Compose、MySQL/Redis/Nacos/MinIO 容器基础设施（ENG-M0-004）
  - mall-web / mall-admin 前端、ai-service（ENG-M0-002/003）
  - 一切业务功能：注册登录、RBAC、商品、SKU、库存、购物车、订单、模拟支付、搜索、会员、系统配置
  - 分布式增强：Outbox、消息最终一致性、RocketMQ 业务、延迟订单、Elasticsearch、RAG、Prometheus/Grafana/Loki/SkyWalking 完整观测平台
  - mall-common-redis/mq/security/openfeign 的完整能力实现（本阶段仅保持模块边界与占位）
  - Maven Wrapper（明确不使用，统一 mvn）
  - 业务测试 Fixture（OrderFixture/ProductFixture/InventoryFixture 等）

## 4. 业务规则

- [版本唯一性] 业务服务 POM 自行声明另一套 Spring Boot/Cloud/SCA 版本 → 违反 BOM 版本权威 → 不允许（由 mall-bom + enforcer 守门约束）
- [core 轻量性] mall-common-core 出现对 Spring Web/Redis/RocketMQ/OpenFeign/业务服务的依赖 → AC-12 违规 → 必须移除（复用 CHG-0002 已核验的零依赖基线）
- [common 边界] mall-common 中出现业务领域模型（Product/Order/Inventory/Member 等）或 Repository/Mapper/DomainService/ApplicationService → AC-06 违规
- [contracts 边界] mall-contracts 中出现 Aggregate/Repository/Mapper/PO/DomainService/ApplicationService/业务实现 → AC-07 违规
- [凭据安全] 数据库真实密码写入代码或提交 Git → 禁止；连接参数必须通过配置与环境变量提供
- [数据隔离] 各服务只维护自己的 Flyway migration 目录 → 跨服务数据库访问禁止
- [证据真实性] 依赖 ENG-M0-004 才能完成的验证（Nacos 注册/MySQL 连接/Flyway 真实执行）→ 必须记录 Pending M0 Integration Verification → 不得伪造 PASS、不得删除测试或 @Disabled 掩盖失败
- [验证代码边界] AC-10 最小验证代码 → 只能以测试形态存在 → 不得演变为正式业务功能（不建业务表、不写业务 Controller）
- [无空转依赖] 服务按需依赖 common 模块 → 禁止创建 mall-common-all 式统一依赖
- [构建入口] 全量构建与单模块 -pl -am 构建统一使用 mvn 命令 → 均须 BUILD SUCCESS

## 5. 验收标准

> 编号沿用需求文档 AC-01~AC-12（保持稳定，供 task 阶段 DU 引用），Smart 化表述：

- [ ] AC-01: 环境核验输出 Java=21 且 Maven>=3.9（Evidence: Environment 记录）
- [ ] AC-02: mvn 校验 Reactor 模块清单——全部规划模块在列，无"有目录未入 module"、无父 POM 指向不存在目录、无重复 module、无解析失败
- [ ] AC-03: backend/ 根目录执行 mvn clean package -DskipTests → BUILD SUCCESS（Evidence: 全量构建日志）
- [ ] AC-04: mvn clean package -pl mall-services/mall-order -am -DskipTests → BUILD SUCCESS（Evidence: 单模块构建日志）
- [ ] AC-05: 版本核验——Java 21 / Spring Boot 3.5.15 / Spring Cloud 2025.0.3 / SCA 2025.0.0.0 由 mall-bom 统一管理，抽样业务服务 POM 无版本覆盖声明
- [ ] AC-06: 静态扫描 mall-common 全部子模块 → 无业务领域模型与 Repository/Mapper/DomainService/ApplicationService（引用 CHG-0002 基线 + 本 Change 复验）
- [ ] AC-07: 静态扫描 mall-contracts 全部子模块 → 无 Repository/Mapper/PO/Aggregate/DomainService/ApplicationService
- [ ] AC-08: mall-gateway + 8 业务服务逐一核验——存在独立 @SpringBootApplication 主类、可独立编译打包、产出独立 Jar
- [ ] AC-09: 抽验服务配置——MyBatis-Plus 与 Flyway 基础配置存在且正确（无跨服务数据库访问；真实 MySQL 连接验证挂 Pending）
- [ ] AC-10: 最小验证通过——统一响应可使用、参数异常可转换、系统异常不暴露 StackTrace/SQL/敏感信息、TraceId 进入响应与日志、OpenAPI 可访问；验证形态为测试，不产生业务功能
- [ ] AC-11: mvn test → BUILD SUCCESS，且至少包含本 Change 新增的最小测试集（不得删测试/@Disabled/伪称 PASS）
- [ ] AC-12: 依赖方向复验——无 Maven 循环依赖、无业务服务直接依赖其他业务服务实现、mall-common-core 依赖树无上层技术模块（引用 CHG-0002 dependency:tree 基线 + 本 Change 复验）

### 未知问题定向决策（承接 exploration §4）

1. **TraceId 归属**：TraceId 生成/上下文/日志 MDC 采用纯 Java 实现放 mall-common-core（守 AC-12 轻量性）；Servlet Filter/响应回写放 mall-common-web。细节（MDC key、header 名、长度策略）留设计阶段
2. **MyBatis-Plus/Flyway 接入方式**：各服务直接依赖官方 starter 并按公共配置规范配置，**不新建 mall-common-persistence 模块**（Requirement 的 8 模块清单为封闭清单）；公共规范沉淀至设计文档
3. **最小测试集**：每业务服务至少 1 个 Spring 上下文冒烟测试（不依赖真实 MySQL——排除 DataSource 自动配置或使用测试嵌入方案）+ mall-common-core/web 单元测试；具体形态留设计阶段
4. **AC-10 验证载体**：以 common-web 的集成测试/测试切片实现，不提供对外业务 Controller
5. **Flyway 目录规范**：各服务 src/main/resources/db/migration；MySQL 未就绪时验证配置结构与迁移文件工程正确性，真实执行挂 Pending
6. **Nacos 预留结构**：依赖声明 + application.yml 配置占位，禁止任何要求 Nacos 在场的启动断言
