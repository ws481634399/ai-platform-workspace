# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0015
- Story ID: STORY-002-03-02-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- Feature Path: 商品与库存 > 商品发布与商城查询 > 商城查询 > 商城商品列表与详情查询
- 状态流转: designed → tasked
- TC 总数: 14

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 网关集成：匿名 GET http://localhost:8080/api/mall/products → 200 且有数据 | AC-001 | DU-BE-501 | 阻塞一回归 |
| TC-002 | 网关集成：匿名 GET /api/mall/products/{id} 200；不存在/下架 → 404/不可售码 | AC-002 | DU-BE-501 | |
| TC-003 | 网关集成：外部经 8080 请求 /api/internal/products/skus/{id} → 404 denyAll | AC-003 | DU-BE-501 | 内部隔离 |
| TC-004 | 端到端：inventory 初始化真实 SKU（携带 X-Internal-Token 的 SkuClient）成功，无误报 | AC-004 | DU-BE-501 | 阻塞二回归 |
| TC-005 | 库存分页测试：33 行数据 total=33，翻页 total 恒定、筛选一致 | AC-005 | DU-BE-501 | 阻塞三/分页插件 |
| TC-006 | JSON 断言：商品列表 id 节点类型为 string，值 "2099..." 不丢精度 | AC-006 | DU-BE-501 | @StringId |
| TC-007 | JSON 断言：商品/SKU/分类/品牌/库存全部对外接口业务 ID 为字符串，嵌套一致；金额/数量/分页仍为 number | AC-007 | DU-BE-501 | 白名单审计 |
| TC-008 | API 测试：入参 ID 传 "123" 与 123 两形态均 200 同结果 | AC-008 | DU-BE-501 | 双形态兼容 |
| TC-009 | 集成测试：列表 minPrice/maxPrice=启用 SKU 价格 MIN/MAX（整数分），无 null | AC-009 | DU-BE-501 | 分组 SQL |
| TC-010 | 集成测试：全 SKU 禁用后商品从列表消失；无启用 SKU 商品不返回 | AC-010 | DU-BE-501 | EXISTS 过滤 |
| TC-011 | 前端回归：mall-admin 商品/SKU/分类/品牌/库存页列表/详情/编辑/分页/跳转冒烟 | AC-011 | DU-FE-501 | vue-tsc+手工冒烟 |
| TC-012 | 端到端：网关取 skuId 字符串原样回传，与库内 long 一致无末位偏差 | AC-012 | DU-FE-501 | 加购预演 |
| TC-013 | 安全单测：InternalIdentityFilter 无头 401、错误头 401、正确头注入 ROLE_SERVICE | AC-003 | DU-BE-501 | |
| TC-014 | 性能断言：价区聚合一次分组 SQL（SQL 计数=1，无 N+1） | AC-009 | DU-BE-501 | |

## 2. 测试策略

- Unit：InternalIdentityFilter 凭证校验、@StringId 序列化器。
- Integration：@SpringBootTest + MockMvc（H2/Testcontainers 对齐项目现状）；价区分组 SQL 与 EXISTS 过滤；分页插件。
- Gateway：针对 8080 的 WebClient/REST 集成断言匿名 200、internal 404。
- Frontend：vue-tsc/eslint/build + 五页面手工冒烟清单（test 阶段执行并截图）。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- 无跨 Change DU 依赖；TC-004 需要 product/inventory 两服务本地启动。
