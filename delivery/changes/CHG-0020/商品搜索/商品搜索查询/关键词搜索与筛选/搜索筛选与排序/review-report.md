# Review Report — STORY-005-01-02-02 搜索筛选与排序

## 0. 元信息

- Change ID：CHG-0020（M5 商品搜索）
- Story ID：STORY-005-01-02-02 搜索筛选与排序
- 审查对象：DU-BE-511（repo-1：categoryId/brandId term、价格区间相交 range、四排序、参数 400 校验）
- Test Report 来源：`evidence/test-report.md`
- Evidence 索引：`evidence/evidence.yaml`（EV-001~EV-004）
- 检查时间：2026-09-19
- 状态：testing 检查点（不推进 Story/Change 状态）

## 1. 检查结论

**通过（PASS，带 2 项开放 minor）。** 冻结契约经源码与真实 ES 用例双向核实：五参数（categoryId/brandId/minPriceFen/maxPriceFen/sort）按需叠加于同一 BoolQuery；价格按区间相交（doc.minPrice≤上限 ∧ doc.maxPrice≥下限，单边开边界）；SortMode.from 仅认小写 price_asc/price_desc/newest，未知值（含大写/空）静默回退 DEFAULT；负价格/min>max/keyword 超长 400 B0502；四排序严格序（newest publishedAt desc + missing=_last）均有断言。ProductSearchApiTest 四个相关方法全绿。无 blocker/major。

### 1.1 需求一致性

| Story AC | test-run 证据 | 结论 |
| --- | --- | --- |
| AC-001 categoryId/brandId 单维过滤且叠加取交集 | ProductSearchApiTest#categoryAndBrandFilter（categoryId=10→4 条；叠加 brandId=100→2 条，跨类目文档被交集排除） | passed |
| AC-002 闭区间边界命中、单边生效、区间相交 | ProductSearchApiTest#priceRangeIntersection（10000–30000 命中跨区间文档与 30000-30000 边界等值；仅 max=5000 单边命中 5000 等值文档；3900 不命中） | passed |
| AC-003 keyword+品牌+价格三合一同时满足 | 双 term 交集 + range 与 multi_match must 在适配器同一 BoolQuery 构建路径叠加（源码第 44–68 行），分机制均有真实 ES 断言 | passed（三合一单跳请求为同机制覆盖，补强项见 EV-003） |
| AC-004 price_asc/desc 严格序、newest 发布时间倒序 | ProductSearchApiTest#sorts（升序 2,6,1,3；降序首 3 尾 2；newest id1 在前、publishedAt=null 的 id6 排尾） | passed |
| AC-005 非法 sort 回退 default 不报错、default 稳定 | #invalidParams（sort=hacker→200）；SortMode.java 源码 null/空白/未知（含大写）均走 DEFAULT；default 确定性由固定数据集分页断言佐证 | passed |
| AC-006 min>max/负值 → 400 统一结构；非数字 → 400 | #invalidParams（30000>10000、min=-1、keyword 65 长度均 400 B0502）+ SearchExceptionAdviceTest#illegalArgument_returns400；非数字绑定为框架类型异常（DU-BE-502 DEV-1 已记录口径） | passed（业务参数分支；非数字绑定分支见 EV-003） |
| AC-007 筛选+排序+分页组合 total/切片正确、ON_SALE 恒效 | #sorts/#categoryAndBrandFilter/#pagination 分项断言；trackTotalHits 取过滤后命中数；OFF_SALE 文档在任何组合不出现 | passed（同请求全量比对为分项覆盖，见 EV-003） |

### 1.2 设计一致性

- 参数与 DSL：SearchQuery 携带五参数、Adapter bool.filter 仅非空追加 term/range、range 以 double 喂 long 字段的无界保护（无价区不加 range）、from/size 继承主链路——与 story-design §1/§2 一致。
- 排序表：price_asc=minPrice asc+_score、price_desc=maxPrice desc+_score、newest=publishedAt desc(missing _last)+_score、DEFAULT=_score+updatedAt，源码 sorts() 与实施记录一致。
- 校验策略：负价/min>max/keyword 超长抛 IllegalArgumentException→B0502，categoryId/brandId 非正经 positiveOrNull 忽略，非法 sort 不报错——与设计 §4"非法 sort 宽松、价格非法 400"一致。
- Deviations 完整性：DU-BE-511 DEV-1（设计表曾写"sort 大小写不敏感"，实际仅接受小写枚举串、大写按未知值回退；NEWEST 次级以 _score 代替 updatedAt）四要素齐全，且与 Change 级冻结契约（sort=DEFAULT/price_asc/price_desc/newest 小写、非法回退 DEFAULT）一致，前端仅透传四个小写值，无真实调用方影响；DEV-2（不单建 QueryNormalizeTest/FilterSortIT，统一在真实 ES IT 断言）记录完整。

### 1.3 跨仓一致性

五参数命名（minPriceFen/maxPriceFen 整数分、sort 四个小写值）与 repo-2 api/search.ts 的 ProductSearchQuery/ProductSearchSort 及 SearchView SORT_TABS 完全对齐；repo-4 环境段不涉及。ES 字段名（categoryId/brandId/minPrice/maxPrice/publishedAt）与 requirement-design §2.2 冻结字段表一致，亦为 CHG-0021 写模型契约。跨仓无矛盾。

### 1.4 代码质量

对照 standards 明确条目抽查：

- api-design-standard §10"排序/筛选参数白名单、非法值回落默认"：SortMode 枚举白名单 + 安全回退，term/range 经强类型 Builder 构造，零字符串拼接——符合。
- 金额域：入参/ES 字段全程整数分 long，无元/分混用；前端换算在视图层 Math.round——边界清晰。
- testing-standard §6 边界覆盖：区间等值/单边/相交、严格升降序、null 排尾、非法回退、反向区间/负值均有真实 ES 断言。
- 测试布局：归一逻辑无纯单测（DEV-2 已记录，集成承载），属已登记覆盖深度项（EV-004，minor）。

### 1.5 知识同步候选

1. SKU 价区筛选 DSL 口径：商品文档以 minPrice/maxPrice 表达启用 SKU 价格区间，筛选按区间相交（`minPrice <= 请求上限 AND maxPrice >= 请求下限`，单边开边界、均不传不加 range），可复用于后续所有"价格区间筛选商品"场景（CHG-0021/后续商城列表增强）。

## 2. 发现清单

| EV id | target | severity | finding | resolution |
| --- | --- | --- | --- | --- |
| EV-003 | Story AC-003/AC-006/AC-007；test-report §4 | minor | "keyword+品牌+价格"三合一单跳请求、"筛选+排序+第 2 页"单请求全量比对、非数字参数绑定三个点为同机制/分项/框架分支覆盖，缺单一端到端断言 | 处置去向：M5 Integration Gate 场景一浏览器/curl 链路顺带补三合一与组合翻页单跳验证；非数字绑定分支待统一类型绑定异常映射时补测（与 DU-BE-502 EV-005 同去向） |
| EV-004 | `domain/search/SortMode.java`、`application/search/ProductSearchService.java`；DU-BE-511 DEV-2 | minor | 排序映射/非法回退/区间校验无独立纯单测，统一经 ProductSearchApiTest 真实 ES 断言，离线快速反馈与定位粒度不足 | 处置去向：维持真实 ES 集成覆盖（断言已逐条承载 AC），或后续按 task-design 设想补 QueryNormalizeTest 纯单测；技术债允许开放 |

无 blocker / major。

## 3. 完成确认

- [x] 四项检查全部执行（需求/设计/跨仓/代码质量）
- [x] 全部 blocker/major finding 已闭环（本 Story 无 blocker/major）
- [x] minor finding 已记录（EV-003/EV-004，允许开放，处置去向明确）
- [x] 知识同步候选已写入 §1.5
- [x] 跨仓一致性已核对（五参数/四排序小写值与 repo-2 对齐、ES 字段与 §2.2 冻结表一致）
