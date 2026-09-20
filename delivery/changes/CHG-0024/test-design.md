# Test Design（Change 级聚合）— CHG-0024 M6 AI 智能应用

> 阶段：sdd-task 聚合产物（4 Story Change）；各 Story 校验细节见对应目录 test-design.md，本文件只引用不复制。

- Change ID: CHG-0024
- 覆盖 Story：S1 智能导购 10 TC、S2 商品对比 9 TC、S3 RAG 客服与知识库 9 TC、S4 订单助手 9 TC、S5 横切 3 TC，共 40 TC；另含 M6 Integration Gate 七场景。
- 覆盖核对：AC-001~040 每条至少 1 个 TC，无 TC-NOT-TESTABLE 项。

## 1. 测试用例

### S1 AI 智能导购（DU-BE-001 / DU-AI-001 / DU-FE-001）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| TC-001 | pytest mock provider：约束提取→Tool 入参映射、recommendations 五元组 | AC-001, AC-002 |
| TC-002 | pytest：信息不足 clarifyingQuestion 不搜索；充分直接 search | AC-003 |
| TC-003 | pytest：推荐 ID ⊆ Tool 返回；诱导不存在商品不出现 | AC-004, AC-005 |
| TC-004 | pytest：价格逐条一致；reason 引用真实属性 | AC-006, AC-007 |
| TC-005 | pytest：会话第二轮命中上轮候选 | AC-009 |
| TC-006 | pytest httpx 故障注入：ES 败→product 兜底；均败→502 | AC-010 |
| TC-007 | 静态架构断言：无业务库连接串 | AC-011 |
| TC-008 | pytest + ruff 回归合集 | AC-013 |
| TC-009 | 网关切片 + feature_gate：开关 false→403 fail-closed | AC-012 |
| TC-010 | mall-web vitest：AssistantView 卡片/澄清/错误/续轮 | AC-008 |

### S2 AI 商品对比（DU-AI-002 / DU-FE-002）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| TC-201 | pytest JavaMock：每个 productId 均经 get_products_detail | AC-015 |
| TC-202 | pytest：对比结构完整、values 键=productId | AC-014 |
| TC-203 | pytest：同类维度集合理；异类不强求统一 Schema | AC-016 |
| TC-204 | pytest：缺属性 → "暂无该项数据" | AC-017 |
| TC-205 | pytest：价格/库存逐格 == Tool 值 | AC-018 |
| TC-206 | pytest：总结引用真实属性 | AC-019 |
| TC-207 | pytest 配置扫描 + ruff：无 Product DB 连接串 | AC-021 |
| TC-208 | pytest：<2/>6/重复/无效 id → 400 | AC-014 |
| TC-209 | mall-web vitest：CompareView 5 例 | AC-020 |

### S3 RAG 智能客服与知识库（DU-INFRA-001 / DU-AI-003 / DU-FE-003）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| TC-301 | compose config + mall-admin vitest：上传校验、状态徽标 | AC-022 |
| TC-302 | pytest：PENDING→COMPLETED、chunkCount>0 | AC-023 |
| TC-303 | pytest mock embedding：命中回答 + sources[] | AC-024 |
| TC-304 | pytest：阈值下固定兜底、sources=[] | AC-025 |
| TC-305 | pytest：rebuild/delete 后投影失效 | AC-026 |
| TC-306 | pytest：文档注入三层防护断言 | AC-027 |
| TC-307 | pytest feature_gate + 鉴权：false→403，ADMIN 放行 | AC-029 |
| TC-308 | pytest + ruff：RAG 全绿 | AC-029 |
| TC-309 | mall-web vitest：SupportView 6 例 | AC-028 |

### S4 AI 订单助手（DU-AI-004 / DU-FE-004）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| TC-401 | pytest：Bearer 透传 + 真实列表 | AC-030 |
| TC-402 | pytest：PENDING_PAYMENT 状态映射 | AC-031 |
| TC-403 | pytest 多步：商品识别→详情→SHIPPED | AC-032 |
| TC-404 | pytest：字段 == Tool；PAID 诱导硬条款 | AC-033 |
| TC-405 | pytest：参数无 memberId；DENY→404 | AC-034 |
| TC-406 | pytest 确认流状态机：pending/confirm/409 分支 | AC-035 |
| TC-407 | pytest：重复消费 409 + 审计字段 | AC-036 |
| TC-408 | pytest + ruff：开关 fail-closed、全绿 | AC-037 |
| TC-409 | mall-web vitest：OrderAssistantView 7 例 | AC-030, AC-035 |

### S5 AI 横切（跨 Story）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| TC-501 | 静态断言 + pytest：出站 Java 调用 X-Trace-Id == 入站 traceId；错误信封回传 traceId | AC-038 |
| TC-502 | pytest mock 故障：LLM 不可用时四入口返回错误信封 + 用户可读降级文案 | AC-039 |
| TC-503 | pytest：redact_secrets 模式用例 + Prompt 拼接前过滤断言 | AC-040 |

## 2. M6 Integration Gate（Change 级场景）

七场景：① 自然语言导购、② 商品对比、③ RAG 客服、④ 订单查询、⑤ 订单越权 DENY、⑥ AI 取消订单（二次确认）、⑦ Prompt Injection 越权防护。单测/切片已出证，真实多服务运行态串联在联调环境执行。

## 3. 测试策略

- 分层：ai-service pytest（mock provider + JavaMock/httpx + 语义同构 stub，无外部中间件依赖）；网关 Maven 切片；mall-web/mall-admin vitest 组件级。
- 环境：uv run pytest / pnpm vitest / mvn -pl mall-gateway test；不依赖真实 LLM key、ES、MinIO、Java 运行态。
