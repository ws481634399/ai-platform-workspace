# Test Report（Change 聚合兼容层）

## 0. 元信息

- Change ID：CHG-0016（商城会员与地址）
- Implementation 来源：`implementation.md`
- Evidence 索引：`evidence/evidence.yaml`（EV-001~021）
- 权威来源：四个 Story 目录下 `evidence/test-report.md`
  （`商城前台/商城会员/会员注册与认证/商城会员注册/`、`.../商城会员登录与会话/`、
  `.../会员资料/会员资料维护/`、`.../收货地址/收货地址管理/`）

## 1. 测试范围

覆盖 AC-001～AC-025，34 条 Story 级 TC 全部 passed：

| Story | TC 数 | 覆盖 AC |
| --- | ---: | --- |
| 商城会员注册 | 9 | AC-001~007 |
| 商城会员登录与会话 | 8 | AC-008~013 |
| 会员资料维护 | 6 | AC-016~018（+AC-025 前端门禁） |
| 收货地址管理 | 11 | AC-019~024（+AC-025 前端门禁） |
| 前端工程门禁（跨 Story） | — | AC-014/015、AC-025 |

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | ---: | ---: | ---: | ---: |
| 后端 Maven 全量（24 模块，最终） | 311 | 311 | 0 | 0 |
| 前端 Vitest（mall-web，12 个 spec） | 58 | 58 | 0 | 0 |
| 前端 type-check（vue-tsc 双 tsconfig）/ lint（0 error）/ build | 3 | 3 | 0 | 0 |

## 3. 证据清单

- 四个 Story 的 `evidence/test-report.md`：逐条 TC 结果与红→绿过程
- EV-001~021（change evidence.yaml）：7 code-change + 7 evidence-ref + 7 test-run
- repo-1 DU evidence：DU-BE-601/602/603/604 的 evidence/（red-green.md + logs，含
  CountDownLatch 并发默认唯一、双会员越权矩阵、V2 生成列迁移与 H2/MySQL 方言验证）
- repo-2 DU evidence：DU-FE-601/602/603 的 evidence/logs/（test/type-check/lint/build 四检）

## 4. 遗留联调项（归 M3 Test，不阻断本 Change）

1. 真实两进程 member 不可用 30s 重试与登录缺档补偿（AC-006）；
2. 刷新页面 restore 与 access 过期单飞刷新（AC-014/015）真实浏览器复验；
3. 真实 MinIO 9000 合规头像上传与对象存储不通时 503 隔离（AC-018）；
4. 浏览器端头像编辑与越权矩阵 toast（AC-017/021）；
5. 真实 MySQL 8 V2 生成列迁移与并发设默认 409 复验（AC-022，DU-BE-604 DEV 已登记，
   H2 可能串行化并发，用例容忍两种结局）。
