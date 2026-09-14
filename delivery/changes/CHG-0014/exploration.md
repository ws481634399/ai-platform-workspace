# Exploration（需求探索报告）

## 1. 需求要点

- 修复 M1/M2 “文档已完成、实际链路不完整”的验收缺口。
- 关闭 Product/SKU/图片/属性创建事务、Gateway 路由、Inventory 内部授权、mall-admin 表单和质量门链路。
- 明确排除手机端与 M3 mall-web 商城页面。
- 历史知识：`product/06-聚合与领域模型设计.md`、`product/11-权限与功能配置.md`、`standards/security-guidelines.md`。

## 2. Story 归属判定

- 复用 STORY-002-02-01-01（商品 SPU 管理）。
- 路径：FEAT-002 → FEAT-002-02 → FEAT-002-02-01 → STORY-002-02-01-01。
- Candidate：否。

## 3. 证据评估

- 证据来源：M1/M2 需求、CHG-0011～0013 AC、实时网关/浏览器检查和质量门结果。
- 结论：充分。

## 4. 冲突点检测

- 与 M3 边界冲突已解决：M2 交付 API，不交付 mall-web 页面。
- 与已完成 Change 重叠通过 CHG-0014 增量修复，不改写历史状态。
- 与 Product/Inventory 领域边界无冲突。

## 5. 待澄清问题

- 无阻断问题；内部库存授权复用 M1 `subject_type=SERVICE` JWT。

