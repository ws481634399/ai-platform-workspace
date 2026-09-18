# Test Design（Change 级聚合）— CHG-0020 M5 商品搜索查询

> 阶段：sdd-task 聚合产物（5 Story Change）；各 Story 明细见对应目录 test-design.md。

- Change ID: CHG-0020
- Feature Path: 商品搜索
- 覆盖 Story: ES 基础 6、异常降级 6、关键词搜索 10、筛选排序 8、mall-web 体验 7，共 37 TC；另含 Change 级 M5 Integration Gate 场景一（商品搜索）。

## 1. 测试用例

### S1 建立 mall-search 与 Elasticsearch 基础环境（DU-WS-501 / DU-BE-501）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S1-TC-001 | compose up ES healthy（yellow 可接受）；down→up 卷 ai-platform-es-data 数据保留 | AC-001 |
| S1-TC-002 | dependency:tree 断言官方 elasticsearch-java 版本解析自 BOM；无 RestHighLevelClient、无写死版本 | AC-002 |
| S1-TC-003 | ES 运行 health components.search=UP；停 ES 后 DOWN 且进程存活 | AC-003 |
| S1-TC-004 | MALL_ES_URIS 覆盖时 client 实际目标 URI 正确 | AC-001 |
| S1-TC-005 | Testcontainers ES：SmokeIT 临时索引写 2 文档检索命中 | AC-003 |
| S1-TC-006 | ContextLoadsTest 无 ES 环境通过（Bean 懒连接） | AC-003 |

### S2 搜索异常响应与降级（DU-BE-510）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S2-TC-001 | MockMvc：ConnectException/cause 链 → 503 B0501，body 无堆栈/主机 | AC-004 |
| S2-TC-002 | SocketTimeoutException → 503 B0501 | AC-004 |
| S2-TC-003 | 别名不存在 → 503 B0501 而非 index_not_found 原生响应 | AC-004 |
| S2-TC-004 | 0 命中 → 200 items=[] total=0，日志无 ERROR | AC-005 |
| S2-TC-005 | WARN 日志与响应链路含 traceId 可串联 | AC-004 |
| S2-TC-006 | cause 链遍历单测（Elasticsearch/Response/Transport 包装）均映射 B0501 | AC-004 |

### S3 商品关键词搜索（DU-BE-502）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S3-TC-001 | ES IT：name/keywords/brandName/categoryName 各可检出；name^3 排序靠前 | AC-006 |
| S3-TC-002 | OFF_SALE 文档任意查询不返回 | AC-007 |
| S3-TC-003 | 响应字段白名单断言，无 skus/聚合全字段 | AC-008 |
| S3-TC-004 | 105 条造数：默认 20、size=500 限 100、total=105、page=0/-1 回退 | AC-009 |
| S3-TC-005 | 无 keyword 返回 ON_SALE default 浏览结果 | AC-009 |
| S3-TC-006 | 网关 8080 无 token GET 搜索 → 200（不 401） | AC-010 |
| S3-TC-007 | 经网关 /api/internal/** → 404；无可达写端点 | AC-010 |
| S3-TC-008 | 停 ES 搜索 → 503 B0501 口径一致 | AC-004 |
| S3-TC-009 | keyword 65 字符、size=0、page=abc → 400 B0502 | AC-009 |
| S3-TC-010 | 归一与 mapper 单测（trim/null/默认值/上限） | AC-008, AC-009 |

### S4 搜索筛选与排序（DU-BE-511）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S4-TC-001 | categoryId/brandId 过滤及叠加取交集 | AC-011 |
| S4-TC-002 | 价格边界 5000 命中、单边生效、区间相交（跨价区间 SKU） | AC-011 |
| S4-TC-003 | keyword+brandId+价格组合逐条满足 | AC-012 |
| S4-TC-004 | price_asc/desc 严格序；newest 按 publishedAt 降 null 排尾 | AC-013 |
| S4-TC-005 | sort=weird 静默回退 default；default 两次稳定 | AC-013 |
| S4-TC-006 | min>max/负值/非数字 → 400 B0502 | AC-011 |
| S4-TC-007 | 筛选+排序+第 2 页 total/ids 与全量一致；OFF_SALE 恒滤 | AC-009, AC-011 |
| S4-TC-008 | 排序映射/非法回退/区间校验单测 | AC-013 |

### S5 mall-web 商品搜索体验（DU-FE-501）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S5-TC-001 | 搜索框回车 → /search?keyword=；回显+卡片（图/名/价/品牌） | AC-014 |
| S5-TC-002 | 筛选/排序/分页参数正确；URL↔状态双向同步、刷新还原 | AC-015 |
| S5-TC-003 | 空态（含分类浏览出口）/骨架/503 错误态+重试 | AC-016 |
| S5-TC-004 | 浏览器 E2E：卡片 → /product/:id 详情正常可返回 | AC-017 |
| S5-TC-005 | 价格元→分换算（120 元→12000）；min>max 前端拦截不发请求 | AC-015 |
| S5-TC-006 | stores/search.ts 成功/空/失败三态；竞态仅最后一次落屏 | AC-016 |
| S5-TC-007 | pnpm type-check/lint/test/build 全绿 | AC-018 |

## 2. M5 Integration Gate（Change 级场景）

场景一（商品搜索 E2E）：compose 起 ES+服务，mall-web 经 8080 网关匿名搜索 ON_SALE 商品——关键词命中四字段、下架不可见、筛选排序分页正确、停 ES 503 B0501、恢复后 200。明细在 Test 阶段 `evidence/test-report.md` 记录。

## 3. 测试覆盖确认

- [x] 全部 18 个 Change 级 AC（AC-001~AC-018）均有 ≥1 个 TC verified-by
- [x] M5 Integration Gate 场景一在端到端联测中覆盖（含浏览器验证 S5-TC-004）
- [x] 红线：匿名可达/internal 404（AC-010）、无 ES 堆栈泄漏（AC-004）、仅摘要字段（AC-008）通过审计
- [x] 前端 AC-014~AC-018 通过组件测试+浏览器+构建门禁
