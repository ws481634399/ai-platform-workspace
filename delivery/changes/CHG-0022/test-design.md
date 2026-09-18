# Test Design（Change 级聚合）— CHG-0022 M5 系统配置

> 阶段：sdd-task 聚合产物（3 Story Change）；各 Story 校验细节见对应目录 test-design.md。

- Change ID: CHG-0022
- Feature Path: 系统配置
- 覆盖 Story: 配置模型与后台管理 10、Redis 缓存与访问边界 8、开关动态生效与公开配置 8，共 26 TC；另含 M5 Integration Gate 场景六/七。

## 1. 测试用例

### S1 配置模型、后台管理与变更审计（DU-BE-507 / DU-FE-503）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S1-TC-001 | mall_system V1 三表+4 种子键 built_in=1；重复迁移幂等 | AC-001 |
| S1-TC-002 | 开关分页/分组/启停/新建/删除非内置全流程；重复 key 409 B0602 | AC-002 |
| S1-TC-003 | INTEGER 写 abc/JSON 非法/越界/BOOLEAN 写 yes → 400 B0601 库值不变 | AC-003 |
| S1-TC-004 | 旧 version 更新 409 B0604；最新 version 200 且 version+1 | AC-004 |
| S1-TC-005 | DELETE/PUT 内置键拒绝；改值允许；删非内置写 history | AC-004 |
| S1-TC-006 | 改值/启停各写 history（old/new/operator/traceId）；history 过滤分页；只追加 | AC-005 |
| S1-TC-007 | 缺 system:feature:update 写 403 读 200；history 需 config-history:list；identity V10 种子 | AC-006 |
| S1-TC-008 | 不存在 id 更新/删除 → 404 B0603 | AC-002, AC-004 |
| S1-TC-009 | Vitest：三页面/切换/类型校验/范围提示/历史筛选/409 提示 | AC-007 |
| S1-TC-010 | mall-admin type-check/lint/test/build 全绿 | AC-007 |

### S2 Redis 配置缓存与统一访问边界（DU-BE-508）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S2-TC-001 | 首次读回源并写 `aimall:{env}:system:feature:{key}` TTL≈600s；二次零回源 | AC-008 |
| S2-TC-002 | 更新提交后单键与 public-features 聚合键删除；再读新值 TTL 重建 | AC-008 |
| S2-TC-003 | 内部端点无 SERVICE 401/403、网关 404；只返回请求键；missingKeys；keys>100 → 400 | AC-009 |
| S2-TC-004 | getString/getInt/getLong/getDecimal/getBoolean 正确；错类型 → default+WARN | AC-010 |
| S2-TC-005 | 停 Redis+HTTP 503 → 代码默认不抛、业务 200；ensureEnabled 缺键默认放行 WARN | AC-010 |
| S2-TC-006 | 本地 TTL 注入 100ms 更新即时可见；负缓存 missing key 60s | AC-008, AC-016 |
| S2-TC-007 | grep 审计：消费服务无 mall_system 数据源/DAO/Mapper，仅依赖 mall-common-config | AC-011 |
| S2-TC-008 | mall-system+common-config+消费服务 mvn test 绿；AutoConfiguration.imports 上下文加载 | AC-010, AC-011 |

### S3 功能开关动态生效与前端公开配置（DU-BE-509 / DU-FE-504）

| TC | 验证方式 | verified-by AC |
| --- | --- | --- |
| S3-TC-001 | 匿名 GET /api/mall/public-features 200 仅 publicFlag=1 的 [{key,enabled}] | AC-014 |
| S3-TC-002 | search.enabled true→false ≤60s 搜索 403 B0606；重开恢复 200 | AC-012 |
| S3-TC-003 | features store：搜索入口 v-if 显隐；false 态 /search 未开放空态；重开恢复 | AC-015 |
| S3-TC-004 | guest-cart.enabled=false：游客 merge-token/merge（M4 游客车服务端唯一入口）403 B0606，匿名加购由前端禁用+登录引导拦截；会员 /cart/items 200；重开恢复 | AC-013 |
| S3-TC-005 | effectType 管理页明示；切换到后端拒绝时延 ≤60s（可注入 TTL） | AC-016 |
| S3-TC-006 | public-features 503/断网：mall-web fail-open 默认可见；服务端全失按代码默认 | AC-010 |
| S3-TC-007 | mall-search/mall-cart mvn test 绿；mall-web vitest+type-check/lint/build 绿 | AC-017 |
| S3-TC-008 | 网关：匿名 public-features 200；/api/admin/system-parameters 未登录 401 | AC-014 |

## 2. M5 Integration Gate（Change 级场景）

- 场景六（开关动态生效）：mall-admin 关闭 search.enabled → ≤本地缓存 TTL 内 mall-web 隐藏入口、直接访问搜索 403 B0606、游客购物车开关联动验证；重开恢复。
- 场景七（缓存一致性）：改值后 Redis 单键/聚合键立即失效，mall-search、mall-cart 经内部端点重读新值；Redis 与 system 全失时 fail-open 业务不中断。

明细在 Test 阶段 `evidence/test-report.md` 记录。

## 3. 测试覆盖确认

- [x] 全部 17 个 Change 级 AC（AC-001~AC-017）均有 ≥1 个 TC verified-by
- [x] M5 Integration Gate 场景六/七在端到端联测中覆盖（AC-017）
- [x] 红线：消费服务不直连 mall_system 库（AC-011）、内部端点 SERVICE 身份+网关 404（AC-009）、后端开关拒绝（AC-012/013）通过审计
- [x] 前端 AC-007/AC-015 经 Vitest+构建门禁+浏览器验证覆盖
