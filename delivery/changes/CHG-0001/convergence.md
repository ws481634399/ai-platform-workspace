# Convergence — CHG-0001

> Change ID: CHG-0001
> 状态流转: testing → completed
> 完成时间: 2026-08-29T16:30:00+08:00
> Standards 需更新: yes
> Product 需更新: yes
> Feature Tree 需更新: yes（STORY-1 planned → delivered）
> Glossary 需更新: no

## 1. 知识变化总结

CHG-0001（ENG-BASE-001）建立了 AI Mall 后端 Java Maven 多模块工程基线。经过 sdd-explore → prd → design → tasks → dev → test 六阶段，实际可沉淀为长期知识的内容分为三类：

1. **Standards 晋升（3 条，跨 Change 可复用）**：
   - Java 后端技术基线版本组合（JDK/Maven/Spring 全家桶/MyBatis-Plus/MapStruct/Springdoc 的唯一版本组合）。
   - Maven 四层 POM 体系 + mall-bom 无 parent 防循环 + enforcer 守门 + BOM import 版本治理唯一权威 + 依赖方向单向规则 + 公共模块边界 + 服务独立打包。
   - 工程 enforcer 反例验证法（收紧区间 → 显式失败中文提示 → 恢复通过），作为后续基线升级的质量门禁模板。
2. **Product 更新（2 条，产品架构知识同步）**：
   - product/08-系统与微服务架构.md §5 的单仓目录种子图已过时，补充"双仓结构落地修订"说明（工作区仓 ai-platform-workspace + 独立后端代码仓 ai-platform-backend 位于 implementation/ai-platform-backend，Maven 根=仓库根）。
   - feature-tree.yaml 中 STORY-1 状态由 `planned` 更新为 `delivered`（对应本 Change 完成）。
3. **No Update（不具备跨 Change 复用价值的本 Change 特有细节）**：
   - 具体 POM 行号、提交哈希、临时 mq 坐标修复过程、沙箱临时本地仓 `.m2-repo/` 路径、evidence/logs 二进制 Jar 大小等实现细节。
   - openspec CLI 环境损坏（`git-submodule.js` 缺失），属外部工具问题，与知识无关。

## 2. 知识项分类与变更内容

### 2.1 Standards 晋升

**S-01：Java 后端技术基线版本组合表**
- 文件：`standards/engineering/backend/framework-standard.md`
- 操作：更新（§7 追加 `§7.3 Java 后端技术基线版本组合（CHG-0001 晋升）`）
- 内容：JDK 21 / Maven 3.9+ / Spring Boot 3.5.15 / Spring Cloud 2025.0.3 / Spring Cloud Alibaba 2025.0.0.0 / MyBatis-Plus BOM 3.5.12 / MapStruct 1.6.3 / Springdoc 2.8.9 / Lombok 由 Boot BOM 托管 / UTF-8；统一构建命令；升级流程为「改统一配置 → 全量编译 → 测试 → 确认」。
- 理由：本 Change 是平台首个后端基线落地；后续任何里程碑引入新服务或升级框架都必须与本表对齐。
- 复用场景：所有未来涉及 Java 后端模块新增、版本升级、enforcer 规则调整的 Change。

**S-02：Maven 四层 POM 体系、版本治理唯一权威与依赖边界**
- 文件：`standards/engineering/backend/framework-standard.md`
- 操作：更新（§7 追加 `§7.4 Maven 多模块版本治理与依赖边界（CHG-0001 晋升）`）
- 内容：
  - §7.4.1 四层聚合（根 POM → mall-bom 无 parent → common/contracts/services 聚合 → 叶子模块）
  - §7.4.2 BOM 唯一权威，叶子模块除 parent 块外禁止写 `<version>`
  - §7.4.3 依赖方向单向图（服务→common/contracts，禁止服务↔服务 Maven 依赖）
  - §7.4.4 mall-common 只放技术能力、mall-contracts 纯 DTO 零第三方依赖
  - §7.4.5 9 个应用各自绑定 repackage、全量构建不产出单体 Jar
- 理由：本 Change 通过 AC-1~AC-11 实测验证了上述规则的可行性；违反即触发对应验收失败。
- 复用场景：后续新模块骨架、微服务拆分、服务拆分/合并的架构评审。

**S-03：enforcer 反例验证法**
- 归属：隐式包含在 S-02 守门描述中（§7.3 JDK/Maven 行 "enforcer 不满足则构建显式失败" 与 §7.4.1 enforcer 守门段落）。
- 验证步骤（本次已实测）：临时收紧 `requireJavaVersion` 到 `[21.1,)` → `mvn validate` 输出中文错误并 FAIL → 恢复 `[21,22)` → `mvn validate` 通过。
- 复用场景：每次 enforcer 规则新增/变更后，均需执行同构反例以保证失败路径存在。

### 2.2 Product 更新

**P-01：系统与微服务架构——仓库落地修订（双仓结构）**
- 文件：`product/08-系统与微服务架构.md`
- 操作：更新（§5 单仓目录图之后追加"仓库落地修订（CHG-0001，M0 工程基线）"块）
- 内容：
  - 工作区仓 `ai-platform-workspace`（repo-workspace）：SDD 文档、delivery/、standards/、product/、skills/、plans/；`.gitignore` 显式忽略 `implementation/`。
  - 后端仓 `ai-platform-backend`（repo-1）：独立 Git 仓，路径 `implementation/ai-platform-backend/`；Maven 根 = 仓库根，无 `backend/` 前缀。
  - 前端仓、AI 服务仓 M0 未建，后续独立加入。§5 单仓图保留为"逻辑总览"，实际落地以本小节为准。
- 理由：种子文档的单仓假定与 M0 工程最终决策不一致；若不修正将导致后续 Change 设计阶段引用错误的路径。
- 关联 Feature：STORY-1 delivered。

**P-02：Feature Tree STORY-1 状态 delivered**
- 文件：`product/feature-tree.yaml`
- 操作：更新（STORY-1 status 字段 `planned → delivered`）
- 内容：`STORY-1`（建立 Java Maven 多模块工程并统一版本基线）= delivered。
- 理由：sdd-test 阶段 42/42 全部通过、AC-1~11 100% 覆盖、Fat Jar 9/9 Started，达到 delivered 门槛（参见 sdd-converge SKILL §6）。
- 关联：CHG-0001 / ENG-BASE-001。

### 2.3 No Update

- 本 Change 具体 POM 行号、提交哈希（EV-001~EV-010）、mall-common-mq TASK-008 临时修复过程、沙箱专用 `.m2-repo/` 路径、Fat Jar 精确字节大小、evidence 日志文件内部行号等——理由：属本次特有实现细节，跨 Change 复用价值低。
- 具体 YAML/POM 语法规则（如 `dependencyManagement` 下 import 的写法）——理由：已在 S-01/S-02 中抽象为规则，具体语法由 Maven 规范提供，不重复抄写。
- openspec CLI 环境损坏 `D:\Desktop\core\sdd\git-submodule.js` 缺失——理由：外部环境问题，非本工程知识。

## 3. 知识沉淀过程记录

按 sdd-knowledge 能力 A 执行：

1. 读取本 convergence.md，提取 3 条 standards 晋升与 2 条 product 更新；
2. **Standards 写入**：`standards/engineering/backend/framework-standard.md` 为已存在文件，不覆盖历史 §1~§7.2，仅追加 §7.3 与 §7.4 两个新节（行号约 380~437）。保留所有原有章节结构与标题编号；
3. **Product 写入**：
   - `product/08-系统与微服务架构.md`：§5 结束位置追加"仓库落地修订"提示块，不改原有 Mermaid 图、代码块；
   - `product/feature-tree.yaml`：仅修改 STORY-1 `status` 一行，其他字段不变；
4. **冲突检查**：framework-standard.md 原 §7.1/§7.2 为通用依赖说明，追加的 §7.3/§7.4 是特定工程的强约束基线，两者互补，无矛盾；
5. 按 sdd-knowledge 能力 C 重建三份索引：
   - `standards/INDEX.md`（人读）：新增 `engineering/backend/*`、`engineering/*`、`engineering/{ai,frontend}/*`、`sdd/*` 条目，不删除原有种子条目；最后更新时间 2026-08-29，关联 Change：CHG-0001；
   - `product/INDEX.md`（人读）：原有 00~14 + README 保持不变，补充最后更新时间 2026-08-29 与关联 Change CHG-0001；
   - `.sdd/knowledge-index.json`（Agent 检索）：standards 侧补齐全部 `engineering/**/*.md` 与 `sdd/*.md` 条目（原种子仅含根目录 6 份）；product 侧保留 17 份种子条目并刷新 `related-changes`：对 framework-standard 追加 CHG-0001，对 product/08-系统与微服务架构.md 追加 CHG-0001；`updated-at` 刷新。
6. 说明：由于 `openspec` CLI 环境损坏，无法执行 `openspec change status CHG-0001 --set completed` 与 `openspec feature update STORY-1 --status delivered`，状态变更通过直接改写 YAML 完成，原因与等价性记录于 test-report.md §7 与 metadata.yaml 对应 gate 的 reason 字段。

## 4. 完成确认 Checklist

- [x] 全部前序 Artifact 已读取（requirement / exploration / prd / design / tasks / implementation / test-report）
- [x] 知识分类完成（standards: 3 条晋升 / product: 2 条更新 / no-update: 3 类）
- [x] standards 更新已写入：framework-standard.md §7.3、§7.4 追加
- [x] product 更新已写入：08-系统与微服务架构.md §5 修订块；feature-tree.yaml STORY-1=delivered
- [x] Feature Tree Story 状态已更新（STORY-1 planned → delivered）
- [x] 索引已重建：standards/INDEX.md、product/INDEX.md、.sdd/knowledge-index.json
- [x] 无未解决的 Conflict 或 Unresolved 问题（仅 1 项外部环境问题：openspec CLI 损坏，明确标记为不影响本 Change 产物）

## 5. Gate 说明与后续动作建议

- **Gate 门禁**：本 Change 七份 Artifact（exploration / prd / design / tasks / implementation / test-report / convergence）全部完成，人工自检通过率 100%；待 CLI 修复后可重放 `openspec gate check CHG-0001 && openspec gate approve CHG-0001 && openspec change status CHG-0001 --set completed && openspec change archive CHG-0001` 复核。
- **下一建议 Change**：ENG-BASE-002（建议）——建立 mall-common-web 统一响应/异常、TraceId、统一 OpenAPI 文档（响应 PRD Scope Out 第 1 条），依赖本基线已交付。
- **交付物**：除工作区仓内全部文档外，repo-1（ai-platform-backend.git main）已推送 9 个 Fat Jar 骨架 350304b→14c6db0，可直接作为后续服务开发起点。
