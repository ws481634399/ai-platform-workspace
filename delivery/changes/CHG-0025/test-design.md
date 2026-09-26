# Test Design（Change 级聚合）— CHG-0025 M7 分布式增强

> 阶段：sdd-task 聚合产物（5 Story Change）；各 Story 校验细节见对应目录 test-design.md，本文件只引用不复制。

- Change ID: CHG-0025
- 覆盖 Story：S1 RocketMQ 基础设施 9 TC、S2 Outbox 可靠投递 8 TC、S3 订单事件与库存消费者 8 TC、S4 延迟自动取消 10 TC、S5 消费幂等与补偿 11 TC，共 46 TC；另含 M7 Integration Gate 七场景。
- 覆盖核对：AC-001~043 每条至少 1 个 TC，无 TC-NOT-TESTABLE 项。

## 1. 测试用例

### S1 RocketMQ 事件基础设施（DU-INFRA-001 / DU-BE-001）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| TC-001 | repo-4 compose 冒烟（clusterList V5_3_4 + send/consume SEND_OK） | AC-001 |
| TC-002 | 契约快照：Envelope 七字段、Topic/Tag/组集中声明、无散落硬编码 | AC-002, AC-003 |
| TC-003 | Testcontainers 真实 broker：sync/async/delay 三路发送、delayLevel 参数化 | AC-004 |
| TC-004 | 消费 MDC traceId 透传、缺失自动生成不阻断 | AC-005 |
| TC-005 | v2 事件 WARN+ACK 拒绝、handler 不执行 | AC-006 |
| TC-006 | 持续失败重试超限进 DLQ、DLQ 可查不静默 | AC-007 |
| TC-007 | enabled=false 不装配走同步、true 恢复装配 | AC-008 |
| TC-008 | 依赖树断言：版本统一无冲突 | AC-041 |
| TC-009 | mq + contracts 回归合集作为基线 | AC-009 |

### S2 Outbox 可靠投递（DU-BE-002 / DU-FE-001）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| TC-001 | 事务集成：Outbox 同事务写入、写失败业务回滚 | AC-010 |
| TC-002 | CAS 投递成功标 SENT+sent_at、keys 含 eventId | AC-011 |
| TC-003 | MQ 停机保留 PENDING、退避推迟、不标失败 | AC-012 |
| TC-004 | MQ 恢复自动续投至 SENT、幂等不重复 | AC-013 |
| TC-005 | 同聚合按 created_at 顺序投递 | AC-014 |
| TC-006 | 超最大重试 FAILED、管理台查 payload | AC-015 |
| TC-007 | 手动重投回 PENDING、审计完整 | AC-016 |
| TC-008 | mall-order + outbox 回归合集 | AC-017 |

### S3 订单集成事件与库存异步消费者（DU-BE-003）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| TC-001 | Assembler 四事件信封、payload 对齐 §41 | AC-018 |
| TC-002 | Flusher async/sync 两模式 + 仓储 insert/transition flush 挂点 | AC-018 |
| TC-003 | 支付/取消 async 不直调库存、sync 降级路径终态一致 | AC-024 |
| TC-004 | 聚合四状态事件收集、reconstitute 无残留 | AC-018 |
| TC-005 | internal status/compensations 端点契约 | AC-023 |
| TC-006 | PaymentSucceededHandler 确认扣减/乱序跳过/异常补偿/业务幂等 | AC-019, AC-021, AC-022, AC-023 |
| TC-007 | OrderCancelledHandler 释放/乱序跳过/异常补偿 | AC-020, AC-021, AC-022 |
| TC-008 | mall-order + mall-inventory 回归合集 | AC-025 |

### S4 延迟订单自动取消（DU-BE-004 / DU-FE-002）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| TC-001 | DelayLevelMapper 18 级向上对齐/封顶/force 覆盖 | AC-026 |
| TC-002 | Policy 动态读取 + 延迟事件组装/同 flush 单超时 | AC-026, AC-031 |
| TC-003 | V5 delay_level 列 + 投递按行内级别分支 | AC-026 |
| TC-004 | PaymentTimeoutCheckHandler 到期取消/各状态跳过/409 归并/异常重试 | AC-027, AC-028, AC-029 |
| TC-005 | systemCancel 共享 doCancel、CAS 幂等、sync 降级 | AC-027, AC-029 |
| TC-006 | 兜底扫描 cutoff/单条隔离/CAS 归并/开关 | AC-030 |
| TC-007 | union 三源视图 + 手动取消 + 审计 | AC-032 |
| TC-008 | V14 权限/菜单种子核对 | AC-032 |
| TC-009 | 前端 delayTaskApi + 状态 Tag + 手动取消交互 | AC-032 |
| TC-010 | 后端 + 前端回归合集 | AC-026~032 |

### S5 消费幂等与补偿机制（DU-BE-005 / DU-FE-003）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| TC-001 | V3/V6 consumed_event 全迁移断言 | AC-033 |
| TC-002 | INSERT IGNORE 占位 FIST/DUPLICATE、markResult、表名白名单 | AC-034 |
| TC-003 | 取消失败登记 ORDER_AUTO_CANCEL 后重抛 | AC-035 |
| TC-004 | 订单取消执行器 payload 反序列化/幂等/坏载荷 | AC-036 |
| TC-005 | CompensationService 执行器选择/退避序列/MDC 生命周期 | AC-036, AC-039 |
| TC-006 | manualComplete 语义 + 审计 | AC-037, AC-038 |
| TC-007 | 三筛选白名单/通配符转义/分页上限/payload | AC-037 |
| TC-008 | V15 权限/菜单/授权核对 | AC-038 |
| TC-009 | traceId 全链路同源断言 | AC-039 |
| TC-010 | 前端 API + 补偿页契约（含 Dashboard 外链） | AC-038 |
| TC-011 | 后端 + 前端回归合集（五 Story 全量，零回退，降级与 M4 一致） | AC-040, AC-042, AC-043 |

### 横切 AC

AC-041 由 S1 TC-008 覆盖；AC-042（七场景就绪）由各 Story TC + 真实 broker IT 覆盖；AC-043（零回退、降级与 M4 一致）由各 Story 回归合集覆盖。

## 2. M7 Integration Gate（Change 级场景）

七场景：① 支付→确认扣减、② 取消→释放、③ 真实并发重复消费仅一次、④ 乱序消息按聚合当前状态裁决、⑤ MQ 停启 Outbox 续投 + enabled=false 降级 M4 同步、⑥ DLQ→补偿自动重试/人工处理、⑦ 延迟消息到期自动取消 + 兜底扫描归并。单测/切片/真实 broker IT 已出证，真实多服务运行态串联在联调环境以 force-level + 真实 RocketMQ 执行。

## 3. 测试策略

- 分层：mall-common-mq/mall-event-contracts 单测 + Testcontainers 真实 broker IT；mall-order/mall-inventory 以 JUnit5 + Mockito 单测与 H2 Flyway 集成为主；mall-admin vitest 组件契约级；repo-4 compose 冒烟。
- 环境：Java 21 Maven、pnpm vitest、Docker；不依赖 Nacos/MySQL/RocketMQ 生产配置，真实运行态统一归 Integration Gate。
