# Test Report — STORY-005-01-01-02 搜索异常响应与降级

> 阶段：sdd-test 产物（Story 级）。

## 0. 元信息

- Change ID：CHG-0020（M5 商品搜索）
- Story ID：STORY-005-01-01-02
- 执行时间：2026-09-19
- 覆盖 AC 范围：AC-001 ~ AC-005（逐条见 §3）
- 覆盖 TC 范围：TC-001 ~ TC-006（逐条对齐本 Story `test-design.md` §1）
- 实施来源：DU-BE-510（repo-1 ai-platform-backend），commit `82ccf6e`（同提交含 DU-BE-501/502/511）

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| TC-001 | ES 连接不可用（ConnectException 在 cause 链）→ 503 UnifyResult{code:B0501}，body 无堆栈/主机信息 | MockMvc standalone（TraceIdFilter + SearchExceptionAdvice，controller 抛 `IOException(cause=ConnectException "Connection refused: /10.0.0.9:9200")`） | passed | `SearchExceptionAdviceTest#connectRefused_returns503`（断言 503、$.success=false、$.code=B0501、X-Trace-Id 响应头存在） |
| TC-002 | 查询超时（SocketTimeoutException cause 链）→ 503 B0501 | MockMvc（抛 `IOException(cause=SocketTimeoutException)`） | passed | `SearchExceptionAdviceTest#socketTimeout_returns503` |
| TC-003 | 索引/别名不存在（ES 404 index_not_found）→ 503 B0501，不回传原生响应 | MockMvc（mock ResponseException status=404、uri=/mall_products/_search）+ 真实 ES 缺失索引佐证 | passed | `SearchExceptionAdviceTest#indexMissing_returns503`（body 断言不含主机 `10.0.0.9`、不含 `at ` 堆栈片段）；`ProductSearchApiTest#missingIndex_throws`（真实 ES 8.17.4 查询不存在的别名 mall_products_missing_alias_it 抛异常，交由 Advice 归一） |
| TC-004 | 0 命中 → 200 {items:[],total:0}，链路无 ERROR 日志 | MockMvc + Testcontainers ES 8.17.4（Logback ListAppender 挂 com.ai.mall.search） | passed | `ProductSearchApiTest#emptyResult_noErrorLog`（关键词 qqqxzz：success=true、total=0、items 空；ListAppender 过滤 Level.ERROR 为空） |
| TC-005 | 异常路径日志带 traceId，可按 traceId 串联本次请求；响应链路透传 traceId | MDC（TraceIdFilter）+ ListAppender 捕获 WARN | passed | `SearchExceptionAdviceTest#connectRefused_returns503`（WARN「搜索不可用」恰 1 条，MDC map 含 traceId 键；响应头 X-Trace-Id 存在） |
| TC-006 | 异常原因链遍历：ElasticsearchException/ResponseException/TransportException 等各类包装均映射 B0501 | MockMvc 切片（三类真实异常形态）+ IAE 分支补充 | passed | `SearchExceptionAdviceTest#connectRefused_returns503`（IOException→ConnectException cause 链）、`#socketTimeout_returns503`（cause 链超时）、`#indexMissing_returns503`（ResponseException 404）；非法参数分支 `#illegalArgument_returns400`（IAE → 400 B0502 安全文案） |

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
| --- | --- | --- |
| mall-search（本 Story 相关） | 全 reactor `mvn test -B -ntp`（`TESTCONTAINERS_RYUK_DISABLED=true`，ES Testcontainers 8.17.4） | `SearchExceptionAdviceTest` **4/4**；空结果语义由 `ProductSearchApiTest#emptyResult_noErrorLog` 共证（该类共 9/9），0 失败 0 跳过 |
| mall-search 模块整体 | 同上（2026-09-19） | **32/32**（7 classes），BUILD SUCCESS |
| 全 reactor 回归 | 同上 | 14 模块 **482/482**，0 失败 0 跳过，BUILD SUCCESS |
| 日志 | `delivery/changes/CHG-0020/evidence/logs/backend-full-test.log` | SearchExceptionAdviceTest 4（0.165s）、ProductSearchApiTest 9（25.50s，真实 ES）、模块 Results 32 |

通过率：本 Story 相关自动化断言 **5/5 个 @Test 方法全部通过**（SearchExceptionAdviceTest 4 + ProductSearchApiTest 中 emptyResult/missingIndex 2 个方法被本 Story 复用引用），TC 层 6/6 全部 passed，**100%**。

## 3. AC 覆盖

| AC | 覆盖 TC |
| --- | --- |
| AC-001 | TC-001、TC-006 |
| AC-002 | TC-002、TC-006 |
| AC-003 | TC-003 |
| AC-004 | TC-004 |
| AC-005 | TC-005 |

## 4. 备注 / 缺口

- TC-003 在 test-design 中设想为「删除别名后查询」的纯 Testcontainers 形态；实际落为两层证据：Advice 切片用 mock `ResponseException`（404 + index_not_found URI）断言归一响应，另由 `ProductSearchApiTest#missingIndex_throws` 在真实 ES 8.17.4 上证明查询缺失别名必抛异常。端到端「真实 HTTP 503 + 缺失别名」单跳链路在 Integration Gate 联调闭合。
- 容器级故障注入（直接停 ES 容器验证 503）未在单元/集成测试中实施，按 Change 级缺口统一在 M5 Integration Gate 场景五联调处置；故障归一机制本身已由 cause 链切片用例证明。
- 错误文案固定为「搜索服务暂时不可用，请稍后重试」；WARN 日志仅记 traceId/异常类型/message，不记敏感头，符合 story-spec §3 可观测口径。
