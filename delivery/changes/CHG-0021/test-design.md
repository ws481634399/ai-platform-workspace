# Test Design（Change 级聚合）— CHG-0021 M5 搜索索引同步

> 阶段：sdd-task 聚合产物（4 Story Change）；各 Story 明细见对应目录 test-design.md。

- Change ID: CHG-0021
- Feature Path: 商品搜索
- 覆盖 Story: Mapping 与首次全量 9、手工重建与检查 8、增量同步 9、幂等乱序与重试 8，共 34 TC；另含 Change 级 M5 Integration Gate 场景二/三/四/五。

## 1. 测试用例

### S1 索引 Mapping 管理与首次全量构建（DU-BE-503）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S1-TC-001 | 空 ES 启动 ApplicationRunner → mall_products_v1+别名 mall_products；再跑 ensureIndex 幂等不覆盖 mapping | AC-001 |
| S1-TC-002 | mapping 断言 price long、productId keyword、mainImage index=false、日期 date；定义在代码资源 | AC-002 |
| S1-TC-003 | 投影端点无内部令牌 401/403；SERVICE 凭据分页返回投影+total；网关 404（Gate 验） | AC-003 |
| S1-TC-004 | SQL EXISTS 过滤：ON_SALE 无启用 SKU/OFF_SALE 不入投影；价格=启用 SKU 极值 | AC-004 |
| S1-TC-005 | 全量构建后 ES _count=投影 total；抽样字段（名/类目品牌/图/价/日期）正确 | AC-004 |
| S1-TC-006 | 1001 条造数批次数≥3；第 2 批 mock 失败 → FAILED+error_message 含批次/productId | AC-004 |
| S1-TC-007 | Flyway mall_search V1 两表列/索引齐全 | AC-001 |
| S1-TC-008 | ES 停机启动：ensureIndex 捕获不阻止启动、ERROR 日志、health DOWN | AC-001 |
| S1-TC-009 | 单商品投影：下架 data=null；正常字段完整 | AC-003, AC-004 |

### S2 手工重建与索引一致性检查（DU-BE-504 / DU-FE-502）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S2-TC-001 | 重建中并发搜索走旧索引可用；完成后别名指新索引、新数据可搜、旧索引 404 | AC-005 |
| S2-TC-002 | RUNNING→SUCCEEDED 进度一致；中途失败 FAILED 且别名/旧索引不变 | AC-006 |
| S2-TC-003 | 首触发 200 {taskNo,RUNNING}；并发再触发 409 B0503 可定位 taskId | AC-006 |
| S2-TC-004 | 一致性检查：相等/3 missing/2 extra/>200 truncated=true 列表 200 | AC-007 |
| S2-TC-005 | 无 search:index:rebuild/list 权限 403；网关未登录 /api/admin/search/** 401 | AC-008 |
| S2-TC-006 | identity V9 权限/菜单种子存在并授予超管 | AC-008 |
| S2-TC-007 | Vitest：列表/confirm/禁用轮询/409 提示/差异表格 | AC-008 |
| S2-TC-008 | mall-admin type-check/lint/test/build 全绿 | AC-008 |

### S3 商品变更增量同步（DU-BE-505）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S3-TC-001 | 上架/新建上架事务提交后 ≤5s 可检出（UPSERT） | AC-009 |
| S3-TC-002 | 改名/改类目品牌/换主图字段更新；SKU 改价刷新 min/max | AC-010 |
| S3-TC-003 | 下架硬删除（doc 404、不可搜）；重复下架/不存在 id 200 幂等 | AC-011 |
| S3-TC-004 | 启用 SKU 极值变化/禁用唯一低价 SKU 摘要正确；最后启用 SKU 禁用 → 文档删除 | AC-010, AC-011 |
| S3-TC-005 | 停 mall-search 调上架仍 200 落库、product WARN；恢复不影响已提交事务 | AC-012 |
| S3-TC-006 | AFTER_COMMIT 单测：回滚不推送/提交推送/7 写方法 op 映射（下架类 DELETE） | AC-009, AC-011 |
| S3-TC-007 | internal sync 无 SERVICE 凭据 401/403；网关内部路径 404 | AC-012 |
| S3-TC-008 | sync upsert 200 {accepted:true}；DELETE 不存在 200 幂等 | AC-011 |
| S3-TC-009 | SearchSyncClient connect 1s/read 3s 超时配置断言 | AC-012 |

### S4 同步幂等乱序防护与失败重试（DU-BE-506）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S4-TC-001 | 相同 upsert 连投两次：仅 1 文档字段最新、无脏 failure_record | AC-013 |
| S4-TC-002 | v200 后投 v100：文档保持 v200、接口 200（VersionConflict 消化 INFO） | AC-014 |
| S4-TC-003 | v200 upsert 后 v100 delete：文档仍在，旧事件忽略有日志 | AC-014 |
| S4-TC-004 | 停 ES sync 返 200 受理+PENDING 记录；恢复后调度拾取 SUCCESS 可搜 | AC-015 |
| S4-TC-005 | 退避 30s/1m/2m/5m/10m next_retry_at；5 次后 FAILED_DEAD 不再拾取（可注入 Clock） | AC-016 |
| S4-TC-006 | 手动 retry FAILED_DEAD（ES 恢复）→ PENDING→成功；不存在 id 404 B0504 | AC-016 |
| S4-TC-007 | 重试拉投影为下架 → DELETE+SUCCESS；重新上架后重试 upsert 成功 | AC-015, AC-016 |
| S4-TC-008 | mvn -pl mall-services/mall-search -am test 全绿（含 IT） | AC-017 |

## 2. M5 Integration Gate（Change 级场景）

- 场景二（改名同步）：mall-admin/mall-web 改商品名/类目品牌/主图，提交后轮询搜索接口，ES 文档字段更新可搜。
- 场景三（下架硬删除）：后台下架商品 → 搜索不可见、doc 404；订单/详情链路不读搜索价格。
- 场景四（改价摘要）：SKU 增删/改价后 minPrice/maxPrice 摘要刷新；最后启用 SKU 禁用文档删除。
- 场景五（ES 故障恢复）：停 mall-search/ES 期间上架仍 200 落库、failure_record PENDING；恢复后定时补偿 SUCCESS、手动 retry FAILED_DEAD 成功。

明细在 Test 阶段 `evidence/test-report.md` 记录。

## 3. 测试覆盖确认

- [x] 全部 17 个 Change 级 AC（AC-001~AC-017）均有 ≥1 个 TC verified-by
- [x] M5 Integration Gate 场景二/三/四/五在端到端联测中覆盖（AC-017）
- [x] 红线：投影端点 SERVICE 身份+网关 404（AC-003）、主流程不被同步故障拖垮（AC-012）、external_gte 防乱序（AC-014）通过审计
- [x] 前端 AC-008 经 Vitest+构建门禁覆盖
