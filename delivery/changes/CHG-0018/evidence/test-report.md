# Test Report（Change 级聚合）— CHG-0018 购物车

> 阶段：sdd-test 产物。各 Story 明细见对应 Story evidence/test-report.md。

## 0. 元信息

- Change ID：CHG-0018
- 执行时间：2026-09-16
- 覆盖：AC-001~AC-022

## 1. 测试执行汇总

| Story | 模块 | 结果 |
| --- | --- | --- |
| 核心操作 | mall-cart | 41/41 |
| 实时校验 | mall-cart | 41/41（含读模型 18） |
| 游客合并 | mall-cart | 53/53（含合并 12） |
| 游客合并 | mall-product | 95/95 |
| 游客合并 | mall-web | 85/85（三检全绿） |

## 2. AC 覆盖

| AC | 覆盖 Story |
| --- | --- |
| AC-001~007 | Story 1 |
| AC-008~013 | Story 2 |
| AC-014 | Story 1 |
| AC-015~020 | Story 3 |
| AC-021 | Story 2 |
| AC-022 | Story 3 |

## 3. 证据

- Story 1：`delivery/changes/CHG-0018/商城前台/购物车/会员购物车/购物车核心操作/evidence/test-report.md`
- Story 2：`delivery/changes/CHG-0018/商城前台/购物车/会员购物车/购物车实时校验/evidence/test-report.md`
- Story 3：`delivery/changes/CHG-0018/商城前台/购物车/游客购物车与合并/游客购物车与登录合并/evidence/test-report.md`
