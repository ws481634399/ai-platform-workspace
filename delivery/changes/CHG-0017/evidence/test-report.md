# Test Report（Change 聚合兼容层）

## 0. 元信息

- Change ID：CHG-0017（商城商品浏览体验）
- Implementation 来源：`implementation.md`
- Evidence 索引：`evidence/evidence.yaml`（EV-001~026）
- 权威来源：五个 Story 目录下 `evidence/test-report.md`
  （`首页与公开分类品牌/商城首页/`、`.../公开分类与品牌查询/`、
  `商品列表与详情/商城商品列表/`、`.../商品详情与 SKU 选择/`、
  `库存状态展示/SKU 可售状态聚合/`）

## 1. 测试范围

覆盖 AC-001～AC-020，Story 级 TC 全部 passed：

| Story | 覆盖 AC |
| --- | --- |
| 商城首页 | AC-001、AC-002 |
| 公开分类与品牌查询 | AC-003、AC-004、AC-005 |
| 商城商品列表 | AC-006～AC-010、AC-020 |
| 商品详情与 SKU 选择 | AC-011～AC-014、AC-018、AC-020 |
| SKU 可售状态聚合 | AC-015、AC-016、AC-017 |
| 跨 Story 前端工程门禁 | AC-018、AC-019、AC-020 |

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过 |
| --- | ---: | ---: | ---: | ---: |
| mall-product（最终全量） | 93 | 93 | 0 | 0 |
| mall-inventory | 24 | 24 | 0 | 0 |
| mall-gateway | 19 | 19 | 0 | 0 |
| mall-web vitest（18 个 spec，最终） | 85 | 85 | 0 | 0 |
| mall-web vue-tsc / vite build | 2 | 2 | 0 | 0 |

## 3. 证据清单

- 五个 Story 的 `evidence/test-report.md`：逐条 TC 结果与红→绿过程
  （含空 IN 退化为全表、三维度组合键误禁用、StateView props API 误用、
  DOMPurify happy-dom 降级四条真实红基线）
- EV-001~026（change evidence.yaml）：9 code-change + 8 evidence-ref + 9 test-run
- repo-1 DU evidence：DU-BE-701/702/703/704/705（MockMvc + JDBC 集成测试）
- repo-2 DU evidence：DU-FE-701/703/704（vitest happy-dom；详情净化用例 jsdom 环境）

## 4. 遗留联调项（M3 Test 五集成场景，2026-09-16 真实环境执行，全部 PASS）

执行环境：Docker infra（MySQL 8.4 :13306 / Redis / Nacos）+ 真实进程 mall-gateway:8080、
mall-product:8103、mall-inventory:8106（M3-dev 分支 jar）+ mall-web Vite dev（:5175），
数据为 16 个 ON_SALE SPU / 34 SKU / 34 库存行。

| # | 场景（AC） | 结果 | 关键证据 |
|---|---|---|---|
| 1 | 两进程+网关匿名浏览与白名单（AC-001/005/019） | PASS | 经网关 /api/mall/home（5 分类/新品10/推荐10）、/categories/tree（5 根）、/brands（9）、/products（total=16）、/products/{id} 匿名 200；/api/admin/products 无 Token 返回 401；不存在商品返回业务码 B2141 同构错误体；浏览器首页/列表/详情匿名可浏览 |
| 2 | inventory 批量三态一次调用 + 故障降级（AC-015/017） | PASS | POST /api/mall/skus/availability 单次请求 34 SKU 全 IN_STOCK；注入库存（180→5/108→0）后同批返回 LOW_STOCK/OUT_OF_STOCK/IN_STOCK 三态，测后已还原；停掉 mall-inventory 后 HTTP 仍 200 且全部 UNKNOWN（前端详情页内层降级不白屏，已有单测覆盖） |
| 3 | 浏览器规格全路径联动 + 加购占位（AC-012/014） | PASS | 星环 X1（仅 2 合法组合）：选 16GB+512GB 后曜石黑禁用/星云蓝可点→选星云蓝显 ¥4,099.00 + sku-1 主图 + 现货徽标；取消颜色维度后 12GB 恢复可点→选曜石黑显 ¥3,999.00 + sku-0 主图；未选全时加购按钮 disabled；availability 为 POST 200 |
| 4 | 子孙分类/品牌多选/四档排序/分页浏览器交互（AC-007/008） | PASS | 数码家电（id=1）子孙展开 6 条、其叶类 2 条；品牌 1,2 多选交集 4 条且单参 brandId 别名可用；PRICE_ASC 首 ¥89 / PRICE_DESC 首 ¥6,399（全量），非法 sort=DROP_TABLE 静默回落 DEFAULT；size 上限 50/9999 被钳为 50；默认页 20 条（16 商品分页器按设计隐藏），?size=5 触发 1/4 分页器，翻页/URL page 参数/返回均正常，query 刷新保留 |
| 5 | 真实浏览器富文本净化（AC-011） | PASS | 临时注入 `<script>window.__xssFired=1</script>`+`<img onerror>`+`javascript:` 链接探针，浏览器实测：p/strong 正常渲染、window.__xssFired===undefined、.rich-text 内无 script/onerror、a 无 javascript: href；探针测后已还原 |

备注：浏览器 console 仅有非业务噪音（/inventory/logs 连接拒绝，非本仓代码发起；EventEmitter 警告），无业务红字。
