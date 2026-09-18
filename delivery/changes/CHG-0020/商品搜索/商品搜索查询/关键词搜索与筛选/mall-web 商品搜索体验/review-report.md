# Review Report — STORY-005-01-02-03 mall-web 商品搜索体验

## 0. 元信息

- Change ID：CHG-0020（M5 商品搜索）
- Story ID：STORY-005-01-02-03 mall-web 商品搜索体验
- 审查对象：DU-FE-501（repo-2：api/search.ts、stores/search.ts、views/search/SearchView.vue、/search 路由与入口）
- Test Report 来源：`evidence/test-report.md`
- Evidence 索引：`evidence/evidence.yaml`（EV-001~EV-010）
- 检查时间：2026-09-19
- 状态：testing 检查点（不推进 Story/Change 状态）

## 1. 检查结论

**通过（2 项 major 已在 review 阶段修复并回归闭环 + 4 项开放 minor）。** 已落地部分质量良好：搜索 API 客户端与后端八参数/七字段/SearchPage 契约对齐（空值省略、0 分边界保留、三排序透传 5 例 vitest），Pinia store 三态与 requestSeq 竞态丢弃实现完整，SearchView 以 route.query 为唯一状态源（watch fullPath immediate）、四排序 Tab、价格元分 Math.round 换算与倒置拦截、StateView 三态、重试、卡片跳既有 /products/:id、/search 路由真实存在；review 回归 type-check/lint/test(22 files/105 例)/build 全绿。抽查源码曾发现：分类/品牌两维筛选在页面与全站均无可操作入口（EV-003，major，AC-002 未完整满足且 Deviations 未记录）；productId 类型违反 ID 字符串化规范（EV-004，major，与 STORY-005-01-02-01 EV-003 联动）。**两项 major 均已在 review 阶段修复并回归闭环**：5ab0979 新增分类树/品牌下拉控件、productId 等 ID 改 string 并新增 SearchView.spec 3 例（本文件 EV-009），mall-web 全量 105 例回归全绿（EV-010）。

### 1.1 需求一致性

| Story AC | test-run 证据 | 结论 |
| --- | --- | --- |
| AC-001 搜索框回车进 /search、回显关键词、展示结果卡片 | SearchView 页内搜索框 submitKeyword→router.replace name:search 并回显；卡片渲染图/名/价/品牌（SearchView 源码）；nav「搜索」入口存在。Header 全局框实际跳 /products?keyword=（DU DEV-1 已记录） | partial（实现落地，无组件/浏览器自动化，全链路待 Gate，见 EV-006/EV-007） |
| AC-002 分类/品牌/价格筛选与四排序、分页可操作，URL 双向同步、刷新一致 | 价格两输入框+四排序 Tab+上一页/下一页均已实现；route.query 解析/回填/buildRouterQuery 对 categoryId/brandId 透传且刷新保留。**分类树/品牌下拉控件已由 5ab0979 补齐**（写 URL 回第 1 页），SearchView.spec 3 例覆盖筛选渲染/URL 同步 | passed（EV-003 major 已闭环，EV-009/EV-010；浏览器全链路操作待 Gate，见 EV-006 minor） |
| AC-003 空/加载/失败三态、失败可重试 | StateView 承载 loading/error/empty，store resolveErrorMessage 归一文案，retry 重发；空态有热门词出口 | partial（实现落地；SearchView.spec 已覆盖部分视图行为，store 三态行为断言与浏览器验证待补，见 EV-005/EV-006） |
| AC-004 点卡片进既有详情页正常渲染 | onCardClick→router.push('/products/'+id)，router products/:id→ProductDetailView 路由存在；SearchView.spec 含雪花大整数 ID 跳转断言（ID 已为 string，精度风险消除） | passed（组件断言；浏览器跳转待 Gate，见 EV-006） |
| AC-005 元→分换算正确、非法区间即时提示不发请求 | yuanToFen=Math.round(yuan*100)；min>max 置"最低价格不能高于最高价格"且不改 URL/不发请求；search.spec.ts 覆盖 minPriceFen:0 边界保留 | partial（API 层 0 边界自动化通过；视图换算/拦截随 SearchView.spec 部分覆盖，store 联动无 spec，见 EV-005） |
| AC-006 vitest store 三态/竞态/query 同步通过；type-check/lint/build 通过 | review 回归门禁四件全绿（vitest 22 files/105 例：src/api/search.spec.ts 5 例 + 新增 src/views/search/SearchView.spec.ts 3 例 + 既有回归；type-check 0 error；lint 0 error/65 warnings；build SUCCESS，EV-010）；stores/search.spec.ts 仍不存在 | partial（门禁与 API/视图层 passed；store 专属测试仍缺，见 EV-005） |

### 1.2 设计一致性

- store 设计：state 最小集 + requestSeq 序号竞态（旧响应不落屏、loading 仅末次请求收尾）+ catch 归一文案，符合 state-management-standard §5/§8（单一来源、loading/error 显式）；query 唯一真实来源放在 URL（SearchView），store 不重复维护条件真相，无多源状态。
- URL 状态机：parseRouteQuery 非法值回退默认、buildRouterQuery 空值省略且 page>1 才带、watch fullPath immediate 覆盖进入/刷新/前进后退，与 story-design §1/§4 一致。
- 三态/重试/错误不清 URL 条件、关闭态（CHG-0022 fail-open）额外出口，与设计 §4 错误处理一致。
- Deviations 完整性：DU-FE-501 DEV-1（Header 全局框跳 /products?keyword=、详情路由复数 /products/:id）、DEV-2（store/视图专属测试缺）、DEV-3（同提交 CHG-0022 关闭态）均记录；评审曾发现"分类/品牌筛选控件未交付"与 story-design §1（类目 select、品牌 brandId 输入/首页品牌卡携带）和 story-spec AC-002 的实质偏差未在任何 Deviations 与 Story 实施 AC 表中标注（EV-003）——**该偏差已以功能补齐方式闭环**：5ab0979 新增分类树/品牌下拉控件并补 SearchView.spec 3 例（EV-009/EV-010）。
- 卡片字段：SearchView 使用 productName/mainImage/minPrice/maxPrice/brandName/categoryName，与后端七字段命名一致（PriceText 渲染分、无图片占位）。

### 1.3 跨仓一致性

对 requirement-design §4 八参数契约的消费核对：路径、参数名（含 minPriceFen/maxPriceFen 整数分）、sort 四值、UnifyResult.data 解包、SearchPage 形状一致；错误码 B0501/B0502 经既有拦截器→error 态承接。评审发现的两处跨仓问题均已修复闭环：

1. 业务 ID 类型：api/search.ts 原声明 `productId: number`（注释明示"后端 long 直出"），与 api-design-standard §5.3 及 catalog.ts 全量 `id: string` 口径矛盾（EV-004，major；后端修复见 STORY-005-01-02-01 EV-003）——已闭环：5ab0979 将 productId/categoryId/brandId 改 string（EV-009/EV-010）。
2. 后端已实现的 categoryId/brandId 过滤能力在前端原无操作入口，跨仓"能力→UI"闭环曾断在最后一段（EV-003）——已闭环：5ab0979 落地分类树/品牌下拉并写 URL 回第 1 页（EV-009/EV-010）。

### 1.4 代码质量

对照 standards 明确条目抽查：

- state-management-standard：setup store 命名（useSearchStore）、领域拆分、异步三态、竞态防护、无直接共享态修改——符合。
- component-standard §2/§7：StateView/PriceText 复用既有组件、props/事件清晰；SearchView 为页面组件承担组合尚合理，但全文 829 行（含约 280 行样式，脚本+模板约 455 行）超过 §9.1"单文件 300–500 行应评估拆分"的评估线（EV-008，minor）。
- api-design-standard §5.3 前端对应约定（"API 层 ID 类型声明为 string；禁止 Number(id) 转换"）：search.ts 原违规（EV-004）已由 5ab0979 改 string 闭环（EV-009/EV-010）。
- testing-standard §2.3/§6：API 层自动化到位；store 竞态与视图 URL 同步/三态原为高交互风险点却无组件测试，且 test-design 本已计划（EV-005，minor）——视图部分已由 SearchView.spec 3 例闭环，store 纯单测仍缺。
- lint 0 error、65 warnings 为既有风格告警，无新增阻断。

### 1.5 知识同步候选

无（搜索 store 的 requestSeq 竞态范式与既有 store 风格一致，无新规范候选）。

## 2. 发现清单

| EV id | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-003 | `src/views/search/SearchView.vue`；联动首页/布局入口；Story AC-002、Change AC-015 | major | 结果页只有关键词/价格/排序/分页控件，无分类下拉与品牌 ID 输入；HomeView 分类卡、商品详情面包屑均跳 /products?categoryId=，全站无携带 categoryId/brandId 进入 /search 的入口——用户无法在 UI 上操作分类/品牌筛选（URL 直拼与后端能力本身可用），spec S5/AC-015 与本 Story AC-002 未完整满足，且 DU-FE-501 Deviations 未记录该偏差 | **已闭环（review 阶段修复并回归）**：5ab0979 在 SearchView 新增分类树选择与品牌下拉（复用既有分类树接口），经 buildRouterQuery 写 URL 并重置 page=1，新增 SearchView.spec 3 例（筛选渲染/URL 同步/雪花 ID 详情跳转）；本文件 EV-009 登记提交、EV-010 全量 105 例全绿；浏览器全链路操作留 Integration Gate（EV-006） |
| EV-004 | `src/api/search.ts`（ProductSearchItem.productId、ProductSearchQuery 注释）；联动 SearchView onCardClick | major | productId 声明为 number，违反 api-design-standard §5.3"前端 API 层 ID 必须 string、禁止 Number(id)"，且与 catalog.ts 全量 string 及后端 mall-product 公开 DTO @StringId 口径不一致；后端当前 number 直出，真实雪花 ID 会末位丢失并导致详情跳错 | **已闭环（review 阶段修复并回归）**：随后端 d7dc2b0 ProductSearchItem @StringId 修复（STORY-005-01-02-01 EV-003），5ab0979 将 productId/categoryId/brandId 改 string（路由模板插值与 query 传参天然兼容），search.spec.ts 类型断言同步；本文件 EV-009/EV-010 回归全绿（后端 26 例见 Change EV-016/EV-018） |
| EV-005 | `src/stores/search.ts`、`src/views/search/SearchView.vue`（缺 spec）；Story AC-006 | minor | stores/search.spec.ts 与 SearchView 专属 spec 原均不存在：成功/空/失败三态、requestSeq 乱序丢弃、URL query 双向同步、三态渲染/重试、元分换算拦截均无自动化断言；test-design 已计划 Vitest 组件/store 测试 | 视图部分已由 5ab0979 新增 SearchView.spec 3 例闭环（筛选渲染/URL 同步/雪花 ID 详情跳转，EV-009/EV-010）；store 三态/竞态纯单测仍缺，处置去向：补 stores/search.spec.ts 或以 Integration Gate 浏览器联测闭合，技术债允许开放 |
| EV-006 | Story AC-001/AC-003/AC-004；test-design 浏览器策略 | minor | 搜索→筛选→排序→详情→返回的完整浏览器链路本阶段无 E2E 证据（test-design 既定浏览器验证放 Gate） | 处置去向：M5 Integration Gate 场景一执行浏览器全链路并留存证据（含 EV-003 控件补齐后） |
| EV-007 | `src/layouts/MallLayout.vue` submitSearch；DU-FE-501 DEV-1 | minor | Header 全局搜索框回车跳 /products?keyword=（商品列表页）而非 /search，与 story-design"全局搜索框→/search"描述有差异；/search 仅 nav 链接与页内框可达 | 处置去向：Gate 联调时由产品确认入口口径；若需统一进搜索工作台，改 submitSearch 跳转目标即可（已记录偏差，非阻断） |
| EV-008 | `src/views/search/SearchView.vue`（829 行） | minor | 单文件超过 component-standard §9.1 的 300–500 行评估线（含大段样式），工具条/结果卡片/价格表单内聚可拆 | 处置去向：后续迭代拆 SearchToolbar/SearchPriceForm/SearchCard 子组件并将样式按组件归属，当前不阻断功能 |

无 blocker。两项 major（EV-003/EV-004）已在 review 阶段修复并回归闭环（5ab0979，本文件 EV-009 提交、EV-010 mall-web 全量 105 例全绿；后端联动见 Change EV-016/EV-018）；4 项 minor（EV-005~EV-008）允许随 Gate 或后续迭代处置，去向已在 resolution 明确。

## 3. 完成确认

- [x] 四项检查全部执行（需求/设计/跨仓/代码质量）
- [x] 全部 blocker/major finding 已闭环（无 blocker；EV-003/EV-004 两项 major 已由 5ab0979 修复，EV-010 全量 105 例回归全绿）
- [x] minor finding 已记录（EV-005~EV-008，允许开放，处置去向明确；EV-005 视图部分已闭环）
- [x] 知识同步候选已写入 §1.5（本 Story 无新增）
- [x] 跨仓一致性已核对（八参数/分页/错误段一致；ID 类型与筛选入口两处断裂已修复闭环）
