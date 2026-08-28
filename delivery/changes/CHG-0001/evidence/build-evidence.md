# Build Evidence — CHG-0001（ENG-BASE-001）

> 记录时间：2026-08-28
> 仓库：repo-1 = `implementation/ai-platform-backend`（独立 Git 仓库，Maven 根 = 仓库根）
> 性质：全部为实测输出记录，非占位

## 1. 验收记录（需求 §21 模板）

```text
Requirement:
ENG-BASE-001（M0，P0：建立 Java Maven 多模块工程并统一版本基线）

Java:
21（实测 java version "21.0.12" 2026-07-21 LTS，Oracle，D:\develop\Java\jdk-21）

Maven:
3.9+（实测 Apache Maven 3.9.16，D:\develop\apache-maven-3.9.16）

Build Command:
mvn clean package -DskipTests

Result:
PASS（24/24 模块 BUILD SUCCESS，Total time: 35.440 s）
```

## 2. Maven 模块结构（Reactor 实测清单，24 个项目）

```text
mall-bom            SUCCESS    backend             SUCCESS
mall-common         SUCCESS    mall-common-core    SUCCESS
mall-common-web     SUCCESS    mall-common-security SUCCESS
mall-common-redis   SUCCESS    mall-common-mq      SUCCESS
mall-common-openfeign SUCCESS  mall-common-log     SUCCESS
mall-common-test    SUCCESS    mall-contracts      SUCCESS
mall-api-contracts  SUCCESS    mall-event-contracts SUCCESS
mall-gateway        SUCCESS    mall-services       SUCCESS
mall-identity       SUCCESS    mall-member         SUCCESS
mall-product        SUCCESS    mall-cart           SUCCESS
mall-order          SUCCESS    mall-inventory      SUCCESS
mall-search         SUCCESS    mall-system         SUCCESS
```

原始留档：[logs/full-build.log](logs/full-build.log)（Reactor Summary 位于第 665~695 行）

## 3. Maven / Java 版本信息

```text
Apache Maven 3.9.16 (2bdd9fddda4b155ebf8000e807eb73fd829a51d5)
Maven home: D:\develop\apache-maven-3.9.16
Java version: 21.0.12, vendor: Oracle Corporation, runtime: D:\develop\Java\jdk-21
Default locale: zh_CN, platform encoding: UTF-8
OS name: "windows 11", version: "10.0", arch: "amd64"
```

留档：[logs/maven-java-version.txt](logs/maven-java-version.txt)

## 4. AC 覆盖核验（AC-1 ~ AC-11）

| AC | 要求 | 实测结果 | 证据 |
| --- | --- | --- | --- |
| AC-1 | 仓库根可全量构建 | `mvn clean package -DskipTests` → BUILD SUCCESS，24 项目 | logs/full-build.log |
| AC-2 | 模块层级符合需求 §3 | Reactor 清单 24 项与 design §2.1 一致，无缺失/无冲突 | logs/full-build.log |
| AC-3 | 编译基线 Java 21、非 21 显式失败 | ① effective POM 中 `maven.compiler.release=21` 命中 23/24（mall-bom 无 parent 且纯 pom 无源码，属设计内例外）；② enforcer `requireJavaVersion [21,22)` + `requireMavenVersion [3.9,)` 全模块生效；③ 收紧区间为 `[21.1,)` 模拟非 21 环境 → 构建显式失败（见下），恢复 `[21,22)` 后 `mvn validate` 重新通过 | 本文件 §5；logs/enforcer-*.txt |
| AC-4 | Spring Boot 版本唯一（3.5.15） | 9 应用依赖树中 spring-boot* 全部 `3.5.15`，无第二版本 | logs/apps-dependency-tree.txt |
| AC-5 | Spring Cloud 版本唯一（2025.0.3） | starter/commons/context `4.3.3`、gateway-server `4.3.5`，均为 2025.0.3 BOM 指定版本 | logs/apps-dependency-tree.txt |
| AC-6 | SCA 版本唯一（2025.0.0.0） | mall-common-mq 未写版本，解析出 `spring-cloud-starter-stream-rocketmq:2025.0.0.0`（SCA BOM 受管），传递 `rocketmq-client:5.3.1` | logs/mq-dependency-tree.txt |
| AC-7 | mall-common 无业务领域代码 | 8 个子模块源码树仅 `package-info.java` 占位 | 工程结构审查 |
| AC-8 | mall-contracts 纯契约定位 | 2 个子模块零第三方依赖，源码树仅 `package-info.java` | POM 审查 |
| AC-9 | 服务间无 Maven 依赖、无循环 | ① mall-services 8 个 POM 无任何对兄弟服务的引用（grep 零命中）；② Reactor 顺序构建成功即无循环 | 本文件；logs/full-build.log |
| AC-10 | 9 应用独立打包可启动 | 9 个 Fat Jar（gateway 36MB、services 各 21MB）逐一 `java -jar` 全部 `Started XxxApplication`（2~3s），无异常退出；全量构建未产出单体 Jar | logs/startup/*.out.log |
| AC-11 | Evidence 留档 | 本文件 + logs/ 目录 | — |

## 5. enforcer 反例实测（AC-3 显式失败证据）

临时将根 POM `requireJavaVersion` 收紧为 `[21.1,)`（模拟非 21 环境，本机仅装 JDK 21.0.12）：

```text
[INFO] Rule 0: org.apache.maven.enforcer.rules.version.RequireMavenVersion passed
[INFO] BUILD FAILURE
[ERROR] Rule 1: org.apache.maven.enforcer.rules.version.RequireJavaVersion failed with message:
[ERROR] 本工程要求 JDK 21，检测到的 Java 版本不满足，请使用 JDK 21。
```

恢复 `[21,22)` 后 `mvn validate` exit 0（Rule 0/1 passed）。

## 6. 版本治理核验（PRD 规则 1/12）

- **规则 1（BOM 管版本的依赖禁止写 version）**：全仓 POM 扫描，mall-common/mall-contracts/mall-gateway/mall-services 全部 22 个 POM 中 `<version>` 仅出现在 `<parent>` 块（第 10 行，parent 坐标），依赖区零版本声明；
- **规则 12（无敏感信息）**：pom.xml/yml/properties 全量扫描 `password|secret|accesskey|access-key|api-key|token`，唯一命中为 mall-identity POM 描述文字「注册、登录、Token（业务代码留待后续里程碑）」，非凭据；
- 编码：全部 POM/application.yml 声明或继承 `UTF-8`（根 POM properties 统一）。

## 7. 独立启动验证汇总（AC-10）

```text
App            Started ExitedEarly Seconds
mall-gateway      True       False       3
mall-identity     True       False       2
mall-member       True       False       2
mall-product      True       False       2
mall-cart         True       False       2
mall-order        True       False       2
mall-inventory    True       False       2
mall-search       True       False       2
mall-system       True       False       2
```

启动日志（9 份 Spring Boot 启动横幅 + Started 行）：`logs/startup/mall-*.out.log`

## 8. Notes

1. **构建修复记录**：mall-common-mq 原声明 `com.alibaba.cloud:rocketmq-spring-boot-starter`（坐标不存在且 SCA 2025.0.0.0 BOM 不管理该 starter），修正为 design §2.4 首选的 `spring-cloud-starter-stream-rocketmq`（commit 1c054b1）；
2. **mall-bom 无 parent**：为避免与根 POM import 形成模型循环的有意设计，故不继承 `maven.compiler.release`（纯 pom、无源码，不影响 AC-3 实质）；
3. **沙箱说明**：Trae 沙箱禁写 Maven 默认本地仓库 `D:\maven-repository`，构建验证统一使用仓库内临时本地仓库 `.m2-repo/`（已 gitignore），不影响构建结果与版本解析逻辑；本机直接执行同命令使用默认缓存效果一致；
4. 提交链：根 POM(14c6db0) → mall-bom(9babc0f) → mall-common(d0421c2) → mall-contracts(94629ad) → gateway(84cd1f5) → services POM(f49c30f) → 启动类+配置(dfed84f) → mq 修复(1c054b1) → README。
