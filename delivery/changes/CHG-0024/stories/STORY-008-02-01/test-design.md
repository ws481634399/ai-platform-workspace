# Test Design（TC 测试用例设计）— STORY-008-02-01 AI 商品对比

## 0. 元信息

- Change ID: CHG-0024
- design 来源: delivery/changes/CHG-0024/requirement-design.md + stories/STORY-008-02-01/story-design.md
- feature-path: FEAT-008 > FEAT-008-02 > FEAT-008-02-01 > STORY-008-02-01
- TC 总数: 9（覆盖 AC-014~021 全部）

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-201 | Unit（pytest，JavaMock 断言调用面） | AC-015 | DU-AI-002 | 每个 productId 均经 get_products_detail 获取实时详情；无纯名称对比路径 |
| TC-202 | Unit/集成（pytest） | AC-014 | DU-AI-002 | 2 商品 → comparisonDimensions/products/summary 结构完整；values 键=productId |
| TC-203 | Unit（pytest） | AC-016 | DU-AI-002 | 同类（两台电脑）维度含 CPU/RAM/存储/GPU/屏幕/重量/价格；异类不强求统一 Schema |
| TC-204 | Unit（pytest） | AC-017 | DU-AI-002 | Tool 未返回属性 → 表格"暂无该项数据"，无推测值 |
| TC-205 | Unit（pytest） | AC-018 | DU-AI-002 | 价格/库存状态 == Tool 返回原值（逐格断言） |
| TC-206 | Unit（pytest，mock LLM 硬约束） | AC-019 | DU-AI-002 | 场景问题总结引用真实属性；无不依据的"A 最好" |
| TC-207 | 回归合集 + 静态架构断言（pytest + ruff + 配置扫描） | AC-021 | DU-AI-002 | 对比核心 pytest 全绿 + ruff；无 Product DB 连接串（仅经 java client） |
| TC-208 | Unit（pytest 边界） | AC-014 | DU-AI-002 | productIds <2/重复/含无效 id → 400；上限 6 |
| TC-209 | 前端组件（mall-web vitest） | AC-020 | DU-FE-002 | CompareView：选择商品→表格+缺失占位+总结；错误态重试；开关 false 入口隐藏 |

覆盖核对：AC-014~021 每条至少 1 个 TC（AC-020→TC-209、AC-021→TC-207、其余→TC-201~208）；无 TC-NOT-TESTABLE 项。

## 2. 测试策略

- **分层**：ai-service pytest 单测为主（复用 tests/helpers.py 的 JavaMock/StubLLM/shopping_test_env 注入；批量详情用 asyncio.gather 确定性）；mall-web vitest 组件级；运行态串联留 Integration Gate。
- **数据准备**：fixture 固定 2~3 个商品详情（含规格属性差异与缺失属性场景）；JavaMock 模拟 /api/mall/products/{id} 成功/404/5xx；mock provider 确定性维度选择与总结。
- **环境要求**：uv run pytest（ai-service）；pnpm vitest（mall-web）；不依赖真实 LLM key。

## 3. DU 覆盖矩阵

| DU | verifies TC | covers AC |
| --- | --- | --- |
| DU-AI-002（[S2]） | TC-201~208 | AC-014~019, AC-021 |
| DU-FE-002（[S2]） | TC-209 | AC-020 |
