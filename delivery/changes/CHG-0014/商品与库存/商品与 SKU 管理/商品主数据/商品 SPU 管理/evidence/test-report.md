# Test Report — 商品 SPU 管理 STORY-002-02-01-01

> 阶段：sdd-test 产物

## 0. 元信息

- Change ID：CHG-0014
- Story ID：STORY-002-02-01-01
- 执行时间：2026-09-14
- 覆盖：AC-001～AC-009

## 1. TC 执行结果

| TC | 验证 | 结果 |
| --- | --- | --- |
| TC-001 | Product+SKU+图片+属性合法聚合创建 | passed |
| TC-002 | 空/非法 SKU 拒绝且事务不留残存 Product | passed |
| TC-003 | mall-admin 图片、主图、属性维护与回显 | passed |
| TC-004 | 创建前 SKU 维护并进入聚合 payload | passed |
| TC-005 | 匿名 Mall Product Gateway route | passed |
| TC-006 | 已认证 Internal Product Gateway route | passed |
| TC-007 | Inventory anonymous/ADMIN/SERVICE 权限矩阵 | passed |
| TC-008 | login 401 不触发 refresh | passed |
| TC-009 | mall-admin 四项质量门 | passed |

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | ---: | ---: | ---: | ---: |
| 后端 Maven reactor | 171 | 171 | 0 | 0 |
| 前端 Vitest | 31 | 31 | 0 | 0 |
| 前端 type-check/lint/build | 3 | 3 | 0 | 0 |
| 浏览器桌面检查 | 1 | 1 | 0 | 0 |

## 3. 证据位置

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0014/商品与库存/商品与 SKU 管理/商品主数据/商品 SPU 管理/DU-BE-401/evidence/`
- repo-2：`implementation/ai-platform-frontend/delivery/CHG-0014/商品与库存/商品与 SKU 管理/商品主数据/商品 SPU 管理/DU-FE-402/evidence/`

## 4. 结论

AC-001～AC-009 全部通过。评审中补充 TC-003/004 的 payload 自动化测试并修复异步错误收口后，前端回归增至 31 项。手机端和 M3 mall-web 页面依照范围声明未实施。
