# Test Design（Change 级聚合）— CHG-0017 商品浏览

> 阶段：sdd-task 聚合产物（5 Story Change）；各 Story 明细见对应目录 test-design.md。

- Change ID: CHG-0017
- Feature Path: 商城前台/商品浏览
- 覆盖 Story: 首页 5、分类品牌 4、列表 9、详情 9、可售聚合 6，共 33 TC（24 独立用例，含前端态）。

## 1. 测试用例

### S1 商城首页（DU-BE-701 / DU-FE-701）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S1-TC-001 | 匿名 /home 200 四段结构真实 | AC-001 |
| S1-TC-002 | ON_SALE+启用 SKU，上架倒序 LIMIT 10，FALLBACK_NEWEST | AC-002 |
| S1-TC-003 | 无商品 newArrivals=[] 仍 200 | AC-002 |
| S1-TC-004 | HomeView 四态与路由（前端） | AC-019 |
| S1-TC-005 | banner/ProductCard 整数分/懒加载三检（前端） | AC-019 |

### S2 公开分类与品牌（DU-BE-702）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S2-TC-001 | 分类树 200；禁用父整枝剪枝；sort | AC-003 |
| S2-TC-002 | brands 启用/keyword/size≤200/字符串 id | AC-004 |
| S2-TC-003 | 匿名 200；internal denyAll | AC-005 |
| S2-TC-004 | 空树/空品牌 [] 非 null | AC-004 |

### S3 商城商品列表（DU-BE-703 / DU-FE-703）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S3-TC-001 | 分页准确；size=51 → 400 | AC-006 |
| S3-TC-002 | categoryId 子孙三层命中 | AC-007 |
| S3-TC-003 | brandIds 多选及组合交集 | AC-007 |
| S3-TC-004 | 四排序（派生表价区序+同分稳定） | AC-008 |
| S3-TC-005 | 非法 sort 回落 default | AC-008 |
| S3-TC-006 | id 字符串/价区整数分非 null | AC-009 |
| S3-TC-007 | 下架/无启用 SKU 全页剔除 | AC-010 |
| S3-TC-008 | 筛选排序分页 URL 同步与三态（前端） | AC-018 |
| S3-TC-009 | 整数分域模型/游客直达/三检（前端） | AC-020 |

### S4 商品详情与 SKU 选择（DU-BE-704 / DU-FE-704）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S4-TC-001 | 详情全字段 specDimensions/skuIndex | AC-011 |
| S4-TC-002 | 表驱动全组合唯一 skuId 联动（前端） | AC-012 |
| S4-TC-003 | 不存在/下架直访 404 商品页 | AC-013 |
| S4-TC-004 | DISABLED 置灰/缺货禁加购（前端） | AC-014 |
| S4-TC-005 | UNKNOWN 可重试降级（前端） | AC-018 |
| S4-TC-006 | Loading/占位/游客路由/三检（前端） | AC-019 |
| S4-TC-007 | 金额整数分无浮点（前端） | AC-020 |
| S4-TC-008 | assembler 矩阵装配集成 | AC-011 |
| S4-TC-009 | 脏数据冲突防御不 500 | AC-013 |

### S5 SKU 可售状态聚合（DU-BE-705）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S5-TC-001 | inventory internal 一次批量 SQL，无记录=0 | AC-015 |
| S5-TC-002 | 公开三态；inventory 调用仅一次 | AC-015 |
| S5-TC-003 | 阈值 0/1-9/≥10 三态 | AC-016 |
| S5-TC-004 | 公开响应白名单无精确数字 | AC-016 |
| S5-TC-005 | inventory 故障 200 + UNKNOWN | AC-017 |
| S5-TC-006 | 空/101/非法 400；internal 401 | AC-015 |

## 2. 测试策略

- 后端 @SpringBootTest：树剪枝/子孙展开/派生表排序/矩阵装配夹具；MockRestServiceServer 断言单次批量与降级；JSON 字面量类型断言；网关 8080 匿名与 denyAll。
- 前端 vitest（表驱动矩阵/query 同步/四态）+ vue-tsc/eslint/build；金额全程整数分。
- 明细见各 Story 级 test-design.md。
