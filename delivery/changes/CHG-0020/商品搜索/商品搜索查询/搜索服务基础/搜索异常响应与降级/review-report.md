# Review Report — STORY-005-01-01-02 搜索异常响应与降级

## 0. 元信息

- Change ID：CHG-0020（M5 商品搜索）
- Story ID：STORY-005-01-01-02 搜索异常响应与降级
- 审查对象：DU-BE-510（repo-1：SearchErrorCode B0501/B0502、SearchExceptionAdvice 异常归一、traceId WARN、空结果 200 语义）
- Test Report 来源：`evidence/test-report.md`
- Evidence 索引：`evidence/evidence.yaml`（EV-001~EV-003）
- 检查时间：2026-09-19
- 状态：testing 检查点（不推进 Story/Change 状态）

## 1. 检查结论

**通过（PASS，带 1 项开放 minor）。** 三类底层异常（连接拒绝/读超时/索引或别名 404）经 cause 链统一归一为 HTTP 503 + UnifyResult{code:"B0501"}，响应不含主机/堆栈；非法参数 400 B0502 仅回显安全文案；空结果为正常 200 空页且无 ERROR 日志；WARN 带 MDC traceId、X-Trace-Id 响应头可串联。SearchExceptionAdviceTest 4/4 与 ProductSearchApiTest 空结果/缺索引共证，全 reactor 482/482。无 blocker/major。

### 1.1 需求一致性

| Story AC | test-run 证据 | 结论 |
| --- | --- | --- |
| AC-001 ES 连接不可用 → 503 B05xx 统一结构、无堆栈/主机泄漏 | SearchExceptionAdviceTest#connectRefused_returns503（IOException cause=ConnectException 含伪主机 10.0.0.9，断言 503、$.code=B0501、body 不含主机） | passed |
| AC-002 查询超时 → 同口径 SEARCH_UNAVAILABLE | SearchExceptionAdviceTest#socketTimeout_returns503（cause 链 SocketTimeoutException） | passed |
| AC-003 索引/别名不存在 → SEARCH_UNAVAILABLE 而非原生 404 | SearchExceptionAdviceTest#indexMissing_returns503（mock ResponseException 404，断言无 `at ` 堆栈片段）+ ProductSearchApiTest#missingIndex_throws（真实 ES 8.17.4 查询不存在别名必抛） | passed（端到端单跳留 Gate，见 EV-003） |
| AC-004 0 命中 → 200 items=[]/total=0，不打 ERROR | ProductSearchApiTest#emptyResult_noErrorLog（真实 ES 无命中词；Logback ListAppender 断言 com.ai.mall.search 无 ERROR） | passed |
| AC-005 不可用响应 WARN 带 traceId 且可串联 | connectRefused_returns503 断言恰 1 条"搜索不可用"WARN、MDC 含 traceId 键、X-Trace-Id 响应头存在 | passed |

### 1.2 设计一致性

- 异常策略：story-design §1/§4 声明的 ElasticsearchException/TransportException/ResponseException/IOException 捕获、cause 链识别、B0501/B0502 映射、不向外泄 ES 细节，与 SearchExceptionAdvice 源码逐条一致；`@Order(HIGHEST_PRECEDENCE)` 优先于 common-web 兜底，未命中异常 rethrow 不盲目吞并，边界清晰。
- 模块职责：SearchErrorCode implements common ErrorCode、SearchException extends common BusinessException，复用 TraceIdFilter/MDC 链路，无自造追踪栈。
- 空结果语义在适配器层空安全返回 SearchPage（hits.total 为 null 时 total=0），不经 Advice，符合"空结果是正常态"。
- Deviations 完整性：DU-BE-510 DEV-1（404 只按状态码判定、不解析 reason 文本，比设计更强健）、DEV-2（不单建 EmptyResultIT，空结果/缺索引断言并入 ProductSearchApiTest 与切片双侧）均四要素齐全，AC-004 验证意图与强度不变。
- 不降级承诺：mall-search pom 零商品库直连依赖，代码无任何 DB 回退路径，符合 spec §2.2/业务规则。

### 1.3 跨仓一致性

requirement-design §4 API Contract 的错误段（B0501/503、B0502/400、UnifyResult 结构）在 repo-1 落地；repo-2 mall-web search store 以非 2xx 进 error 态、resolveErrorMessage 归一文案承接，前后端对错误口径无矛盾。网关透传 503/400 不吞错误码。跨仓一致。

### 1.4 代码质量

对照 standards 明确条目抽查：

- api-design-standard §7（统一异常处理/业务异常明确/系统异常记日志且不暴露内部细节）：B0501/B0502 明确语义码、WARN 含 traceId 与异常类型、safeMessage 仅回显参数语义文案（"minPriceFen 不能大于 maxPriceFen"），完全符合。
- testing-standard §6（异常流程必须覆盖）：三类异常 + IAE 分支 + 空结果 + 日志/traceId 均有自动化断言；切片用 standalone MockMvc 装配真实 Filter/Advice，非 mock 掉被测对象。
- 小项：UncheckedIOException 包装经 Spring 异常解析的 cause 链递归可命中 IOException 处理器（连接/超时用例已实证），机制可靠，无质量问题。

### 1.5 知识同步候选

1. B05xx 搜索域错误码规范：B0501 SEARCH_UNAVAILABLE（503，"搜索服务暂时不可用，请稍后重试"）/ B0502 SEARCH_BAD_REQUEST（400，"搜索参数不合法"），可作为后续搜索相关错误码（B05xx 段）的分配基线。
2. ES 客户端异常归一样式：遍历 cause 链识别 ConnectException/SocketTimeoutException 与 404 ResponseException（只认状态码、不依赖 reason 文案），未匹配异常 rethrow 交兜底；WARN 记 traceId+异常类型、响应体不含主机/堆栈——可复用为后续基础设施依赖（Redis/MQ 等）故障归一模板。

## 2. 发现清单

| EV id | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-003 | Story AC-001/AC-002/AC-003；test-report §4 | minor | 故障归一由 MockMvc cause 链切片 + 真实 ES 缺索引双层证明，未做"直接停止 ES 容器"的容器级故障注入；真实 HTTP 503 + 缺失别名的单跳端到端未在同一用例闭合 | 处置去向：M5 Integration Gate 场景五实停 ES 容器，验证 mall-search 503 B0501、进程存活、X-Trace-Id 可串联、mall-web Error 态；机制本身已有自动化护栏，开放可接受 |

无 blocker / major。

## 3. 完成确认

- [x] 四项检查全部执行（需求/设计/跨仓/代码质量）
- [x] 全部 blocker/major finding 已闭环（本 Story 无 blocker/major）
- [x] minor finding 已记录（EV-003，允许开放，处置去向 Gate 场景五）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（错误码段 repo-1→repo-2 承接一致）
