# Implementation（跨仓实施汇总）— CHG-0022 M5 系统功能与参数配置

> 阶段：sdd-dev 产物。本文件为 Change 级跨 Story 汇总，各 Story 实施正文见对应 Story 目录。

## 0. 元信息

- Change ID：CHG-0022（M5 系统功能与参数配置）
- 实施日期：2026-09-18
- 范围：系统配置模型/后台管理/变更审计（S1）、Redis 配置缓存与统一访问边界（S2）、功能开关动态生效与前端公开配置（S3）

## 1. Story 实施总览

| Story | DU | 仓库 | 状态 |
| --- | --- | --- | --- |
| STORY-006-01-01-01 配置模型、后台管理与变更审计 | DU-BE-507 / DU-FE-503 | repo-1 / repo-2 | completed |
| STORY-006-02-01-01 Redis 配置缓存与统一访问边界 | DU-BE-508 | repo-1 | completed |
| STORY-006-02-01-02 功能开关动态生效与前端公开配置 | DU-BE-509 / DU-FE-504 | repo-1 / repo-2 | completed |

## 2. Commit 记录

| Commit | 仓库 | 说明 |
| --- | --- | --- |
| 82ccf6e | repo-1 | M5 三 Change 合并提交：mall-system 配置垂直（三表 V1/4 种子/领域与应用服务/三 admin 控制器/安全链/缓存服务/内部端点/公开端点）、mall-common-config 新模块（三级读客户端/Gate/Provider）、mall-search 与 mall-cart 消费切点、mall-identity V10 权限菜单、mall-gateway 管理端与公开路由 |
| 404eb77 | repo-2 | DU-FE-503：mall-admin 功能开关/系统参数/变更历史三页面与 config API（12 例单测） |
| af19b9e | repo-2 | DU-FE-504：mall-web 公开开关 store（fail-open）、搜索入口与游客加购受控（features.spec 3 例 + 商品详情新增 2 例） |

## 3. 各 Story 实施引用

- 配置模型、后台管理与变更审计：`系统配置/功能开关与参数管理/配置管理与审计/配置模型、后台管理与变更审计/implementation.md`
- Redis 配置缓存与统一访问边界：`系统配置/配置缓存与动态生效/缓存分发与生效/Redis 配置缓存与统一访问边界/implementation.md`
- 功能开关动态生效与前端公开配置：`系统配置/配置缓存与动态生效/缓存分发与生效/功能开关动态生效与前端公开配置/implementation.md`

## 4. 关键技术决策

1. **乐观锁 version CAS 双保险**：应用服务更新前先做版本预检，落库再以 `WHERE id=? AND version=?` 条件 UPDATE 仲裁，rows=0 即 B0604 CONFIG_VERSION_CONFLICT/409；前端编辑表单携带 version，冲突（B0604）提示「请刷新后重试」。
2. **内置配置保护**：built_in=true 的键 key 不可变、禁止删除（B0601，message「内置配置不可删除: {key}」），仅 enabled/value 等可改；需求草图中的 B0605 未启用，内置保护并入 B0601 语义。
3. **三级读取 + 有界时延**：消费侧「本地 ConcurrentHashMap 60s（无清理线程，currentTimeMillis 判定）→ Redis 600s（负标记 60s）→ HTTP RestClient 直连 mall-system 8108（X-Internal-Token）」；管理端提交后 AFTER_COMMIT 同步删 Redis 单键并恒删 public-features 聚合键，全服务最坏 60s 收敛；所有 Redis/HTTP 故障吞掉降级，FeatureGate fail-open（仅显式 false 拦截，B0606/403），不中断业务。
4. **Redis 唯一写者与键冻结**：mall-system ConfigCacheService 是配置命名空间唯一读写者（HTTP 回源由服务端回填，消费客户端只读）；键 `aimall:{env}:system:feature:{key}` / `:parameter:{key}` / `:public-features`，env 统一由 Environment.getActiveProfiles()[0] 解析（空→dev），两侧实现一致避免键空间错配。
5. **错误码 B06 段跨服务统一定义**：B0601~B0604 + B0606 在 mall-common-config ConfigErrorCode 统一定义，mall-system 与 mall-search/mall-cart 共用；FeatureDisabledException 由 common-config 自动装配的 advice 统一转 403 UnifyResult。
6. **4 个内置种子宁少勿滥**：search.enabled、mall.guest-cart.enabled（公开开关，默认 true）+ search.default-page-size=20[1,100]、cart.max-item-quantity=99[1,999]（INTEGER、DYNAMIC）；V1 裸 INSERT，重复启动不重复播种由 Flyway 版本化迁移保证。
7. **权限/菜单/路由配套**：identity V10 幂等插入五权限码 + 「系统配置」目录与三 PAGE 菜单（component_key=FeatureConfigs/SystemParameters/ConfigHistory）并向 SUPER_ADMIN 授权；mall-admin 走动态菜单 + 组件注册表（无静态路由）；网关拆 mall-system-admin（ADMIN）与 mall-system-mall（public-features 白名单）两路由，内部端点 /api/internal/** 在网关 denyAll。
8. **切点最小化、会员不受影响**：search 切点在 ProductSearchService.search 首行；游客车切点仅 merge-token/merge——M4 游客数据在服务端的唯一入口（游客暂存为前端 LocalStorage），会员全部端点不接 Gate；前端以「入口隐藏 + 空态 + 按钮禁用 + 方法兜底」先于请求受控，后端 Gate 为权威安全边界。
9. **公开端点数组契约**：GET /api/mall/public-features 的 UnifyResult.data 直接为数组（非分页 items 包裹），仅暴露 key/enabled 两字段，非公开键与系统参数不出域。
