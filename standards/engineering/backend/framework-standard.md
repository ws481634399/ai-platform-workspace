# 后端框架使用规范

> 版本：v0.1  
> 类型：后端工程规范  
> 作用域：OpenSpec Workspace


# 1. 文档目的


本文档定义后端技术框架、基础设施组件和工程配置的使用规范。


目标：

- 保证技术栈使用统一；
- 降低框架使用复杂度；
- 提升系统稳定性；
- 指导 AI Coding Agent 正确使用后端框架。


---

# 2. 框架使用原则


## 2.1 技术服务于业务


框架应该解决工程问题。


选择框架时应考虑：

- 业务需求；
- 团队维护能力；
- 技术成熟度；
- 长期维护成本。


避免：

为了技术先进而引入复杂方案。


---

## 2.2 遵循框架最佳实践


使用框架时：

应该遵循官方推荐方式。


避免：

- 过度封装；
- 破坏框架生命周期；
- 自定义不必要机制。


---

## 2.3 保持技术边界


框架应该服务于对应层。


例如：

```
Web框架

负责：

接口处理


ORM框架

负责：

数据访问


消息框架

负责：

异步通信
```


避免：

框架职责混乱。


---

# 3. Spring类框架使用规范


> 说明：本规范不绑定具体技术框架，以下以常见后端框架为例。


---

## 3.1 应用启动规范


应用启动类负责：

- 服务初始化；
- 框架启动。


不应该：

包含业务逻辑。


---

## 3.2 依赖注入规范


推荐：

使用构造器注入。


示例：

```java
public class OrderService {

    private final OrderRepository repository;

    public OrderService(OrderRepository repository) {
        this.repository = repository;
    }
}
```


避免：

大量使用隐藏依赖。


---

## 3.3 配置管理规范


配置应该：

- 集中管理；
- 环境隔离；
- 可追踪。


例如：

```
application-dev.yml

application-test.yml

application-prod.yml
```


禁止：

将敏感配置直接提交代码。


---

# 4. 微服务基础设施规范


## 4.1 服务注册与发现


微服务环境中：

服务应该通过统一机制进行发现。


要求：

- 服务名称明确；
- 注册信息准确；
- 健康检查有效。


---

## 4.2 配置中心


公共配置应该集中管理。


包括：

- 数据库配置；
- 服务地址；
- 系统参数。


避免：

每个服务维护大量重复配置。


---

## 4.3 服务通信


服务通信应该：

- 明确协议；
- 明确接口；
- 明确异常处理。


避免：

直接依赖内部实现。


---

# 5. 消息系统规范


## 5.1 异步场景使用消息


适用于：

- 异步处理；
- 解耦服务；
- 削峰。


例如：

```
订单创建

↓

订单事件

↓

库存处理
```


---

## 5.2 消息设计


消息应该包含：


- 事件名称；
- 业务标识；
- 发生时间；
- 业务数据。


---

## 5.3 消息可靠性


需要考虑：

- 消息重复；
- 消息丢失；
- 消息顺序。


消费者应该具备：

幂等处理能力。


---

# 6. 日志框架规范


## 6.1 日志要求


日志应该用于：

- 问题定位；
- 业务追踪；
- 系统监控。


---

## 6.2 日志内容


重要日志应该包含：

- 请求标识；
- 业务ID；
- 关键参数。


例如：

```
订单创建失败 orderId=10001
```


---

## 6.3 禁止事项


禁止记录：

- 密码；
- Token；
- 敏感用户信息。


---

# 7. 依赖管理规范


## 7.1 新增依赖要求


引入新依赖需要说明：


- 使用原因；
- 解决问题；
- 维护成本；
- 安全风险。


---

## 7.2 避免重复能力


新增依赖前：

应该检查已有能力。


避免：

多个依赖解决同一问题。


---

## 7.3 Java 后端技术基线版本组合（CHG-0001 晋升）

> 关联 Change：CHG-0001（ENG-BASE-001，M0 工程基线）。
> 以下组合为 AI Mall 后端 Maven 多模块工程的唯一技术基线。任何升级必须走「改统一配置 → 全模块编译 → 测试 → 确认」流程，业务 POM 禁止私自覆盖。

| 组件 | 版本 | 管理位置 | 备注 |
|------|------|----------|------|
| JDK | 21（编译 `release=21`，运行时要求区间 `[21,22)`） | 根 POM `maven.compiler.release` + enforcer `requireJavaVersion` | enforcer 不满足则构建显式失败，不允许静默降级 |
| Maven | `[3.9,)` | 根 POM enforcer `requireMavenVersion` | 不提交 Maven Wrapper，本地/CI 保证 3.9+ |
| Spring Boot | 3.5.15 | `mall-bom` import `spring-boot-dependencies:3.5.15` | |
| Spring Cloud | 2025.0.3 | `mall-bom` import `spring-cloud-dependencies:2025.0.3` | |
| Spring Cloud Alibaba | 2025.0.0.0 | `mall-bom` import `spring-cloud-alibaba-dependencies:2025.0.0.0` | |
| MyBatis-Plus（BOM） | 3.5.12 | `mall-bom` 直接 `dependencyManagement` | |
| MapStruct | 1.6.3 | `mall-bom` 直接 `dependencyManagement`（含 processor） | |
| Springdoc | 2.8.9 | `mall-bom` 直接 `dependencyManagement` | |
| Lombok | 由 Spring Boot BOM 托管 | 不在 mall-bom 重复声明 | 技术决策 6：避免版本锁定冲突 |
| 编码 | UTF-8 | 根 POM `project.build.sourceEncoding` / `project.reporting.outputEncoding` | 全模块统一 |
| 构建统一命令 | 根目录：`mvn clean package -DskipTests`；单模块：`mvn -pl <module> -am package -DskipTests` | 工程契约（CHG-0001 design §2.6） | |

---

## 7.4 Maven 多模块版本治理与依赖边界（CHG-0001 晋升）

> 关联 Change：CHG-0001。以下规则由 enforcer + BOM import + 模块 POM 审计三层保证，违反视为验收失败。

### 7.4.1 四层 POM 聚合体系（从根到叶）

1. **仓库根 pom.xml**（packaging=pom，坐标 `com.ai-mall:backend:1.0.0-SNAPSHOT`）：统一坐标、聚合全部模块、Java 21 编译属性、`pluginManagement`（compiler/enforcer/spring-boot/surefire/resources）、`dependencyManagement` **仅 import** `com.ai-mall:mall-bom:${project.version}`；`maven-enforcer-plugin` 作为公共 plugins 对全模块生效（守门 JDK 21 / Maven 3.9+）。
2. **mall-bom/pom.xml**（packaging=pom，**无 parent**——避免根 POM import 形成 Maven 模型循环）：groupId/version 与根 POM 人工同步；`dependencyManagement` import Spring Boot / Spring Cloud / Spring Cloud Alibaba 三方 BOM，并首批直接管理 MyBatis-Plus BOM / MapStruct / Springdoc。
3. **聚合层**：`mall-common` / `mall-contracts` / `mall-services`（packaging=pom，父=backend 或 mall-services）；仅声明 modules，不新增业务依赖。
4. **叶子模块**：8 个 common 子模块 / 2 个 contracts 子模块 / mall-gateway / 8 个业务服务（jar）；各自按定位声明依赖（**全部不写 `<version>`**）。

### 7.4.2 版本治理唯一权威（违反 = PRD 规则 1 失败）

- mall-bom 已通过 import / direct management 管理的依赖 → 业务/技术/契约模块 POM **不得声明 `<version>`**；`parent` 块内版本除外。
- Spring Boot / Spring Cloud / Spring Cloud Alibaba 三者版本只能在 mall-bom 升级。解析依赖树出现同一组件两个版本即验收失败。
- Lombok 由 Spring Boot BOM 托管，mall-bom 不重复声明。

### 7.4.3 依赖方向单向规则（违反 = 循环/服务间依赖 AC-9 失败）

```
mall-services/*  →  mall-common/*   （按需，单向）
mall-services/*  →  mall-contracts/*（按需，单向）
mall-gateway     →  仅官方 starter（M0）
mall-common / mall-contracts  →  无内部业务依赖，仅官方 starter/第三方库
服务 ↔ 服务：禁止 Maven 依赖；跨服务协作 = API Contract / OpenFeign / 集成事件
```

### 7.4.4 公共模块边界（违反 = AC-7 / AC-8 失败）

- **mall-common**：只存放公共技术能力（core/web/security/redis/mq/openfeign/log/test）。出现 Product/Order/Inventory/Member 等业务领域模型即违规。
- **mall-contracts**：`mall-api-contracts`（内部 API DTO）与 `mall-event-contracts`（集成事件 DTO + 元数据）两个子模块；零第三方依赖。出现 Repository、领域聚合、MyBatis PO、业务 Service 即违规。

### 7.4.5 服务独立打包（违反 = AC-10 失败）

- mall-gateway 与 8 个服务各自 POM 绑定 `spring-boot-maven-plugin` 的 `repackage` goal（配置由根 POM `pluginManagement` 继承）。
- `mvn package` 产出各自的独立可执行 Fat Jar；全量构建**不得**产出包含全部业务的单体 Jar。

---

# 8. 工程配置规范


项目配置应该：

- 分环境管理；
- 结构清晰；
- 可追踪。


推荐：

```
config/

├── dev

├── test

└── prod
```


---

# 9. AI Coding Agent 框架使用规则


AI 修改框架相关代码前必须读取：


```
delivery/

design.md

+

framework-standard.md

+

implementation/
```


确认：

- 当前技术方案；
- 框架使用方式；
- 配置影响；
- 部署影响。


---

AI 不应该：


## 9.1 随意升级框架版本


框架升级必须经过：

```
Change

↓

Compatibility Analysis

↓

Test
```


---

## 9.2 随意增加基础设施


例如：

没有需求时：

- 新增中间件；
- 引入新的框架组件。


---

## 9.3 修改核心配置不说明影响


配置变化必须记录：

- 修改原因；
- 影响范围；
- 验证结果。


---

# 10. 框架变更流程


框架相关修改属于 Change。


流程：


```
Requirement

↓

Change

↓

Technical Design

↓

Implementation

↓

Validation

↓

Evidence
```


---

# 11. 框架检查清单


提交前检查：


```
[ ] 框架使用符合规范

[ ] 配置管理正确

[ ] 无敏感信息泄露

[ ] 新依赖已评估

[ ] 基础设施影响已分析

[ ] 测试已验证
```


---

# 12. 总结


后端框架使用规范用于保证：


```
业务系统

+

技术框架

+

基础设施

+

AI开发行为
```


保持统一。


良好的框架使用应该：

- 简洁；
- 稳定；
- 可维护；
- 易演进。


# 13. 统一响应与错误码分段约定（CHG-0003 晋升）


## 13.1 统一响应结构

所有 WebMVC 业务服务的 HTTP 响应体必须使用 `UnifyResult<T>` 结构：

- 字段冻结为五项：`success`（boolean）、`code`（string）、`message`（string）、`data`（T）、`traceId`（string）
- 静态工厂统一出口：`UnifyResult.ok(data)` / `UnifyResult.fail(errorCode, message)`
- 禁止业务代码手工 new UnifyResult

来源：CHG-0003 design.md §2.3 接口契约


## 13.2 错误码分段

错误码分段约定（`ErrorCode` 接口 + `CommonErrorCode` 常量）：

| 段 | 前缀 | 含义 | 示例 |
|----|------|------|------|
| 0  | 0    | 成功 | 0 |
| A  | A    | 参数类 | A0001（参数校验失败） |
| B  | B    | 业务类 | B0001~（业务异常携带） |
| S  | S    | 系统类 | S0001（系统繁忙，请稍后重试） |

来源：CHG-0003 design.md §2.3 错误码分段


## 13.3 TraceId 约定

- Header 名：`X-Trace-Id`
- MDC key：`traceId`
- 格式：32 位十六进制小写（UUID 去横线）
- 生成：请求无合法 TraceId 时由 TraceContext.generate() 生成
- 透传：有合法 TraceId 时透传不重生成
- 清理：请求结束后 finally 块清理 ThreadLocal + MDC（防线程池污染）

来源：CHG-0003 design.md §2.3 TraceId 基础


## 13.4 全局异常处理

`@RestControllerAdvice` 统一异常处理，响应体一律 UnifyResult：

- 参数校验异常 → HTTP 400 + A 段码
- BusinessException → 业务码 + 对应 HTTP 语义（400/404/409 等）
- 未预期异常 → HTTP 500 + S 段通用文案（禁止泄露 StackTrace/SQL/凭据）

来源：CHG-0003 design.md §2.3 GlobalExceptionHandler
