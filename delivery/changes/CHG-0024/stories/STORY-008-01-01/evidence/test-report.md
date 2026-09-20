# Test Report — AI 智能导购 STORY-008-01-01

## 0. 元信息

- Change ID：CHG-0024（M6 AI 智能应用）
- Story：STORY-008-01-01
- 日期：2026-09-20
- 证据：workspace evidence.yaml EV-001（repo-1 eab992d）、EV-002（repo-3 bc984bc）、EV-003（repo-2 5dd4508）；
  story evidence.yaml EV-101（repo-3 全量回归日志）、EV-102（mall-web 全量回归日志）

## 1. 测试范围

- repo-1 mall-gateway：/api/ai/** 路由至 ai-service:8120、三端点 permitAll/会员/管理员矩阵、V12 知识库权限种子（切片+契约测试 7 例）。
- repo-3 ai-service：导购 Workflow 五节点链与 enforce_grounding、Tool 注册表/搜索降级、JWT 解析、Redis 会话、FeatureGate fail-closed、推荐端点契约。
- repo-2 mall-web：AssistantView 对话/澄清/推荐卡片/错误重试/403 空态、conversationId 续轮。

## 2. 测试执行汇总

| 套件 | 命令 | 结果 | 用例数 |
| --- | --- | --- | --- |
| mall-gateway（mvn 切片，DU-BE-001 交付时） | `mvn -pl mall-gateway test` | passed | 7（新增） |
| ai-service（pytest 全量回归） | `uv run pytest tests/ -q` | passed | 81（含导购 28） |
| ai-service（ruff，DU 交付时） | `uv run ruff check app tests` | clean | — |
| mall-web（vitest 全量回归） | `pnpm vitest run` | passed，26 文件全过 | 129（含 AssistantView 6） |

## 3. AC 覆盖

| AC | 自动化证据 | 结果 |
| --- | --- | --- |
| AC-001、AC-002 | TC-001（约束提取→Tool 入参映射；recommendations 五元组结构） | passed |
| AC-003 | TC-002（信息不足→clarifyingQuestion 且不调 search；充分→直接 search） | passed |
| AC-004、AC-005 | TC-003（推荐 ID ⊆ Tool 返回；诱导不存在商品不出现） | passed |
| AC-006、AC-007 | TC-004（价格逐条一致；reason 引用真实属性） | passed |
| AC-008 | TC-010（AssistantView 6 例：卡片/澄清/续轮/403/502 重试/Loading） | passed |
| AC-009 | TC-005（第二轮命中上轮候选） | passed |
| AC-010 | TC-006（search 5xx → product 兜底；均败 → 502） | passed |
| AC-011 | TC-007（架构扫描：无 Java 业务库连接串，商品数据仅经 java client） | passed |
| AC-012 | TC-009（开关 false → 403 fail-closed；网关路由/角色矩阵 7 例回归） | passed |
| AC-013 | TC-008（导购核心 pytest 全绿 + ruff） | passed |

## 4. 缺口备注

- 真实 mall-search/mall-product 端到端（经网关 8080）属 C 类 Integration Gate：单测以 httpx mock 出证，联调环境串一次真实推荐链路。
- 网关 7 例为切片/契约级测试（Spring WebTestClient），未起真实 ai-service，符合最小依赖原则。
