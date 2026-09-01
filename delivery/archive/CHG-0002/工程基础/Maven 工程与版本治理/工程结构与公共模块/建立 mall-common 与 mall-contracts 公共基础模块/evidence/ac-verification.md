# AC Verification — CHG-0002（ENG-BASE-002）

> 复验时间：2026-08-31
> 仓库：repo-1 = `implementation/ai-platform-backend`（独立 Git 仓库，Maven 根 = 仓库根）
> 性质：验收核验型 Change——按 PRD §4 证据策略执行：引用 CHG-0001 归档证据 + 本 Change 新增 core 依赖方向审计实证 + `mvn validate` 快速复验，不重复全量构建
> DU：DU-BE-001（tasks.md §任务清单）
> 结论：**AC-1 ~ AC-10 全部通过，R1~R4 零违规，最小修复预案未触发，POM/代码零变更**

## 1. 审计规则集执行记录（design.md §2.2）

| 规则 | 判定标准 | 执行手段 | 结果 |
|------|---------|---------|------|
| R1 core 零反向依赖 | core POM `<dependencies>` 为空；依赖树无任何 `mall-common-*` 节点 | 静态 POM 审查 + `dependency:tree -pl mall-common/mall-common-core` | **PASS**（树仅自身一行） |
| R2 公共层无横向依赖 | web/security/redis/mq/openfeign/log 互不依赖 | 全部 8 子模块 POM 全量 grep `<artifactId>mall-common-(core\|web\|…)` ——命中仅为聚合 POM `<module>` 声明与各模块自身 `<artifactId>`/`<name>`，无任何 `<dependency>` 声明 | **PASS** |
| R3 test 豁免条款 | test 允许依赖其他 common-*（预防性规则）；其他 common 模块禁止依赖 test | 方向判定：test POM 当前无 common 内部依赖；其余 7 模块 POM 无对 test 的依赖声明 | **PASS**（当前事实零依赖，条款为面向后续迭代的预防性规则） |
| R4 契约层纯度 | 两个 contracts 模块零第三方/零 common 依赖 | 静态 POM 审查 + `dependency:tree` | **PASS**（两树均仅自身一行） |

条件性最小修复预案：**未触发**（R1~R4 全部通过，零违规；预期零代码变更成立）。

## 2. AC 复验记录表

| AC | 要求（PRD §5） | 复验方式 | 实测结果 | 证据 |
|----|---------------|---------|---------|------|
| AC-1 | mall-common 8 子模块目录与聚合 POM 全部存在 | 目录枚举 + 聚合 POM `<modules>` 核对 | **PASS**：core/web/security/redis/mq/openfeign/log/test 8/8 目录 + pom.xml 齐备（test 为 `src/test` 形态），聚合 POM modules 8 项一致 | 本文件 §3.1 |
| AC-2 | mall-contracts 2 子模块目录与聚合 POM 全部存在 | 同上 | **PASS**：mall-api-contracts / mall-event-contracts 2/2，聚合 POM modules 2 项一致 | 本文件 §3.2 |
| AC-3 | 10 个公共模块全部出现在根 POM Reactor 构建列表 | `mvn validate` Reactor Build Order 复核 | **PASS**：mall-common + 8 子模块 + mall-contracts + 2 子模块共 10 项全部在 Reactor（总 24 项目，序号 3~14） | [logs/mvn-validate.txt](logs/mvn-validate.txt) L5~L28、L201~L214 |
| AC-4 | 根目录 Maven 构建成功 | 本 Change validate 复验 + 引用 CHG-0001 全量构建归档 | **PASS**：validate 24/24 SUCCESS（2026-08-31T22:49:17，8.927 s，enforcer Maven/Java 版本守门通过）；CHG-0001 全量 `mvn clean package -DskipTests` 24/24 BUILD SUCCESS（2026-08-28） | [logs/mvn-validate.txt](logs/mvn-validate.txt)；`delivery/archive/CHG-0001/evidence/build-evidence.md` §1~§3 |
| AC-5 | mall-common 无业务领域模型与业务实现 | grep `class\|interface (Product\|Order\|Inventory\|Member\|Role\|Menu)`（大小写不敏感，全源码） | **PASS**：零命中；源码仅 8 个 `package-info.java` 空模块 | 本文件 §3.3 |
| AC-6 | mall-contracts 无 Repository/Mapper/PO/ApplicationService/DomainService/领域聚合/持久化实现 | grep `Repository\|Mapper\|ApplicationService\|DomainService\|@Entity` | **PASS**：零命中；源码仅 2 个 `package-info.java` | 本文件 §3.3 |
| AC-7 | 无业务服务之间直接 Maven 实现依赖 | mall-services 全部 9 个 POM grep `mall-` 依赖 | **PASS**：命中仅为聚合 POM `<artifactId>mall-services</artifactId>` 与各服务 parent 声明/自身坐标，无任何服务依赖其他服务实现模块 | 本文件 §3.4 |
| AC-8 | 无 Maven 循环依赖 | enforcer 守门 + validate 全链依赖解析成功 + R2 无横向依赖 | **PASS**：validate 24/24 成功（依赖图可完整解析即无环）；公共层零横向依赖使环不可能形成；CHG-0001 全量构建同样通过 | [logs/mvn-validate.txt](logs/mvn-validate.txt)；`delivery/archive/CHG-0001/evidence/build-evidence.md` |
| AC-9 | 各模块职责边界明确，且 **mall-common-core 依赖方向审计通过**（本 Change 核心增量） | R1~R4 审计规则集执行 + dependency:tree 实证（覆盖传递依赖路径） | **PASS**：core 依赖树仅 `com.ai-mall:mall-common-core:jar:1.0.0-SNAPSHOT` 一行，不含 web/security/redis/mq/openfeign/log/test 任一节点；两 contracts 模块树均零依赖 | [logs/dependency-tree-core.txt](logs/dependency-tree-core.txt)、[logs/dependency-tree-api-contracts.txt](logs/dependency-tree-api-contracts.txt)、[logs/dependency-tree-event-contracts.txt](logs/dependency-tree-event-contracts.txt)；本文件 §1 |
| AC-10 | 审计结论与复验证据归档至 evidence/ | 本文件汇总索引 | **PASS**：全部证据归档于本目录，索引见 §4 | 本文件 |

## 3. 审计明细

### 3.1 mall-common 模块清单（AC-1）

聚合 POM（`mall-common/pom.xml`，packaging=pom，parent=com.ai-mall:backend）`<modules>`：

```
mall-common-core / mall-common-web / mall-common-security / mall-common-redis /
mall-common-mq / mall-common-openfeign / mall-common-log / mall-common-test
```

目录实测：8 个子模块目录均存在，各含 `pom.xml` 与 `package-info.java`（core/web/security/redis/mq/openfeign/log 位于 `src/main/java/com/ai/mall/common/<域>/`，test 位于 `src/test/java/com/ai/mall/common/test/`）。

### 3.2 mall-contracts 模块清单（AC-2）

聚合 POM（`mall-contracts/pom.xml`，packaging=pom）`<modules>`：

```
mall-api-contracts / mall-event-contracts
```

目录实测：2 个子模块均存在，各含 `pom.xml` 与 `package-info.java`（`src/main/java/com/ai/mall/api/` 与 `src/main/java/com/ai/mall/event/`）。两模块 POM description 均明示"零第三方依赖，纯数据定义"。

### 3.3 源码业务渗入扫描（AC-5 / AC-6）

- AC-5：对 `mall-common/**` 源码执行 `class|interface (Product|Order|Inventory|Member|Role|Menu)`（-i）→ **No matches found**
- AC-6：对 `mall-contracts/**` 源码执行 `Repository|Mapper|ApplicationService|DomainService|extends JpaRepository|@Entity`（-i）→ **No matches found**

（扫描工具 ripgrep；mall-common / mall-contracts 当前为纯 package-info 空模块形态，与 PRD"零能力提前实现"规则一致）

### 3.4 服务间依赖审计（AC-7）

对 `mall-services/**/pom.xml` grep `<artifactId>mall-`，命中 17 行全部为：

- 聚合 POM 自身坐标：`mall-services/pom.xml:13 <artifactId>mall-services</artifactId>`
- 各服务（identity/member/product/cart/order/inventory/search/system）POM 的 `<parent>…mall-services…` 与自身 `<artifactId>mall-<服务名>`

**无任何 `<dependency>` 指向其他业务服务实现模块** → 服务间隔离规则通过（跨服务协作预留 API 契约 / OpenFeign / 集成事件通道，即 mall-contracts 层）。

### 3.5 dependency:tree 实证（AC-9 / R1 / R4）

三棵依赖树均仅含模块自身坐标一行（详见 logs/ 下三个留证文件）：

```
com.ai-mall:mall-common-core:jar:1.0.0-SNAPSHOT        （BUILD SUCCESS，29.794 s）
com.ai-mall:mall-api-contracts:jar:1.0.0-SNAPSHOT      （BUILD SUCCESS，3.070 s）
com.ai-mall:mall-event-contracts:jar:1.0.0-SNAPSHOT    （BUILD SUCCESS，1.471 s）
```

dependency:tree 输出为解析后的完整依赖图（含传递依赖），树中零依赖节点证明静态审计结论未被传递依赖绕过——design.md §6 风险项"传递依赖绕过 POM 声明"实证排除。

## 4. 证据索引（AC-10）

| 证据文件 | 覆盖 AC | 说明 |
|---------|--------|------|
| [logs/mvn-validate.txt](logs/mvn-validate.txt) | AC-3 / AC-4 / AC-8 | validate 复验，Reactor 24 项目全 SUCCESS（含 enforcer 守门记录） |
| [logs/dependency-tree-core.txt](logs/dependency-tree-core.txt) | AC-9（R1） | core 依赖树零节点，核心增量审计证据 |
| [logs/dependency-tree-api-contracts.txt](logs/dependency-tree-api-contracts.txt) | AC-9（R4） | API 契约纯度实证 |
| [logs/dependency-tree-event-contracts.txt](logs/dependency-tree-event-contracts.txt) | AC-9（R4） | 事件契约纯度实证 |
| 本文件（ac-verification.md） | AC-1 / AC-2 / AC-5 / AC-6 / AC-7 / AC-8 / AC-9 / AC-10 | 规则集执行记录 + AC 复验记录表 + 审计明细 |
| `delivery/archive/CHG-0001/evidence/build-evidence.md` | AC-4 / AC-8（补强） | CHG-0001 全量构建 24/24 BUILD SUCCESS 归档（2026-08-28，Maven 3.9.16 + JDK 21.0.12） |

## 5. 环境与执行说明

- Maven 3.9.16 + JDK 21.0.12（Oracle，`D:\develop\Java\jdk-21`），满足根 POM enforcer `requireMavenVersion [3.9,)` + `requireJavaVersion [21,22)`。
- Trae 沙箱禁止向工作区外写入（`D:\maven-repository`），`dependency:tree` 以 `-Dmaven.repo.local=D:/Desktop/ai-platform/.m2-sandbox` 在工作区内完成插件解析（参数加引号防 PowerShell 解析截断）；该参数仅作用于本次实证命令，不改变工程配置。`mvn validate` 无需额外插件下载，在默认本地仓库模式下执行成功。
- 本 Change 审计全程 **POM/代码零变更**，符合"验收核验型 Change 预期零代码变更"定位（PRD §1/§3.1、design §2.1）。
