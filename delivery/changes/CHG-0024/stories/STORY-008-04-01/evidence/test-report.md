# Test Report — AI 订单助手 STORY-008-04-01

## 0. 元信息

- Change ID：CHG-0024（M6 AI 智能应用）
- Story：STORY-008-04-01
- 日期：2026-09-20
- 证据：workspace evidence.yaml EV-007（repo-3 736f828）、EV-008（repo-2 f2fd7ca）；
  repo-3 DU-AI-004/evidence/logs（pytest.txt、ruff-check.txt）；
  repo-2 DU-FE-004/evidence/logs（mall-web-vitest/typecheck/eslint/build.txt）

## 1. 测试范围

- repo-3：order_tools 三 Tool（Bearer 透传/状态筛选/统一 404/业务拒绝 409）、OrdersAgent 多步 Workflow（意图分类/按商品识别/PAID 硬条款/多笔澄清）、PendingActionService（GETDEL 一次性+memberId 绑定+降级）、assistant+confirm 端点（强制 MEMBER/fail-closed）、审计；ruff。
- repo-2 mall-web：aiApi.ordersAssistant/ordersConfirm（409 透出）、OrderAssistantView（订单卡片/二次确认模态/401 引导/409 透出）、路由守卫与导航开关；type-check/eslint/build。

## 2. 测试执行汇总

| 套件 | 命令 | 结果 | 用例数 |
| --- | --- | --- | --- |
| ai-service（pytest，当前全量） | `uv run pytest tests/ -q` | passed | 81（含订单 16） |
| ai-service（ruff） | `uv run ruff check app tests` | clean | — |
| mall-web（vitest） | `pnpm vitest run` | passed，26 文件全过 | 129（含 OrderAssistantView 7） |
| mall-web type-check/eslint/build | `pnpm type-check` / `eslint src` / `build` | passed / 0 error / passed | — |

## 3. AC 覆盖

| AC | 自动化证据 | 结果 |
| --- | --- | --- |
| AC-030 | TC-401（Bearer 原样透传断言+真实列表）、TC-409 前端查询卡片渲染 | passed |
| AC-031 | TC-402（"待支付" → status=PENDING_PAYMENT 映射 + 列表） | passed |
| AC-032 | TC-403（"iPhone 订单发货了吗" 多步：列表→商品识别→详情→SHIPPED） | passed |
| AC-033 | TC-404（订单号/状态/金额 == Tool；PAID 诱导仍按 PAID 解释） | passed |
| AC-034 | TC-405（"查用户 10001" Tool 参数无 memberId；Java DENY→404） | passed |
| AC-035 | TC-406（pendingAction 不执行；confirm 才执行；confirm≠true/缺 actionId/非待支付 → 409）、TC-409 前端确认流/取消无副作用/未登录引导 | passed |
| AC-036 | TC-407（actionId 重复消费 → 409；审计成功/失败字段完整） | passed |
| AC-037 | TC-408（开关 false → 403；pytest+ruff 全绿） | passed |

## 4. 缺口备注

- 真实 mall-order 取消的端到端链路（含库存释放）属 C 类 Integration Gate：单测以 OrdersJavaMock 出证，CAS/幂等由 M4 Java 既有链路保证，联调时串一次真实取消。
- Redis 故障降级（内存 TTL 令牌）由代码分支覆盖；fakeredis GETDEL 语义与真实 Redis 7.4 一致。
