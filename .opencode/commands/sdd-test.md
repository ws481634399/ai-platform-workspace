---
description: 独立测试验证 Skill——照 test-design TC 逐条执行，不读 implementation.md，产出 EVD 证据
---
对 Change `$ARGUMENTS` 执行 OpenSpec SDD **test** 阶段。

## 执行步骤
1. 运行 `openspec workflow run --change $ARGUMENTS --stage test` 获取 Instruction。
   - 若 `$ARGUMENTS` 为空或不是 CHG-ID，先向用户询问 Change ID。
   - 若返回等待/报错状态，如实向用户转述，不要自行绕过。
2. 严格按照 Instruction 中的 Prompt 片段与 `skills/sdd-test/SKILL.md` 方法论执行。
3. 将产物写入 Instruction 指定的 Artifact 路径（写回 Change 目录）。
4. 运行 `openspec gate check $ARGUMENTS --stage test` 做机器检查；
   通过后进入人工评审：向用户展示待审内容摘要，用户确认后运行 `openspec approve $ARGUMENTS --yes --reviewer <用户姓名>`
   一键完成 Human Gate 审批并自动续跑 workflow（免记 --stage/--story 参数；审计要求 --reviewer 必填）。

## DU 绑定（必须）
本阶段必须绑定 Delivery Unit：运行 `openspec du list` 确认 DU，
执行时追加 `--du <DU-ID>` 参数；未绑定直接运行会报错。

## 约束
- 不得跳过 Instruction/SKILL.md 自行发挥；不得直接修改 Change 生命周期状态。
- 产物只写入 Change 目录或 SKILL.md 指定位置，不触碰 standards/ product/ 等其他目录。

<!-- openspec-ide-commands: v0.4.0 skill:sdd-test -->
