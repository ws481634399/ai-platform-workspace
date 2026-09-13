# sdd-task: TC 测试用例设计 + DU 仓内技术方案

> 阶段: task
> 状态转换: designed → tasked
> 产出: test-design.md（STORY 级 TC 测试用例设计）+ 仓内 DU task-design.md / task-spec.md
> 提示片段: prompts/common/persona-sdd.md · prompts/common/constraints.md · prompts/common/output-format.md · prompts/design/persona-task.md

Phase 4.4 起 sdd-task 产出模型调整：

- **STORY 级产物**：仅 `test-design.md`（TC 测试用例设计，verified-by AC-NNN），是 task 阶段机检锚点
- **仓内 DU 产物**：`task-design.md`（技术方案：§6 Implementation Sketch 必填 / §7 Pseudocode 条件必填）+ `task-spec.md`（契约验收：verifies TC / covers AC），由 `du materialize` 生成骨架后 Agent 填充
- **DU 划分表 SSOT**：`requirement-design.md` §6（Change 级）或 `story-design.md` §5（Story 级），task 阶段只引用不新造（du-source-of-truth 机检：blocking）
- **外部 tasks.md 已废弃**：Implementation Guidance 不再写外部文件，全部下沉到实现仓

## 前置条件

- Change 处于 `designed` 状态
- requirement-design.md 已完成（含 §6 DU 划分表 + affected-repositories front-matter）
- Change 已绑定 feature-path（metadata.feature-path；未绑定先执行
  `openspec change bind-feature-path <CHG> --story <STORY-ID>`）

## 执行步骤

### 1. 读取前序 Artifact

读取 `delivery/changes/<CHG>/requirement-design.md`。

#### 1.1 信息提取清单

从设计文档提取：

- **DU 划分表**（requirement-design.md §6 / story-design.md §5）→ 本阶段权威输入，DU/仓库/covers AC/depends on 已由 design 决定，**只引用不新造**（du-source-of-truth 机检：blocking）
- **affected-repositories**（front-matter）→ 影响仓全集（design 已保证每仓至少 1 个 DU）
- 提议方案（新增/修改模块、接口、数据模型）→ 归入对应 DU 的 Scope
- **仓库影响分仓小节**（§3.x）→ 每个 DU 的 Goal 来源
- **跨仓协作契约**（§4）→ DU 间的 Dependencies 与 Acceptance（须与 DU 划分表 depends on 一致）
- 数据变更 → 如需 Migration，归入对应仓的 DU
- 风险评估 → 高风险缓解措施纳入 DU 的 Acceptance
- 待澄清问题 → 已解决的转化为 DU 内容，未解决的标注阻塞

### 2. 生成 test-design.md（STORY 级 TC 测试用例设计）

读取模板 `templates/artifacts/test-design.md`，按结构填写。

产物位置：`delivery/changes/<CHG>/<L1>/<L2>/<L3>/<STORY>/test-design.md`
（STORY 级 artifact，由 metadata.feature-path 决定目录）

元信息 section（占位符替换）：

- `{{change-id}}`：Change ID
- `{{design-source}}`：`<CHG>/requirement-design.md`
- `{{feature-path}}`：`L1 > L2 > L3 > STORY`
- `{{tc-count}}`：TC 总数

**test-design.md 是验证意图（Verification Intent），不是测试代码**——在 dev 开始前锁定 TC-NNN 测试用例表，
保证 test 阶段的独立性（test Agent 不读 implementation.md，照 test-design 执行）。

**TC 表构造规则：**

- 每个 requirement-spec.md / story-spec.md 中的 AC-NNN 至少被一个 TC-NNN verified-by（tc-coverage 机检：blocking）
- 允许标注 `TC-NOT-TESTABLE: 理由`（不可测的 AC 进 warnings 不阻断，但需有替代验证方式）
- verified-by AC 列必须引用 spec 中真实存在的 AC-NNN
- 归属 DU 列必须引用 DU 划分表中真实存在的 DU id
- TC 编号三位递增不复用（TC-001, TC-002, ...）

**TC 表格式：**

```markdown
| TC     | 验证方式     | verified-by AC | 归属 DU   | 备注 |
| ------ | ------------ | -------------- | --------- | ---- |
| TC-001 | API 集成测试 | AC-001         | DU-BE-001 |      |
| TC-002 | E2E          | AC-002         | DU-FE-001 |      |
```

**测试策略段（§2）：**

- 分层测试策略（Unit / Integration / API / E2E），各层覆盖范围与不重复原则
- 数据准备策略（fixture / mock / seed）
- 环境要求（测试运行环境与依赖服务）

### 3. 注册并物化 DU

DU 划分表已在 design 阶段定义。task 阶段执行注册与物化：

```bash
# 注册 DU（若 design 阶段未执行）
openspec du create <CHG> --id DU-BE-001 --repository backend \
  --scope "user-domain,registration-api" --dependencies "" \
  --acceptance "AC-001 注册流程可用;AC-002 重复邮箱拒绝" \
  --complexity "business-flow"

# 物化到实现仓（生成 task-design.md + task-spec.md 骨架 + 记录 baseline commit）
openspec du materialize <CHG> DU-BE-001
```

- `--complexity <triggers>`（business-flow/algorithm/state-transition/orchestration）：
  命中任一则 Pseudocode 必填（metadata.implementation-guidance.pseudocode 自动置 true）；
  简单 DU 可不传，或显式 `--pseudocode false`
- 未绑定 feature-path 时 du create 会报错（先补绑）
- materialize 前置校验：requirement-design.md Machine Gate passed + Human Gate approved

### 4. 填充仓内 DU 技术方案

对每个已物化的 DU，填充实现仓内的两个文件：

**仓内路径**：`implementation/<repo>/delivery/<CHG>/<L1>/<L2>/<L3>/<STORY>/<DU-ID>/`

#### 4.1 task-design.md（技术方案）

| 章节                     | 内容                                                             | 必填     |
| ------------------------ | ---------------------------------------------------------------- | -------- |
| §1 元信息                | DU id / 仓库 / Goal / Scope                                      | 是       |
| §2 目标                  | 该 DU 要实现什么                                                 | 是       |
| §3 Scope                 | 代码范围（模块/文件/目录）                                       | 是       |
| §4 Design References     | 引用 requirement-design.md 章节                                  | 是       |
| §5 Dependencies          | 依赖的其他 DU                                                    | 是       |
| §6 Implementation Sketch | 组件配合关系（Controller → Service → Domain → Repository）       | **必填** |
| §7 Pseudocode            | 关键流程伪代码（complexity-trigger 命中时必填，否则 N/A + 理由） | 条件必填 |

#### 4.2 task-spec.md（契约与验收）

- `verifies: TC-NNN`：引用 test-design.md 中定义的 TC（每个 DU 至少一个）
- `covers: AC-NNN`：引用 requirement-spec.md 中的 AC
- Acceptance Criteria：该 DU 的验收标准
- Verification 清单：Unit / Integration / API / Migration / Error Case

Sketch 与 Pseudocode 不等价：Sketch = 结构方案（组件/调用关系），Pseudocode = 执行逻辑（条件/顺序/异常）。
两者都是 **Dev Guidance**（Expected Implementation），不是强制代码翻译模板；
真实代码事实源始终是 sdd-dev 产出的源代码与 implementation.md。

### 5. 质量自检

产出前自检：

- [ ] affected-repositories 的每个仓库是否都有至少 1 个 DU？（du-coverage 机检）
- [ ] 每个 DU 是否 1:1 对应一个仓库？
- [ ] DU ID 是否符合 `DU-<别名>-<nnn>` 且 Workspace 内唯一？
- [ ] 所有 DU 是否全部在 DU 划分表中定义？（du-source-of-truth 机检：只引用不新造）
- [ ] test-design.md 中每个 AC-NNN 是否至少被一个 TC-NNN verified-by？（tc-coverage 机检：blocking）
- [ ] test-design.md 的 verified-by AC 列是否引用 spec 中真实存在的 AC-NNN？
- [ ] test-design.md 的归属 DU 列是否引用 DU 划分表中的 DU id？
- [ ] 不可测 AC 是否标注 `TC-NOT-TESTABLE: 理由`（进 warnings 不阻断）？
- [ ] requirement-design.md 的每个变更点是否落入某个 DU 的 Scope？
- [ ] 每条 spec 验收标准（AC-NNN）是否映射到某 DU 的 Acceptance？
- [ ] 跨仓依赖是否显式声明且无循环？
- [ ] 每个仓内 DU task-design.md §6 Implementation Sketch 是否非空？（du-task-files 机检）
- [ ] complexity-trigger 命中的 DU，§7 Pseudocode 是否完整（无 placeholder/N/A）？（du-task-files 机检）
- [ ] 未命中触发器的 DU，§7 是否写了 N/A + 理由？
- [ ] 每个仓内 DU task-spec.md 是否有 verifies TC / covers AC？（du-task-files 机检）
- [ ] Sketch/Pseudocode 是否与 requirement-design.md §2/§4 契约一致（未引入新接口/新表）？
- [ ] 是否已用 `openspec du create` 注册全部 DU（含 --complexity/--pseudocode 声明）？
- [ ] 是否已用 `openspec du materialize` 物化全部 DU？

### 6. 用户交互

展示 DU 清单时，主动确认：

- DU 拆分粒度是否合理（跨仓边界正确？）？
- 跨仓依赖顺序是否正确？
- 是否有遗漏的变更点或影响仓？

**Implementation Guidance Review（Human Gate）：**

- DU 是否足够支持 Dev（拿着 task-design/task-spec 不回读 Workspace 能开工吗）？
- Implementation Sketch 是否符合 Design（未违背 §2 方案与 §4 跨仓契约）？
- 是否出现不合理的技术细节（越权下沉系统级决策）？
- Pseudocode 是否违背 API / Data / Architecture Contract？
- 是否遗漏关键异常流程（错误分支 / 边界条件）？
- complexity-trigger 判定是否合理？

> 核心原则：Machine Gate = 是否完整；Human Gate = 是否合理。

## 产出草稿

- `delivery/changes/<CHG>/<L1>/<L2>/<L3>/<STORY>/test-design.md` — TC 测试用例设计（task 阶段锚点产物）
- `implementation/<repo>/delivery/<CHG>/<L1>/<L2>/<L3>/<STORY>/<DU-ID>/task-design.md` — 仓内技术方案
- `implementation/<repo>/delivery/<CHG>/<L1>/<L2>/<L3>/<STORY>/<DU-ID>/task-spec.md` — 仓内契约验收

## 用户确认

展示 test-design.md + DU 清单草稿给用户：

- DU 拆分与跨仓边界是否合理？
- TC 覆盖是否完整（每个 AC 至少一个 TC）？
- 依赖关系是否正确？
- 是否有遗漏的影响仓？

确认后：

```bash
openspec gate check <CHG>
openspec gate approve <CHG>
openspec change status <CHG> --set tasked
```

## 工作示例

> 完整示例参考: `templates/artifacts/examples/test-design.md`（含 TC 测试用例设计 + DU 分解/依赖图/覆盖矩阵）

**需求：** 用户注册（邮箱/手机号），影响 backend 与 frontend 两仓

**DU 清单（节选）：**

```markdown
### DU-BE-001: 注册服务后端

- 仓库: backend | 顺序: 1 | 并行组: A
- Goal: 注册 API（校验 → bcrypt 哈希 → 存储 → 返回 token）
- Scope: models/User, services/auth/, controllers/auth/
- Design References: requirement-design.md §2 / §4 API Contract
- Dependencies: 无
- Acceptance: POST /api/auth/register 201；重复 409；AC-001~3
```

**仓内 task-design.md §6 Implementation Sketch 示例：**

```text
RegisterController → RegisterApplicationService → UserDomainService
    ├── UserRepository
    └── PasswordEncoder
```

**仓内 task-spec.md 示例：**

```yaml
verifies: TC-001, TC-002
covers: AC-001, AC-002, AC-003
acceptance:
  - POST /api/auth/register 返回 201
  - 重复邮箱返回 409
```

> 通用行为约束（产出草稿供用户确认 / 不直接推进状态等）见 prompts/common/constraints.md。
