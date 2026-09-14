# Test Design（Change 级聚合）— CHG-0015 商城查询前置就绪修复

> 阶段：sdd-task 聚合产物（单 Story Change）
> Story 测试设计明细：商品与库存/商品发布与商城查询/商城查询/商城商品列表与详情查询/test-design.md

- Change ID: CHG-0015
- Feature Path: 商品与库存/商品发布与商城查询/商城查询/商城商品列表与详情查询
- 覆盖 Story: STORY-002-03-02-01（14 TC）

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU |
| --- | --- | --- | --- |
| TC-001 | 网关匿名 GET /api/mall/products → 200 有数据 | AC-001 | DU-BE-501 |
| TC-002 | 匿名详情 200；不存在/下架 → 404/不可售 | AC-002 | DU-BE-501 |
| TC-003 | 外网 /api/internal/** → 404 denyAll；过滤器无头/错头 401 | AC-003 | DU-BE-501 |
| TC-004 | inventory 携 X-Internal-Token 初始化真实 SKU 成功 | AC-004 | DU-BE-501 |
| TC-005 | 库存分页 total=33 且翻页恒定 | AC-005 | DU-BE-501 |
| TC-006 | 商品 id JSON 为字符串不丢精度 | AC-006 | DU-BE-501 |
| TC-007 | 全对外业务 ID 字符串；金额/分页仍 number | AC-007 | DU-BE-501 |
| TC-008 | 入参 "123"/123 双形态等价 | AC-008 | DU-BE-501 |
| TC-009 | 价区=启用 SKU MIN/MAX 整数分；分组 SQL 计数=1 | AC-009 | DU-BE-501 |
| TC-010 | 无启用 SKU/全禁用商品不返回 | AC-010 | DU-BE-501 |
| TC-011 | mall-admin 五业务面冒烟回归 | AC-011 | DU-FE-501 |
| TC-012 | skuId 字符串端到端无末位偏差 | AC-012 | DU-FE-501 |
| TC-013 | InternalIdentityFilter 三态单测 | AC-003 | DU-BE-501 |
| TC-014 | 价区聚合一次分组 SQL 无 N+1 | AC-009 | DU-BE-501 |

## 2. 测试策略

- 后端 @SpringBootTest+MockMvc（JSON 类型/SQL 计数/分页）；网关 8080 匿名与 denyAll 矩阵；前端 vue-tsc/eslint/build + 五页面手工冒烟。
- 明细与依赖前置条件见 Story 级 test-design.md。
