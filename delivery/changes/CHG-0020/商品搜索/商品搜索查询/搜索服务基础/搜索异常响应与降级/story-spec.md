---
story-id: "STORY-005-01-01-02"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S4]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.1 [S4]/§4/§5
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0020
- Story ID: STORY-005-01-01-02 搜索异常响应与降级
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`（S4）

## 1. Story 目标

为搜索查询建立统一异常口径：ES 不可用、查询超时、索引（别名）不存在三类底层异常统一捕获并转换为 B05xx 业务错误（SEARCH_UNAVAILABLE，HTTP 503/统一错误结构），日志含 traceId/异常类型可定位；搜索结果为空是正常 200 空分页。M5 明确不做数据库降级搜索，故障体验由 mall-web Error 态承接（STORY-005-01-02-03）。

## 2. Scope（范围）

### 2.1 包含

- [S4] SearchExceptionAdvice（或扩展全局异常处理）：ElasticsearchException / TransportException / ConnectException / SocketTimeoutException / index_not_found 响应的归一处理。
- [S4] SearchErrorCode：B05xx 段（SEARCH_UNAVAILABLE 等），统一 UnifyResult 错误结构 + HTTP 503 映射。
- [S4] 可定位日志：error 日志含 traceId（沿用链路追踪基线）、异常类型、ES 节点信息（不记录敏感头）。
- [S4] 空结果语义：0 命中 → 200 + 空分页（由查询 Story 实现，本 Story 定义/测试该语义不被误判为错误）。

### 2.2 不包含

- 数据库降级搜索（M5 明确不做；禁止 mall-search 直查商品库）。
- mall-web Error 态 UI（STORY-005-01-02-03）。
- 重试/熔断组件（不引入 Resilience4j 等新组件；连接超时由 Client 配置承担）。

## 3. 业务规则

- [异常归一] ES 客户端抛出的任何基础设施异常不得原样透传到 HTTP 响应；对外只暴露 B05xx + "搜索服务暂时不可用，请稍后重试"文案。
- [索引不存在] 别名 mall_products 不存在（首次部署尚未全量构建）按 SEARCH_UNAVAILABLE 处理，不返回 500 原生错误。
- [空结果] 正常业务态，不触发告警级日志。
- [可观测] 每次 SEARCH_UNAVAILABLE 打 WARN/ERROR 结构化日志（traceId、异常类型、message），便于 Integration Gate 场景五排查。

## 4. 接口与字段规格

- 错误响应：UnifyResult `{success:false, code:"B0501", message:"搜索服务暂时不可用，请稍后重试", traceId:"..."}`，HTTP 503（最终错误码命名以 design 为准）。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 模拟 ES 连接不可用（错误端口/容器停止）→ 搜索接口返回统一错误结构 B05xx + 503，响应体不含 ES 原生堆栈/主机细节 |
| AC-002 | 模拟查询超时 → 同上归一为 SEARCH_UNAVAILABLE |
| AC-003 | 索引/别名不存在 → 同上 SEARCH_UNAVAILABLE（而非 index_not_found 原生错误） |
| AC-004 | 查询正常但 0 命中 → HTTP 200，分页结构 items=[]、total=0，不打 ERROR |
| AC-005 | 每次搜索不可用响应均有 WARN/ERROR 日志且带 traceId，可在日志中按 traceId 串联本次请求 |
