# Review Report（Change 级聚合）— CHG-0025 M7 分布式增强

## 1. 检查结论

通过（approved）。5 个 Story review 全部 approved，0 blocker；3 项 major 均已闭环（消费者生命周期、自动装配格式、构造器循环）；四查（需求一致性 / 设计一致性 / 跨仓适用性 / 代码质量）无阻断项，AC-001~043 全部有自动化或静态审计证据闭环。

| 维度 | 结论 |
| --- | --- |
| 需求一致性 | 通过：五 Story AC 逐条映射；Envelope 契约、Outbox 同事务、双幂等、三入口收敛、开关降级语义落地 |
| 设计一致性 | 通过：六步消费链、CAS 投递状态机、订单聚合事件收集、延迟 18 级对齐、CompensationActionHandler 接口化与各 Story 设计一致 |
| 跨仓适用性 | 通过：repo-4 broker 5.3.4 compose 冒烟通过；repo-1 mall-bom 统一版本无冲突；repo-2 三管理页契约与后端一致；降级路径与 M4 同步实现结果一致 |
| 代码质量 | 通过：mall-order 118、mall-inventory 37、common-mq/contracts 32、mall-admin 33 文件 134 用例全绿；vue-tsc/eslint/build 全过 |
| 安全 | 通过：JDBC 标识符白名单、LIKE 通配符转义、system:compensation:* 三权限码最小授权、人工操作结构化审计、traceId 全链路 |

## 2. 发现清单

| 来源 | 严重度 | 状态 | 说明 |
| --- | --- | --- | --- |
| S1 EV-011 | major | 已闭环 | JVM shutdown hook 脱离 Spring 生命周期 → 改 SmartLifecycle 托管，已晋升 framework-standard §5.5 |
| S1 EV-012 | major | 已闭环 | 模块命名偏离（mall-mq→mall-common-mq）未记录 → 补记 DEV-6 |
| S1 EV-013/014 | minor | 已闭环 | tableName 拼接加标识符白名单；自问式草稿注释改陈述式 |
| S2 RV-001 | major | 已闭环 | AutoConfiguration.imports 误用 spring.factories 键值格式 → 纯类名列表收口（e375c40），已晋升 framework-standard §5.6 |
| S2 RV-002 | minor | 已闭环（接受偏离） | 审计以结构化日志承载，记 DEV-2 |
| S3 RV-001 | minor | 已闭环 | evidence.yaml 未加引号 sha 被解析为 Infinity → 全量加引号，已晋升 testing-standard §8.1 |
| S3 RV-002 | minor | 已闭环（接受偏离） | ORDER_CANCELLED 对未知状态保守抛错重试，失败安全语义满足，记 DEV-3 |
| S4 RV-001 | minor | 已闭环 | verify 基本类型 long 误用 any() 拆箱 NPE → anyLong() |
| S4 RV-002 | minor | 已闭环（接受规避） | harness 0.5.0 `--du` 的 join 未定义 bug → 以不带 --du 的 run 推进 |
| S5 RV-001 | major | 已闭环 | 执行器列表化引入构造器循环（集成上下文 31 错误）→ ObjectProvider 延迟解析 + 保留单测构造器，已晋升 framework-standard §5.7 |
| S5 RV-002 | minor | 已闭环 | 权限码切换后测试授权同步切 system:compensation:* |
| 外部事项 | info | 非本批 | mall-identity 3 个既有失败对照确认与 M7 无关；各 Story 均不处理 |

无遗留 blocker/major。

### 观察项（不阻断，统一归 M7 Integration Gate）

- 支付→确认扣减、取消→释放、真实并发重复消费、乱序裁决、MQ 停启续投、DLQ 补偿、延迟到期取消的真实多服务运行态：单测/切片/真实 broker IT 已出证，七场景在联调环境串验。
- force-level 配置用于联调短延迟验证；生产默认延迟级别由超时参数动态映射。

### 红线核对

- 未手改 `.sdd/`；状态全部经 openspec workflow/gate 推进。
- 本地提交未 push（当前授权范围）。
- 未把实现细节写入 standards/；Spec 候选待人工评审，未直接落 product/specs/。

## 3. 完成确认

- [x] 5 个 Story review-report 均 accepted
- [x] 无开放 blocker/major；观察项均归 Integration Gate
- [x] 仓指针经 `openspec du sync-status CHG-0025` 对账（result == 各仓 HEAD）
- [x] 43 条 AC 全局对照完成（见 convergence.md §4）

Change 可判 completed。
