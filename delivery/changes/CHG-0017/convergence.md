# Convergence — CHG-0017 商城商品浏览体验

> 阶段：sdd-converge 产物

## 0. 元信息

- Change ID：CHG-0017
- 完成时间：2026-09-16T03:30:00+08:00
- standards-need-update：yes（2 个文件追加）
- product-need-update：yes（Spec 晋升候选 1 篇，待人工评审；不直接落 product/specs/）
- featuretree-need-update：yes（5 个 Story planned → delivered，已执行）
- glossary-need-update：no

## 1. 知识变化总结

本 Change 交付商城商品浏览域全部 5 个 Story（商城首页 / 公开分类与品牌 / 商品列表 /
商品详情与 SKU 选择 / SKU 可售状态聚合）、8 个 DU（repo-1 五个、repo-2 三个），
确立两类可跨 Change 复用的规则与一组长期产品业务规则：

1. **公开只读查询口径（BE）**：不可售/不存在同构 404 防存在性泄漏；可售过滤在 SQL 层；
   价区走分组派生表而非内存；排序枚举白名单 + Mapper choose 固定片段；IN/分页显式上限；
   树展开有界且空集短路；聚合读部分数据降级；公开 DTO 不暴露精确库存。
   ——直接适用于后续搜索、营销活动商品位等所有 C 端只读接口。
2. **商城浏览页交互测试栈与页面模式（FE）**：修订 CHG-0016 §15 的 node-only 测试形态为
   分层栈（api/utils/store 仍逻辑切片；复用组件/视图用 happy-dom + @vue/test-utils；
   jsdom 仅 per-file 用于 DOMPurify 类真实 DOM 依赖）；route.query 唯一状态源 +
   requestSeq 竞态防护；富文本必净化；金额整数分组件化；表驱动选择器纯数据 props。
3. **跨服务实时数据的业务安全降级**：库存三态（阈值在后端）+ 故障 UNKNOWN 不阻塞主流程，
   前端可重试但不锁死页面——适用于后续价格、促销等一切实时只读数据。

新业务能力：FEAT-003 商城前台下商城首页、公开分类与品牌、商品列表、商品详情与 SKU
选择、SKU 可售状态聚合五个 Story 节点全部交付（Feature Tree 已置 delivered）。
无新术语条目（SKU、SPU、三态库存为通用电商概念，已由 Feature Tree 节点承载；
workspace 当前无 glossary 目录，不为此单建）。

## 2. 更新判断

### Standards 晋升

- 文件：`standards/engineering/backend/api-design-standard.md`
- 操作：§10 接口安全 新增「公开只读查询口径（CHG-0017 晋升）」
- 内容：①不可售/不存在/无可售子实体同构 404；列表 SQL 层 ON_SALE+EXISTS 过滤；
  ②价区分组派生表 LEFT JOIN + ORDER BY 派生列，禁内存排序；③排序枚举白名单、
  Mapper choose 固定片段；④IN/分页显式上限（brandIds 50/size 50/字典 200）；
  ⑤树展开深度≤3、空集短路防空 IN 查全表；⑥附属数据缺失降级不 500、跨服务实时数据
  故障降级 UNKNOWN；⑦公开 DTO 只给三态不给精确数量/内部错误。
- 理由：搜索、活动商品位、评价等后续 C 端只读能力面对完全相同的口径（存在性泄漏、
  排序注入面、拉全量、部分故障），需统一范式。
- 复用场景：所有 /api/mall/** 匿名只读端点。

- 文件：`standards/engineering/frontend/coding-standard.md`
- 操作：新增「16. 商城浏览页交互测试栈与页面模式（CHG-0017 晋升，修订 §15）」
- 内容：分层测试栈（逻辑切片不退化；SFC 限复用组件与四态视图用 happy-dom；
  jsdom per-file 例外并留痕依赖授权）；route.query SSOT + watch fullPath +
  requestSeq 竞态防护；v-html 必经 DOMPurify；金额 PriceText 整数拆分；
  表驱动选择器纯数据 props + 全组合兼容匹配禁用判定。
- 理由：CHG-0017 实际突破了 §15「默认不挂组件」的边界并验证了新栈（85 例含 4 SFC spec），
  须把例外规则、依赖授权与页面模式固定下来，防止后续 DU 各自选型。
- 复用场景：mall-web/mall-admin 全部含筛选/四态/复杂选择交互的页面。

### Spec 晋升候选（人工评审后落 product/specs/）

- 文件：`product/specs/商城商品浏览.md`（评审通过后创建）
- 操作：新增
- 内容（草稿，来源 requirement-spec.md AC-001~020，经 5 Story 实施与 93+85 测试验证成立）：
  - 可售口径：仅 ON_SALE 且存在启用 SKU 的商品对商城可见；下架商品与无启用 SKU 商品
    在首页、列表均不出现；详情直访（不存在/下架/无可售 SKU）统一展示不可售 404 页，
    页面不提供任何加购操作态。
  - 分类与品牌：商城分类树仅含启用分类，禁用分类的整棵子树不出现；品牌仅启用项可见、
    支持关键字；internal 路径对商城外网不可达。
  - 列表：分类筛选包含后代分类商品；品牌多选取交集；排序固定四档
    （default/newest/price_asc/price_desc），非法值回落 default；分页每页上限 50。
  - 库存展示：对外只呈现三态——现货（available≥10）/库存紧张（1–9）/缺货（0）；
    阈值归后端，前台不展示精确库存数字；库存仅为展示参考，不作为交易保证；
    库存服务不可用时显示「状态获取失败」并允许重试，商品图文仍可浏览；
    仅现货/库存紧张可执行加购。
  - 金额：全链路金额整数分（人民币分），前台不做浮点解析。
  - 详情内容：商品图文介绍为运营受信内容，前台渲染仍须净化；规格组合必须定位唯一 SKU，
    失效组合不可选。
  - 访客：首页/列表/详情游客可直接访问，不强制登录。
- 理由：上述为长期产品行为约束（做什么），CHG-0018 购物车与订单履约在判断「可否加购、
  展示什么库存态、哪些商品可见」时需要稳定产品依据。
- 来源：requirement-spec.md §AC-001~020 + 各 story-spec AC 验证结果。

### Feature Tree 更新

- 节点：STORY-003-02-01-01 商城首页 / STORY-003-02-01-02 公开分类与品牌查询 /
  STORY-003-02-02-01 商城商品列表 / STORY-003-02-02-02 商品详情与 SKU 选择 /
  STORY-003-02-03-01 SKU 可售状态聚合
- 操作：planned → delivered（5 节点，全部 Story 下 DU 已 completed 且 dev/test/review
  三阶段门禁 check+approve 通过，workflow 均到 completed）
- 方式：`openspec feature update <STORY-ID> --status delivered`（已执行）

### Glossary 更新

无。SKU/SPU/规格组合/库存三态为电商通用领域概念且已由 Feature Tree 节点与接口契约承载；
「派生表价区」「表驱动选择器」为技术实现术语，已进 standards。workspace 无 glossary 目录，
不为此单建。

### No Update

- 各端点具体 JSON 字段、UnifyResult 包装、@StringId 序列化：实现细节/既有标准已覆盖。
- 阈值 10、分页 50、品牌 200、分类深度 3、首页 8/10 等具体数值：已抽象为「阈值/上限归后端」
  规则，具体数值留在代码与 Story 文档，不进长期规则。
- SkuIndex 组合键分隔符 `|`、specification_data JSON 对象形态：本 Change 数据模型细节。
- 加购按钮占位（console.info）：跨 Change 临时桩，CHG-0018 DU-FE-801 接入后消失。
- DOMPurify/happy-dom/jsdom 版本号：环境配置，走 package.json 锁文件。

## 3. 知识沉淀过程

- 通读 5 Story 全部 Artifact（requirement/exploration/spec/design、5 套 story-spec/
  design/test-design、8 个仓内 DU 的 task-design/implementation、5 份 Story test-report/
  review-report、change evidence EV-001~026），提取技术候选 4 组、业务规则候选 1 组。
- 检索既有 standards：CHG-0016 已立「归属 404/默认唯一/Outbox-Lite/前端逻辑切片」等规则 →
  本次仅补未覆盖部分：公开只读口径整体成段（api-design-standard §10 新增小节）、
  前端测试栈以 §16 显式修订 §15 而非悄悄覆盖；均追加不改写既有条文，无 Conflict。
- Spec 候选只在本文件起草（§2），未直接写 product/specs/，等待人工评审。
- 知识索引：本次为既有 standards 文件章节追加，文件级索引条目仍有效；
  feature-tree.yaml 经 openspec feature update 变更，待提交后由派生缓存命令刷新。
- 无 Unresolved 问题；五个 Story review-report 无开放 blocker/major（FE 自审发现的
  2 个 major 已在门禁前修复并补守护测试，见详情 Story review-report F-001/F-002）。

## 4. 全局验收标准对照

| AC | 验收点 | 证据 | 结论 |
| --- | --- | --- | --- |
| AC-001 | 匿名首页 200，真实分类/新品/推荐 | EV-007~009，首页 story test-report | 通过 |
| AC-002 | 首页仅上架且有启用 SKU；空态不报错 | EV-007~009（MallHomeApiTest 空态） | 通过 |
| AC-003 | 分类树仅启用且禁用父整枝剪除 | EV-001~003，分类品牌 story test-report | 通过 |
| AC-004 | 品牌仅启用 + 关键字 | EV-001~003 | 通过 |
| AC-005 | internal 路径外网不可达 | mall-gateway 19/19（EV-002） | 通过 |
| AC-006 | 分页生效、total 准确、size>50 收敛 | EV-013~015（sizeCap50） | 通过 |
| AC-007 | 后代分类 + 品牌多选交集 | EV-013~015（descendantCategory/brandIdsMultiSelect） | 通过 |
| AC-008 | 四档排序正确，非法回落 default | EV-013~015（sortByPrice/invalidSortFallback） | 通过 |
| AC-009 | 列表字段 id 字符串、价区整数分非 null | EV-013~015（priceRangeNonNull） | 通过 |
| AC-010 | 下架/无启用 SKU 首页列表均不返回 | EV-007~009 + EV-013~015 | 通过 |
| AC-011 | 详情 200 含图集/品牌/路径/富文本/规格维度/SKU 索引 | EV-019~021（detailWithMatrix） | 通过 |
| AC-012 | 规格组合定位唯一 SKU，价格/图/状态联动 | EV-022~026（SkuSelector/ProductDetailView） | 通过 |
| AC-013 | 不存在/下架直访 404 不可售页无加购 | EV-019~021 + EV-025/026（两 404 例 + empty 态） | 通过 |
| AC-014 | 失效组合不可选 + 缺货标识 | EV-025/026（disabled 置灰 + StockBadge） | 通过 |
| AC-015 | 批量三态 ≤100，仅一次 inventory 调用 | EV-004~006（库存 story test-report） | 通过 |
| AC-016 | 阈值 0/<10/≥10，公开响应无精确数字 | EV-004~006（StockStatus 白名单 DTO） | 通过 |
| AC-017 | inventory 不可用降级 UNKNOWN 不白屏 | EV-004~006 + EV-025/026（前端 try/catch 降级） | 通过 |
| AC-018 | 空/错/载分视图（首页/列表/详情） | EV-010~012、EV-016~018、EV-025/026（StateView 四态） | 通过 |
| AC-019 | 三路由游客直达 + build/type-check | 路由均未标 requiresMember；85 例 + vue-tsc + build | 通过 |
| AC-020 | 全链路整数分、无浮点解析 | PriceText 4 例 + 全部 DTO long/number | 通过 |

追踪链：20 AC ↔ 5 Story test-report TC（首页 3、分类品牌 5、库存 6、列表 7、
详情 10）↔ 8 DU（repo-1：DU-BE-701/702/703/704/705；repo-2：DU-FE-701/703/704）
↔ EV-001~026（9 code-change + 8 evidence-ref + 9 test-run），无断链。
遗留联调项（不阻断收敛，统一归 M3 Test 五集成场景）：真实两进程 + 网关 + MySQL 下的
首页/列表/详情浏览、三态库存真实 inventory 调用与故障注入 UNKNOWN、真实浏览器规格选择
全路径与加购占位行为。

## 5. 完成确认

- [x] 全部前序 Artifact 已读取（含 5 Story 与两仓 8 个 DU 证据）
- [x] 知识分类完成（2 个 standards 文件追加、1 篇 Spec 晋升候选、5 节点 Feature Tree、其余 no-update）
- [x] standards 更新已写入（2 处，标注来源 CHG-0017 与红基线，仅追加/显式修订）
- [x] Spec 晋升候选已按业务规则整理于 §2（商城商品浏览.md，待人工评审，未直接落 product/specs/）
- [x] Glossary 判定无需更新（理由见 §2）
- [x] Feature Tree 五个 Story 已置 delivered（openspec feature update）
- [x] 索引已核对（文件级索引不受章节追加影响）
- [x] 8 个 DU 均 completed，result commit 与各自仓提交链一致
- [x] 无未解决 Conflict、Unresolved 问题或开放的 blocker/major
