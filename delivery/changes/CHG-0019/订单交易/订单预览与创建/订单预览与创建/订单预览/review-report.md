# Review Report — STORY-004-01-01-01 订单预览

## 0. 元信息

- Change ID：CHG-0019
- Story ID：STORY-004-01-01-01
- 审查对象：DU-BE-901（repo-1：mall-order 骨架/preview + mall-member 内部地址端点 + 网关路由）
- 审查时间：2026-09-17
- 审查者：trae-agent
- 测试报告来源：`evidence/test-report.md`（mall-order 18/18、mall-member 79/79、mall-gateway 无回归）

## 1. 检查结论

**通过（PASS）。** 预览实现严格只读：不锁库存、不落订单；CART 源取服务端购物车选中项（请求体 items 忽略）；BUY_NOW 校验数量 1..999 与条目 ≤100；逐行 product 实时快照价 + inventory 可用量三档聚合；地址归属由 mall-member 内部端点统一 404 不泄露差异；submitToken 仅在 availableToSubmit=true 时签发（Redis TTL 600s、载荷含 source/addressId/行指纹 SHA）；依赖故障统一 503 ORDER_DEPENDENCY_UNAVAILABLE。OrderApiTest 18/18 全绿。

## 2. 发现清单

| 编号 | 严重度 | 发现 | 处理 |
|------|--------|------|------|
| F-001 | minor | AccessDeniedException 在 Spring Security 默认映射下返回 403 但为 HTML 错误页，前端取包体失败 | 已修复（a06ed4c）：OrderWebExceptionHandler @RestControllerAdvice 统一转 403 业务包体 |
| F-002 | minor | H2 与 MySQL 时间戳 NULL 兼容：reservation 新建时 createdAt/updatedAt 未赋值违反 NOT NULL | 已修复（a06ed4c）：reservationToPo 对 null 时间戳回填 Instant.now() |

无遗留 blocker / major。

## 3. 完成确认

| 检查项 | 结论 |
|--------|------|
| CART/BUY_NOW 双源行装配，伪造 items 忽略 | 通过（TC-001/TC-002） |
| 下架/失效/无库存 → issueCodes + availableToSubmit=false + token=null | 通过（TC-003） |
| 金额一律服务端 product 实时价，请求无金额入口 | 通过（TC-001/TC-006） |
| 地址非本人/不存在/为空不可下单，不泄露归属 | 通过（TC-004） |
| submitToken TTL 600s + 行指纹 | 通过（TC-007 真实 Redis） |
| 依赖故障 503 | 通过（TC-008） |
| 鉴权边界：未认证 401、内部端点 401/404、网关 /api/internal 404 | 通过（TC-009） |
| 工程骨架可启动、smoke 通过 | 通过（TC-010） |
| 不锁库存、不落单 | 通过：preview 路径无 inventory lock/order save 调用 |

证据索引：Story `evidence/evidence.yaml` EV-001~EV-002。

## 4. Deviations

无实质偏离。
