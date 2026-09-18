---
affected-repositories: [repo-1]
story-id: "STORY-005-01-01-02"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §2.1/§2.4
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0020
- Story ID: STORY-005-01-01-02
- 状态流转: specified → designed
- 相关仓库: repo-1
- 需要 Migration: no
- 数据变更概要: 无

## 1. 模块改动（Module Changes）

### repo-1 mall-search（DU-BE-501 增量）

- domain.search.SearchErrorCode（enum implements 既有 ErrorCode 契约）：B0501 SEARCH_UNAVAILABLE(httpStatus=503,"搜索服务暂时不可用，请稍后重试")、B0502 SEARCH_BAD_REQUEST(httpStatus=400)。
- domain.search.SearchException extends BusinessException（沿用既有业务异常基类；若无基类则本服务定义并由 advice 映射）。
- interfaces.rest（或 infrastructure.web）.SearchExceptionAdvice @RestControllerAdvice：
  - catch co.elastic.clients.elasticsearch._types.ElasticsearchException、org.elasticsearch.client.ResponseException（404/index_not_found）、TransportException 及其 cause 链 ConnectException/SocketTimeoutException；
  - 统一 log.warn（traceId 取自 MDC 既有链路键、异常类型、message 前 500 字）→ throw/返回 B0501；
  - IllegalArgumentException（分页/价格参数）→ B0502 400。
- 空结果语义在 repository/app service 层保证：hits.total=0 → SearchPage.empty，不抛错、不打 WARN。
- 测试：SearchExceptionAdviceTest（MockMvc：mock repository 抛三类异常 → 503 统一结构；空结果 200）；日志/traceId 断言用 MDC 注入捕获。

## 2. 接口契约细化

| 场景 | HTTP | body（UnifyResult） |
| --- | --- | --- |
| ES 不可用/超时/索引缺失 | 503 | {success:false,code:"B0501",message:"搜索服务暂时不可用，请稍后重试",traceId} |
| 参数非法（min>max 等，下一 Story 起产生） | 400 | {success:false,code:"B0502",message,traceId} |
| 0 命中 | 200 | {success:true,data:{items:[],total:0,page,size}} |

## 3. 数据变更

无。

## 4. 错误处理

- 异常原因链遍历（ExceptionUtils.getThrowableList 或手写循环）识别连接/超时；不外泄 ES 主机/堆栈。
- index_not_found：ResponseException status 404 且 reason 含 index_not_found → B0501。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-510 | repo-1 | 错误码 B0501/B0502、SearchExceptionAdvice 三类异常归一、空结果 200 语义与 traceId 日志 | AC-001, AC-002, AC-003, AC-004, AC-005 | 无 |

> 跨 Story 依赖（不入本表）：DU-BE-510 实际前置 DU-BE-501（STORY-005-01-01-01 ES Client/健康基线），同模块增量发布。

## 6. 测试策略

- MockMvc 切片：三类 ES 异常 → 503/B0501/无堆栈；traceId 透传。
- Testcontainers：0 命中查询返回 200 空分页且无 WARN（日志断言可选）。
