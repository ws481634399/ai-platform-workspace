# PRD

> 阶段：sdd-prd 产物
> 输入：CHG Context（exploration.md + requirement.md）
> 产出状态：specified

本文档将需求转化为产品规格。

## 0. 元信息

- Change ID: CHG-0002
- Requirement: ENG-BASE-002
- Feature ID: STORY-2
- 状态流转: exploring → specified
- 关联 Change: CHG-0001（前置需求 ENG-BASE-001 已交付归档，本 Change 复用其结构成果）

## 1. 背景

CHG-0001（ENG-BASE-001）已搭建 Maven 多模块工程骨架，并按边界约定交付了 mall-common 8 个技术子模块与 mall-contracts 2 个契约子模块的目录结构、聚合 POM 与依赖声明。

ENG-BASE-002 作为独立需求，目标是将"技术复用层 + 跨服务契约层"的两层公共边界**形式化固化**：

- **mall-common（技术复用层）**：只承载"怎么用框架"的横切技术能力（core/web/security/redis/mq/openfeign/log/test）；
- **mall-contracts（跨服务契约层）**：只承载跨服务边界的稳定数据形状（API Request/Response、内部服务 DTO、集成事件、事件公共元数据）；
- 架构目标：**防止业务领域模型（商品/订单/库存/会员等）渗入公共层**，避免演化为强耦合的分布式单体；跨服务协作必须走 API 契约 / OpenFeign / 集成事件，而非 Maven 直接依赖业务实现模块。

经探索阶段重叠分析（exploration.md §1.2）：ENG-BASE-002 的 9 条验收标准中 8.5 条已由 CHG-0001 结构交付覆盖；唯一形式化增量为「mall-common-core 不反向依赖 Web/Redis/MQ/OpenFeign 等上层模块」的显式审计（CHG-0001 的 AC 清单未将其单列，当时通过设计约定隐式满足）。

因此本 Change 定位为**验收核验型 Change**：复用既有结构、审计依赖方向、复验 9 条 AC 并独立留证，预期零代码变更（若审计发现依赖方向违规，仅做最小 POM 修正）。

## 2. 用户价值

（基于 Job-to-be-Done 框架分析）

- 目标用户: 平台后端开发工程师（公共模块消费者）、平台架构师 / 工程治理者（边界治理者）
- 痛点摘要: 公共层一旦被业务领域模型渗入，会演化为强耦合的分布式单体；core 若反向依赖上层模块会失去基础稳定性；缺少显式审计证据使边界约束难以持续复核
- 预期价值: 将两层公共边界固化为可复核的验收证据，为 M0 后续及 M1+ 各服务 Change 提供稳定的公共能力底座与 review/test 检查依据

**JTBD 场景：**

```
角色：平台后端开发工程师
场景：When I 需要在业务服务中复用技术能力或跨服务传递数据,
      I want 依赖职责边界清晰的 mall-common / mall-contracts 模块
价值：So that 我不把业务领域模型放进公共层、不通过 Maven 依赖其他服务的实现模块，
      跨服务协作统一走 API 契约 / OpenFeign / 集成事件
```

```
角色：平台架构师 / 工程治理者
场景：When I 需要审计或评审公共层依赖方向,
      I want 有明确的依赖边界规则与可复核的审计证据
价值：So that 公共层长期保持稳定可复用，架构约束能落地为可持续的检查依据
```

## 3. 范围

### 3.1 包含（Scope In）

- 核验 mall-common 8 个子模块（core/web/security/redis/mq/openfeign/log/test）目录与聚合 POM 完备；
- 核验 mall-contracts 2 个子模块（mall-api-contracts / mall-event-contracts）目录与聚合 POM 完备；
- 核验 10 个公共模块全部加入 Maven Reactor 并参与统一构建；
- **显式审计 mall-common-core 依赖方向**：core 不依赖 web/redis/mq/openfeign/security/log 等上层模块（本 Change 唯一形式化增量，dependency:tree + POM 审计留证）；
- 将 mall-common-test 依赖其他 common 模块的"测试工具链"方向显式留证为合法例外；
- 复验 ENG-BASE-002 的 9 条验收标准并独立留证（证据策略见 §4 末尾说明）；
- 若审计发现依赖方向违规：仅做最小 POM 修正并复验（预期小概率）。

### 3.2 不包含（Scope Out）

- 不新增任何业务/工具代码到公共模块（保持 package-info.java 空模块形态）；
- 不实现统一响应、全局异常、JWT/RBAC、Redis 业务能力、RocketMQ 业务消息、OpenFeign 具体业务调用（需求明确排除）；
- 不实现商品、订单、库存、会员等业务功能；
- 不调整根 POM / 业务服务 POM（预计零改动）；
- 不修改 CHG-0001 已归档的交付成果。

## 4. 业务规则

- [模块清单完备]：mall-common 必须且仅包含 core/web/security/redis/mq/openfeign/log/test 8 个子模块 → 缺任一模块 = 验收失败
- [契约层清单完备]：mall-contracts 必须且仅包含 mall-api-contracts / mall-event-contracts 2 个子模块 → 缺任一模块 = 验收失败
- [Reactor 统一构建]：所有公共模块必须加入 Maven Reactor → 构建列表缺失或构建失败 = 验收失败
- [领域模型隔离]：mall-common 中禁止出现 Product/Order/Inventory/Member/Role/Menu 等业务领域模型与业务实现 → 发现即验收失败
- [契约纯度]：mall-contracts 仅允许存放 API Request/Response、内部服务 DTO、集成事件、事件公共元数据 → 出现 Repository/Mapper/PO/ApplicationService/DomainService/领域聚合即验收失败
- [依赖方向]：mall-common-core 不依赖 mall-common-web/redis/mq/openfeign/security/log 等上层模块 → dependency:tree 或 POM 审计发现反向依赖 = 验收失败（最小修复后复验）
- [测试模块例外]：mall-common-test 可依赖其他 mall-common-* 模块（测试工具链聚合方向）→ 该方向为显式豁免，不属于违规（豁免条款细则在 design 阶段正式定义）
- [服务间隔离]：业务微服务按需依赖公共模块，不得通过 Maven 直接依赖其他业务微服务的实现模块 → 跨服务协作只能走 API 契约 / OpenFeign / 集成事件
- [无循环依赖]：Maven 依赖图不得存在循环 → enforcer 检测失败或构建失败 = 验收失败
- [零能力提前实现]：本阶段仅固化结构/依赖/职责边界 → 公共模块出现完整业务能力实现 = 超范围

**AC 复验证据策略（exploration 未知问题 3 的处理结论）**：引用 CHG-0001 归档 evidence 作为结构交付证据 + 本 Change 新增 core 依赖方向审计实证 + 一次 `mvn validate` 快速复验确认当前基线未漂移；不重复执行全量 package 构建。此策略与 §5 AC 编号绑定，一经确认保持稳定。

## 5. 验收标准

- [ ] AC-1: mall-common 下 8 个子模块（core/web/security/redis/mq/openfeign/log/test）目录与聚合 POM 全部存在
- [ ] AC-2: mall-contracts 下 2 个子模块（mall-api-contracts / mall-event-contracts）目录与聚合 POM 全部存在
- [ ] AC-3: 10 个公共模块全部出现在根 POM Maven Reactor 构建列表中（构建输出可复核）
- [ ] AC-4: 根目录执行 Maven 构建成功（validate 级复验通过，引用 CHG-0001 全量构建 24/24 BUILD SUCCESS 归档证据）
- [ ] AC-5: mall-common 源码中不存在 Product/Order/Inventory/Member/Role/Menu 等业务领域模型与业务实现（审计留证）
- [ ] AC-6: mall-contracts 中不存在 Repository/Mapper/PO/ApplicationService/DomainService/领域聚合及持久化实现（审计留证）
- [ ] AC-7: 不存在业务服务之间的直接 Maven 实现依赖（服务 POM 依赖审计留证）
- [ ] AC-8: 不存在 Maven 循环依赖（enforcer 检查 + 依赖解析审计留证）
- [ ] AC-9: 各模块职责边界明确，且 **mall-common-core 依赖方向审计通过**——core 的 POM/依赖树中不含 mall-common-web、mall-common-redis、mall-common-mq、mall-common-openfeign、mall-common-security、mall-common-log（审计留证，本 Change 核心增量；mall-common-test 的聚合方向为显式豁免，不在此列）
- [ ] AC-10: 审计结论与复验证据归档至本 Change evidence/ 目录（含 core 依赖方向审计报告、9 条 AC 复验记录）

**exploration 未知问题处理结果：**

| 未知问题 | 处理方式 |
|---------|---------|
| 1. mall-common-core 实际依赖是否满足"不反向依赖上层" | 已解决 → 转化为 AC-9 显式审计项，dev 阶段以 dependency:tree + POM 审计实证 |
| 2. mall-common-test 聚合方向是否需要显式留证为合法例外 | 部分解决 → §4 已列"测试模块例外"规则，豁免条款细则待设计阶段确认 |
| 3. AC 复验是否需重新全量构建 | 已解决 → 采用"引用归档证据 + 新增 core 审计实证 + validate 快速复验"策略（§4 末尾） |
