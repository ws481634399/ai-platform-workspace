# Test Report — RAG 智能客服与知识库 STORY-008-03-01

## 0. 元信息

- Change ID：CHG-0024（M6 AI 智能应用）
- Story：STORY-008-03-01
- 日期：2026-09-20
- 证据：workspace evidence.yaml EV-004（repo-4 cf5c18c）、EV-006（repo-3 e2734f9）、EV-008（repo-2 f2fd7ca）；
  repo-3 DU-AI-003/evidence/logs（pytest.txt、ruff-check.txt）；
  repo-2 DU-FE-003/evidence/logs（mall-admin/mall-web 四件套日志）

## 1. 测试范围

- repo-4：docker-compose ai-service 容器定义、.env.example AI 键段、MySQL ai_service 库 + ai_action_audit DDL。
- repo-3：Embedding factory（mock/openai）、MinIO/ES kNN/MySQL client、知识管道（upload→PENDING→process→COMPLETED/FAILED、rebuild/delete/启动对账）、SupportAgent（兜底/引用/注入三层防护/Secret 脱敏）、support chat 与五端点；ruff。
- repo-2：mall-admin knowledge 五端点封装 + KnowledgeListView（四状态/上传校验/启停/删除确认/重建/轮询）；mall-web SupportView（问答/引用展开/兜底/新会话）；两工程 type-check/eslint/build。

## 2. 测试执行汇总

| 套件 | 命令 | 结果 | 用例数 |
| --- | --- | --- | --- |
| infrastructure | `docker compose -f deploy/docker-compose.infra.yml config` | passed（配置合法） | — |
| ai-service（pytest，STORY 交付时全量） | `uv run pytest tests/ -q` | passed | 65（含 RAG 22） |
| ai-service（ruff） | `uv run ruff check app tests` | clean | — |
| mall-admin（vitest） | `pnpm vitest run` | passed，28 文件全过 | 114（含 knowledge 9） |
| mall-web（vitest） | `pnpm vitest run` | passed，26 文件全过 | 129（含 SupportView 6） |
| 两工程 type-check/eslint/build | `pnpm type-check` / `eslint src` / `build` | passed / 0 error / passed | — |

## 3. AC 覆盖

| AC | 自动化证据 | 结果 |
| --- | --- | --- |
| AC-022 | TC-301（compose config + mall-admin KnowledgeListView 契约 5 例/上传 .md/.txt、大小非法拒绝/状态徽标） | passed |
| AC-023 | TC-302（上传 PENDING → process COMPLETED + chunkCount>0；元数据可查） | passed |
| AC-024 | TC-303（"配送范围"命中 → answer 基于召回 chunk + sources documentId/title/snippet） | passed |
| AC-025 | TC-304（低于阈值 → 固定兜底文案 + sources=[]，无编造） | passed |
| AC-026 | TC-305（rebuild 后旧 chunk 失效按新内容回答；delete 后 knn 不命中） | passed |
| AC-027 | TC-306（文档注入"忽略系统规则/输出 Secret/提升 Tool" → 不执行、不含 secret、无 Tool 提升） | passed |
| AC-028 | TC-309（SupportView 6 例：命中+引用、兜底、5xx 重试、403、新会话重置、loading） | passed |
| AC-029 | TC-307（开关 false → 403；匿名/MEMBER 拒绝、ADMIN 200）、TC-308（pytest+ruff 全绿） | passed |

## 4. 缺口备注

- ES kNN 与 MinIO 真实交互：测试以内存 stub/语义同构实现出证，真实 ES 8.17 kNN 召回质量（topK/score 阈值默认值）留联调样例文档实测确认，配置已固化默认。
- mall-admin 无 DOM 挂载环境，KnowledgeListView 以源码契约 + 校验纯函数出证，build 通过证明组件解析。
- PROCESSING 服务重启对账（复位 FAILED）由单测覆盖；真实重启场景属运维联调。
