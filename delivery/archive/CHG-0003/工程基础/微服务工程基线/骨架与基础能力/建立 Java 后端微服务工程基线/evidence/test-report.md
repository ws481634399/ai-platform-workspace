# Test Report

> 阶段：sdd-test 产物
> 位置：CHG-0003/evidence/test-report.md
> 输入：implementation.md + tasks.md
> 产出状态：testing

本文档记录测试执行情况与证据。

## 0. 元信息

- Change ID: CHG-0003
- Implementation 来源: CHG-0003/implementation.md
- 状态流转: developing → testing
- 执行时间: 2026-09-01T22:55:00+08:00
- Evidence 索引: CHG-0003/evidence/evidence.yaml（EV-001~EV-011）

## 1. 测试范围

本 Change 为单仓（repo-1）实现型交付，测试覆盖两个 DU：

- **DU-BE-001**（公共基础能力）：mall-common-core 单元测试（17 tests）+ mall-common-web @WebMvcTest 切片测试（11 tests）
- **DU-BE-002**（服务与网关基线接入）：8 服务 + gateway 上下文冒烟测试（9 tests）+ mall-common-test 聚合器占位测试（1 test）+ 全量构建 + 单模块构建

测试环境：
- Java 21.0.12（Oracle JDK）
- Maven 3.9.16
- 本地仓库：.m2-sandbox（工作区内临时仓库，规避沙箱对工作区外目录的写拦截）
- 测试框架：Spring Boot Test + JUnit 5 + MockMvc（@WebMvcTest 切片）
- 数据库：H2 MODE=MySQL 内存库（冒烟测试，不依赖真实 MySQL）

### 1.1 repo-1（backend）

测试模块清单：
| 模块 | 测试类 | 测试数 | 类型 |
|------|--------|--------|------|
| mall-common-core | CommonErrorCodeTest | 6 | 单元 |
| mall-common-core | UnifyResultTest | 5 | 单元 |
| mall-common-core | TraceContextTest | 6 | 单元 |
| mall-common-web | GlobalExceptionHandlerTest | 6 | 切片（@WebMvcTest） |
| mall-common-web | TraceIdFilterTest | 5 | 切片（@WebMvcTest） |
| mall-common-test | CommonTestAggregatorTest | 1 | 单元 |
| mall-gateway | MallGatewayApplicationSmokeTest | 1 | 集成（上下文冒烟） |
| mall-identity | MallIdentityApplicationSmokeTest | 1 | 集成（上下文冒烟） |
| mall-member | MallMemberApplicationSmokeTest | 1 | 集成（上下文冒烟） |
| mall-product | MallProductApplicationSmokeTest | 1 | 集成（上下文冒烟） |
| mall-cart | MallCartApplicationSmokeTest | 1 | 集成（上下文冒烟） |
| mall-order | MallOrderApplicationSmokeTest | 1 | 集成（上下文冒烟） |
| mall-inventory | MallInventoryApplicationSmokeTest | 1 | 集成（上下文冒烟） |
| mall-search | MallSearchApplicationSmokeTest | 1 | 集成（上下文冒烟） |
| mall-system | MallSystemApplicationSmokeTest | 1 | 集成（上下文冒烟） |

## 2. 测试执行汇总

| 分类     | 总数 | 通过 | 失败 | 跳过 |
| -------- | ---- | ---- | ---- | ---- |
| 单元测试 | 18   | 18   | 0    | 0    |
| 集成测试 | 20   | 20   | 0    | 0    |
| E2E 测试 | 0    | 0    | 0    | 0    |
| 合计     | 38   | 38   | 0    | 0    |

- 通过率: 100%

分类说明：
- 单元测试（18）：core 17（ErrorCode 6 + UnifyResult 5 + TraceContext 6）+ test 聚合器 1
- 集成测试（20）：web @WebMvcTest 切片 11（GlobalExceptionHandler 6 + TraceIdFilter 5）+ 上下文冒烟 9（gateway 1 + 8 services × 1）

执行命令与结果：
| 命令 | 耗时 | 结果 | 日志引用 |
|------|------|------|----------|
| mvn clean package -DskipTests | 01:29 min | BUILD SUCCESS | EV-008 |
| mvn test | 53.316 s | BUILD SUCCESS（38/38 全绿） | EV-009 |
| mvn test -pl mall-common/mall-common-web,mall-common/mall-common-core -am | 6.323 s | BUILD SUCCESS（28/28 全绿） | EV-010 |
| mvn clean package -pl mall-services/mall-order -am -DskipTests | 13.505 s | BUILD SUCCESS | EV-011 |

## 3. 证据清单

- evidence-ref: DU-BE-002 full-build.log → `implementation/ai-platform-backend/delivery/CHG-0003/.../DU-BE-002/evidence/logs/full-build.log`（EV-001/EV-008，24/24 BUILD SUCCESS）
- evidence-ref: DU-BE-002 full-test.log → `implementation/ai-platform-backend/delivery/CHG-0003/.../DU-BE-002/evidence/logs/full-test.log`（EV-002/EV-009，38 tests 全绿）
- evidence-ref: DU-BE-002 single-module-build.log → `implementation/ai-platform-backend/delivery/CHG-0003/.../DU-BE-002/evidence/logs/single-module-build.log`（EV-003/EV-011，mall-order 8/8 SUCCESS）
- evidence-ref: DU-BE-001 test-output.log → `implementation/ai-platform-backend/delivery/CHG-0003/.../DU-BE-001/evidence/logs/test-output.log`（EV-004/EV-010，core 17 + web 11 全绿）
- code-change: EV-005~EV-007（dev 阶段提交留证，见 implementation.md §2）

## 4. AC 覆盖矩阵

| AC | 测试用例 | 类型 | 状态 |
|----|---------|------|------|
| AC-01 | mvn --version 输出 Java=21, Maven=3.9.16 | 环境核验 | 通过 |
| AC-02 | mvn validate Reactor 24 模块全解析 | 构建验证 | 通过 |
| AC-03 | mvn clean package -DskipTests → 24/24 BUILD SUCCESS | 全量构建 | 通过 |
| AC-04 | mvn clean package -pl mall-order -am → 8/8 BUILD SUCCESS | 单模块构建 | 通过 |
| AC-05 | POM 审计无版本覆盖声明（BOM 统一管理） | 静态核验 | 通过 |
| AC-06 | core/web 测试无业务模型断言 + 全量构建无业务污染 | 单元+切片 | 通过 |
| AC-07 | contracts 模块零变更（全量构建复验） | 静态核验 | 通过 |
| AC-08 | 9 个冒烟测试独立上下文加载成功（@gateway + 8 services） | 集成 | 通过 |
| AC-09 | 冒烟测试 H2+Flyway 配置验证通过（MyBatis-Plus 上下文加载） | 集成 | 通过 |
| AC-10 | GlobalExceptionHandler（参数→400/系统→500 不泄露）+ TraceIdFilter（生成/透传/MDC） | 切片 | 通过 |
| AC-11 | mvn test → 38/38 全绿，含最小测试集 | 全量测试 | 通过 |
| AC-12 | core 依赖树零反向（CHG-0002 基线 + core 测试通过） | 依赖复验 | 通过 |

### Pending 项（真实中间件验证）

以下项标注为 Pending M0 Integration Verification，需真实 MySQL/Nacos 环境验证：
- AC-09 真实 MySQL 连接验证（H2 内存库冒烟已通过，配置结构验证完成）
- AC-10 OpenAPI 可访问（springdoc 传递依赖已声明，真实启动验证挂 Pending）

## 5. 失败项分析

无失败项。所有 38 个测试全部通过，0 failures, 0 errors, 0 skipped。

## 6. 质量自检（sdd-test §5 清单）

- [x] tasks.md 中每个 DU 是否都有测试覆盖（du-fan-in-testing）？DU-BE-001（28 tests）+ DU-BE-002（10 tests + 构建）
- [x] PRD 每条验收标准是否有对应测试用例？AC-01~AC-12 全覆盖（见 §4 矩阵）
- [x] design.md §4 跨仓协作契约是否有集成测试覆盖？单仓交付无跨仓契约，冒烟测试覆盖仓内上下文加载
- [x] 正常路径和异常路径是否都覆盖？core 正常路径（UnifyResult ok/fail）+ web 异常路径（参数→400/系统→500/TraceId 非法重生成）
- [x] 边界值是否有测试？TraceContext 非法 hex/空值重生成 + TraceIdFilter 合法/非法/缺失 header
- [x] design.md 高风险项是否有测试覆盖？WebFlux 栈隔离（gateway 冒烟不依赖 common-web）+ 数据库口令环境变量化（无硬编码）
- [x] 各仓测试日志是否完整保存到该仓 DU evidence/？4 份日志已保存至 repo 侧 DU evidence/logs/
- [x] DU 状态是否已回传（sync-status）？du sync-status 已回填 result commit
- [x] 失败项是否有分析和处理建议？无失败项
- [x] 通过率是否 ≥ 90%？100%（38/38 全绿）
