# Tasks

> 阶段：sdd-task 产物
> 输入：design.md
> 产出状态：tasked

本文档将 CHG-0001 设计拆解为可执行任务。

## 0. 元信息

- Change ID: CHG-0001
- Design 来源: CHG-0001/design.md
- 状态流转: designed → tasked
- Task 总数: 11

> **修订记录（2026-08-28）**：按 exploration 技术决策 3 修订，目标仓库调整为独立仓库 `ai-platform-backend`（repo-1，Maven 根=仓库根，目录路径去掉原 `backend/` 前缀）；工作区侧产物（README/Evidence 之外的文档）归 workspace 仓。原 ai-mall-platform 为废弃版本，不作为实现参考。

## 任务清单

共 11 个 Task，按依赖顺序执行；TASK-008~011 为验证与证据任务，粒度上各自独立成 Task 以保证 AC 可追溯。TASK-001~007 的目标仓库均为 repo-1（ai-platform-backend）。

### TASK-001: 创建根聚合 POM

- 目标仓库: repo-1
- 目标模块: pom.xml（仓库根）
- 预期变更: 新增根 POM——坐标 `com.ai-mall:backend:1.0.0-SNAPSHOT`（pom）；modules 声明 mall-bom/mall-common/mall-contracts/mall-gateway/mall-services；properties（java.version=21、maven.compiler.release=21、project.build.sourceEncoding=UTF-8、project.reporting.outputEncoding=UTF-8）；dependencyManagement 仅 import `com.ai-mall:mall-bom:${project.version}`；pluginManagement 集中管理 compiler/enforcer/spring-boot/surefire/resources 插件版本；enforcer 全模块生效（requireMavenVersion [3.9,)、requireJavaVersion [21,22)）
- 验证方法: POM 结构审查（本 Task 完成后全量构建尚不可用，首个构建验证点在 TASK-008）
- 依赖: 无
- 预估变更: ~120 行

### TASK-002: 创建 mall-bom 版本权威模块

- 目标仓库: repo-1
- 目标模块: mall-bom/pom.xml
- 预期变更: 新增 mall-bom（packaging=pom，父=backend）：dependencyManagement import spring-boot-dependencies 3.5.15、spring-cloud-dependencies 2025.0.3、spring-cloud-alibaba-dependencies 2025.0.0.0；直接管理 MyBatis-Plus BOM、MapStruct、Springdoc；Lombok 不声明（由 Boot BOM 托管）
- 验证方法: `mvn help:effective-pom -pl mall-bom` 核对三方 BOM 导入与首批依赖版本
- 依赖: TASK-001
- 预估变更: ~60 行

### TASK-003: 创建 mall-common 聚合与 8 个技术子模块骨架

- 目标仓库: repo-1
- 目标模块: mall-common/
- 预期变更: 新增 mall-common 聚合 POM（父=backend）与 8 个子模块 POM（core/web/security/redis/mq/openfeign/log/test，父=mall-common），按 design §2.4 声明各自定位依赖（如 web→spring-boot-starter-web、security→starter-security、redis→starter-data-redis、openfeign→openfeign+loadbalancer、test→starter-test scope=test），全部不写 `<version>`；建立 `com.ai.mall.common.*` 包结构占位
- 验证方法: 子模块 POM 无版本声明审计 + 包结构存在性检查（全量构建在 TASK-008）
- 依赖: TASK-002
- 预估变更: ~9 个 POM ≈ 200 行

### TASK-004: 创建 mall-contracts 聚合与 2 个契约子模块骨架

- 目标仓库: repo-1
- 目标模块: mall-contracts/
- 预期变更: 新增 mall-contracts 聚合 POM 与 mall-api-contracts、mall-event-contracts 两个子模块 POM（无第三方依赖，纯 DTO 定位），建立对应包结构占位
- 验证方法: 子模块 POM 审计（零依赖、零版本声明）+ 包结构存在性检查
- 依赖: TASK-002
- 预估变更: ~3 个 POM ≈ 80 行

### TASK-005: 创建 mall-gateway 独立应用骨架

- 目标仓库: repo-1
- 目标模块: mall-gateway/
- 预期变更: 新增 gateway POM（父=backend，依赖 spring-cloud-starter-gateway，绑定 spring-boot-maven-plugin repackage）+ `com.ai.mall.gateway.MallGatewayApplication` 最小启动类 + application.yml（spring.application.name=mall-gateway、server.port=8080）
- 验证方法: POM 审计 + 启动类/配置存在性检查（启动验证在 TASK-009）
- 依赖: TASK-001
- 预估变更: ~40 行

### TASK-006: 创建 mall-services 聚合与 8 个业务服务 POM 骨架

- 目标仓库: repo-1
- 目标模块: mall-services/
- 预期变更: 新增 mall-services 聚合 POM（父=backend）与 8 个服务模块 POM（identity/member/product/cart/order/inventory/search/system，父=mall-services，依赖 spring-boot-starter-web，绑定 repackage），建立 `com.ai.mall.<svc>` 包结构占位
- 验证方法: POM 审计（版本零声明、repackage 绑定齐全）+ 包结构存在性检查
- 依赖: TASK-002
- 预估变更: ~9 个 POM ≈ 220 行

### TASK-007: 补齐 8 个服务的启动类与最小配置

- 目标仓库: repo-1
- 目标模块: mall-services/mall-{identity,member,product,cart,order,inventory,search,system}/
- 预期变更: 每服务新增最小启动类 `Mall<Svc>Application`（仅 @SpringBootApplication）+ application.yml（spring.application.name + server.port 8101~8108 顺序分配）；M0 不含任何业务 Bean 与 Nacos/DB 配置
- 验证方法: 启动类/配置存在性与端口分配核对（design §2.5）
- 依赖: TASK-006
- 预估变更: ~8 类 + 8 yml ≈ 90 行

### TASK-008: 仓库根全量构建验证（覆盖 AC-1、AC-2）

- 目标仓库: repo-1
- 目标模块: 仓库根
- 预期变更: 无代码变更（验证任务；如遇失败做最小修复）
- 验证方法: 在仓库根执行 `mvn clean package -DskipTests` → BUILD SUCCESS；核对 Reactor 摘要包含全部 24 个 Maven 项目、无模块缺失/artifactId 冲突；输出留档
- 依赖: TASK-003、TASK-004、TASK-005、TASK-006
- 预估变更: ~0 行

### TASK-009: 独立打包与启动验证（覆盖 AC-10）

- 目标仓库: repo-1
- 目标模块: mall-gateway/、mall-services/\*
- 预期变更: 无代码变更（验证任务）
- 验证方法: 确认 9 个应用均产出可执行 Fat Jar（target/\*-SNAPSHOT.jar 且含 repackage 布局）；逐一 `java -jar` 启动 → 应用正常起容器（观察 Spring Boot 启动横幅/端口监听）后停止；确认全量构建未产出单体 Jar
- 依赖: TASK-007、TASK-008
- 预估变更: ~0 行

### TASK-010: 版本治理与边界规则核验（覆盖 AC-3~AC-9）

- 目标仓库: repo-1
- 目标模块: 仓库根（只读核验 + 证据留存）
- 预期变更: 无代码变更（如核验失败做最小修复）
- 验证方法: ① 抽查全部模块 effective POM → maven.compiler.release=21 统一（AC-3）；② 用非 Java 21 JDK 执行构建（或检查 enforcer 输出）→ 显式失败（AC-3）；③ 9 个应用 dependency:tree → Spring Boot/Cloud/SCA 版本唯一且来自 mall-bom（AC-4~6）；④ mall-common/mall-contracts 源码树无业务领域代码（AC-7/8）；⑤ 依赖解析无循环、服务间无 Maven 依赖（AC-9）；⑥ 全 POM 扫描无 BOM 管依赖的 `<version>`、无敏感信息（PRD 规则 1/12）
- 依赖: TASK-008
- 预估变更: ~0 行

### TASK-011: 构建 Evidence 汇总与工程 README（覆盖 AC-11）

- 目标仓库: repo-1（README）+ workspace 仓（Evidence）
- 目标模块: delivery/changes/CHG-0001/evidence/（workspace 仓）、README.md（repo-1 仓库根）
- 预期变更: 新增 evidence/build-evidence.md（按需求 §21 模板：Requirement=ENG-BASE-001、Java=21、Maven 版本、Build Command、Result=PASS/FAIL、Modules 实际清单、Notes）；新增后端仓库根 README.md（构建说明 + JDK 21/Maven 3.9+ 环境要求 + 常用命令）；根 .gitignore 已在前置仓库初始化提交中建立，本 Task 核对其覆盖 target/ 等忽略项
- 验证方法: Evidence 内容与 TASK-008~010 实测输出一致，不存在"构建应该可以通过"式占位记录
- 依赖: TASK-009、TASK-010
- 预估变更: ~120 行

## 覆盖检查

- design.md 变更点：根 POM（001）✓ mall-bom（002）✓ mall-common 8 子模块（003）✓ mall-contracts 2 子模块（004）✓ gateway（005）✓ services 8 模块+启动类（006/007）✓ README/.gitignore（011）✓
- PRD 验收标准：AC-1/2 → 008；AC-3~9 → 010；AC-10 → 009；AC-11 → 011 ✓ 全覆盖
- 风险缓解：版本组合实测（008/010）✓、repackage 单体化防范（005/006/009）✓、enforcer 环境要求文档化（001/011）✓
- 依赖关系：001 → 002 → {003, 004, 006, 005} → 008 → {009, 010} → 011，无循环
