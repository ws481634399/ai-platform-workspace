# Implementation（跨仓实施汇总）— 搜索异常响应与降级 STORY-005-01-01-02

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0020（Elasticsearch 商品搜索）
- Story：STORY-005-01-01-02 搜索异常响应与降级
- 实施日期：2026-09-18

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-510 | repo-1（ai-platform-backend） | B0501/B0502 错误码 + SearchExceptionAdvice 异常归一/traceId WARN/空结果 200；SearchExceptionAdviceTest 4 例，空结果断言在 ProductSearchApiTest |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 82ccf6e | DU-BE-510 | repo-1 | feat(search): 搜索异常统一响应（连接/超时/404→503 B0501，非法参数→400 B0502，traceId WARN） |

## 3. 各仓实施引用

- repo-1（ai-platform-backend）：
  - 实施记录：`implementation/ai-platform-backend/delivery/CHG-0020/商品搜索/商品搜索查询/搜索服务基础/搜索异常响应与降级/DU-BE-510/implementation.md`
  - 要点：
    - `domain/search/SearchErrorCode.java`：B0501 SEARCH_UNAVAILABLE「搜索服务暂时不可用，请稍后重试」、B0502 SEARCH_BAD_REQUEST「搜索参数不合法」（implements common ErrorCode）；SearchException 按码映射 HTTP 503/400。
    - `interfaces/rest/SearchExceptionAdvice.java`：@RestControllerAdvice 最高优先级；ElasticsearchException/TransportException/ResponseException/IOException 经 cause 链判定（ConnectException/SocketTimeoutException/404）→503 B0501，不匹配 rethrow；IAE→400 B0502 safeMessage；响应体不含主机/堆栈；WARN「搜索不可用 trace={} type={}」带 MDC traceId。
    - 空结果正常 200（items=[]/total=0），不打 WARN/ERROR；traceId 沿用 common-web TraceIdFilter（X-Trace-Id + MDC + 日志 pattern）。
    - 未做 DB 降级：搜索域无商品库直连依赖，故障口径统一为 B0501 + 前端 Error 态重试。

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | 连接拒绝（cause 链 ConnectException）→503 UnifyResult{success:false,code:"B0501"}，body 无主机 IP/堆栈 | passed（SearchExceptionAdviceTest.connectRefused_returns503） |
| AC-002 | SocketTimeoutException cause 链 →503 B0501 | passed（SearchExceptionAdviceTest.socketTimeout_returns503） |
| AC-003 | 别名/索引不存在（ES 404）→503 B0501 统一结构，不回传 index_not_found 原文 | passed（SearchExceptionAdviceTest.indexMissing_returns503；真实缺失别名佐证 ProductSearchApiTest.missingIndex_throws） |
| AC-004 | 0 命中返回 200、items=[]、total=0，且无 ERROR 日志 | passed（ProductSearchApiTest.emptyResult_noErrorLog，ListAppender 断言 com.ai.mall.search 无 ERROR） |
| AC-005 | 503 时 WARN 日志含 traceId 且响应头 X-Trace-Id 可串联 | passed（connectRefused_returns503 断言 MDC traceId 与响应头；SearchExceptionAdviceTest 共 4 例） |
