# Implementation（跨仓实施汇总）— CHG-0021 商品搜索索引同步

> 阶段：sdd-dev 产物。本文件为 Change 级跨 Story 汇总，各 Story 实施正文见对应 Story 目录。

## 0. 元信息

- Change ID：CHG-0021（商品搜索索引同步）
- 实施日期：2026-09-18
- 范围：索引 Mapping 管理与首次全量构建（STORY-005-02-01-01）、手工重建与索引一致性检查（STORY-005-02-01-02）、商品变更增量同步（STORY-005-02-02-01）、同步幂等乱序防护与失败重试（STORY-005-02-02-02）
- 涉及仓库：repo-1 ai-platform-backend（mall-search 8107、mall-product 8103、mall-identity、mall-gateway）、repo-2 ai-platform-frontend（mall-admin）

## 1. Story 实施总览

| Story | DU | 仓库 | 状态 |
| --- | --- | --- | --- |
| STORY-005-02-01-01 索引 Mapping 管理与首次全量构建 | DU-BE-503 | repo-1 | completed（AC-006 大批量/批次失败无自动化，代码具备） |
| STORY-005-02-01-02 手工重建与索引一致性检查 | DU-BE-504 / DU-FE-502 | repo-1 / repo-2 | completed（后端）；前端 dev 完成但有状态枚举不一致遗留，须 Integration Gate 前修复 |
| STORY-005-02-02-01 商品变更增量同步 | DU-BE-505 | repo-1 | completed（回滚零调用依赖框架语义，无专项用例；跨服务 E2E 留 Integration Gate） |
| STORY-005-02-02-02 同步幂等乱序防护与失败重试 | DU-BE-506 | repo-1 | completed（AC-008 mvn 全绿执行证据留 CI/Integration Gate） |

## 2. Commit 记录

| Commit | 仓库 | 说明 |
| --- | --- | --- |
| 82ccf6e | repo-1 | feat(search,system): M5 商品搜索+索引同步+系统配置（CHG-0020/0021/0022 后端）——M5 三 Change 合并提交，CHG-0021 四个后端 DU 全部内容在其中（mall-search 索引生命周期/重建/一致性/增量受理/失败重试，mall-product 投影端点与事件链路，mall-identity V9，mall-gateway admin 路由） |
| a196082 | repo-2 | feat(search): 管理端搜索索引运维页（CHG-0021 FE-502）——仅 `src/api/search/index.ts`（117 行）与 `src/views/search/SearchIndexView.vue`（707 行）两文件，824 行新增 |
| 5a5056f | repo-2 | fix(search): FE-502 前后端枚举契约对齐——RebuildStatus/SyncFailureStatus 按 Java enum 改齐（SUCCESS/FAILED_DEAD，去除 RETRYING/SUCCEEDED/DEAD 误用） |

> 跨 Change 依赖：前端动态组件注册 `component-registry.ts` 的 `SearchIndex` 键随 CHG-0022 FE-503 一并合入，主干 HEAD 已包含；mall-search 对 mall-inventory 无本 Change 代码联动。

## 3. 各 Story 实施引用

- 索引 Mapping 管理与首次全量构建：`商品搜索/搜索索引同步/索引生命周期与全量构建/索引 Mapping 管理与首次全量构建/implementation.md`
- 手工重建与索引一致性检查：`商品搜索/搜索索引同步/索引生命周期与全量构建/手工重建与索引一致性检查/implementation.md`
- 商品变更增量同步：`商品搜索/搜索索引同步/增量同步与可靠性/商品变更增量同步/implementation.md`
- 同步幂等乱序防护与失败重试：`商品搜索/搜索索引同步/增量同步与可靠性/同步幂等乱序防护与失败重试/implementation.md`

## 4. 关键技术决策

1. **别名 + 物理索引原子切换重建**：常驻别名 `mall_products`，重建写临时索引 `mall_products_rebuild_yyyyMMddHHmmss`（UTC），灌完后单请求 `updateAliases`（remove 旧/add 新）并显式 refresh，再删旧物理索引；任一步失败任务置 FAILED、临时索引与旧别名保留可排查，保证构建期间旧搜索不中断。
2. **RUNNING 互斥与 202 受理**：`RebuildService.startRebuild()` 先查执行中任务，冲突抛 B0503（409「已有重建任务执行中，请稍后再试」）并携带当前任务；受理返回 202，M5 单实例下在请求线程内同步跑完（秒级），前端轮询对"返回即终态/仍在跑"两种情况均兼容。
3. **AFTER_COMMIT 应用事件 + 同步 HTTP 投递**：product 侧 8 个写方法发布 `ProductSearchChangedEvent(productId, operation)`，监听器仅事务提交后触发并重查当前投影决定 sync/delete，全异常 catch 不外抛（search 停摆不回滚商品写）；RestClient 超时 connect 1s/read 3s，X-Internal-Token 内部链。MQ 按 requirement-design 决策推迟 M7。
4. **updatedAt 毫秒 external_gte 乱序仲裁**：upsert 与 delete 全部携带以投影 updatedAt epoch millis 为外部版本的 external_gte 条件；旧版本 upsert/delete 的 409 统一映射 STALE_VERSION 并按成功 INFO 消化——旧下架事件不会删掉新文档；删除遇 404 归 WRITTEN 保证幂等。
5. **失败表有界退避 + 重拉投影重放**：`search_sync_failure_record` 记录 PENDING/SUCCESS/FAILED_DEAD，退避 30s/1m/2m/5m/10m、最多 5 次后 FAILED_DEAD 不再拾取；@Scheduled 30s 扫描 LIMIT 100、单条隔离；重放不信旧载荷，重拉 product 投影当前态（查无则删）；人工重试 rearm 后立即执行，未知记录 B0504 404。M5 单实例，多实例需 ShedLock（类注释已声明）。
6. **权限与路由**：mall-identity V9 幂等种子 `search:index:list`/`search:index:rebuild` 两权限码 + 「搜索索引/索引管理」菜单（component_key=SearchIndex）+ SUPER_ADMIN 授权；gateway 新增 `/api/admin/search/**`→8107 路由，`/api/internal/**` 全局 denyAll 返 404；mall-search 方法级 @PreAuthorize 与角色链（/api/mall permitAll、internal SERVICE、admin ADMIN）双重保证。

## 5. 测试证据与遗留风险

### 5.1 自动化用例（方法级清点，工作区无 target/surefire-reports，未杜撰执行数字）

| 测试类 | 模块 | 用例数 | 覆盖 |
| --- | --- | --- | --- |
| IndexSyncIntegrationTest（真实 ES Testcontainers 8.17.4 + H2 + 真实安全链） | mall-search | 9 | ensureIndex 幂等/standard 回退、sync 受理可搜、乱序 upsert/版本化删除、删除幂等、完整重建别名切换、一致性差集、鉴权 401/403、重建冲突 409 |
| SyncFailureFlowTest（H2 + Mockito） | mall-search | 6 | 故障受理落 PENDING、退避序列与 FAILED_DEAD、重放成功/陈旧消化、投影缺失删除、人工重试复活/B0504、故障去重复用行 |
| ProductSearchSyncEventTest | mall-product | 2 | CREATE/publish/unpublish 事件链（sync/delete 分流、价区断言）、监听器异常不阻写接口 |
| ProductSearchProjectionApiTest | mall-product | 4 | 在架分页口径/total/价区、id 升序分页、无令牌 401、单条 200 与 404 场景 |
| 合计 | — | **21** | 另 ElasticsearchSmokeTest 1 例属 CHG-0020，作 ES 环境旁证 |

前端 mall-admin 本地实测（2026-09-18）：`pnpm type-check` ✅、`pnpm lint` 0 error（221 全仓存量 warning）、`pnpm test` 16 文件 47 用例全通过（无 SearchIndexView 专属 spec）、`pnpm build` ✅。

### 5.2 遗留与风险

1. **前端状态枚举跨端不一致（须修复）**：`api/search/index.ts` 使用 SUCCEEDED/DEAD/RETRYING，后端实际返回 SUCCESS/FAILED_DEAD（无 RETRYING）。影响重建成功终态误报、失败记录标签/筛选、FAILED_DEAD 人工重试入口隐藏。详见 DU-FE-502 DEV-4，Integration Gate 前须对齐。
2. **自动化缺口**：1001 条分批与批次失败 FAILED、重建失败注入、一致性 missing/超 200 截断、ES 真实停启恢复调度、网关 401/404 E2E、V9 种子断言、事务回滚零同步、跨服务 5s 时延均无自动化，代码路径具备，建议 Integration Gate 优先补齐高风险项。
3. **M5 已接受边界**：单实例部署（调度与去重无分布式锁，多实例需 ShedLock）；product 完全调不通 search 的丢失窗口依赖人工一致性检查发现；重建同步执行占用请求线程（千级商品秒级）；无 IK 插件环境分词退化为 standard。
4. **执行证据**：后端未在本机运行 `mvn test`（真实 ES 用例需 Docker），无 surefire 报告；全绿结论以 CI / Integration Gate 执行为准。
