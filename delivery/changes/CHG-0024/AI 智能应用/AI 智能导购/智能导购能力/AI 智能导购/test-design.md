# Test Design（TC 测试用例设计）— STORY-008-01-01 AI 智能导购

## 0. 元信息

- Change ID: CHG-0024
- design 来源: delivery/changes/CHG-0024/requirement-design.md + stories/STORY-008-01-01/story-design.md
- feature-path: FEAT-008 > FEAT-008-01 > FEAT-008-01-01 > STORY-008-01-01
- TC 总数: 10（覆盖 AC-001~013 全部）

## 1. TC 测试用例表

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | Unit/集成（pytest，mock provider） | AC-001, AC-002 | DU-AI-001 | 约束提取→Tool 入参映射断言；recommendations 结构完整 |
| TC-002 | Unit（pytest） | AC-003 | DU-AI-001 | 缺预算+场景→clarifyingQuestion 且不调 search；充分→直接 search |
| TC-003 | Unit（pytest） | AC-004, AC-005 | DU-AI-001 | 真实商品约束：推荐 ID ⊆ Tool 返回；诱导不存在的商品不出现 |
| TC-004 | Unit（pytest） | AC-006, AC-007 | DU-AI-001 | 价格逐条一致；reason 引用真实属性字段 |
| TC-005 | Unit（pytest） | AC-009 | DU-AI-001 | 会话第二轮"第二台再详细说说"命中上轮候选 |
| TC-006 | Unit（pytest，httpx mock 故障注入） | AC-010 | DU-AI-001 | mall-search 5xx→mall-product 兜底；均败→502 文案 |
| TC-007 | 静态架构断言（配置扫描+代码审查） | AC-011 | DU-AI-001 | 无 Java 库连接串；商品数据仅经 java client |
| TC-008 | 回归合集（pytest + ruff） | AC-013 | DU-AI-001 | TC-001~007 全绿 + ruff 通过 |
| TC-009 | 切片测试（gateway 路由/安全 + pytest feature_gate） | AC-012 | DU-AI-001 | 开关关闭→403 fail-closed；网关路由/角色矩阵回归（DU-BE-001 侧） |
| TC-010 | 前端组件（mall-web vitest） | AC-008 | DU-FE-001 | AssistantView：输入→卡片/澄清态/错误态；conversationId 续轮 |

覆盖核对：AC-001~013 每条至少 1 个 TC（AC-008→TC-010、AC-012→TC-009、其余→TC-001~008）；无 TC-NOT-TESTABLE 项。

## 2. 测试策略

- **分层**：ai-service pytest 单测为主（provider/tool/workflow/会话/开关分层可注入，mock LLM 与 httpx 保证确定性）；mall-gateway 路由/安全切片测试回归；mall-web vitest 组件级；跨服务运行态串联留 Integration Gate（M6 七场景收尾实测）。
- **数据准备**：pytest fixture 固定商品候选集（3 个笔记本商品含价格/属性）；mock provider 确定性回复；httpx MockTransport 注入 mall-search/mall-product 成功/失败响应；Redis 会话用 fakeredis 或 fixture 清理。
- **环境要求**：uv run pytest（ai-service）；mall-gateway Maven 切片测试（H2 不涉及）；pnpm vitest（mall-web）；不依赖真实 ES/MinIO/LLM key。

## 3. DU 覆盖矩阵

| DU | verifies TC | covers AC |
| --- | --- | --- |
| DU-BE-001 | TC-009（网关部分） | AC-012 |
| DU-AI-001 | TC-001~009 | AC-001~007, AC-009~013 |
| DU-FE-001 | TC-010 | AC-008, AC-012 |
