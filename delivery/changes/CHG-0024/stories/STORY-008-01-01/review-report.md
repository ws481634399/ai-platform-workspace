# Review Report — AI 智能导购 STORY-008-01-01

## 0. 元信息

- Change ID：CHG-0024（M6 AI 智能应用）
- Story：STORY-008-01-01
- 评审日期：2026-09-20
- 评审人：trae-agent（本机自审 + 机 gate）
- 评审对象：repo-1 eab992d、repo-3 bc984bc、repo-2 5dd4508；Story 全量产物
- 验证依据：网关 7 例、ai-service pytest 81（含导购 28）、mall-web vitest 129（含 AssistantView 6）、ruff/vue-tsc/eslint/build 全过

## 1. 检查结论

通过（approved）。四查（需求一致性 / 设计一致性 / 跨仓适用性 / 代码质量）均无阻断项，AC-001~013 全部有自动化证据闭环，未引入超出设计的依赖与连接路径。

| 维度 | 结论 |
| --- | --- |
| 需求一致性 | 通过：AC-001~013 逐条在 test-report §3 映射，场景五（开关）/场景六（兜底）行为落地 |
| 设计一致性 | 通过：五节点链、enforce_grounding、Tool 注册表、会话 TTL/截断、fail-closed 开关均与 story-design 一致 |
| 跨仓适用性 | 通过：网关路由 /api/ai/** → 8120、permitAll 与角色矩阵未破坏既有链路；ai-service 仅经 java client 访问商品 API |
| 代码质量 | 通过：pytest/ruff 全绿；前端无 v-html、无新依赖；分层（api/agents/services/infrastructure）清晰 |
| 安全 | 通过：JWT 非法→GUEST；memberId 不可由普通参数指定；开关 fail-closed |

## 2. 发现清单

### F-01（观察项，不阻断）

- 真实 mall-search/mall-product 端到端串联未在本阶段执行（测试以 httpx mock/JavaMock 出证），列入 C 类 Integration Gate，联调环境按 story-design §4 串一次。
- 网关切片测试未起真实 ai-service，属最小依赖范式。

### 红线核对

- 未手改 `.sdd/`；状态全部经 openspec gate/workflow 推进。
- 本地提交未 push（当前授权范围）。
- 未把实现细节写入 standards/。

## 3. 完成确认

- [x] AC-001~007 推荐链路（约束提取/澄清/真实商品/真实价格/有据理由）
- [x] AC-008 AssistantView 对话与卡片
- [x] AC-009 会话多轮上下文
- [x] AC-010 搜索故障降级与 502
- [x] AC-011 不直连业务库
- [x] AC-012 开关 fail-closed
- [x] AC-013 测试/ruff 门禁
- [x] 遗留项均归 C 类 Integration Gate，无代码缺口

Story 可判 completed。
