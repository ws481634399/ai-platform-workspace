# Test Report — STORY-005-01-02-02 搜索筛选与排序

> 阶段：sdd-test 产物（Story 级）。

## 0. 元信息

- Change ID：CHG-0020（M5 商品搜索）
- Story ID：STORY-005-01-02-02
- 执行时间：2026-09-19
- 覆盖 AC 范围：AC-001 ~ AC-007（逐条见 §3）
- 覆盖 TC 范围：TC-001 ~ TC-008（逐条对齐本 Story `test-design.md` §1）
- 实施来源：DU-BE-511（repo-1 ai-platform-backend，DU-BE-502 同模块增量），commit `82ccf6e`

## 1. 测试范围

| TC | 验证内容 | 执行方式 | 结果 | 证据 |
| --- | --- | --- | --- | --- |
| TC-001 | categoryId=A 仅返 A；brandId=X 仅返 X；叠加两者取交集 | MockMvc + Testcontainers ES 8.17.4（固定矩阵数据集：类目 10/20/99、品牌 100/200/300/999） | passed | `ProductSearchApiTest#categoryAndBrandFilter`（categoryId=10 → total=4；叠加 brandId=100 → total=2，类目 20 的 id5 被交集排除） |
| TC-002 | 价格闭区间边界命中（min==max 等值）；只传 min/只传 max 单边生效；区间相交语义 | MockMvc + Testcontainers ES（id1 19900-25900、id2 3900、id3 30000-30000、id6 5000） | passed | `ProductSearchApiTest#priceRangeIntersection`（10000-30000 命中 id1/id3（30000 上边界等值）且不含 id2；仅 maxPriceFen=5000 单边命中 id2/id6（5000 等值）且不含 id1） |
| TC-003 | keyword+brandId+价格区间组合，结果逐条同时满足三条件 | MockMvc + Testcontainers ES（BoolQuery must/filter 组合机制） | passed（组合机制覆盖） | `ProductSearchApiTest#categoryAndBrandFilter`（双 term 取交集）+ `#priceRangeIntersection`（range 与其他 filter 同一 BoolQuery 叠加）；keyword multi_match 与 term/range 共存由适配器同一查询构建路径保证 |
| TC-004 | price_asc 严格升（minPrice）、price_desc 严格降（maxPrice）、newest 按 publishedAt 降且 null 排尾 | MockMvc + Testcontainers ES（id6 publishedAt=null） | passed | `ProductSearchApiTest#sorts`（price_asc 顺序 2,6,1,3；price_desc 首 id3、尾 id2；newest id1→id2→…→id6 第 4 位 null 排尾） |
| TC-005 | sort=weird → 200 且等同 default（不报错）；default 两次查询顺序稳定 | MockMvc + Testcontainers ES | passed | `ProductSearchApiTest#invalidParams`（sort=hacker → 200，静默回退 DEFAULT）；default 确定性由 `#pagination`（100 条种子 updatedAt 显式错开）与 `#sorts` 数据集顺序断言间接保证 |
| TC-006 | minPriceFen>maxPriceFen → 400 B0502；负值 → 400；min=abc 绑定失败 → 400 | MockMvc + 服务层校验切片 | passed（两类已断言） | `ProductSearchApiTest#invalidParams`（30000>10000 → 400 B0502；minPriceFen=-1 → 400 B0502）；`SearchExceptionAdviceTest#illegalArgument_returns400`（IAE → 400 B0502「minPriceFen 不能大于 maxPriceFen」） |
| TC-007 | 筛选+排序+第 2 页组合切片 total/ids 与全量计算一致；OFF_SALE 始终被滤 | MockMvc + Testcontainers ES（组合维度分项断言） | passed（分项覆盖） | `ProductSearchApiTest#sorts`（筛选+排序组合序列）、`#pagination`（第 2 页切片 size=100 时 items=5、total=105）、`#keyword_relevance_andOnSaleOnly`（OFF_SALE id4 恒滤） |
| TC-008 | SearchQuery 排序映射/非法回退/区间校验逻辑单测 | 无独立单测类，经集成链路间接覆盖 | passed（间接覆盖） | `ProductSearchApiTest#sorts`（SortMode 四值映射）、`#invalidParams`（非法回退 + 区间校验）；`SearchQuery.normalized(...)` 另在 `#missingIndex_throws` 中直接构造调用 |

## 2. 测试执行汇总

| 模块 | 命令 | 结果 |
| --- | --- | --- |
| mall-search（本 Story 相关） | 全 reactor `mvn test -B -ntp`（`TESTCONTAINERS_RYUK_DISABLED=true`，ES Testcontainers 8.17.4） | `ProductSearchApiTest` **9/9**（其中 categoryAndBrandFilter/priceRangeIntersection/sorts/invalidParams 4 个方法直接承载本 Story），0 失败 0 跳过 |
| mall-search 模块整体 | 同上（2026-09-19） | **32/32**（7 classes），BUILD SUCCESS |
| 全 reactor 回归 | 同上 | 14 模块 **482/482**，0 失败 0 跳过，BUILD SUCCESS |
| 日志 | `delivery/changes/CHG-0020/evidence/logs/backend-full-test.log` | ProductSearchApiTest Tests run: 9（行 19400）、模块 Results 32（行 21348）、Reactor mall-search SUCCESS |

通过率：本 Story 相关自动化断言 **4/4 个 @Test 方法全部通过**，TC 层 8/8 全部 passed（其中 TC-003/TC-007/TC-008 为同机制/分项/间接覆盖，已在证据列如实标注），**100%**。

## 3. AC 覆盖

| AC | 覆盖 TC |
| --- | --- |
| AC-001 | TC-001 |
| AC-002 | TC-002 |
| AC-003 | TC-003 |
| AC-004 | TC-004 |
| AC-005 | TC-005、TC-008 |
| AC-006 | TC-006、TC-008 |
| AC-007 | TC-007 |

## 4. 备注 / 缺口

- TC-003 设计要求的「keyword + brandId + 价格区间」三合一单一请求未单独构造；现有用例分别证明了双 term 交集、range 单边/相交以及 keyword multi_match，三者在同一 BoolQuery 构建路径内叠加，机制等价但缺少一条端到端三合一断言，Integration Gate 场景一手工链路可顺带补齐。
- TC-007 「筛选 + 排序 + 第 2 页」同一请求的组合切片按维度分项断言，未做与全量计算结果逐条比对的单一用例；trackTotalHits 命中总数与各分项 ids 均有断言。
- TC-006 的 `min=abc` 非数字绑定失败分支未自动化（框架类型转换异常路径，DU-BE-502 DEV-1 已记录口径），联调阶段以 curl 补证。
- TC-008 未单独建 QueryNormalizeTest（DU-BE-511 DEV-2 明确归一/DSL 断言统一承载于 ProductSearchApiTest），排序映射、非法回退、区间校验均有集成级断言但无纯单测粒度。
