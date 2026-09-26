# Convergence — CHG-0025 M7 分布式增强

## 0. 元信息

- change-id：CHG-0025
- 标题：M7 分布式增强（RocketMQ 事件基础设施 / Outbox 可靠投递 / 订单集成事件与库存异步消费者 / 延迟订单自动取消 / 消费幂等与补偿机制）
- 完成时间：2026-09-26
- 生命周期：当前 testing；本文件仅作收敛判断与知识登记，completed 由流程审批推进
- 参与仓库：repo-1（ai-platform-backend）、repo-2（ai-platform-frontend）、repo-4（ai-platform-infrastructure）
- standards-need-update：yes（更新 4 篇既有标准，见 §2.1）
- product-need-update：yes（Spec 晋升候选 1 篇 product/specs/分布式事件与订单一致.md，待人工评审后落库）
- featuretree-need-update：yes（5 个 Story 节点 planned → delivered）
- glossary-need-update：yes（M7 分布式消息与一致性 7 条术语合并入既有词汇表）
- review 结论：5 个 Story 均 approved；blocker 0 / major 项全部闭环；真实多服务运行态统一归 M7 Integration Gate 七场景，无代码缺口
- 仓指针对账：各 DU metadata 已填 result commit（DU-BE-005=d30f9a7、DU-FE-003=5ce2ad0 等），与所属仓 HEAD 对齐

## 1. 知识变化总结

本 Change 将 M4 的同步强耦合交易链路升级为可靠异步事件驱动，沉淀 6 类可跨 Change 复用的工程模式：

1. **Envelope + 契约集中声明**：事件统一七字段信封（eventId/eventType/eventVersion/occurredAt/producer/traceId/payload）；Topic/Tag/消费者组集中在 mall-event-contracts，服务无散落硬编码；eventId 同时是消息 keys 与全链路唯一幂等键。
2. **Outbox 原子写入 + CAS 投递**：事件行与业务数据同事务落库（写失败回滚业务事务）；投递任务以原生 UPDATE CAS 抢占领取，成功 SENT、失败有界退避，同聚合按 created_at 顺序投递；MQ 停机保留 PENDING、恢复自动续投，不丢事件。
3. **消费先占位后处理（双幂等）**：consumed_event (event_id, consumer_group) 唯一键 INSERT IGNORE 占位，插入成功才处理，重复消息直接 ACK；业务操作本身（确认扣减/释放/取消）同样幂等，两层兜底。
4. **乱序以聚合当前状态裁决**：已取消收支付成功、已完成/已取消收取消事件 → 跳过 + 告警；判断基于订单聚合当前状态、不依赖消息快照；库存服务经内部 API 回查、不直连订单库。
5. **补偿复用不重建**：新增 ORDER_AUTO_CANCEL 操作类型并接口化执行器，沿用 M4 的 30s 扫描与有界退避（30s/1m/2m/5m/10m、5 次封顶）；延迟消息、兜底扫描、补偿执行器三入口收敛到同一应用服务；人工可重试/标记完成，结构化审计（操作人/任务/状态/时间）。
6. **开关单权威与降级一致**：`rocketmq.enabled=false` 时生产消费整体关闭、Outbox 仍写，跨服务写操作降级 M4 同步路径并记降级日志，业务结果与异步路径一致；Spring 装配层沉淀 SmartLifecycle、AutoConfiguration.imports 纯类名、标识符白名单、LIKE 通配符转义、sha 加引号等评审教训。

## 2. 更新判断

### 2.1 Standards（更新 4 篇，无新建文件）

- 文件：standards/engineering/backend/framework-standard.md（更新）
  - 新增 §5.6 自动装配登记文件须为纯类名列表（S2 RV-001）；
  - 新增 §5.7 RocketMQ 事件驱动集成规范（Envelope 七字段/版本拒绝/Outbox 原子+CAS/先占位后处理/补偿复用/开关单权威/ObjectProvider 破循环）；
  - §5.5 消费者容器托管（SmartLifecycle）已在 Story 1 review 时先行晋升。
- 文件：standards/engineering/backend/database-access-standard.md（更新）
  - §9 标识符白名单已先行晋升；本次补 LIKE 参数通配符转义（%/_ 转义、空白归 null、枚举走白名单）。
- 文件：standards/engineering/testing-standard.md（更新）
  - 新增 §8.1 Evidence YAML 中 commit sha 一律双引号（YAML 1.1 科学计数法陷阱）。
- 理由：上述均为后续一切事件驱动扩展（新事件/新消费者/新 Topic）与 Spring 装配的共性基线；以合并方式更新既有标准，保留历史与来源标注。
- 复用场景：后续消息链路开发、多仓 SDD 证据编写、持久层模糊查询、自动装配变更。

### 2.2 Product（Spec 晋升候选，人工评审后落 product/specs/）

- 文件：product/specs/分布式事件与订单一致.md（评审通过后创建）
- 操作：新增
- 草稿要点（产品行为规则，来源 requirement-spec.md §4 业务规则总纲）：
  - 超时处理：订单创建后 30 分钟（可配置）未支付自动取消，cancelReason 固定 PAYMENT_TIMEOUT；已支付/已取消/已完成订单收到到期消息不取消；
  - 重复不重放：同一事件重复投递业务只执行一次；用户侧重复取消幂等；
  - 死信不静默：消费失败经重试/补偿最终收敛，运营可在管理台查询 payload 并手动重试或标记完成；
  - 人工介入留痕：手动重投/重试/标记完成须有操作人、时间与前后状态记录；
  - MQ 故障业务不停：停机期间下单/支付/取消结果与正常路径一致。
- 状态：候选草稿，待人工评审；本阶段不写入 product/specs/。

### 2.3 Feature Tree（5 节点，planned → delivered）

- STORY-009-01-01（RocketMQ 事件基础设施）：planned → delivered
- STORY-009-02-01（Outbox 可靠投递）：planned → delivered
- STORY-009-03-01（订单集成事件与库存异步消费者）：planned → delivered
- STORY-009-04-01（延迟订单自动取消）：planned → delivered
- STORY-009-05-01（消费幂等与补偿机制）：planned → delivered
- 方式：`openspec feature update <ID> --status delivered`

### 2.4 Glossary（合并入既有词汇表）

- 文件：product/glossary/terms.md（已有，追加「分布式消息与一致性（M7）」7 条）
- 内容：事件信封 Envelope、发件箱模式 Outbox、消费幂等表 consumed_event、死信队列 DLQ、延迟消息、有界退避、人工标记完成。
- 理由：M7 引入一批分布式概念，团队叫法与含义需统一；与 M6 词汇同表追加。

### 2.5 No Update

- 各端点/事件 JSON 字段级明细：属实现细节，契约冻结在 requirement-design、mall-event-contracts 与 Spec 候选中。
- 退避具体分钟数、扫描批量/间隔、18 级延迟对齐算法参数：属本次实现选择，已在 §5.7 固化模式，不沉淀参数表。
- docker-compose 服务坐标、Nacos 配置键：属环境配置，不具备知识复用价值。

## 3. 知识沉淀过程

1. 通读 Change 级产物（requirement/exploration/requirement-spec/requirement-design）与 5 个 Story 各 6~7 篇 Artifact，提取知识项并分类（4 standards 更新 + 1 spec 候选 + 5 feature-tree + 7 glossary + 3 no-update）。
2. 对照 5 份 Story review-report 核实发现项去向：全部 blocker/major（自动装配格式、消费者生命周期、构造器循环等）均已闭环，真实运行态统一归 M7 Integration Gate 七场景。
3. 核对全部 DU metadata：status=completed、result commit 与各仓 HEAD 一致（含本 Change 末两个 DU 的 d30f9a7 / 5ce2ad0），供 submodule-pointer-aligned 机检消费。
4. 逐条核对 43 条 AC（40 Story AC + 3 横切 AC）与自动化证据形成 §4。
5. standards/glossary 本阶段实际写回并随收口提交；Spec 候选待人工评审，未直接写入 product/specs/；索引在审批后重建。

## 4. 全局验收标准对照

证据口径：mall-order 最终 118/118（S1~S5 逐 Story 净增）、mall-inventory 37/37、mall-common-mq 32/32（含真实 broker IT）、mall-admin 前端 33 测试文件/134 用例；repo-4 RocketMQ 5.3.4 容器冒烟通过。代码提交（均本地未 push）：repo-1 跨 S1~S5 各 Story commit（末段 d30f9a7、f9f2b81、aba4dca、9c2849c 等）、repo-2（末段 5ce2ad0）、repo-4 broker/compose 提交。

| ID | 验收点 | 覆盖 Story | 证据引用 | 结论 |
| --- | --- | --- | --- | --- |
| AC-001 | compose 启动 NameServer+Broker 健康检查、Nacos 配置连接 | S1 | Story1 EV-010（repo-4 broker 冒烟）+ test-report | 通过 |
| AC-002 | 消息到达指定 Topic/Tag，Envelope 七字段非空 | S1 | Story1 EV-009/018（Envelope 构建 + broker IT） | 通过 |
| AC-003 | Topic/Tag/消费者组集中契约声明、无散落硬编码 | S1 | Story1 EV-004 契约快照 + EV-018 | 通过 |
| AC-004 | 同步/异步/延迟三种发送、delayLevel 参数化 | S1 | Story1 EV-009 三模式用例 | 通过 |
| AC-005 | 消费 MDC 写 traceId，缺失生成且不阻断 | S1 | Story1 EV-009/018 traceId 用例 | 通过 |
| AC-006 | 高 eventVersion 拒绝告警、不按旧解析 | S1 | Story1 v2 事件拒绝用例 | 通过 |
| AC-007 | 异常重试、超限进 DLQ 且可查询 | S1 | Story1 DLQ 用例（broker IT） | 通过（真实运行态随 Integration Gate） |
| AC-008 | enabled=false 不初始化走同步、置 true 恢复 | S1 | Story1 开关两态用例 | 通过 |
| AC-009 | mall-common-mq 单测/集成测试通过 | S1 | Story1 32/32 | 通过 |
| AC-010 | Outbox 同事务写入，写失败回滚业务 | S2 | Story2 EV-003（OutboxRecordWriterTest + 仓储集成） | 通过 |
| AC-011 | 投递成功标 SENT+sent_at，keys 含 eventId | S2 | Story2 claim CAS + 投递用例 | 通过（真实运行态随 Integration Gate） |
| AC-012 | MQ 停机保留 PENDING、退避推迟、不标失败 | S2 | Story2 OutboxBackoffPolicy 用例 | 通过（真实运行态随 Integration Gate） |
| AC-013 | MQ 恢复自动续投至 SENT、幂等不重复 | S2 | Story2 续投/幂等用例 | 通过（真实运行态随 Integration Gate） |
| AC-014 | 同 orderId 按 created_at 顺序投递 | S2 | Story2 sameAggregate 顺序用例 | 通过 |
| AC-015 | 超最大重试 FAILED，管理台筛选查 payload | S2 | Story2 超限分支 + admin 用例 | 通过 |
| AC-016 | 手动重投回 PENDING 并成功，审计完整 | S2 | Story2 resetForRetry + outbox-audit 用例 | 通过 |
| AC-017 | Outbox 核心单测+集成测试通过 | S2 | Story2 mall-order 46/46 | 通过 |
| AC-018 | 四状态迁移发布四 Tag，Payload 对齐 §41 | S3 | Story3 EV-010（聚合事件 + assembler/flusher + 契约校验） | 通过 |
| AC-019 | PAYMENT_SUCCEEDED 消费 → 预留转确认扣减 | S3 | Story3 EV-011 PaymentSucceededHandler 用例 | 通过（真实运行态=Gate 1） |
| AC-020 | ORDER_CANCELLED 消费 → 锁定库存释放 | S3 | Story3 EV-011 OrderCancelledHandler 用例 | 通过（真实运行态=Gate 2） |
| AC-021 | 同一事件重复投递仅扣减/释放一次 | S3 | Story3 两 Handler 幂等用例 | 通过（真实运行态随 Integration Gate） |
| AC-022 | 乱序消息跳过+告警、库存不变 | S3 | Story3 CANCELLED/markSkipped 分支用例 | 通过（真实运行态=Gate 4） |
| AC-023 | 消费失败登记对应补偿并可查询 | S3 | Story3 registerCompensation + internal 端点用例 | 通过 |
| AC-024 | MQ 不可用降级同步、终态一致+降级日志 | S3 | Story3 sync 分支 confirmAfterPaid/releaseAfterCancel | 通过（真实运行态随 Integration Gate） |
| AC-025 | 库存消费者核心单测+集成测试通过 | S3 | Story3 107/107 | 通过 |
| AC-026 | 延迟消息同事务进 Outbox，payload/级别映射正确 | S4 | Story4 事件收集 + V5 承载 + assembler 用例 | 通过 |
| AC-027 | 到期 PENDING 自动取消，CANCELLED+库存释放 | S4 | Story4 PaymentTimeoutCheckHandler 5 用例 | 通过（真实运行态=Gate 7） |
| AC-028 | 已支付/取消/完成订单到期消息 ACK 跳过 | S4 | Story4 非 PENDING→SKIPPED 用例 | 通过 |
| AC-029 | 重复延迟消息仅一次取消/释放 | S4 | Story4 sendDelay/幂等用例 | 通过（真实运行态随 Integration Gate） |
| AC-030 | 消息丢失时兜底扫描取消、无双取消 | S4 | Story4 扫描器 + systemCancel CAS 用例 | 通过（真实运行态随 Integration Gate） |
| AC-031 | 超时配置动态生效映射新延迟级别 | S4 | Story4 policy/mapper 动态读取用例 | 通过 |
| AC-032 | 延迟任务管理台查询+手动取消+审计 | S4 | Story4 union 三源集成 + 控制器/服务用例 | 通过 |
| AC-033 | 成功处理后 consumed_event 落记录七字段 | S5 | Story5 EV-015（V3/V6 迁移 + 消费链用例） | 通过 |
| AC-034 | 重复 eventId 占位命中直接跳过 | S5 | Story5 ConsumedEventRepository 占位/冲突用例 | 通过（真实并发运行态=Gate 3） |
| AC-035 | 消费失败登记三类补偿、重复失败仅一条 | S5 | Story5 PaymentTimeoutCheckHandler + insertIgnore 用例 | 通过 |
| AC-036 | 30s 扫描重试成功、持续失败有界退避 | S5 | Story5 dispatch/handler 退避序列用例 | 通过 |
| AC-037 | 超限 FAILED，三条件筛选查 payload | S5 | Story5 控制器白名单/转义 + toView 用例 | 通过 |
| AC-038 | 手动重试/标记完成、审计含前后状态 | S5 | Story5 EV-015/016（控制器/前端契约/V15） | 通过 |
| AC-039 | 全链路同 eventId/traceId、补偿沿用原 traceId | S5 | Story5 MDC 写入/remove + enqueueTrace 用例 | 通过（真实运行态随 Integration Gate） |
| AC-040 | 幂等补偿核心单测+集成测试通过 | S5 | Story5 两模块 118/37 全绿 | 通过 |
| AC-041 | RocketMQ 版本 mall-bom 统一、无冲突 | 横切 | Story1 依赖树核对（EV-009/018） | 通过 |
| AC-042 | Integration Gate 七场景脚本/用例就绪 | 横切 | 五 Story test-design TC + 真实 broker IT 已具备 | 通过（运行态联调收尾执行） |
| AC-043 | M0~M6 用例零回退，降级与 M4 一致 | 横切 | 五 Story 全量回归 118/37/32/134 | 通过 |

**汇总结论**：43 条 AC 全部有自动化或静态审计证据支撑；真实多服务运行态（支付→扣减、取消→释放、真实并发重复、乱序跳过、MQ 停/启、超时自动取消）统一归 M7 Integration Gate 七场景，联调环境以 force-level + 真实 RocketMQ 串演，无阻断收敛的开放项。

## 5. 完成确认

- [x] 全部前序 Artifact 已读取（Change 级 + 5 Story 各篇 + DU 证据）
- [x] 知识分类完成（4 standards 更新 / 1 spec 候选 / 5 feature-tree / 7 glossary / 3 no-update）
- [x] 全部 DU completed，result commit 与所属仓 HEAD 一致
- [x] 43 条全局 AC 已逐条对照真实证据，无裸用例占位
- [x] 无未解决 blocker/major；运行态观察项均归 Integration Gate
- [x] standards/glossary 已写回；Spec 候选待人工评审；feature-tree delivered 与索引重建按审批后收口执行
