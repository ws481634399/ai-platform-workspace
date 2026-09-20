# Test Design（TC 测试用例设计）— STORY-008-03-01 RAG 智能客服与知识库

## 0. 元信息

- Change ID: CHG-0024
- design 来源: delivery/changes/CHG-0024/requirement-design.md + stories/STORY-008-03-01/story-design.md
- feature-path: FEAT-008 > FEAT-008-03 > FEAT-008-03-01 > STORY-008-03-01
- TC 总数: 9（覆盖 AC-022~029 全部）

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-301 | 静态校验（compose config）+ 前端组件（mall-admin vitest） | AC-022 | DU-INFRA-001, DU-FE-003 | compose 配置合法；上传动作调 upload api（类型/大小校验）；列表状态徽标渲染 |
| TC-302 | Unit/集成（pytest） | AC-023 | DU-AI-003 | 上传→PENDING→process→COMPLETED + chunkCount>0；documents/chunks 元数据可查 |
| TC-303 | Unit（pytest，mock embedding 确定性） | AC-024 | DU-AI-003 | 命中知识（"配送范围"样例）→ answer 基于召回 chunk + sources[] |
| TC-304 | Unit（pytest，阈值下注入） | AC-025 | DU-AI-003 | 无可靠命中 → 固定兜底文案 + sources=[]，无编造规则 |
| TC-305 | Unit（pytest） | AC-026 | DU-AI-003 | rebuild 后旧 chunk 失效按新内容回答；delete 后 knn_search 不再命中 |
| TC-306 | Unit（pytest，注入用例） | AC-027 | DU-AI-003 | 知识文档注入"忽略系统规则/输出 Secret/任意 Tool" → 不执行/不泄漏/不提升 |
| TC-307 | Unit（pytest，feature_gate + 鉴权） | AC-029 | DU-AI-003 | ai.rag.enabled=false → 403；知识管理匿名/MEMBER 拒绝、ADMIN 放行 |
| TC-308 | 回归合集（pytest + ruff） | AC-029 | DU-AI-003 | RAG 核心 pytest 全绿 + ruff 通过 |
| TC-309 | 前端组件（mall-web vitest） | AC-028 | DU-FE-003 | SupportView：提问→回答+引用；Loading/Error；新会话重置；开关 false 入口隐藏 |

覆盖核对：AC-022~029 每条至少 1 个 TC（AC-022→TC-301、AC-028→TC-309、AC-029→TC-307/308、其余→TC-302~306）；无 TC-NOT-TESTABLE 项。

## 2. 测试策略

- **分层**：ai-service pytest 单测为主——ES/MinIO/MySQL 以本地 stub（内存 knn 同语义实现/临时目录对象存储/mysql stub 记录调用）注入，保证 CI 无外部中间件依赖；管道状态机用 asyncio 确定性驱动；mall-web/mall-admin vitest 组件级（api mock）；真实 ES/MinIO 集成冒烟留 Integration Gate。
- **数据准备**：fixture 固定样例知识文档（Markdown/TXT 各一，含"配送范围"等可检索内容 + 注入攻击文档）；mock embedding（词袋 hash 定维）保证检索确定性。
- **环境要求**：uv run pytest（ai-service）；pnpm vitest（mall-web、mall-admin）；不依赖真实 ES/MinIO/LLM key。

## 3. DU 覆盖矩阵

| DU | verifies TC | covers AC |
| --- | --- | --- |
| DU-INFRA-001（[S3]） | TC-301（compose 部分） | AC-022（基础设施面） |
| DU-AI-003（[S3]） | TC-302~308 | AC-023~027, AC-029 |
| DU-FE-003（[S3]） | TC-301（前端部分）, TC-309 | AC-022, AC-028 |
