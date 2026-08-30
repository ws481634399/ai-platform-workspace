---
id: "ENG-BASE-001"
name: "建立 Java Maven 多模块工程并统一 Java、Spring Boot、Spring Cloud Alibaba 版本"
content: "建立 AI Mall 后端统一的 Maven 多模块工程基线：统一 Java 21、mall-bom 统一管理 Spring Boot/Spring Cloud/Spring Cloud Alibaba 版本、清晰模块边界与统一构建入口（M0，P0）"
source: user
created-at: "2026-08-28T13:04:40Z"
---

## 需求描述

> 以下为用户提供的原始需求全文（保持原话，未做改写），原始文档已归档至 `references/ENG-BASE-001.md`。

### ENG-BASE-001 建立 Java Maven 多模块工程并统一 Java、Spring Boot、Spring Cloud Alibaba 版本

**需求类型：** 工程基础需求\
**开发阶段：** M0\
**优先级：** P0\
**来源：** `14-开发计划.md`、`08-系统与微服务架构.md`、`13-部署方案.md`\
**影响范围：** `backend/` 下全部 Java 模块

***

## 1. 需求目标

建立 AI Mall 后端统一的 Maven 多模块工程基线，使 Gateway、公共模块、契约模块以及全部业务微服务能够在同一个 Maven Reactor 中进行统一依赖管理、统一插件管理、统一编译和统一构建。

本需求需要解决的核心问题包括：

1. 所有 Java 模块具有统一的 Maven 构建入口；
2. 所有 Java 模块统一使用 Java 21；
3. Spring Boot 版本只能由公共版本管理层统一决定；
4. Spring Cloud 版本只能由公共版本管理层统一决定；
5. Spring Cloud Alibaba 版本只能由公共版本管理层统一决定；
6. 公共第三方依赖原则上统一管理版本；
7. 各业务微服务不得自行维护另一套基础框架版本；
8. 根目录能够一次完成全部 Java 模块的依赖解析和构建；
9. 为后续 Gateway、Nacos、OpenFeign、Redis、Security、MyBatis-Plus、RocketMQ 等能力建立稳定依赖基线。

***

## 2. 技术基线要求

项目后端统一采用：

- Java 21；
- Maven 3.9+；
- Spring Boot 3；
- Spring Cloud；
- Spring Cloud Alibaba；
- MyBatis-Plus。

Spring Boot、Spring Cloud 和 Spring Cloud Alibaba 必须选择彼此兼容的一组版本。

确定版本后，不允许业务模块自行覆盖基础框架版本。

例如不允许：

```
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-web</artifactId>
    <version>某个业务模块自己的版本</version>
</dependency>

```

正确方式应由统一的 Dependency Management / BOM 提供版本。

***

## 3. Maven 工程层级要求

后端工程至少按照以下结构建立：

```
backend/
├── pom.xml
│
├── mall-bom/
│   └── pom.xml
│
├── mall-common/
│   ├── pom.xml
│   ├── mall-common-core/
│   ├── mall-common-web/
│   ├── mall-common-security/
│   ├── mall-common-redis/
│   ├── mall-common-mq/
│   ├── mall-common-openfeign/
│   ├── mall-common-log/
│   └── mall-common-test/
│
├── mall-contracts/
│   ├── pom.xml
│   ├── mall-api-contracts/
│   └── mall-event-contracts/
│
├── mall-gateway/
│   └── pom.xml
│
└── mall-services/
    ├── pom.xml
    ├── mall-identity/
    ├── mall-member/
    ├── mall-product/
    ├── mall-cart/
    ├── mall-order/
    ├── mall-inventory/
    ├── mall-search/
    └── mall-system/

```

其中：

### `backend/pom.xml`

作为整个 Java 后端的 Maven 聚合入口。

职责包括：

- 聚合后端所有 Maven 模块；
- 定义项目统一坐标；
- 定义统一项目版本；
- 定义 Java 编译版本；
- 引入公共 BOM；
- 管理公共 Maven Plugin；
- 提供整个后端统一构建入口。

***

### `mall-bom`

作为项目依赖版本管理模块。

主要职责：

```
统一框架版本
+
统一第三方依赖版本
+
降低各模块 POM 中的版本声明数量

```

需要集中管理的依赖至少包括基础框架层：

- Spring Boot；
- Spring Cloud；
- Spring Cloud Alibaba；
- MyBatis-Plus；

后续项目确定其他公共基础组件版本后，也应优先纳入统一版本管理。

业务微服务原则上只声明：

```
我要使用哪个 dependency

```

而不重复声明：

```
我要使用这个 dependency 的哪个版本

```

***

## 4. 根 Maven 坐标要求

所有 Java 模块必须属于统一项目坐标体系。

例如：

```
groupId:
统一使用项目级 groupId

artifactId:
按照模块名称定义

version:
统一使用项目版本

```

子模块不得自行采用完全独立的版本体系。

项目版本升级时，应能够通过统一位置完成版本调整，而不是逐个修改十几个 POM。

***

## 5. Java 版本统一要求

所有 Java 模块必须：

```
source = 21
target = 21
release = 21

```

或采用等效的统一 Maven Compiler 配置。

禁止出现：

```
mall-order       Java 21
mall-product     Java 17
mall-identity    Java 21
mall-gateway     Java 17

```

所有模块必须使用相同 Java 基线。

编译环境使用非 Java 21 时，应明确构建失败，而不是静默使用不同 Java 版本产生不同构建结果。

***

## 6. Spring Boot 版本管理要求

Spring Boot 只能存在一个统一项目基线。

必须满足：

- 所有 Spring Boot 服务使用同一基础版本；
- Spring Boot Starter 不在各服务内重复指定版本；
- Spring Boot Maven Plugin 使用统一版本；
- Spring Boot 升级应通过公共版本管理完成；
- 不允许某个微服务自行升级 Spring Boot。

例如：

```
mall-identity
mall-member
mall-product
mall-cart
mall-order
mall-inventory
mall-search
mall-system

```

必须共享同一 Spring Boot 基线。

***

## 7. Spring Cloud 版本管理要求

Spring Cloud 需要通过统一 BOM 管理。

所有涉及 Spring Cloud 的模块，包括：

```
mall-gateway
mall-identity
mall-member
mall-product
mall-cart
mall-order
mall-inventory
mall-search
mall-system

```

不得各自声明 Spring Cloud 组件版本。

后续使用：

- Spring Cloud Gateway；
- OpenFeign；
- LoadBalancer；
- 其他 Spring Cloud 组件；

均应服从同一个 Spring Cloud Release Train。

***

## 8. Spring Cloud Alibaba 版本管理要求

Spring Cloud Alibaba 必须建立统一版本。

主要用于后续：

- Nacos Discovery；
- Nacos Configuration（如启用）；
- 其他 Spring Cloud Alibaba 能力。

所有服务不得自行指定不同版本的：

```
spring-cloud-starter-alibaba-*

```

Spring Cloud Alibaba 版本必须与当前：

```
Spring Boot
+
Spring Cloud

```

版本组合兼容。

确定版本组合后应形成项目技术基线，不在业务开发过程中随意升级。

***

## 9. 依赖管理要求

### 9.1 基础原则

版本应该尽量集中维护。

业务模块 POM 应主要表达：

```
这个服务需要什么能力

```

而不是：

```
整个项目的版本治理规则

```

例如 `mall-order` 可以声明：

```
Spring Web
MyBatis-Plus
OpenFeign
Redis
RocketMQ

```

但是对应公共基础库的版本不应全部写在 `mall-order/pom.xml` 中。

***

### 9.2 禁止版本漂移

必须防止以下情况：

```
mall-product 使用依赖 A 1.x
mall-order 使用依赖 A 2.x
mall-inventory 使用依赖 A 3.x

```

如果是项目公共基础依赖，应由 BOM 统一。

确实存在必须使用不同版本的特殊情况时，应作为显式工程例外记录，而不是直接在业务 POM 中偷偷覆盖。

***

### 9.3 禁止无理由重复声明

如果版本已经由 BOM 管理：

业务模块不得继续重复填写 `<version>`。

目的：

- 减少版本漂移；
- 降低升级成本；
- 简化 POM；
- 提高依赖可读性。

***

## 10. Maven Plugin 管理要求

公共 Maven Plugin 应在父工程统一管理。

至少考虑：

### Maven Compiler Plugin

负责：

```
统一 Java 21 编译

```

### Spring Boot Maven Plugin

负责：

```
Spring Boot 应用构建

```

### 测试相关 Plugin

为后续 M0 基础测试和 M8 自动化测试预留统一配置入口。

各业务模块原则上不得复制一整套 Plugin 配置。

***

## 11. 模块职责边界要求

建立 Maven 工程时，不能因为“方便复用”破坏项目架构边界。

### `mall-common`

只能存放：

```
公共技术能力

```

例如：

- 通用工具；
- Web 基础能力；
- Security 基础能力；
- Redis 基础能力；
- MQ 基础能力；
- OpenFeign 基础能力；
- 日志能力；
- 测试能力。

禁止放入：

```
Product
Order
Inventory
Member
Role
Refund

```

等具体业务领域模型。

***

### `mall-contracts`

只能用于跨服务契约。

包括：

```
内部 API DTO
集成事件 DTO
事件公共元数据

```

禁止放入：

```
领域聚合
Repository
MyBatis PO
业务 Service

```

***

### `mall-services`

用于承载实际业务微服务。

包括：

```
mall-identity
mall-member
mall-product
mall-cart
mall-order
mall-inventory
mall-search
mall-system

```

业务模型必须留在所属服务内部，不允许为了 Maven 复用方便将领域模型抽到 `mall-common`。

***

## 12. 模块依赖方向要求

Maven 模块依赖必须避免循环依赖。

推荐的基础关系：

```
业务服务
    ↓
mall-common 技术模块

业务服务
    ↓
mall-contracts 契约模块

```

禁止形成类似：

```
mall-common
    ↓
mall-order
    ↓
mall-common

```

或者：

```
mall-product
    ↔
mall-order

```

这样的 Maven 双向依赖。

跨微服务协作以后通过：

```
API Contract
OpenFeign
Integration Event

```

完成，而不是通过 Maven 直接依赖另一个服务的业务实现模块。

***

## 13. 微服务模块独立性要求

虽然所有模块处于 Maven 多模块工程中，但每个业务微服务仍然必须保持独立应用边界。

例如：

```
mall-identity
mall-member
mall-product
mall-cart
mall-order
mall-inventory
mall-search
mall-system

```

后续都应能够：

- 独立编译；
- 独立运行；
- 独立测试；
- 独立打包；
- 独立生成 Spring Boot Jar；
- 独立生成 Docker Image。

Maven 多模块只用于工程治理，不能把所有微服务重新变成一个单体应用。

***

## 14. 构建要求

### 14.1 根构建

在：

```
backend/

```

目录执行统一 Maven 构建时，必须能够解析所有模块。

项目设计中的基本构建命令为：

```
mvn clean package -DskipTests

```

必须能够完成全部 Java 模块构建。

***

### 14.2 Reactor 构建

Maven Reactor 中应正确包含所有计划中的后端模块。

不存在：

- 模块目录存在但未加入父 POM；
- 父 POM 声明了不存在模块；
- 模块父 POM 指向错误；
- 模块 artifactId 冲突；
- 依赖模块无法解析。

***

### 14.3 单模块构建

后续业务开发时，应支持针对单个模块及其依赖进行构建。

例如开发：

```
mall-order

```

不应该要求手动逐个进入所有公共模块执行 install 才能继续开发。

***

## 15. 版本升级要求

以后升级：

```
Java
Spring Boot
Spring Cloud
Spring Cloud Alibaba
MyBatis-Plus

```

时，应遵循：

```
修改统一版本配置
→ Maven 解析
→ 全模块编译
→ 自动化测试
→ 再确认升级完成

```

不得采用：

```
先升级 mall-order
→ 再升级 mall-product
→ 某些服务忘记升级

```

的方式维护基础版本。

***

## 16. 工程配置要求

需要保证：

- 模块命名统一；
- Maven artifactId 与项目模块名称保持一致；
- 编码统一为 UTF-8；
- Java 编译版本统一；
- 项目版本统一；
- 依赖管理集中；
- Plugin 配置集中；
- 子模块 POM 尽量只保留自身依赖；
- 不在 POM 中保存密码、Token、数据库密码等敏感配置。

***

## 17. 本需求不包含的内容

`ENG-BASE-001` 只负责建立 Java Maven 工程和版本治理基线。

以下内容由其他 M0 Requirement 负责，不应全部塞进本 Change：

```
统一响应结构
统一异常处理
TraceId
日志体系
OpenAPI
Flyway
Nacos 实际服务注册
MySQL 连接
Redis 连接
Docker Compose
AI Service
Vue 工程

```

本需求可以为这些能力预留 Maven 模块和依赖管理入口，但不要求在 `ENG-BASE-001` 中全部实现。

***

## 18. 关键约束

### MUST

必须：

- 使用 Java 21；
- 使用 Maven 多模块；
- 使用 Spring Boot 3 技术基线；
- 统一管理 Spring Boot 版本；
- 统一管理 Spring Cloud 版本；
- 统一管理 Spring Cloud Alibaba 版本；
- 建立根 Maven 构建入口；
- 建立 `mall-bom`；
- 建立公共模块、契约模块、Gateway 和业务服务模块结构；
- 所有模块能够参与统一 Maven 构建；
- 禁止业务模块自行维护另一套基础框架版本；
- 禁止将具体业务领域模型放入 `mall-common`；
- 禁止将领域模型放入 `mall-contracts`。

### SHOULD

建议：

- 第三方公共依赖尽量由 BOM 统一版本；
- Maven Plugin 由父工程统一管理；
- 子模块 POM 保持精简；
- Maven 模块与系统架构中的服务名称保持一致；
- 版本升级通过一个中心位置完成。

### MAY

可以：

- 根据后续实际需求增加新的 `mall-common-*` 技术模块；
- 对少量特殊依赖设置明确版本例外；
- 随项目演进增加新的 Plugin 管理配置。

但新增微服务本身不属于本需求范围，不能因为 Maven 工程搭建方便而自行扩展服务边界。

***

## 19. 验收场景

### AC-01 根工程能够识别所有模块

**Given**

后端 Maven 工程已建立。

**When**

从 `backend/` 执行 Maven 构建。

**Then**

Maven 能正确识别项目全部 Java 模块，不出现模块缺失或路径错误。

***

### AC-02 全模块能够一次构建

**When**

执行：

```
mvn clean package -DskipTests

```

**Then**

所有当前 Java 模块均构建成功。

***

### AC-03 Java 版本统一

检查全部模块。

**Then**

所有模块统一编译到 Java 21，不存在单独使用 Java 17、Java 8 等其他版本的业务模块。

***

### AC-04 Spring Boot 版本唯一

检查 Effective POM / Dependency Tree。

**Then**

所有服务使用统一 Spring Boot 基线，不存在业务服务自行覆盖另一套 Spring Boot 版本。

***

### AC-05 Spring Cloud 版本统一

检查所有 Spring Cloud 依赖。

**Then**

均来自统一的 Dependency Management，不在多个微服务中分别维护版本。

***

### AC-06 Spring Cloud Alibaba 版本统一

检查所有 Alibaba Starter。

**Then**

由统一版本管理提供版本，不存在不同服务分别指定不同版本。

***

### AC-07 公共模块边界正确

检查：

```
mall-common

```

**Then**

不存在 Product、Order、Inventory、Member 等具体业务领域代码。

***

### AC-08 契约模块边界正确

检查：

```
mall-contracts

```

**Then**

只包含 API / Event 等跨边界契约，不包含 Repository、领域聚合或业务实现。

***

### AC-09 不存在 Maven 循环依赖

所有 Maven 模块依赖关系能够正常解析，不存在业务服务之间的双向 Maven 依赖。

***

### AC-10 微服务可以独立打包

Gateway 和各业务服务最终均能形成独立构建产物，而不是只能生成一个包含所有业务的单体 Jar。

***

## 20. 最终交付物

完成该 Requirement 后至少应产生：

```
backend/
├── pom.xml
├── mall-bom/pom.xml
├── mall-common/
├── mall-contracts/
├── mall-gateway/
└── mall-services/

```

以及：

- 可用的统一父 POM；
- 可用的统一依赖版本管理；
- Java 21 编译配置；
- Spring Boot / Spring Cloud / Spring Cloud Alibaba 统一版本配置；
- 当前全部 Java 模块 POM；
- 成功的 Maven 全量构建结果；
- 对应测试或构建 Evidence。

***

## 21. Evidence 要求

本需求完成后建议保存至少以下证据：

```
ENG-BASE-001
├── Maven 模块结构
├── Maven 版本信息
├── Java 版本信息
├── 全量构建命令
└── 全量构建结果

```

测试/验收记录至少说明：

```
Requirement:
ENG-BASE-001

Java:
21

Maven:
3.9+

Build Command:
mvn clean package -DskipTests

Result:
PASS / FAIL

Modules:
列出实际参与构建的模块

Notes:
异常或遗留问题

```

不得只写：

```
构建应该可以通过

```

必须记录实际执行结果。

***

## 22. Definition of Done

只有同时满足以下条件，`ENG-BASE-001` 才允许标记完成：

- `backend/pom.xml` 已建立；
- Maven 多模块层级已建立；
- `mall-bom` 已建立；
- `mall-common` 模块结构已建立；
- `mall-contracts` 模块结构已建立；
- `mall-gateway` 已加入 Reactor；
- 8 个业务微服务模块均已加入 Reactor；
- Java 版本统一为 21；
- Spring Boot 版本统一管理；
- Spring Cloud 版本统一管理；
- Spring Cloud Alibaba 版本统一管理；
- 公共依赖没有明显版本漂移；
- Maven Plugin 有统一管理入口；
- 不存在 Maven 循环依赖；
- `mall-common` 未包含业务领域模型；
- `mall-contracts` 未包含领域实现；
- 根目录全量 Maven 构建成功；
- 构建结果形成 Evidence；
- 未提前实现与本 Requirement 无关的大量业务功能。

***

## 23. 重点说明

这个 Requirement 的核心并不是：

```
创建十几个空 Maven 文件夹

```

而是建立：

```
统一工程结构
+
统一 Java 基线
+
统一框架版本
+
统一依赖治理
+
统一构建入口
+
清晰模块边界

```

如果只是把 `mall-order`、`mall-product`、`mall-inventory` 等目录创建出来，但每个服务仍然自行声明 Spring Boot、Spring Cloud、Spring Cloud Alibaba 版本，那么 `ENG-BASE-001` 实际上没有完成。

最终需要达到的效果是：

> 后续任何一个微服务开始开发时，开发者只需要关心“这个服务需要哪些能力”，而不需要重新决定“整个项目应该使用什么 Java、Spring Boot、Spring Cloud 和 Spring Cloud Alibaba 版本”。

