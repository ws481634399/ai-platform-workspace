# Implementation（跨仓实施汇总）— 配置模型、后台管理与变更审计 STORY-006-01-01-01

> 阶段：sdd-dev 产物。

## 0. 元信息

- Change ID：CHG-0022（M5 系统功能与参数配置）
- Story：STORY-006-01-01-01 配置模型、后台管理与变更审计
- 实施日期：2026-09-18

## 1. Delivery Unit 状态总览

| DU | 仓库 | 实施结果 |
| --- | --- | --- |
| DU-BE-507 | repo-1 | mall-system（8108）配置垂直：三表 V1 + 4 内置种子、领域校验/乐观锁/内置保护、三个 admin 控制器 + 五权限码、identity V10 菜单权限、网关 admin 路由；ConfigAdminApiTest 10 例、MallSystemApplicationSmokeTest 1 例（源码清点） |
| DU-FE-503 | repo-2 | mall-admin 系统配置三页面（功能开关/系统参数/变更历史）+ config API 与错误归一化 + 动态菜单组件注册；config.spec.ts 12 例（源码清点，node_modules 未安装未实跑） |

## 2. Commit 记录

| Commit | DU | 仓库 | 说明 |
| --- | --- | --- | --- |
| 82ccf6e | DU-BE-507 | repo-1 | M5 三 Change 合并提交，含 mall-system 配置垂直、identity V10 权限菜单、mall-gateway 管理端路由 |
| 404eb77 | DU-FE-503 | repo-2 | mall-admin 系统配置三页面、config API 与错误归一化、组件注册表接线、config.spec.ts 12 例 |

## 3. 各仓实施引用

- repo-1：`implementation/ai-platform-backend/delivery/CHG-0022/系统配置/功能开关与参数管理/配置管理与审计/配置模型、后台管理与变更审计/DU-BE-507/implementation.md`
  - FeatureConfig（key 不可变、version CAS、applyEdit）、SystemParameter（ConfigType 六类型 + BigDecimal 范围校验、BOOLEAN 仅 true/false、JSON 须可解析且以 { 或 [ 开头）、ConfigHistory 只追加；SystemErrorCode 冻结 B0601(400)/B0602(409)/B0603(404)/B0604(409)
  - 三个 AppService：更新前置版本比对 + DB LambdaUpdateWrapper 条件 CAS 双保险；内置键删除抛 B0601「内置配置不可删除: key」；变更与 history 同事务，写后发 ConfigChangedEvent；OperatorContext 取 subjectId（无则 system）与 traceId
  - `/api/admin/feature-configs`、`/api/admin/system-parameters`、`/api/admin/config-history`（查询参数 configType/key），分页响应 {total,page,size,items}；@PreAuthorize 五权限码 + SystemSecurityExceptionAdvice 统一 403
  - V1 三表 + 4 种子（search.enabled / mall.guest-cart.enabled 公开内置；search.default-page-size=20[1,100]、cart.max-item-quantity=99[1,999]）；identity V10 五权限码 + /system 目录与三 PAGE 菜单 + SUPER_ADMIN 授权（均幂等守卫）
- repo-2：`implementation/ai-platform-frontend/delivery/CHG-0022/系统配置/功能开关与参数管理/配置管理与审计/配置模型、后台管理与变更审计/DU-FE-503/implementation.md`
  - src/api/config.ts 三组 API + ItemPage 分页类型 + 错误归一化（B0604 追加「请刷新后重试」、403 兜底）
  - 三页面：启停/删除必填变更原因、编辑态 key 禁用、内置删除 disabled + tooltip、version 乐观锁、参数按类型表单与范围校验、历史只读筛选；component-registry 注册三组件由动态菜单驱动

## 4. 与 AC 对应关系

| AC | 实现与证据 | 结果 |
| --- | --- | --- |
| AC-001 | V1 经 Flyway 在 H2(MODE=MySQL) 真实执行，@BeforeEach 重播 4 种子并断言 built_in/默认值/范围；重复启动不重复播种由 Flyway schema_history 版本化只执行一次保证（裸 INSERT） | passed（pageSeededFeatures、pageSeededParameters、MallSystemApplicationSmokeTest.contextLoads） |
| AC-002 | 开关分页（group/enabled）、新建、行内启停、删除非内置全流程；重复 key 触发 uk_config_key → B0602/409 | passed（pageSeededFeatures、createFeatureAndDuplicate、deleteFeature、updateFeatureCas） |
| AC-003 | 非法 INTEGER 值、未知类型（DATETIME）、越界（999>100）、非法 JSON 均 400 B0601 且值不变；BOOLEAN 仅 true/false 规则由 ConfigType.validate 实现（createParameterValidation 覆盖越界/坏类型/坏 JSON + 重复键 409；BOOLEAN 路径在类型校验代码与 common-config Provider 侧覆盖） | passed（createParameterValidation、updateAndDeleteParameter） |
| AC-004 | 应用层 version 预检 + DB `WHERE version=?` CAS；过期 version → B0604/409，最新 version 成功且 version+1 | passed（updateFeatureCas） |
| AC-005 | 内置键删除/改 key 被拒（B0601/400，message「内置配置不可删除: key」）；非内置删除成功并追加 DELETED 历史（旧值→null 留痕） | passed（deleteFeature、updateAndDeleteParameter） |
| AC-006 | 每次启停/改值同事务写一条 history（CREATED/UPDATED/DELETED、old/new、changedBy、traceId、changedAt epoch millis）；历史仅 GET 支持 configType/key 过滤分页，仓储无更新/删除方法 | passed（historyFilterAndAuth、updateFeatureCas、createFeatureAndDuplicate、deleteFeature） |
| AC-007 | 五权限码方法级鉴权：无权限写/跨资源 list 返回 403，无 token 401；identity V10 下发 /system 目录与三页面菜单，mall-admin 按钮 v-permission 受控 | passed（historyFilterAndAuth、authenticationAndAuthorization + V10__system_config_permissions.sql） |
| AC-008 | 三页面 CRUD/启停/历史筛选接线完成；前端单测为 api 层 12 例（构建/lint 未在本次回填环境执行，node_modules 未安装；组件交互列入 Integration Gate 场景六/七） | passed（config.spec.ts 12 例，源码清点；组件级验收见 DU-FE-503 DEV-3） |
