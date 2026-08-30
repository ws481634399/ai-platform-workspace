# Test Report — CHG-0001

> Change ID: CHG-0001
> Implementation 来源: CHG-0001/implementation.md
> 状态流转: developing → testing
> 测试完成时间: 2026-08-29T00:12:00+08:00
> 测试执行者: sdd-test（人工自检 + 实测输出，openspec CLI 环境损坏无法机检）

## 1. 测试范围与环境

### 1.1 测试对象

本 Change（ENG-BASE-001）为工程基线变更，不产生业务逻辑。测试围绕"工程结构可构建、版本治理唯一、模块边界清晰、应用独立可启动、Evidence 留档完整"五个维度展开。

**受测模块清单（24 个 Maven 项目）：**

| 层级 | 模块 | artifactId | 说明 |
|------|------|-----------|------|
| 根 | backend（repo-1 根） | — | 聚合 POM + enforcer + pluginManagement |
| BOM | mall-bom | mall-bom | 唯一版本权威（import Boot/Cloud/SCA 三方 BOM + 首批直接版本） |
| 聚合 | mall-common | mall-common | 技术能力聚合 |
| 技术子模块 | mall-common-core | mall-common-core | 公共核心工具（空骨架） |
| 技术子模块 | mall-common-web | mall-common-web | Web 增强（空骨架） |
| 技术子模块 | mall-common-security | mall-common-security | 安全基础（空骨架） |
| 技术子模块 | mall-common-redis | mall-common-redis | Redis 封装（空骨架） |
| 技术子模块 | mall-common-mq | mall-common-mq | RocketMQ Stream starter（SCA BOM 受管） |
| 技术子模块 | mall-common-openfeign | mall-common-openfeign | OpenFeign 封装（空骨架） |
| 技术子模块 | mall-common-log | mall-common-log | 日志基础（空骨架） |
| 技术子模块 | mall-common-test | mall-common-test | 测试基础（空骨架） |
| 聚合 | mall-contracts | mall-contracts | 内部契约聚合 |
| 契约子模块 | mall-api-contracts | mall-api-contracts | 零第三方依赖，API DTO 定位 |
| 契约子模块 | mall-event-contracts | mall-event-contracts | 零第三方依赖，事件 DTO 定位 |
| 应用 | mall-gateway | mall-gateway | Spring Cloud Gateway 独立应用（port=8080） |
| 聚合 | mall-services | mall-services | 业务服务聚合 |
| 应用服务 | mall-identity | mall-identity | 认证鉴权服务（port=8101） |
| 应用服务 | mall-member | mall-member | 会员服务（port=8102） |
| 应用服务 | mall-product | mall-product | 商品服务（port=8103） |
| 应用服务 | mall-cart | mall-cart | 购物车服务（port=8104） |
| 应用服务 | mall-order | mall-order | 订单服务（port=8105） |
| 应用服务 | mall-inventory | mall-inventory | 库存服务（port=8106） |
| 应用服务 | mall-search | mall-search | 搜索服务（port=8107） |
| 应用服务 | mall-system | mall-system | 系统管理服务（port=8108） |

### 1.2 测试类型

| 类别 | 内容 | 等价类型 |
|------|------|--------|
| 构建验证 | 根目录 `mvn clean package -DskipTests` 全量 Reactor | 集成构建测试 |
| 治理审计 | Effective POM / enforcer 反例 / dependency:tree / 源码 POM 审计 | 环境审计（静态 + 动态混合） |
| 启动验证 | 9 个 Fat Jar 逐个 `java -jar` 检测 Started 行 | E2E 等价启动冒烟 |
| 留档核验 | Evidence 文件齐全性 + 内容真实性核对 | 文档留档审计 |

### 1.3 测试环境

| 项 | 值 |
|----|----|
| OS | Windows 11 (amd64)，zh_CN / UTF-8 |
| Java | 21.0.12 LTS (Oracle，`D:\develop\Java\jdk-21`) |
| Maven | 3.9.16 (`D:\develop\apache-maven-3.9.16`) |
| Spring Boot | 3.5.15（mall-bom import） |
| Spring Cloud | 2025.0.3（mall-bom import） |
| Spring Cloud Alibaba | 2025.0.0.0（mall-bom import） |
| MyBatis-Plus BOM | 3.5.12（mall-bom 直接管理） |
| MapStruct | 1.6.3（mall-bom 直接管理） |
| Springdoc | 2.8.9（mall-bom 直接管理） |
| 沙箱说明 | Trae 沙箱禁写 `D:\maven-repository`，实测使用仓库内临时本地仓 `.m2-repo/`（`-Dmaven.repo.local=…\.m2-repo`）；与默认缓存等价，不影响构建结果与版本解析 |

## 2. 执行汇总

### 2.1 构建验证（EV-100，覆盖 AC-1 / AC-2 / AC-9）

命令：`mvn clean package -DskipTests -B -Dmaven.repo.local=<repo>\.m2-repo`
耗时：35.440s

| 子项 | 总数 | 通过 | 失败 | 跳过 | 通过率 |
|------|------|------|------|------|--------|
| Reactor 24 项目构建 | 24 | 24 | 0 | 0 | 100% |
| 合计 | 24 | 24 | 0 | 0 | 100% |

结果：**PASS**。原始留档：[logs/full-build.log](logs/full-build.log)。

### 2.2 治理与边界审计（EV-101，覆盖 AC-3 / AC-4 / AC-5 / AC-6 / AC-7 / AC-8）

审计由四类子动作完成（见 build-evidence.md §3~§6）：

| 子项 | 检查点 | 通过数 | 失败数 | 跳过数 | 结果 |
|------|--------|--------|--------|--------|------|
| Java 编译基线 | compiler.release=21 一致性（mall-bom 纯 POM 属设计例外）+ enforcer 反例 + 恢复 | 3 | 0 | 0 | ✅ |
| Spring Boot 版本唯一 | 9 应用依赖树 spring-boot* 全 3.5.15 | 1 | 0 | 0 | ✅ |
| Spring Cloud 版本唯一 | starter/commons/context/gateway-server 均为 2025.0.3 指定版本 | 1 | 0 | 0 | ✅ |
| SCA 版本唯一 | mq starter 解析 2025.0.0.0（SCA BOM 受管），传递 rocketmq-client 5.3.1 | 1 | 0 | 0 | ✅ |
| mall-common 无业务领域代码 | 8 子模块源码仅 package-info.java | 1 | 0 | 0 | ✅ |
| mall-contracts 纯契约 | 2 子模块零第三方依赖、仅 package-info.java | 1 | 0 | 0 | ✅ |
| 版本规则（BOM 管的依赖禁写 version；敏感信息零命中） | POM 全扫描 + yml 全扫描 | 1 | 0 | 0 | ✅ |
| 合计（子项展开计数，与 EV-101 summary 对齐） | | 9 | 0 | 0 | **PASS** |

留档：[build-evidence.md](build-evidence.md) §4~§6；[logs/apps-dependency-tree.txt](logs/apps-dependency-tree.txt)；[logs/mq-dependency-tree.txt](logs/mq-dependency-tree.txt)；enforcer 反例与恢复日志在 build-evidence.md §5 原文引用。

### 2.3 独立启动验证（EV-102，覆盖 AC-10 / AC-11）

| 子项 | 总数 | 通过 | 失败 | 跳过 | 通过率 |
|------|------|------|------|------|--------|
| 9 Fat Jar Started 检测（gateway≈36MB，各 service≈21MB，非单体） | 9 | 9 | 0 | 0 | 100% |
| 合计 | 9 | 9 | 0 | 0 | 100% |

启动日志：[logs/startup/mall-gateway.out.log](logs/startup/mall-gateway.out.log) … [logs/startup/mall-system.out.log](logs/startup/mall-system.out.log)。

### 2.4 汇总合计

| 类型 | 总数 | 通过 | 失败 | 跳过 | 通过率 |
|------|------|------|------|------|--------|
| 构建验证（EV-100） | 24 | 24 | 0 | 0 | 100% |
| 治理审计（EV-101） | 9 | 9 | 0 | 0 | 100% |
| 启动验证（EV-102） | 9 | 9 | 0 | 0 | 100% |
| **合计** | **42** | **42** | **0** | **0** | **100%** |

## 3. AC 覆盖矩阵

| AC | 要求摘要 | 测试用例（method） | 类型 | 关联 EV | 状态 |
|----|---------|-------------------|------|---------|------|
| AC-1 | 根目录构建识别 24 项目，无缺失冲突 | `mvn clean package` → Reactor Summary 24 SUCCESS | 构建集成 | EV-100 | ✅ |
| AC-2 | 全模块 BUILD SUCCESS | `mvn clean package -DskipTests` exit 0（24/24） | 构建集成 | EV-100 | ✅ |
| AC-3 | Java 21 编译基线；非 21 显式失败 | ① effective POM release=21 核对；② enforcer 收紧 `[21.1,)` → FAIL 中文错误；③ 恢复 `[21,22)` → PASS | 审计+动态反例 | EV-101 | ✅ |
| AC-4 | Spring Boot 版本唯一 3.5.15 | 9 应用 `dependency:tree` 全 spring-boot* 3.5.15 | 审计 | EV-101 | ✅ |
| AC-5 | Spring Cloud 版本唯一 2025.0.3 | starter/commons/context/gateway-server 版本对齐 2025.0.3 | 审计 | EV-101 | ✅ |
| AC-6 | SCA 版本唯一 2025.0.0.0 | mq 模块依赖解析到 `spring-cloud-starter-stream-rocketmq:2025.0.0.0` | 审计 | EV-101 | ✅ |
| AC-7 | mall-common 无业务领域代码 | 源码树审查：8 子模块仅 package-info.java | 审计 | EV-101 | ✅ |
| AC-8 | mall-contracts 纯契约（无 Repository/领域/业务） | POM 零第三方依赖 + 源码仅 package-info.java | 审计 | EV-101 | ✅ |
| AC-9 | 无服务间 Maven 依赖、无循环 | POM 扫描服务兄弟依赖零命中 + Reactor 顺序构建成功 | 构建+审计 | EV-100 | ✅ |
| AC-10 | 9 应用独立 Fat Jar 可启动，非单体 | 9 Fat Jar 分别 `java -jar` → Started；大小 gateway≈36MB、service≈21MB（9/9） | 启动冒烟 | EV-102 | ✅ |
| AC-11 | Evidence 留档齐全（命令/版本/模块清单/结果） | build-evidence.md §1 模板齐全 + full-build.log / java-version / deptree / startup 日志齐全 | 文档审计 | EV-100, EV-101, EV-102 | ✅ |

**AC 通过率：11/11 = 100%**

## 4. 证据清单

| 证据 | 路径 | 说明 |
|------|------|------|
| 构建日志 | [logs/full-build.log](logs/full-build.log) | 24 SUCCESS，总耗时 35.4s |
| Maven/Java 版本 | [logs/maven-java-version.txt](logs/maven-java-version.txt) | 3.9.16 / 21.0.12 |
| 应用依赖树 | [logs/apps-dependency-tree.txt](logs/apps-dependency-tree.txt) | Spring Boot/Cloud 版本唯一性 |
| MQ 依赖树 | [logs/mq-dependency-tree.txt](logs/mq-dependency-tree.txt) | SCA starter + rocketmq-client 版本 |
| 启动日志 | [logs/startup/](logs/startup/) | 9 份 Started 留档 |
| 主证据文档 | [build-evidence.md](build-evidence.md) | AC 覆盖记录、enforcer 反例原文、版本治理核验原文 |
| 结构化证据 | [evidence.yaml](evidence.yaml) | 10 条 code-change + 3 条 test-run，合计 13 EV |
| 变更清单 | [changeset.md](changeset.md) | 双仓文件改动统计 |
| 提交清单 | [commits.md](commits.md) | Task ↔ Commit 映射 |
| 实现轨迹 | [implementation.md](../implementation.md) | tasked→developing 阶段记录 |

关于 EV-101 `enforcer-*.txt`：反例输出原文直接引用于 build-evidence.md §5（未单独复制文件），阅读以 `build-evidence.md §5` 为准，信息等价且可复核。

## 5. 失败项分析

**无失败项。** 42/42 全部通过；AC-1~11 全覆盖通过。

**说明项（非失败）：**

1. EV-101 `logs/enforcer-*.txt` 未独立落盘——反例运行属于"构建验证过程中临时收紧→验证后立即恢复"的状态依赖动作，实际结果写入 build-evidence.md §5。如需后续独立引用，可由 `mvn validate` 同命令复现并直接写入 `evidence/logs/enforcer-negative.txt` 与 `enforcer-restored.txt`，不影响结论。
2. mall-bom 无 parent、不继承 `maven.compiler.release`——为避免与根 POM import 形成 Maven 模型循环的有意设计；mall-bom 为纯 pom 无源码，不影响编译基线。

## 6. 质量自检（sdd-test §5）

- [x] PRD 每条验收标准（AC-1~11）均有对应测试用例覆盖
- [x] 正常路径（构建/启动）与异常路径（enforcer 反例）均覆盖
- [x] 边界值（Java 版本区间、0 业务代码、0 服务间依赖、9 应用独立 Jar 大小）均有核验
- [x] design.md 高风险项（BOM 循环、版本漂移、模块边界破坏）有测试覆盖
- [x] 测试日志完整保存到 evidence/ 目录并入库（.gitignore 已加例外）
- [x] 无失败项，失败分析为 0
- [x] 通过率 100%（≥90%）

## 7. CLI 说明

`openspec gate check CHG-0001` 与 `openspec change status CHG-0001 --set testing` 当前不可用：全局 OpenSpec Harness CLI 存在环境级损坏（`ERR_MODULE_NOT_FOUND: D:\Desktop\core\sdd\git-submodule.js`），与本次变更产物无关。本报告以人工自检 + 实测输出完成验证，等 CLI 修复后可重放同命令复核。
