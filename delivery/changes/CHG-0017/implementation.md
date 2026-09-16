# Implementation（Change 跨仓聚合兼容层）

## 0. 元信息

- Change ID：CHG-0017（商城商品浏览体验：首页 / 公开分类品牌 / 商品列表 / 详情与 SKU 选择 / SKU 可售状态）
- Task 来源：两实现仓 8 个 DU 的 task-design.md / task-spec.md
- 主仓库：repo-1
- Story：STORY-003-02-01-01（商城首页）、STORY-003-02-01-02（公开分类与品牌查询）、
  STORY-003-02-02-01（商城商品列表）、STORY-003-02-02-02（商品详情与 SKU 选择）、
  STORY-003-02-03-01（SKU 可售状态聚合）

## 1. Delivery Unit 状态总览

| DU | 仓库 | Story | 状态 |
| --- | --- | --- | --- |
| DU-BE-702 | repo-1 | 公开分类与品牌查询 | completed（mall-product 75 + mall-gateway 19） |
| DU-BE-705 | repo-1 | SKU 可售状态聚合 | completed（inventory 24 + product 81） |
| DU-BE-701 | repo-1 | 商城首页 | completed（mall-product 84） |
| DU-FE-701 | repo-2 | 商城首页 | completed（首页 + 四公共组件，68 例） |
| DU-BE-703 | repo-1 | 商城商品列表 | completed（brandIds/子孙分类/派生表价区排序，90 例） |
| DU-FE-703 | repo-2 | 商城商品列表 | completed（query SSOT + requestSeq，71 例） |
| DU-BE-704 | repo-1 | 商品详情与 SKU 选择 | completed（矩阵装配 + 404 同构，93 例） |
| DU-FE-704 | repo-2 | 商品详情与 SKU 选择 | completed（SkuSelector/StockBadge/详情页，85 例） |

## 2. Commit 记录

### repo-1（分支 M3-dev，代码提交）

| Commit | DU | 说明 |
| --- | --- | --- |
| b4b5a1f | DU-BE-702 | 公开分类树/品牌接口 + 网关匿名白名单 |
| b982bf5 | DU-BE-705 | SKU 可售状态聚合（内部批量 + 公开三态 UNKNOWN 降级） |
| 868ee02 | DU-BE-701 | 商城首页 /home 三路聚合 |
| 751a792 | DU-BE-703 | 商品列表增强（brandIds/子孙分类/价区派生表排序/size≤50） |
| 8496b53 | DU-BE-704 | 商品详情增强（brandName/categoryPath/specDimensions/skuIndex + 冲突防御） |

### repo-2（分支 M3-dev，代码提交）

| Commit | DU | 说明 |
| --- | --- | --- |
| 2c85e52 | DU-FE-701 | 商城首页 + ProductCard/PriceText/StateView/BannerSlot |
| 5a97392 | DU-FE-703 | 商品列表页（分类树/品牌多选/排序/分页，query SSOT） |
| 30712bd | DU-FE-704 | 商品详情页 + SkuSelector + StockBadge |
| 92b0839 | DU-FE-704 | 自审修复（多维禁用算法/StateView API/UNKNOWN 降级/tsc） |

（各 DU 另有 docs 类仓内提交；完整 40 位 hash 见各 DU metadata.yaml。）

## 3. 各仓实施引用

- repo-1：
  - `.../首页与公开分类品牌/公开分类与品牌查询/DU-BE-702/implementation.md`
  - `.../库存状态展示/SKU 可售状态聚合/DU-BE-705/implementation.md`
  - `.../首页与公开分类品牌/商城首页/DU-BE-701/implementation.md`
  - `.../商品列表与详情/商城商品列表/DU-BE-703/implementation.md`（价区派生表 SQL、空集短路、ECJ 条件拆块）
  - `.../商品列表与详情/商品详情与 SKU 选择/DU-BE-704/implementation.md`（LinkedHashMap 归并、冲突取小 warn、部分数据降级）
- repo-2：
  - `.../商城首页/DU-FE-701/implementation.md`
  - `.../商城商品列表/DU-FE-703/implementation.md`
  - `.../商品详情与 SKU 选择/DU-FE-704/implementation.md`（happy-dom 测试栈、jsdom 净化例外、DOMPurify）

## 4. 与 Task / AC 对应关系

| AC | 内容（摘要） | 承载 DU |
| --- | --- | --- |
| AC-001/002 | 匿名首页真实聚合；仅可售商品；空态 | DU-BE-701、DU-FE-701 |
| AC-003/004/005 | 启用分类树（禁用父整枝剪除）、启用品牌关键字、internal 隔离 | DU-BE-702 |
| AC-006~010 | 分页上限、后代分类、品牌多选、四档排序、价区非 null、不可售不返回 | DU-BE-703、DU-FE-703 |
| AC-011~014 | 详情矩阵、唯一 SKU 联动、404 同构、失效组合不可选/缺货标识 | DU-BE-704、DU-FE-704 |
| AC-015~017 | 批量三态一次调用、阈值 10 后端口径无精确数字、故障 UNKNOWN 不白屏 | DU-BE-705、DU-FE-704 |
| AC-018 | Empty/Error/Loading 视图（三页） | DU-FE-701/703/704 |
| AC-019 | 游客直达三路由 + build/type-check | DU-FE-701/703/704 |
| AC-020 | 全链路整数分无浮点 | 全部 DU（PriceText + long/number DTO） |

## 5. Deviations

- DU-FE-701 将 vitest 全局环境切 happy-dom 并引入 @vue/test-utils，DU-FE-704 追加 jsdom
  （DOMPurify per-file 例外）：已在 converge 沉淀为前端 coding-standard §16，显式修订 §15。
- 其余 DU 级偏差（ECJ 链式 eq 拆块、specification_data JSON 对象夹具、空 IN 短路）
  见各 DU implementation.md 与 Story test-report 红→绿记录。
