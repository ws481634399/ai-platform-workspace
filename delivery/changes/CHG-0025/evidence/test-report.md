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

- 真实多服务运行态（支付→确认扣减、取消→释放、真实并发重复消费、乱序裁决、MQ 停启续投、延迟到期取消）归 M7 Integration Gate 七场景：单测/真实 broker IT 已出证，联调环境以 force-level + 真实 RocketMQ 串演。
- mall-identity 模块 3 个既有失败（M1AuditAppendOnlyTest / InternalMemberSeedApiTest）经对照确认与本 Change 无关，不在本批处理。
