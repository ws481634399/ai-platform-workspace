# Review Report — AI 订单助手 STORY-008-04-01

## 0. 元信息

- Change ID：CHG-0024（M6 AI 智能应用）
- Story：STORY-008-04-01
- 评审日期：2026-09-20
- 评审人：trae-agent（本机自审 + 机 gate）
- 评审对象：repo-3 736f828、repo-2 f2fd7ca（DU-FE-004 部分）；Story 全量产物
- 验证依据：ai-service pytest 81（含订单 16）；mall-web vitest 129（含 OrderAssistantView 7）；ruff/vue-tsc/eslint/build 全过

## 1. 检查结论

通过（approved）。四查（需求一致性 / 设计一致性 / 跨仓适用性 / 代码质量）均无阻断项，AC-030~037 全部有自动化证据闭环；订单数据全部来自 Tool 透传，取消动作强制二次确认且一次性消费，未引入超出设计的依赖与连接路径。

| 维度 | 结论 |
| --- | --- |
| 需求一致性 | 通过：AC-030~037 逐条在 test-report §3 映射；真实列表/状态筛选/多步追踪/诱导硬条款/确认流语义均落地 |
| 设计一致性 | 通过：意图分类→待确认动作→confirm 执行的状态机、GETDEL 一次性令牌 + memberId 绑定、审计成功/失败字段与 story-design 一致 |
| 跨仓适用性 | 通过：Bearer 原样透传 mall-order，统一 404 口径、业务拒绝 409 双端透出；Java 侧归属/CAS/幂等域规则零改动；前端成功直出不 unwrap |
| 代码质量 | 通过：pytest/ruff 全绿；OrderAssistantView 原生模态、无 v-html、无新依赖；三 Tool/client/Service 边界清晰 |
| 安全 | 通过：端点强制 MEMBER（401）；注入无法指定他人 memberId（Tool 参数无该字段，DENY→404）；ai.order-assistant.enabled 开关 fail-closed |

## 2. 发现清单

### F-01（观察项，不阻断）

- 真实 mall-order 取消端到端链路（含库存释放）未在本阶段执行：单测以 OrdersJavaMock 出证，CAS/幂等由 M4 Java 既有链路保证，列入 C 类 Integration Gate，联调时串一次真实取消。
- Redis 故障降级（内存 TTL 令牌）由代码分支覆盖；fakeredis GETDEL 语义与真实 Redis 7.4 一致。

### 红线核对

- 未手改 `.sdd/`；状态全部经 openspec gate/workflow 推进。
- 本地提交未 push（当前授权范围）。
- 未把实现细节写入 standards/。

## 3. 完成确认

- [x] AC-030 "看看最近的订单" → Bearer 透传 + 真实订单列表，前端订单卡片渲染
- [x] AC-031 "待支付订单" → status=PENDING_PAYMENT 入参映射 + 真实列表
- [x] AC-032 多步 Workflow 按商品识别订单并追踪详情（SHIPPED → "已发货"）
- [x] AC-033 订单号/状态/金额 == Tool 返回；PAID 状态下诱导"已发货"仍按 PAID 解释
- [x] AC-034 "查用户 10001 的订单" Tool 参数无 memberId 字段，Java DENY → 404 透传
- [x] AC-035 取消意图只生成 pendingAction 不执行；confirm 才执行；confirm≠true/缺 actionId/非待支付 → 409；前端确认/取消无副作用/未登录引导
- [x] AC-036 actionId 重复消费 → 409；Java 幂等透传；ai_action_audit 成功/失败字段完整
- [x] AC-037 开关 false → 403 fail-closed；订单核心 pytest + ruff 全绿
- [x] 遗留项均归 C 类 Integration Gate，无代码缺口

Story 可判 completed。
