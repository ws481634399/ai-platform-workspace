---
id: "REQ-M5-002"
name: "商品搜索索引同步"
content: "建立 Product 权威数据与 Elasticsearch Search Projection 之间的同步机制：代码化索引生命周期（Create/Rebuild/Replace）、首次全量构建、商品新增/修改/上架/下架/价格变化增量同步、同步幂等与乱序防护、失败记录与有界重试、手工重建与基础一致性检查；M5 用同步调用/应用事件/后台任务，不引入 RocketMQ/Outbox。"
source: requirement-doc
created-at: "2026-09-18T10:36:52.371Z"
---

# Requirement

> 原始需求全文归档于 `references/M5.md`（M5 三 REQ + Integration Gate 七场景 + DoD），本文件记录本 Change（REQ-M5-002）的输入边界。

## 需求描述

**阶段：** M5 搜索与系统配置
**类型：** 数据同步需求
**优先级：** P1
**前置依赖：** REQ-M2-003、REQ-M5-001
**主要服务：** mall-product、mall-search

### 一、需求目标

建立 Product 权威数据与 Elasticsearch Search Projection 之间的同步机制，确保：

```text
商品新增
商品修改
商品上架
商品下架
SKU/价格变化
```

能够合理反映到搜索索引。同时建立：单商品同步、批量同步、全量重建、失败记录、重试基础等能力。

### 二、索引生命周期

至少支持：

```text
Create Index
Rebuild Index
Delete / Replace Index
```

索引 Mapping 和 Settings 必须通过代码或部署配置管理，不能依赖开发人员手工进入 Elasticsearch Console 创建生产所需 Mapping。

### 三、首次全量索引

系统第一次启用 Elasticsearch 时，需要能够：

```text
Product DB
↓
读取所有合法上架商品
↓
构建 Search Document
↓
Bulk Index
↓
Elasticsearch
```

完成首次索引构建。

### 四、增量同步

商品发生变化后需要同步搜索索引，至少考虑：

```text
Product Created
Product Updated
Product Published
Product Unpublished
Price Changed
```

对应搜索数据更新。

### 五、上架同步

商品上架（Product Published）→ 建立/更新 Search Document，保证上架商品可以进入搜索结果。

### 六、下架同步

商品下架（Product Unpublished）→ 搜索索引删除或标记不可搜索，下架商品不得长期继续出现在正常商城搜索结果。具体采用 Delete Document 还是 `status = OFF_SALE` 由 Design 决定。

### 七、价格变化

SKU 价格变化后，搜索索引中用于列表展示的 `minPrice`、`maxPrice` 价格摘要需要同步更新。但：

```text
搜索价格 ≠ 订单可信成交价
```

订单仍然必须从 Product 服务重新获取实时价格。

### 八、同步幂等

相同商品同步请求重复执行时不应产生错误数据。例如 Product 1001 Published Event × 2，最终只能得到正确的一份最新 Search Document。

### 九、乱序更新

需要考虑旧商品更新晚于新商品更新到达 Search Service 的情况，应通过 version、updatedAt、eventVersion 等方式避免旧数据覆盖新数据，具体方案由 Design 决定。

### 十、同步失败

```text
Product 已更新
↓
Elasticsearch 暂时不可用
↓
Search Sync Failed
```

不能简单 log error 后永久丢失。M5 至少需要形成 Sync Failure Record + Retry 基础。

### 十一、手工重建能力

后台或运维需要具备 Rebuild Product Search Index 能力，用于：Elasticsearch 数据丢失、Mapping 升级、索引数据不一致、环境初始化。全量重建必须：可重复执行、有执行状态、能发现失败、不依赖手工逐条商品处理。

### 十二、索引一致性检查

需要具备基础检查能力，例如：Product 上架数量 vs Search Index 数量，或按 productId 检查是否存在明显数据缺失。M5 不要求建设完整数据治理平台，但必须具备基本排错方式。

### 十三、与 M7 的关系

M5 可以先使用同步调用、应用事件、后台任务等适合当前阶段的同步策略。M7 再将 Product Published/Updated/Unpublished 等重要跨服务同步升级为 RocketMQ + Outbox + 可靠消费。M5 不需要为了索引同步提前完成整个 M7。

### 十四、验收标准

- 可以创建搜索索引；
- 可以全量构建商品索引；
- 上架商品可以同步进入索引；
- 商品更新可以同步；
- 商品价格变化可以更新搜索摘要；
- 下架商品可以从正常搜索中消失；
- 重复同步保持幂等；
- 旧数据不会明显覆盖新版本；
- Elasticsearch 不可用时同步失败可追踪；
- 失败同步具备基础重试能力；
- 可以执行全量索引重建；
- 索引重建后搜索结果正确；
- 搜索同步测试通过。

### 十五、非本需求范围

- RocketMQ 最终可靠同步；
- Outbox；
- Dead Letter；
- AI Embedding；
- Vector Search。

这些属于 M7 / M6。

## 补充信息

- 优先级：P1；开发依赖顺序位于 CHG-0020（REQ-M5-001）搜索文档结构确定之后。
- 前置依赖：REQ-M2-003（商品权威数据与商城查询）、REQ-M5-001（搜索服务与 Search Document/Mapping 雏形）。
- 主要仓库：repo-1（backend：mall-search 索引管理/同步/重建/失败记录 + mall-product 变更触达与内部分页投影端点；mall-search 8107 / mall_search 库，mall-product 8103）、repo-2（frontend：mall-admin 重建触发/状态与一致性检查页面入口，复用既有后台 RBAC）、repo-4（infrastructure：Elasticsearch 运行环境随 CHG-0020 落地）。
- 技术约束：Java 21 + Spring Boot 3.5.x + Elasticsearch Java Client + MyBatis-Plus/Flyway（sync_failure_record 等自有表）+ Redis（可选调度协调）；M5 同步机制仅限同步调用 / Spring 应用事件 / @Scheduled 后台任务（单实例足够，M7 再升级 MQ+Outbox）；有界重试参照 CHG-0019 CompensationTask 既有模式；跨服务 Internal API 走 RestClient + X-Internal-Token，禁止 mall-search 直连 mall_product 库。
- 已知现状（explore 实测）：mall-product 内部 API 目前仅有单 SKU/批量 SKU 查询端点，尚无"分页读取全部上架商品投影"端点，本 Change 需在 mall-product 新增该内部端点（SERVICE 身份）。
