# Test Report（Change 级聚合）— CHG-0025 M7 分布式增强

## 0. 元信息

- Change ID：CHG-0025（M7 分布式增强）
- 日期：2026-09-26
- 本文件为 Change 级聚合，各 Story 执行细节见 stories/STORY-009-05-0X-01/evidence/test-report.md

## 1. 测试范围

- repo-4：RocketMQ namesrv/broker/dashboard compose 三服务冒烟（真实 5.3.4 收发）
- repo-1：mall-common-mq / mall-event-contracts（单测 + Testcontainers 真实 broker IT）；mall-order Outbox/订单事件/延迟取消/幂等补偿；mall-inventory 异步消费者；mall-identity V13/V14/V15 权限种子
- repo-2：mall-admin Outbox/延迟任务/补偿三管理页 vitest + type-check/eslint/build

## 2. 测试执行汇总

| 套件 | 命令 | 结果 | 用例数 |
| --- | --- | --- | --- |
| infrastructure compose 冒烟（repo-4） | mqadmin clusterList + send/consume | passed | broker-a V5_3_4 SEND_OK |
| mall-common-mq + contracts（repo-1） | `mvn -pl mall-common-mq,mall-event-contracts test` | passed | 32（含真实 broker IT） |
| mall-order（repo-1，全量） | `mvn -pl mall-services/mall-order clean test` | passed | 118/118 |
| mall-inventory（repo-1，全量） | `mvn -pl mall-services/mall-inventory clean test` | passed | 37/37 |
| mall-admin vitest（repo-2） | `pnpm vitest run` | passed，33 测试文件 | 134（order.spec 3 + 补偿契约 7 + Outbox/延迟页 10 等） |
| mall-admin type-check | `pnpm type-check` | passed | — |
| eslint | `pnpm exec eslint src` | 0 error | — |
| vite build | `pnpm build` | passed | — |

## 3. AC 覆盖汇总

- AC-001~009/041（基础设施）：S1 TC-001~009 全绿，见 Story1 test-report
- AC-010~017（Outbox）：S2 TC-001~008 全绿，见 Story2 test-report
- AC-018~025（订单事件与库存消费）：S3 TC-001~008 全绿，见 Story3 test-report
- AC-026~032（延迟取消）：S4 TC-001~010 全绿，见 Story4 test-report
- AC-033~040（幂等补偿）：S5 TC-001~011 全绿，见 Story5 test-report
- AC-042/043（横切）：七场景脚本就绪 + 全量回归零回退、降级与 M4 一致

46 TC 全绿，43 AC 全覆盖，无 TC-NOT-TESTABLE 项。

## 4. 缺口备注

- ~~真实多服务运行态归 M7 Integration Gate 七场景~~ 已于 2026-09-26 真实联调环境执行，结果见 §5。
- mall-identity 模块 3 个既有失败（M1AuditAppendOnlyTest / InternalMemberSeedApiTest）经对照确认与本 Change 无关，不在本批处理。

## 5. M7 Integration Gate 七场景真实运行态验证

- 时间：2026-09-26 19:19–20:12
- 环境：Docker（MySQL 13306 / Redis / Nacos / RocketMQ namesrv+broker 5.3.4 healthy），七微服务经网关 8080；事件均投递真实 broker
- 总结果：**七场景全部通过**；期间发现并修复 3 个仅真实 broker 暴露的装配缺陷（commit db28b6a），修复后复验通过

### 场景① 支付→确认扣减（AC-019）

- 订单 ORD202609261919309070000：下单同步预占 locked+1；支付后 PAYMENT_SUCCEEDED 经 outbox 中继真实投递
- 结果：库存 total 222→221、预占 LOCKED→DEDUCTED；consumed_event 对应 eventId result=SUCCESS

### 场景② 取消→释放（AC-020）

- 订单 ORD202609261920353010001：取消后 ORDER_CANCELLED 真实投递
- 结果：locked 2→1、预占 RELEASED；consumed_event result=SUCCESS

### 场景③ 并发重复消费仅一次（AC-034）

- jshell 12 线程以同一 eventId（evt-conc-a8c7687a-5e83-4d0b-a286-7acae26d9778）并发投递真实 broker，12 条全部 SEND_OK
- 结果：consumed_event 该 eventId 仅 1 行 SUCCESS；库存恰好扣减 1 次（DEDUCTED）；日志 DUP=11 / END=12

### 场景④ 乱序消息按聚合当前状态裁决（AC-022）

| 迟到消息 | 订单（真实状态） | consumed_event | 副作用 |
| --- | --- | --- | --- |
| PAYMENT_SUCCEEDED evt-ooo-pay-49ac8e0a… | ORD202609261936090070003（CANCELLED） | **SKIPPED** | 不重复扣减 |
| ORDER_CANCELLED evt-ooo-cancel-1cd3281b… | ORD202609261936100130004（PAID） | **SKIPPED** | 不释放 |

- 库存保持 total=220 locked=1；A 预占 RELEASED、B 预占 DEDUCTED，均不变
- 告警：`PAYMENT_SUCCEEDED 乱序到达：订单已取消，跳过确认扣减`、`ORDER_CANCELLED 乱序到达：订单真实状态=PAID，跳过释放防误扣`

### 场景⑤ MQ 停启 Outbox 续投 + enabled=false 同步降级（AC-012/013/024）

- **停机保留（AC-012）**：broker 停机期间支付 ORD202609261948053000001，支付业务未阻断；outbox PAYMENT_SUCCEEDED 留存 PENDING、retry_count 递增、next_retry_at 按退避推迟；预占保持 LOCKED
- **恢复续投（AC-013）**：broker 恢复 healthy 后中继自动续投 SENT；total 219→218、locked 2→1、预占 DEDUCTED、consumed_event SUCCESS，无人工干预、无重复处理
- **同步降级（AC-024）**：order 以 rocketmq.enabled=false 重启后
  - 支付 ORD202609261950381150000 → 同步确认扣减，total 218→217、预占 DEDUCTED
  - 取消 ORD202609261950384810001 → 同步释放，预占 RELEASED
  - 两单 outbox 行数均为 0；降级日志可查（`rocketmq.enabled=false，…走同步降级路径`）

### 场景⑥ DLQ→补偿自动重试/人工处理（AC-007/035/036）

- **重试与 DLQ（AC-007）**：持续失败消息按 RocketMQ 策略重试，超限进入 `%DLQ%inventory-consumer-group`（队列 max offset=3）；mqadmin queryMsgByOffset 可查（tag=ORDER_CANCELLED、Reconsume Times=3、ORIGIN_MESSAGE_ID 可溯），不静默丢弃
- **任务登记与去重（AC-035）**：失败登记对应补偿任务；同一业务操作多次失败仅保留 1 行任务（重复投递不新增）
- **扫描自动重试（AC-036）**：ORD202609262005110490001 任务 PENDING（20:05:23）→ CompensationService 30s 扫描到期自动执行 → 20:06:06 置 SUCCESS，locked 2→1、预占 RELEASED；持续失败按 30s/1m/2m/5m/10m 有界退避，5 次失败转 FAILED_DEAD
- **人工处理**：admin 登录（system:compensation:retry/complete 权限）对 FAILED_DEAD 任务 POST `/api/admin/compensations/{id}/retry` 复活并重试成功（SUCCESS、库存释放）；POST `/{id}/complete` 人工标记完成成功；compensation-audit 审计日志含操作人/任务/时间

### 场景⑦ 延迟到期自动取消 + 重复/兜底归并（AC-027/029/030）

- **延迟自动取消（AC-027）**：ORDER_DELAY_FORCE_LEVEL=1 下创建 ORD202609262008217850000 不支付，PAYMENT_TIMEOUT_CHECK 到期回查 → 系统取消：CANCELLED、cancelReason=PAYMENT_TIMEOUT、操作人 SYS:DELAY_MESSAGE；库存释放 locked 2→1、预占 RELEASED
- **重复消息归并（AC-029）**：重复投递同一延迟消息（evt-dup-delay-4ea157d1…）→ result=SKIPPED；状态历史仍为 2 笔、locked 保持 1，无重复取消/重复释放
- **兜底扫描归并（AC-030）**：删除该单 PAYMENT_TIMEOUT_CHECK outbox 行模拟消息丢失，10s 后订单仍 PENDING_PAYMENT；OrderTimeoutFallbackScanner 到期按 created_at+超时（测试设 1 分钟）捞出并取消，操作人 SYS:TIMEOUT_FALLBACK，库存 RELEASED、locked 归 1；两路径共用 systemCancel CAS 收口，仅产生一次真实取消

### Gate 期间缺陷修复（commit db28b6a）

1. 自动配置排序：`@AutoConfiguration(after = JdbcTemplateAutoConfiguration.class)`，修复幂等组件被排序跳过；
2. 同组订阅冲突：按（消费组, topic）归并单一物理消费者 + 合并订阅 + tag 内部分发；
3. SKIPPED 被覆盖：处理链收尾改 CAS 条件回写（仅 PROCESSING→SUCCESS）。

均以 TDD 补测试覆盖，mall-common-mq 全量测试通过。

**Gate 结论：七场景真实运行态全部通过，43 AC 全覆盖，M7 分布式增强运行态验收合格。**
