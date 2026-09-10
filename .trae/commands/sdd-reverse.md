---
description: Knowledge Reverse 骨架——扫描 implementation/ 代码树，生成 Agent 执行指令，指导知识提取
---
执行 OpenSpec Skill **sdd-reverse**（Knowledge Reverse 骨架——扫描 implementation/ 代码树，生成 Agent 执行指令，指导知识提取）。

## 执行步骤
1. 阅读 `skills/sdd-reverse/SKILL.md` 并严格按其方法论执行。
2. 若该 Skill 需要 Change/Story 上下文而用户未提供，先向用户询问。
3. 将产出写回 SKILL.md 指定位置（Knowledge 类写回 knowledge/ 目录）。

## 约束
- 不得跳过 Instruction/SKILL.md 自行发挥；不得直接修改 Change 生命周期状态。
- 产物只写入 Change 目录或 SKILL.md 指定位置，不触碰 standards/ product/ 等其他目录。

<!-- openspec-ide-commands: v0.4.0 skill:sdd-reverse -->
