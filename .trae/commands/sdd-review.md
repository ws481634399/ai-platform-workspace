---
description: 评审检查点 Skill——需求一致性 / 设计一致性 / 代码质量 / 知识同步四项检查
---
对 Change `$ARGUMENTS` 执行 OpenSpec SDD **review** 阶段。

## 执行步骤
1. 运行 `openspec workflow run --change $ARGUMENTS --stage review` 获取 Instruction。
   - 若 `$ARGUMENTS` 为空或不是 CHG-ID，先向用户询问 Change ID。
   - 若返回等待/报错状态，如实向用户转述，不要自行绕过。
2. 严格按照 Instruction 中的 Prompt 片段与 `skills/sdd-review/SKILL.md` 方法论执行。
3. 将产物写入 Instruction 指定的 Artifact 路径（写回 Change 目录）。
4. 运行 `openspec gate check $ARGUMENTS --stage review` 做机器检查；
   通过后提示用户执行 `openspec gate approve $ARGUMENTS --stage review`（人工评审）。

## 约束
- 不得跳过 Instruction/SKILL.md 自行发挥；不得直接修改 Change 生命周期状态。
- 产物只写入 Change 目录或 SKILL.md 指定位置，不触碰 standards/ product/ 等其他目录。

<!-- openspec-ide-commands: v0.4.0 skill:sdd-review -->
