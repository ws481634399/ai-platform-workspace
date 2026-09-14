# Exploration（需求探索报告）

> 阶段：sdd-fast-plan 产物

## 1. 需求要点

- 对象：后台商品管理员、内部服务消费方与 M3 将使用的商城查询 API。
- 目标：修复“文档已完成但实际产品链路不完整”，使 M1/M2 验收标准与实现一致。
- 功能要点：网关暴露公开商城商品 API 和受信内部商品 API；后台完整维护 Product 图片、属性与 SKU；创建时至少一个 SKU 与 Product 同事务写入；库存内部变更接口仅允许 SERVICE 主体。
- 质量要点：错误登录不得触发 refresh；mall-admin lint/type-check/test/build 全部通过。
- 明确排除：手机端与 mall-web 真实商城页面。

知识检索命中 `product/06-聚合与领域模型设计.md`、`product/08-系统与微服务架构.md`、`product/11-权限与功能配置.md`、`standards/security-guidelines.md`、`standards/engineering/frontend/coding-standard.md`。

## 2. Story 归属判定

- Feature ID：FEAT-002-02-01。
- Story：STORY-002-02-01-01（商品 SPU 管理），复用已有 Story 承载验收缺口修复。
- Feature 路径：商品与库存 → 商品与 SKU 管理 → 商品主数据 → 商品 SPU 管理。
- Candidate：否。

## 3. 证据评估

- 业务证据：`docs/需求/M1/需求M1.md`、`docs/需求/M2/M2.md` 以及 CHG-0011～0013 的 AC 已明确范围。
- 缺口证据：实时网关请求、浏览器页面检查、ESLint 及模块测试结果。
- 结论：充分，无需新增业务能力，仅使已确认 AC 真实可用。

## 4. 冲突点检测

- 与 M3 冲突：已解决。M2 只提供商城查询 API，mall-web 页面保留到 M3。
- 与已完成 Change 重叠：修复基于 CHG-0009、CHG-0011、CHG-0012、CHG-0013，不修改其历史状态，以 CHG-0014 记录增量证据。
- 与领域边界冲突：无。Product 不保存库存数量，Inventory 仍只识别 skuId。

## 5. 待澄清问题

- 无阻断问题。
- 内部接口本次使用现有 JWT `subject_type=SERVICE` 作为信任边界，不引入新的 API Key 或 mTLS。

