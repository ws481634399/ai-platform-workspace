# Test Report — STORY-005-01-02-03 mall-web 商品搜索体验

> 阶段：sdd-test 产物（Story 级）。

## 0. 元信息

- Change ID：CHG-0020（M5 商品搜索）
- Story ID：STORY-005-01-02-03
- 执行时间：2026-09-19
- 覆盖 AC 范围：AC-001 ~ AC-006（逐条见 §3）
- 覆盖 TC 范围：TC-001 ~ TC-007（逐条对齐本 Story `test-design.md` §1）
- 实施来源：DU-FE-501（repo-2 ai-platform-frontend / mall-web），commit `ec0921b`

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| TC-001 | 搜索框输入回车 → router push /search?keyword=；SearchView 回显关键词、渲染卡片（图/名/价/品牌） | 组件测试 + 浏览器（test-design 双层）——本阶段无 SearchView 组件 spec，浏览器 E2E 归 Integration Gate | 待联测 | 实现物：`src/views/search/SearchView.vue`、`src/router/index.ts` /search 路由（commit ec0921b）；本 Story `implementation.md` §4 AC-001（Header 全局框实际跳 /products?keyword= 的入口差异见 DU-FE-501 DEV-1） |
| TC-002 | 分类/品牌/价格/排序控件触发请求参数正确；分页；URL→状态回填与状态→URL 同步 | API 序列化层已有自动化；控件/URL 同步无组件 spec，浏览器验证归 Integration Gate | partial | `src/api/search.spec.ts`#「serializeSearchQuery 完整参数：ID/价区/分页转字符串，sort 原样传递」、#「serializeSearchQuery 空参数与默认排序（""）全部省略」、#「serializeSearchQuery 三种排序值均可透传」（证明控件发出的 query 经序列化参数正确）；SearchView route.query 唯一状态源为实现物核对，无 UI 断言 |
| TC-003 | 空结果空态（含分类浏览引导）、loading 骨架、503/网络错误 Error 态 + 重试按钮点击重发 | 组件测试 —— 无 SearchView/store 专属 spec | 待联测 | 实现物：SearchView StateView 三态、stores/search.ts resolveErrorMessage（commit ec0921b）；行为断言留待组件测试补齐或 Integration Gate 浏览器验证 |
| TC-004 | 点击卡片进入 /product/:id 详情页正常渲染并可返回 | 浏览器 E2E（test-design 标注 Integration Gate） | 待联测 | 实现物：SearchView 卡片 router.push('/products/'+id)；router products/:id → ProductDetailView 路由存在（commit ec0921b） |
| TC-005 | 价格输入「120」元 → 请求 minPriceFen=12000；min>max 前端即时提示且不发请求 | API 参数层自动化 + 视图换算/拦截无 spec | partial | `src/api/search.spec.ts`#「serializeSearchQuery 价格 0 分边界保留（!= null 判定，非真值判定）」（分单位参数原样透传/0 值保留）；元↔分 Math.round 换算与「最低价格不能高于最高价格」拦截在 SearchView 内实现，无自动化断言，浏览器联调补 |
| TC-006 | stores/search.ts 成功/空/失败三态 action；快速连续查询仅最后一次落屏（竞态） | Vitest —— stores/search 无专属 spec（文件不存在），现有自动化仅覆盖 API 层 | partial | `src/api/search.spec.ts`#「products 命中 GET /api/mall/search/products 并解包分页摘要」（成功态解包链路）共 5 例覆盖 API 客户端；store 三态与 requestSeq 竞态丢弃无自动化断言（实现物：stores/search.ts requestSeq 序号防护，commit ec0921b） |
| TC-007 | 构建门禁：type-check、lint、test、build 全绿 | pnpm 脚本（2026-09-19 实跑） | passed | 日志四件：`mall-web-vitest.log`（Test Files 21 passed / Tests 102 passed，含 src/api/search.spec.ts 5 tests）、`mall-web-type-check.log`（vue-tsc 0 error）、`mall-web-lint.log`（0 errors，65 warnings）、`mall-web-build.log`（✓ built，SUCCESS） |

> `src/api/search.spec.ts` 5 例（describe「商城商品搜索 API（CHG-0020 FE-501）」）：① products 命中 GET /api/mall/search/products 并解包分页摘要；② serializeSearchQuery 空参数与默认排序全部省略；③ serializeSearchQuery 完整参数序列化；④ 价格 0 分边界保留；⑤ 三种排序值透传。

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
| --- | --- | --- |
| mall-web 单测 | `pnpm -C mall-web exec vitest run` | **21 files / 102 tests 全部 passed**；其中 `src/api/search.spec.ts` **5/5** 为本 Story 用例，其余 97 例为回归 |
| mall-web 类型检查 | `pnpm -C mall-web type-check`（vue-tsc --noEmit 双 tsconfig） | **0 error** |
| mall-web lint | `pnpm -C mall-web lint` | **0 error**，65 warnings（既有风格告警，无新增阻断） |
| mall-web 构建 | `pnpm -C mall-web build` | **SUCCESS**（✓ built in 519ms） |
| 日志目录 | `delivery/changes/CHG-0020/evidence/logs/` | mall-web-vitest.log / mall-web-type-check.log / mall-web-lint.log / mall-web-build.log |

通过率：本 Story 自动化用例（API 层）**5/5 = 100%**，构建门禁 4/4 全绿；TC 维度 TC-007 passed、TC-002/TC-005/TC-006 partial、TC-001/TC-003/TC-004 按 test-design 既定策略待 Integration Gate 浏览器联测。

## 3. AC 覆盖

| AC | 覆盖 TC |
| --- | --- |
| AC-001 | TC-001 |
| AC-002 | TC-002 |
| AC-003 | TC-003 |
| AC-004 | TC-004 |
| AC-005 | TC-005 |
| AC-006 | TC-006、TC-007 |

## 4. 备注 / 缺口

- **AC-006 整体判定为 partial**：门禁（type-check/lint/test/build）与 API 客户端 5 例全绿，但 `src/stores/search.spec.ts` 与 `src/views/search/SearchView` 专属 spec 不存在（DU-FE-501 DEV-2 已记录），store 成功/空/失败三态、requestSeq 竞态丢弃、URL query 双向同步、三态渲染与重试、元分换算拦截均无自动化断言，需后续补组件/store 测试或以 Integration Gate 浏览器联测闭合。
- **AC-001/AC-003/AC-004 依赖浏览器验证**：test-design §2 策略即为「Vitest 组件 + 浏览器验证放 Integration Gate」；本阶段仅完成实现物落地与构建门禁，搜索→筛选→排序→详情→返回的完整手工链路在 M5 Integration Gate 场景一执行。
- 入口差异（非阻断）：SearchView 页内搜索框与 nav「搜索」入口符合设计；Header 全局搜索框实际跳转 `/products?keyword=` 列表页而非 `/search`（DU-FE-501 DEV-1），功能可达但与设计入口存在偏差，联调时确认产品口径。
