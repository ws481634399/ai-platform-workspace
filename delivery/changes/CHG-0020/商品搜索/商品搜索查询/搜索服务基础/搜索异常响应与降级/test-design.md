# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0020
- Story ID: STORY-005-01-01-02
- Feature Path: 商品搜索 > 商品搜索查询 > 搜索服务基础 > 搜索异常响应与降级
- 状态流转: designed → tasked
- TC 总数: 6

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API（MockMvc，repository mock 抛 ConnectException/cause 链）：GET 搜索 → 503 UnifyResult{code:B0501}，body 无堆栈/主机信息 | AC-001 | DU-BE-510 | [S1] |
| TC-002 | API：mock 抛 SocketTimeoutException → 503 B0501 | AC-002 | DU-BE-510 | [S1] |
| TC-003 | 集成/API：别名不存在（删除别名后查询）→ 503 B0501 而非 index_not_found 原生响应 | AC-003 | DU-BE-510 | [S1] |
| TC-004 | 集成（Testcontainers）：无命中关键词 → 200 {items:[],total:0,...}；日志无 ERROR（cap/log 断言 WARN=0 亦可） | AC-004 | DU-BE-510 | [S1] |
| TC-005 | API：MDC 注入 traceId 调异常路径，捕获日志断言含 traceId；响应链路透传 traceId | AC-005 | DU-BE-510 | [S1] |
| TC-006 | 单测：异常原因链遍历（ElasticsearchException/ResponseException/TransportException 包装）均映射 B0501 | AC-001, AC-002, AC-003 | DU-BE-510 | [S1] |

## 2. 测试策略

- MockMvc 切片 + 手动注入 MDC；异常体结构断言 UnifyResult 字段。
- Testcontainers 真实 ES 覆盖 index_not_found 与空结果，避免 mock 猜测客户端异常类型。
- 日志断言使用 LogCaptor 或工程既有日志测试手段。

## 3. 不可测项标注

- 无。

## 4. 依赖与前置条件

- STORY-005-01-01-01 ES Client 基线；B0501/B0502 错误码与 Advice 随本 Story 落地。

