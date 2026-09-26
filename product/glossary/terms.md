---
title: 统一语言词汇表
tags: [glossary, ai, distributed]
related-changes: [CHG-0024, CHG-0025]
created-at: 2026-09-20T23:05:00+08:00
updated-at: 2026-09-26T10:00:00+08:00
---

# 统一语言词汇表

> 团队对同一概念的叫法与含义以此为准。本批为 M6 AI 领域首批条目，后续里程碑合并追加。

## AI 基础概念

| 术语 | 英文/别名 | 含义 |
| --- | --- | --- |
| 检索增强生成 | RAG（Retrieval-Augmented Generation） | 先从知识库检索相关内容，再连同用户问题交给 LLM 生成回答的技术模式 |
| 接地 | Grounding | LLM 的回答必须基于可溯源的真实数据（Tool 返回/召回内容），不得凭模型记忆编造 |
| 提示词注入 | Prompt Injection | 用户在输入中嵌入"忽略系统规则/提升权限/泄露密钥"等指令，试图让 AI 越权的攻击方式 |
| 提示词 | Prompt | 发给 LLM 的完整指令文本，含角色、上下文、任务与约束 |
| 令牌 | Token | 本词汇两个含义按上下文区分：① LLM 处理文本的最小计量单位；② 身份/待确认动作的一次性凭证 |

## RAG 与知识库

| 术语 | 英文/别名 | 含义 |
| --- | --- | --- |
| 知识分块 | Chunk | 知识文档经 Parser 切分后形成的最小检索单元 |
| 向量嵌入 | Embedding | 将文本映射为高维向量，用于语义相似度计算 |
| 向量近邻检索 | kNN（k-Nearest Neighbors） | 在向量库中检索与查询向量最相似的 k 个 Chunk；本平台用 Elasticsearch kNN |
| 引用来源 | sources | RAG 回答附带的知识出处（documentId/title/snippet），供用户核对 |
| 知识投影 | Knowledge Projection | 向量库中由原始知识文档派生的 Chunk/Embedding；原始事实以 MinIO 文件 + 元数据为准，投影须随重建/删除失效 |

## Agent 与工具

| 术语 | 英文/别名 | 含义 |
| --- | --- | --- |
| 智能体 | Agent | 模型能力 + 任务流程 + 工具 + 知识上下文 + 结果验证组成的智能执行单元 |
| 工具调用 | Tool Calling / Function Calling | LLM 按 Schema 请求外部 Tool（商品/订单/检索能力）并以返回结果作答 |
| 待确认动作 | pendingAction | 写操作意图生成的、等待用户二次确认的待执行动作；凭一次性 actionId 消费，绑定本人且有 TTL |
| 失败即拒绝 | fail-closed | 开关关闭或配置读取失败时默认拒绝请求；AI 能力统一采用此策略（对应主交易参数消费的 fail-open） |

## 分布式消息与一致性（M7）

| 术语 | 英文/别名 | 含义 |
| --- | --- | --- |
| 事件信封 | Envelope | 事件统一外壳：eventId/eventType/eventVersion/occurredAt/producer/traceId/payload 七字段；业务内容只放 payload |
| 发件箱模式 | Outbox Pattern | 业务事务内同库写事件行，提交后由独立投递任务异步发送消息，保证「业务落库」与「消息发出」原子一致 |
| 消费幂等表 | consumed_event | 消费方库内以 (event_id, consumer_group) 唯一键占位的表；重复消息命中占位直接跳过，业务不重复执行 |
| 死信队列 | DLQ（Dead Letter Queue） | 消息重试超限后转入的队列；本平台由补偿任务接管死信，人工可查询/重试，不静默丢弃 |
| 延迟消息 | Delay Message | 由 Broker 计时、到期后才投递的消息；M7 用于替代订单超时的全表定时扫描 |
| 有界退避 | Bounded Backoff | 失败后按递增间隔（30s/1m/2m/5m/10m）重试、次数封顶（5 次），超限转人工的策略 |
| 人工标记完成 | Manual Complete | 人工确认业务已闭环后将补偿任务直接置 SUCCESS 的动作；原错误信息保留并追加 MANUAL_COMPLETE 标记，全程审计 |
