# Test Report（Change 聚合兼容层）

## 0. 元信息

- Change ID：CHG-0017（商城商品浏览体验）
- Implementation 来源：`implementation.md`
- Evidence 索引：`evidence/evidence.yaml`（EV-001~026）
- 权威来源：五个 Story 目录下 `evidence/test-report.md`
  （`首页与公开分类品牌/商城首页/`、`.../公开分类与品牌查询/`、
  `商品列表与详情/商城商品列表/`、`.../商品详情与 SKU 选择/`、
  `库存状态展示/SKU 可售状态聚合/`）

## 1. 测试范围

覆盖 AC-001～AC-020，Story 级 TC 全部 passed：

| Story | 覆盖 AC |
| --- | --- |
| 商城首页 | AC-001、AC-002 |
| 公开分类与品牌查询 | AC-003、AC-004、AC-005 |
| 商城商品列表 | AC-006～AC-010、AC-020 |
| 商品详情与 SKU 选择 | AC-011～AC-014、AC-018、AC-020 |
| SKU 可售状态聚合 | AC-015、AC-016、AC-017 |
| 跨 Story 前端工程门禁 | AC-018、AC-019、AC-020 |

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | ---: | ---: | ---: | ---: |
| mall-product（最终全量） | 93 | 93 | 0 | 0 |
| mall-inventory | 24 | 24 | 0 | 0 |
| mall-gateway | 19 | 19 | 0 | 0 |
| mall-web vitest（18 个 spec，最终） | 85 | 85 | 0 | 0 |
| mall-web vue-tsc / vite build | 2 | 2 | 0 | 0 |

## 3. 证据清单

- 五个 Story 的 `evidence/test-report.md`：逐条 TC 结果与红→绿过程
  （含空 IN 退化为全表、三维度组合键误禁用、StateView props API 误用、
  DOMPurify happy-dom 降级四条真实红基线）
- EV-001~026（change evidence.yaml）：9 code-change + 8 evidence-ref + 9 test-run
- repo-1 DU evidence：DU-BE-701/702/703/704/705（MockMvc + JDBC 集成测试）
- repo-2 DU evidence：DU-FE-701/703/704（vitest happy-dom；详情净化用例 jsdom 环境）

## 4. 遗留联调项（归 M3 Test 五集成场景，不阻断本 Change）

1. 真实两进程 + 网关 + MySQL 下首页/列表/详情匿名浏览与白名单（AC-001/005/019）；
2. 真实 inventory 服务下批量三态一次调用验证（无 N+1）与故障注入 UNKNOWN 不白屏（AC-015/017）；
3. 真实浏览器规格选择全路径联动（价格/主图/三态）与加购占位行为（AC-012/014）；
4. 子孙分类/品牌多选/四档排序在真实数据量下的浏览器交互（AC-007/008）；
5. 富文本净化在真实浏览器的效果复核（AC-011）。
