# Review Report — RAG 智能客服与知识库 STORY-008-03-01

## 0. 元信息

- Change ID：CHG-0024（M6 AI 智能应用）
- Story：STORY-008-03-01
- 评审日期：2026-09-20
- 评审人：trae-agent（本机自审 + 机 gate）
- 评审对象：repo-4 cf5c18c、repo-3 e2734f9、repo-2 f2fd7ca（DU-FE-003 部分）；Story 全量产物
- 验证依据：compose config 合法；ai-service pytest 81（含 RAG 22）；mall-admin vitest 114（含 knowledge 9）；mall-web vitest 129（含 SupportView 6）；ruff/vue-tsc/eslint/build 全过

## 1. 检查结论

通过（approved）。四查均无阻断项，AC-022~029 全部有自动化证据；知识投影一致性与注入三层防护有对应用例。

| 维度 | 结论 |
| --- | --- |
| 需求一致性 | 通过：AC-022~029 逐条映射，四状态/兜底/新会话语义落地 |
| 设计一致性 | 通过：upload→PENDING→process→COMPLETED/FAILED 管道、rebuild/delete/启动对账、引用回答结构与 story-design 一致 |
| 跨仓适用性 | 通过：compose ai-service 容器依赖四中间件 health；DDL ai_service 库 + ai_action_audit；前端成功直出不 unwrap |
| 代码质量 | 通过：pytest/ruff 全绿；KnowledgeListView/SupportView 无 v-html；MinIO/ES/MySQL client 边界清晰 |
| 安全 | 通过：知识管理强制 ADMIN + ai:knowledge:* 码（见 DEV-1）；注入用例三层防护；Secret 双向脱敏；开关 fail-closed |

## 2. 发现清单

### DEV-1（实施期偏差，已评审通过）：权限码对齐 V12 种子

- 现象：story-design 早期稿写 knowledge:doc:* 权限码，实施时 V12 种子实际落码为 ai:knowledge:list/upload/update/delete/rebuild。
- 处置：前端按钮/接口权限码统一按 V12 实际值，DU implementation.md 已记录偏差。
- 评审结论：以唯一真实权限来源（迁移脚本）为准，属必要对齐非范围变更；五码粒度与五端点一一对应；证据闭环。
- 定级：approved-with-note，无需返工。

### F-02（观察项，不阻断）

- ES kNN 真实召回质量（topK/score 阈值默认值）留联调样例实测；测试以语义同构 stub 出证。
- mall-admin 无 DOM 挂载环境，KnowledgeListView 以源码契约 + 校验纯函数出证。

### 红线核对

- 未手改 `.sdd/`；状态全部经 openspec gate/workflow 推进。
- 本地提交未 push（当前授权范围）。
- 未把实现细节写入 standards/。

## 3. 完成确认

- [x] AC-022 知识文档上传（.md/.txt、≤5MB）落 MinIO + 四状态列表
- [x] AC-023 Parser→Chunking→Embedding→Vector 全链路与元数据
- [x] AC-024 命中回答基于召回 Chunk 且附 sources[]
- [x] AC-025 低置信兜底、不编造
- [x] AC-026 rebuild/delete 后知识投影失效
- [x] AC-027 注入三层防护与 Secret 脱敏
- [x] AC-028 SupportView 问答/引用/新会话
- [x] AC-029 开关 fail-closed + RAG 测试门禁
- [x] 遗留项均归 C 类 Integration Gate，无代码缺口

Story 可判 completed。
