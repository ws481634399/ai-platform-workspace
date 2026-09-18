# Review Report — STORY-005-01-02-01 商品关键词搜索

## 0. 元信息

- Change ID：CHG-0020（M5 商品搜索）
- Story ID：STORY-005-01-02-01 商品关键词搜索
- 审查对象：DU-BE-502（repo-1：GET /api/mall/search/products、multi_match/ON_SALE/白名单摘要/分页归一、mall-gateway 匿名路由）
- Test Report 来源：`evidence/test-report.md`
- Evidence 索引：`evidence/evidence.yaml`（EV-001~EV-007）
- 检查时间：2026-09-19
- 状态：testing 检查点（不推进 Story/Change 状态）

## 1. 检查结论

**通过（1 项 major 已在 review 阶段修复并回归闭环 + 2 项开放 minor）。** 主读链路功能与冻结契约核对一致：端点八参数全部可选、multi_match（productName^3/keywords/brandName/categoryName，OR）+ 恒效 status=ON_SALE filter、ProductSearchItem 七字段白名单、分页默认 20/上限 100/越界静默归一、trackTotalHits 保 total 准确、网关路由 mall-search-mall 与 /api/mall/search/** 白名单落地；ProductSearchApiTest 9/9 真实 ES 通过。抽查曾发现 ProductSearchItem 的业务 ID 未按 api-design-standard §5.3 字符串化（EV-003，major），**已在 review 阶段修复并回归闭环**：d7dc2b0 为 productId 加 @StringId、前端 5ab0979 联动改 string（本文件 EV-006），定向回归 26 例全绿（EV-007；Change 级 EV-016~EV-019，含 mall-web 105 例）；网关运行时契约待 Gate 联测（EV-004，minor）。

### 1.1 需求一致性

| Story AC | test-run 证据 | 结论 |
| --- | --- | --- |
| AC-001 关键词命中四字段、名称加权置顶 | ProductSearchApiTest#keyword_relevance_andOnSaleOnly（keyboard 命中名称与 keywords 且名称命中置顶，"机械"命中类目/名称路径） | passed |
| AC-002 OFF_SALE 任何查询不返回 | 同方法同名 OFF_SALE 文档被恒效 term filter 剔除；#pagination 浏览态 total=105 亦不含下架文档 | passed |
| AC-003 响应仅摘要白名单字段 | ProductSearchApiTest#responseWhitelist 正断言七字段存在、反断言 keywords/status/publishedAt/updatedAt 不存在；ProductSearchItem record 源码七字段 | passed（字段集合；ID 序列化形态已修复——productId 经 @StringId 字符串直出，EV-003 已闭环，EV-007 回归 26/26） |
| AC-004 分页切片正确、size 越界限 100、page<1 回退 1 | ProductSearchApiTest#pagination（默认 20/total=105、size=999→100、尾页 5、page=0→page=1） | passed（静默归一口径与 spec AC-004 一致；test-design 的 400 设想差异已在 DU DEV-1 记录） |
| AC-005 无 keyword 浏览态返在售商品 | #pagination 无参 total=105（must 不加、filter 恒效） | passed |
| AC-006 网关无 token 访问 200（不 401） | gateway application.yml 路由 mall-search-mall（Path=/api/mall/search/**→8107）+ GatewaySecurityConfiguration 白名单 permitAll 配置物核对 | partial（配置已落地，无网关自动化，运行时 200 证据待 Gate，见 EV-004） |
| AC-007 /api/internal/** 经网关 404、无可达写端点 | 网关无 internal 搜索路由、/api/internal/** denyAll 且匿名/认证均回 404 源码核对；MallSearchController 仅一个 GET | partial（配置/源码核对通过，运行时 404 证据待 Gate，见 EV-004） |
| AC-008 ES 故障统一 B05xx | #missingIndex_throws + SearchExceptionAdviceTest 连接/超时/404 三例 | passed（沿用 STORY-005-01-01-02 结论） |

### 1.2 设计一致性

- API 契约：MallSearchController 源码实测八参数（keyword/categoryId/brandId/minPriceFen/maxPriceFen/sort/page/size，均 required=false）与 §4 冻结一致；UnifyResult<SearchPage<ProductSearchItem>> 包裹；SearchPage{items,total,page,size} record 与冻结一致。
- DSL 口径：适配器 bool.must 仅 keyword 非空时追加 multi_match（四字段、productName^3、Operator.OR），filter 恒含 term status=ON_SALE，DEFAULT 排序 _score desc+updatedAt desc，from/size 与 trackTotalHits 与设计 §2.1 一致。
- 模块职责：Controller 仅收参转发，归一枚举在 ProductSearchService，DSL 在 Adapter，端口 ProductSearchPort 位于 domain——分层符合 api-design-standard §3.1。
- Deviations 完整性：DU-BE-502 DEV-1（分页静默归一替代 test-design 的 400 设想、非数字绑定走框架异常未映 B0502）、DEV-2（白名单由 story-design 九字段收紧为七字段，categoryId/brandId 仅留读模型供过滤）、DEV-3（端口/适配器命名与安全链合并成型）、DEV-4（同提交 FeatureGate 切点 fail-open）均四要素记录；其中 DEV-2 与 spec §4 摘要契约一致，前端类型同步为七字段，记录可接受。
- 网关：直连 8107 与既有路由同风格，可由 MALL_GATEWAY_SEARCH_URI 覆盖；服务内 SearchSecurityConfiguration 对 /api/mall/** permitAll 双保险，/api/internal/** 需 SERVICE 角色，纵深一致。

### 1.3 跨仓一致性

§4 契约的 repo-1→repo-2 段抽查：前端 api/search.ts 路径、八参数名、UnifyResult 解包、SearchPage{items,total,page,size} 与七字段命名均与后端一致；网关 8080 路由/白名单闭合匿名访问链路。跨仓一处类型矛盾已修复闭环：业务 ID 序列化形态原后端裸 Long number ↔ 规范要求 string（mall-product 全部公开 DTO 已 @StringId、catalog.ts 全部 id 为 string），见 EV-003；d7dc2b0 后端加 @StringId、5ab0979 前端改 string 后两侧口径一致（EV-006/EV-007）。repo-4→repo-1 段（ES 8.17.4/别名 mall_products 缺省不阻断启动）与 STORY-005-01-01-01 结论一致。

### 1.4 代码质量

对照 standards 明确条目抽查：

- api-design-standard §5.1/§5.2：独立响应 record、不直出 ES _source（Document→Item 显式映射七字段）、统一 UnifyResult——符合。
- api-design-standard §8 分页结构：items/page/size/total 形状一致——符合。
- api-design-standard §10 参数安全：sort/分页均白名单化或收敛，无字符串拼接进 DSL（ES Client Builder 强类型）——符合。
- **违规一项，已修复闭环**：§5.3"对外 DTO 业务 ID 必须序列化为 JSON 字符串（统一 @StringId）；金额/分页保持 number；前端 ID 类型声明 string"——ProductSearchItem.productId 原为裸 Long 序列化为 number，同仓 mall-product 公开 DTO 均已 @StringId，本服务曾为唯一例外（EV-003，major）；d7dc2b0 已加 @StringId（入参保持 Long）并同步断言，EV-006/EV-007 闭环。
- testing-standard：9 例全部真实 ES Testcontainers，含正反白名单断言；归一/mapper 无独立纯单测但经集成链路覆盖（EV-005，minor）。

### 1.5 知识同步候选

无（本 Story 相关的 B05xx 异常归一、ES 8.x 版本与 PIT 知识已在 STORY-005-01-01-01/02 报告 §1.5 提名）。

## 2. 发现清单

| EV id | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-003 | mall-search `domain/search/ProductSearchItem.java`（productId）；联动 repo-2 `src/api/search.ts` | major | productId 以裸 Long number 直出，违反 api-design-standard §5.3 业务 ID 字符串化强制要求，且与 mall-product 全部公开 DTO 使用 @StringId、mall-web catalog.ts 全部 id:string 的既有口径不一致；真实雪花 ID（超 2^53）在前端解析末位丢失，点搜索结果卡片可能进入错误详情页 | **已闭环（review 阶段修复并回归）**：d7dc2b0 为 ProductSearchItem.productId 加 common-web `@StringId`（入参仍保持 Long），ProductSearchApiTest#responseWhitelist 与 IndexSyncIntegrationTest 断言同步期望字符串；repo-2 5ab0979 将 productId 等 ID 改 string 并更新 search.spec.ts；本文件 EV-006 登记提交、EV-007 定向回归 26/26 全绿（Change 级 EV-016~EV-019，含 mall-web 105 例） |
| EV-004 | Story AC-006/AC-007；mall-gateway application.yml、GatewaySecurityConfiguration | minor | 匿名 200 与 /api/internal/** 404 仅配置物+源码核对，无网关运行时自动化证据（test-design §3 既定以 Gate E2E/curl 替代） | 处置去向：M5 Integration Gate 以 curl/E2E 闭合 8080 无 token 200 与 internal 404，含场景一 mall-web→8080→mall-search 全链路 |
| EV-005 | `application/search/ProductSearchService.java` 归一/mapper；DU-BE-502 DEV-1 | minor | 参数归一（trim/默认 20/上限 100/超长拒绝）与 hits→Item 映射无独立纯单测，经 ProductSearchApiTest 真实 ES 9 例间接覆盖，故障定位粒度粗于纯单测；非数字绑定异常未映 B0502（已在 DEV-1 记录） | 处置去向：维持集成覆盖（已有等价断言强度），或在后续 Change 补 QueryNormalize 纯单测与 MethodArgumentTypeMismatchException→B0502 映射；联调补非数字参数 curl 证据 |

无 blocker。EV-003 major 已在 review 阶段修复并回归闭环（EV-006 提交、EV-007 回归 26/26）；EV-004/EV-005 两项 minor 允许随 Gate 或后续迭代处置，去向已在 resolution 明确。

## 3. 完成确认

- [x] 四项检查全部执行（需求/设计/跨仓/代码质量）
- [x] 全部 blocker/major finding 已闭环（无 blocker；EV-003 major 已由 d7dc2b0/5ab0979 修复，EV-007 定向回归 26/26 全绿）
- [x] minor finding 已记录（EV-004/EV-005，允许开放，处置去向明确）
- [x] 知识同步候选已写入 §1.5（本 Story 无新增）
- [x] 跨仓一致性已核对（八参数/分页/错误段一致；原 ID 类型矛盾 EV-003 已修复闭环）
