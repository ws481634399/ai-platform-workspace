# Test Design（Change 聚合兼容层）

## 0. 元信息

- Change ID：CHG-0014
- Feature Path：商品与库存 / 商品与 SKU 管理 / 商品主数据 / 商品 SPU 管理
- 权威来源：`商品与库存/商品与 SKU 管理/商品主数据/商品 SPU 管理/test-design.md`
- TC 总数：9

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU |
| --- | --- | --- | --- |
| TC-001 | Product 聚合创建集成测试 | AC-001 | DU-BE-401 |
| TC-002 | 空/非法 SKU 回滚测试 | AC-002 | DU-BE-401 |
| TC-003 | 图片与属性 payload 测试 | AC-003 | DU-FE-402 |
| TC-004 | 初始 SKU payload 测试 | AC-004 | DU-FE-402 |
| TC-005 | Mall Product route 契约测试 | AC-005 | DU-BE-401 |
| TC-006 | Internal Product route 契约测试 | AC-006 | DU-BE-401 |
| TC-007 | Inventory SERVICE 安全矩阵测试 | AC-007 | DU-BE-401 |
| TC-008 | login 401 refresh 回归测试 | AC-008 | DU-FE-402 |
| TC-009 | test/type-check/lint/build | AC-009 | DU-FE-402 |

## 2. 测试策略

根级文件只用于兼容当前 Harness 的 Change 聚合门禁。执行细节、数据准备与环境约束以 Story 级 `test-design.md` 为准；后端使用 Spring/H2 与安全集成测试，前端使用 Vitest 纯函数测试并补桌面浏览器检查。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

DU-BE-401 先冻结创建契约，DU-FE-402 再消费；两个 DU 均已 completed。
