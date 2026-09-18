# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0020
- Story ID: STORY-005-01-02-01
- Feature Path: 商品搜索 > 商品搜索查询 > 关键词搜索与筛选 > 商品关键词搜索
- 状态流转: designed → tasked
- TC 总数: 10

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 集成（ES IT）：bulk 4 文档（关键词分别在 name/keywords/brandName/categoryName）→ 各自可被对应关键词检出；name boost 体现在名称命中排序靠前 | AC-001 | DU-BE-502 | [S1] |
| TC-002 | 集成：含 OFF_SALE 文档数据集，任意关键词/浏览态查询均不返回下架文档（显式 status filter 兜底） | AC-002 | DU-BE-502 | [S1] |
| TC-003 | API：响应 JSON 字段白名单断言（productId/productName/mainImage/minPrice/maxPrice/brandName/categoryName...），无 skus/全量聚合字段 | AC-003 | DU-BE-502 | [S1] |
| TC-004 | 集成：造 105 条文档，page=1 size=20 默认；size=500 实际按 100 切片且 total=105；page=0/-1 回退第 1 页 | AC-004 | DU-BE-502 | [S1] |
| TC-005 | 集成：无 keyword 请求返回 ON_SALE 文档（default 排序浏览态），结构与 keyword 查询一致 | AC-005 | DU-BE-502 | [S1] |
| TC-006 | 网关/E2E：8080 无 token GET /api/mall/search/products → 200（路由+白名单） | AC-006 | DU-BE-502 | [S1] Integration Gate 联测 |
| TC-007 | 网关/E2E：经网关访问 /api/internal/search/products/sync → 404；mall-search 无可达写端点（GET 内部路径 404） | AC-007 | DU-BE-502 | [S1] |
| TC-008 | API：停 ES 场景搜索 → 503 B0501（复用 STORY-01-02 Advice，回归断言） | AC-008 | DU-BE-502 | [S1] |
| TC-009 | API：keyword 长度 65、size=0、page=abc 绑定失败 → 400 B0502 统一结构 | AC-004 | DU-BE-502 | [S1] 参数类 |
| TC-010 | 单测：ProductSearchService 参数归一（trim/null/默认值/上限）与 mapper 映射 | AC-003, AC-005 | DU-BE-502 | [S1] |

## 2. 测试策略

- ES Testcontainers 造数（含下架/无品牌/无图），bulk 后 refresh 立即查。
- 网关行为在 Integration Gate 与 dev 本地联测双保险；服务层 MockMvc 不验证路由。
- 分页边界同时验证响应分页结构字段名（供前端契约冻结）。

## 3. 不可测项标注

- 网关 AC 单测覆盖薄弱，以 Integration Gate E2E + 手工 curl evidence 替代。

## 4. 依赖与前置条件

- DU-WS-501/DU-BE-501（ES 与异常口径）；网关白名单常量。
