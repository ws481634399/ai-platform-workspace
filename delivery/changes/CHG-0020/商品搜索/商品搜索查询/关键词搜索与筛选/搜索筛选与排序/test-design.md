# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0020
- Story ID: STORY-005-01-02-02
- Feature Path: 商品搜索 > 商品搜索查询 > 关键词搜索与筛选 > 搜索筛选与排序
- 状态流转: designed → tasked
- TC 总数: 8

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 集成：类目 A/B、品牌 X/Y 造数，categoryId=A 仅返 A；brandId=X 仅返 X；叠加两者取交集 | AC-001 | DU-BE-511 | [S1] |
| TC-002 | 集成：价格段 1000/5000/9000 文档，min=5000&max=5000 命中边界；只传 min、只传 max 各自生效；区间相交语义（跨价区间 SKU 商品） | AC-002 | DU-BE-511 | [S1] |
| TC-003 | 集成：keyword+brandId+价格区间组合，结果全部满足三条件（逐条断言） | AC-003 | DU-BE-511 | [S1] |
| TC-004 | 集成：price_asc 序列严格升（minPrice）；price_desc 严格降（maxPrice）；newest 按 publishedAt 降且 null 排尾 | AC-004 | DU-BE-511 | [S1] |
| TC-005 | API：sort=weird → 200 且结果等同 default（不报错）；default 两次查询顺序稳定 | AC-005 | DU-BE-511 | [S1] |
| TC-006 | API：minPriceFen=5000&maxPriceFen=1000 → 400 B0502；负值 → 400；min=abc 绑定失败 → 400 | AC-006 | DU-BE-511 | [S1] |
| TC-007 | 集成：筛选+排序+第 2 页组合切片 total/ids 与全量计算一致；OFF_SALE 始终被滤 | AC-007 | DU-BE-511 | [S1] |
| TC-008 | 单测：SearchQuery 排序映射/非法回退/区间校验逻辑 | AC-005, AC-006 | DU-BE-511 | [S1] |

## 2. 测试策略

- 单一 ES IT 类造固定矩阵数据（2 类目/3 品牌/6 价格段/含未发布），各 TC 用不同查询复用数据集。
- 边界相等与跨区间商品需显式造 min/max 不同的商品文档。

## 3. 不可测项标注

- 无。

## 4. 依赖与前置条件

- STORY-005-01-02-01 查询链路（本 Story 为同 DU 增量）。

